package com.moxtra.mepplugin;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.content.res.Resources;
import android.graphics.Color;
import android.graphics.PointF;
import android.graphics.RectF;
import android.text.TextUtils;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewTreeObserver;
import android.widget.FrameLayout;
import android.widget.ScrollView;

import org.apache.cordova.CordovaWebView;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.ConcurrentHashMap;

@SuppressWarnings("deprecation")
public class PluginLayout extends FrameLayout implements ViewTreeObserver.OnScrollChangedListener, ViewTreeObserver.OnGlobalLayoutListener {
    private static final String TAG = "PluginLayout";
    private View browserView;
    private Context context;
    private FrontLayerLayout frontLayer;
    private ScrollView scrollView;
    public FrameLayout scrollFrameLayout;
    public Map<String, IPluginView> pluginOverlays = new ConcurrentHashMap<String, IPluginView>();
    private Map<String, TouchableWrapper> touchableWrappers = new ConcurrentHashMap<String, TouchableWrapper>();
    private boolean isScrolling = false;
    public final Object _lockHtmlNodes = new Object();
    private Activity mActivity = null;
    public boolean stopFlag = false;
    public boolean isSuspended = false;
    private float zoomScale;
    private static final Object timerLock = new Object();
    private RectF mDrawRect;
    private Map<String, RectF> mDivPosMap = new HashMap<>();

    private static Timer redrawTimer;

    @Override
    public void onGlobalLayout() {
        ViewTreeObserver observer = browserView.getViewTreeObserver();
        observer.removeGlobalOnLayoutListener(this);
        observer.addOnScrollChangedListener(this);
    }

    private Runnable resizeWorker = new Runnable() {
        @Override
        public void run() {
            final int scrollY = browserView.getScrollY();
            final int scrollX = browserView.getScrollX();

            Set<String> keySet = pluginOverlays.keySet();
            String[] toArrayBuf = new String[pluginOverlays.size()];
            String[] layoutIds = keySet.toArray(toArrayBuf);
            String layoutId;
            IPluginView pluginOverlay;
            for (int i = 0; i < layoutIds.length; i++) {
                layoutId = layoutIds[i];
                if (layoutId == null) {
                    continue;
                }
                pluginOverlay = pluginOverlays.get(layoutId);

                if (mDrawRect == null || mDrawRect.left == 0 && mDrawRect.top == 0 && mDrawRect.width() == 0 && mDrawRect.height() == 0) {
                    continue;
                }

                int width = (int) mDrawRect.width();
                int height = (int) mDrawRect.height();
                int x = (int) mDrawRect.left;
                int y = (int) mDrawRect.top + scrollY;

                ViewGroup.LayoutParams lParams = pluginOverlay.getView().getLayoutParams();
                LayoutParams params = (LayoutParams) lParams;
                //Log.d("MyPluginLayout", "-->FrameLayout x = " + x + ", y = " + y + ", w = " + width + ", h = " + height);
                if (params.leftMargin == x && params.topMargin == y &&
                        params.width == width && params.height == height) {
                    continue;
                }
                params.width = width;
                params.height = height;
                params.leftMargin = x;
                params.topMargin = y;
                pluginOverlay.getView().setLayoutParams(params);
            }
        }
    };

    public void updateMapPositions() {
        mActivity.runOnUiThread(resizeWorker);
    }

    private class ResizeTask extends TimerTask {
        @Override
        public void run() {
            mActivity.runOnUiThread(resizeWorker);
        }
    }

    @SuppressLint("NewApi")
    public PluginLayout(CordovaWebView webView, Activity activity) {
        super(webView.getView().getContext());
        this.browserView = webView.getView();
        browserView.getViewTreeObserver().addOnGlobalLayoutListener(this);
        mActivity = activity;
        ViewGroup root = (ViewGroup) browserView.getParent();
        this.context = browserView.getContext();

        zoomScale = Resources.getSystem().getDisplayMetrics().density;
        frontLayer = new FrontLayerLayout(this.context);

        scrollView = new ScrollView(this.context);
        scrollView.setLayoutParams(new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));

        root.removeView(browserView);
        frontLayer.addView(browserView);

        scrollFrameLayout = new FrameLayout(this.context);
        scrollFrameLayout.setLayoutParams(new LayoutParams(LayoutParams.MATCH_PARENT, 9999));

        scrollView.setHorizontalScrollBarEnabled(true);
        scrollView.setVerticalScrollBarEnabled(true);
        scrollView.setBackgroundColor(Color.WHITE);
        scrollView.addView(scrollFrameLayout);

        browserView.setDrawingCacheEnabled(false);

