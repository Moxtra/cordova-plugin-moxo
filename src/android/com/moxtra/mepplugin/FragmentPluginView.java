package com.moxtra.mepplugin;

import android.graphics.RectF;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import androidx.annotation.IdRes;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentActivity;
import androidx.fragment.app.FragmentManager;

import com.moxtra.mepsdk.MEPClient;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaWebView;
import org.json.JSONArray;

public class FragmentPluginView implements IPluginView {
    private CordovaInterface mCordova;
    private CordovaWebView mWebView;
    private float mTop, mLeft, mWidth, mHeight;
    private FrameLayout mFrameLayout;
    private @IdRes
    int mLayoutId;

    public FragmentPluginView(CordovaInterface cordova, final CordovaWebView webView) {
        this.mCordova = cordova;
        this.mWebView = webView;

        mLayoutId = cordova.getActivity().getResources().getIdentifier("layout_container", "id", cordova.getActivity().getPackageName());
        mFrameLayout = new FrameLayout(this.mCordova.getContext());
        FrameLayout.LayoutParams layoutParams = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
        mFrameLayout.setLayoutParams(layoutParams);
        mFrameLayout.setId(mLayoutId);
    }

    @Override
    public boolean getVisible() {
        return true;
    }

    @Override
    public boolean getClickable() {
        return true;
    }

    @Override
    public String getOverlayId() {
        return FragmentPluginView.class.getSimpleName() + FragmentPluginView.this.hashCode();
    }

    @Override
    public ViewGroup getView() {
        return mFrameLayout;
    }

    @Override
    public int getViewDepth() {
        return 0;
    }

    @Override
    public void onDestroy() {

    }

    @Override
    public void onStart() {

    }

    @Override
    public void onStop() {

    }

    @Override
    public void onPause(boolean multitasking) {

    }

    @Override
    public void onResume(boolean multitasking) {

    }

    @Override
    public void remove(JSONArray args, CallbackContext callbackContext) {

    }

    @Override
    public void attachToWebView(JSONArray args, CallbackContext callbackContext) {

    }

    @Override
    public void detachFromWebView(JSONArray args, CallbackContext callbackContext) {

    }

    public void setArea(float top, float left, float width, float height) {
        this.mTop = top;
        this.mLeft = left;
        this.mWidth = width;
        this.mHeight = height;
    }

    public void resizeFragment(boolean isLite) {
        Fragment fragment = MEPClient.createTimelineFragment(isLite);
        resizeFragment(fragment);
    }

    public void resizeFragment(Fragment fragment) {
        if (fragment == null) {
            return;
        }
        this.mCordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {

                RectF drawRect = new RectF(mLeft, mTop, mLeft + mWidth, mTop + mHeight);

                if (drawRect != null) {
                    final int scrollY = mWebView.getView().getScrollY();

                    int width = (int) drawRect.width();
                    int height = (int) drawRect.height();
                    int x = (int) drawRect.left;
                    int y = (int) drawRect.top + scrollY;
                    ViewGroup.LayoutParams lParams = mFrameLayout.getLayoutParams();
                    FrameLayout.LayoutParams params = (FrameLayout.LayoutParams) lParams;

                    params.width = width;
                    params.height = height;
                    params.leftMargin = x;
                    params.topMargin = y;
                    mFrameLayout.setLayoutParams(params);

                    FragmentManager fragmentManager = ((FragmentActivity) mCordova.getActivity()).getSupportFragmentManager();
                    if (mCordova.getActivity() instanceof FragmentActivity) {
                        ((FragmentActivity) mCordova.getActivity()).getSupportFragmentManager();
                    }
                    fragmentManager.beginTransaction().add(mLayoutId, fragment).commitAllowingStateLoss();
                }
            }
        });
    }
}