        this.addView(scrollView);
        this.addView(frontLayer);
        root.addView(this);
        browserView.setBackgroundColor(Color.TRANSPARENT);
        scrollView.setHorizontalScrollBarEnabled(false);
        scrollView.setVerticalScrollBarEnabled(false);
        startTimer();
    }

    public synchronized void stopTimer() {
        synchronized (timerLock) {
            try {
                if (redrawTimer != null) {
                    redrawTimer.cancel();
                    redrawTimer.purge();
                    ResizeTask task = new ResizeTask();
                    task.run();
                    isSuspended = true;
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
            redrawTimer = null;
        }
    }

    public synchronized void startTimer() {
        synchronized (timerLock) {
            if (redrawTimer != null) {
                return;
            }

            redrawTimer = new Timer();
            redrawTimer.scheduleAtFixedRate(new ResizeTask(), 0, 25);
            isSuspended = false;
        }
    }

    public void setDrawRect(RectF rectF) {
        this.mDrawRect = rectF;
    }

    public IPluginView removePluginOverlay(final String overlayId) {
        if (pluginOverlays == null || !pluginOverlays.containsKey(overlayId)) {
            return null;
        }
        final IPluginView pluginOverlay = pluginOverlays.remove(overlayId);

        mActivity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    scrollFrameLayout.removeView(pluginOverlay.getView());
                    pluginOverlay.getView().removeView(touchableWrappers.remove(overlayId));
                } catch (Exception e) {
                    // ignore
                    e.printStackTrace();
                }
            }
        });
        return pluginOverlay;
    }

    public void addPluginOverlay(final IPluginView pluginOverlay) {
        pluginOverlays.put(pluginOverlay.getOverlayId(), pluginOverlay);

        mActivity.runOnUiThread(new Runnable() {
            @Override
            public void run() {

                if (pluginOverlay.getView().getParent() == null) {
                    TouchableWrapper wrapper = new TouchableWrapper(context);
                    touchableWrappers.put(pluginOverlay.getOverlayId(), wrapper);
                    pluginOverlay.getView().addView(wrapper);
                    int childCnt = scrollFrameLayout.getChildCount();
                    scrollFrameLayout.addView(pluginOverlay.getView(), childCnt - 1);
                }
            }
        });
    }

    public void scrollTo(int x, int y) {
        this.scrollView.scrollTo(x, y);
    }

    public void inValidate() {
        this.frontLayer.invalidate();
    }

    @Override
    public void onScrollChanged() {
        scrollView.scrollTo(browserView.getScrollX(), browserView.getScrollY());
    }

    private class FrontLayerLayout extends FrameLayout {

        public FrontLayerLayout(Context context) {
            super(context);
            this.setWillNotDraw(false);
        }

        @Override
        public boolean onInterceptTouchEvent(MotionEvent event) {
            if (pluginOverlays == null || pluginOverlays.size() == 0) {
                return false;
            }
            PluginLayout.this.stopFlag = true;

            int action = event.getAction();
            isScrolling = action != MotionEvent.ACTION_UP && isScrolling;
            if (isScrolling) {
                PluginLayout.this.stopFlag = false;
                return false;
            }

            IPluginView pluginOverlay;
            Iterator<Entry<String, IPluginView>> iterator = pluginOverlays.entrySet().iterator();
            Entry<String, IPluginView> entry;

            PointF clickPoint = new PointF(event.getX(), event.getY());

            synchronized (_lockHtmlNodes) {
                while (iterator.hasNext()) {
                    entry = iterator.next();
                    pluginOverlay = entry.getValue();

                    if (!pluginOverlay.getVisible() || !pluginOverlay.getClickable()) {
                        continue;
                    }

                    if (mDrawRect == null || !mDrawRect.contains(clickPoint.x, clickPoint.y)) {
                        continue;
                    }

                    if (mDivPosMap != null && !mDivPosMap.isEmpty()) {
                        for (RectF rectF : mDivPosMap.values()) {
                            if (rectF != null && rectF.contains(clickPoint.x, clickPoint.y)) {
                                return false;
                            }
                        }
                    }

                    return true;
                }
            }
            isScrolling = (action == MotionEvent.ACTION_DOWN) || isScrolling;
            return false;
        }
    }

    @Override
    public boolean onInterceptTouchEvent(MotionEvent event) {
        return false;
    }

    private class TouchableWrapper extends FrameLayout {

        public TouchableWrapper(Context context) {
            super(context);
        }

        @Override
        public boolean dispatchTouchEvent(MotionEvent event) {
            int action = event.getAction();
            if (action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_UP) {
                scrollView.requestDisallowInterceptTouchEvent(true);
            }
            return super.dispatchTouchEvent(event);
        }
    }

    public void addDivRect(String divId, RectF divRectF) {
        if (mDivPosMap != null && !TextUtils.isEmpty(divId) && divRectF != null) {
            mDivPosMap.put(divId, divRectF);
        }
    }

    public void removeDivRect(String divId) {
        if (mDivPosMap != null && !TextUtils.isEmpty(divId) && mDivPosMap.containsKey(divId)) {
            mDivPosMap.remove(divId);
        }
    }
}
