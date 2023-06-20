package com.moxtra.mepplugin;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.Application;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.RectF;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewTreeObserver;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

import com.moxtra.mepsdk.ErrorCodes;
import com.moxtra.mepsdk.FeatureConfig;
import com.moxtra.mepsdk.MEPClient;
import com.moxtra.mepsdk.MEPClientDelegate;
import com.moxtra.mepsdk.data.MEPChat;
import com.moxtra.mepsdk.data.MEPScheduleMeetOptions;
import com.moxtra.mepsdk.data.MEPStartMeetOptions;
import com.moxtra.sdk.LinkConfig;
import com.moxtra.sdk.chat.model.ChatMember;
import com.moxtra.sdk.common.ActionListener;
import com.moxtra.sdk.common.ApiCallback;
import com.moxtra.sdk.common.model.User;
import com.moxtra.sdk.meet.model.Meet;

import org.apache.commons.lang3.StringUtils;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.LOG;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;

import static com.moxtra.mepplugin.ErrorCodeUtil.MEPNotLinkedError;

/**
 * Created by Moxtra on 05/28/19.
 */

public class MoxtraPlugin extends CordovaPlugin implements ViewTreeObserver.OnScrollChangedListener {

    private static final String TAG = MoxtraPlugin.class.getName();

    private CallbackContext mOnLogoutCallback;

    private CallbackContext mOnLogoutClickedCallback;

    private CallbackContext mOnCloseButtonClickedCallback;

    private CallbackContext mOnAddMemberInChatClickedCallback;

    private CallbackContext mOnJoinMeetButtonClickedCallback;

    private CallbackContext mOnCallButtonClickedCallback;

    private CallbackContext mOnMeetViewButtonClickedCallback;

    private CallbackContext mOnMeetEditButtonClickedCallback;

    private CallbackContext mOnInviteButtonInLiveMeetClickedCallback;

    private CallbackContext mCanAddUserInChatCallback;

    private static final String NOTIFICATION_ACTION = "com.moxtra.notification_action";
    private static final String UNREAD_ALL = "unread_all";
    private static Application.ActivityLifecycleCallbacks callbacks;

    private Activity activity;
    private ViewGroup root;
    private PluginLayout mPluginLayout = null;
    private FragmentPluginView mFragmentPluginView;
    private List<Activity> mActivityList;
    private CountDownLatch mCountDownLatch;
    private Boolean mAddUserInChatResult = true;
    private Map<String, CallbackContext> mUnreadCountCallbackMap;
    private Map<String, Integer> mUnreadCountMap;

    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
        Log.d(TAG, "Init plugin...");

        if (root != null) {
            return;
        }
        LOG.setLogLevel(LOG.ERROR);
        setActivityChangedListener(false);
        activity = cordova.getActivity();
        createNotificationChannel(activity.getPackageName());
        final View view = webView.getView();
        view.getViewTreeObserver().addOnScrollChangedListener(MoxtraPlugin.this);
        root = (ViewGroup) view.getParent();

        cordova.getActivity().runOnUiThread(new Runnable() {
            @SuppressLint("NewApi")
            public void run() {
                webView.getView().setBackgroundColor(Color.TRANSPARENT);
                webView.getView().setOverScrollMode(View.OVER_SCROLL_NEVER);
                mPluginLayout = new PluginLayout(webView, activity);
                mPluginLayout.stopTimer();
            }
        });

        mUnreadCountCallbackMap = new HashMap<>();
        mUnreadCountMap = new HashMap<>();
        //MEP Feature config
        FeatureConfig.hideFABOnTimeline(true);
    }

    public MoxtraPlugin() {

    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) {
        try {
            if (action.equals("setupDomain")) {
                setupDomain(args);
            } else if (action.equals("linkWithAccessToken")) {
                initWithAccessToken(args, callbackContext);
            } else if (action.equals("showMEPWindow")) {
                showMEPWindow();
            } else if (action.equals("hideMEPWindow")) {
                hideMEPWindow();
            } else if (action.equals("destroyMEPWindow")) {
                destroyMEPWindow();
            } else if (action.equals("openChat")) {
                openChat(args, callbackContext);
            } else if (action.equals("registerNotification")) {
                registerNotification(args);
            } else if (action.equals("isMEPNotification")) {
                isMEPNotification(args, callbackContext);
            } else if (action.equals("parseRemoteNotification")) {
                parseRemoteNotification(args, callbackContext);
            } else if (action.equals("isLinked")) {
                isLinked(callbackContext);
            } else if (action.equals("unlink")) {
                unlink();
            } else if (action.equals("showMEPWindowLite")) {
                showMEPWindowLite();
            } else if (action.equals("onLogout")) {
                onLogoutCallback(args, callbackContext);
            } else if (action.equals("onLogoutClicked")) {
                onLogoutClickedCallback(args, callbackContext);
            } else if (action.equals("onCloseButtonClicked")) {
                onCloseButtonClickedCallback(args, callbackContext);
            } else if (action.equals("startMeet")) {
                startMeet(args, callbackContext);
            } else if (action.equals("scheduleMeet")) {
                scheduleMeet(args, callbackContext);
            } else if (action.equals("joinMeet")) {
                joinMeet(args, callbackContext);
            } else if (action.equals("onAddMemberInChatClicked")) {
                onAddMemberInChatClicked(args, callbackContext);
            } else if (action.equals("showMEPWindowInDiv")) {
                showTimelineInDiv(args, callbackContext);
            } else if (action.equals("onJoinMeetButtonClicked")) {
                onJoinMeetButtonClicked(args, callbackContext);
            } else if (action.equals("onCallButtonClicked")) {
                onCallButtonClicked(args, callbackContext);
            } else if (action.equals("onMeetViewButtonClicked")) {
                onMeetViewButtonClicked(args, callbackContext);
            } else if (action.equals("onMeetEditButtonClicked")) {
                onMeetEditButtonClicked(args, callbackContext);
            } else if (action.equals("onInviteButtonInLiveMeetClicked")) {
                onInviteButtonInLiveMeetClicked(args, callbackContext);
            } else if (action.equals("setFeatureConfig")) {
                setFeatureConfig(args);
            } else if (action.equals("switchMainPage")) {
                switchMainPage(args);
            } else if (action.equals("showClientDashboardInDiv")) {
                showDashBoardInDiv(args, callbackContext);
            } else if (action.equals("makeDivInteractive")) {
                makeDivInteractive(args);
            } else if (action.equals("makeDivNoninteractive")) {
                makeDivNoninteractive(args);
            } else if (action.equals("getUnreadMessageCount")) {
                getUnreadMessageCount(callbackContext);
            } else if (action.equals("onUnreadMessageCountUpdated")) {
                onUnreadMessageCountUpdated(args, callbackContext);
            } else if (action.equals("getLastActiveTimestamp")) {
                getLastActiveTimestamp(args, callbackContext);
            } else if (action.equals("canAddUserInChat")) {
                canAddUserInChat(args, callbackContext);
            } else if (action.equals("setCanAddUserInChatResult")) {
                setCanAddUserInChatResult(args, callbackContext);
            } else if (action.equals("openLiveChat")) {
                openLiveChat(args, callbackContext);
            } else if (action.equals("openServiceRequest")) {
                openServiceRequest(args, callbackContext);
            } else if (action.equals("joinMeetAnonymously")) {
                joinMeetAnonymously(args, callbackContext);
            } else if (action.equals("getUnreadMessageCountWithOption")) {
                getUnreadMessageCountWithOption(args, callbackContext);
            } else if (action.equals("showServiceRequestInDiv")) {
                showServiceRequestInDiv(args, callbackContext);
            } else if (action.equals("showLiveChatInDiv")) {
                showLiveChatInDiv(args, callbackContext);
            } else {
                return false;
            }
            return true;
        } catch (Exception e) {
            e.printStackTrace();
        }
        return false;
    }

    private void setupDomain(final JSONArray args) {
        Log.d(TAG, "setupDomain called...");
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                try {
                    String domain = args.getString(0);

                    LinkConfig linkConfig = null;
                    if (args.length() > 1) {
                        String certOrgName = args.getString(1);
                        String certPublicKey = args.getString(2);
                        String ignoreBadCertStr = args.getString(3);
                        boolean ignoreBadCert = Boolean.parseBoolean(ignoreBadCertStr);
                        linkConfig = new LinkConfig();

                        if (!StringUtils.equals("null", certOrgName)) {
                            linkConfig.setCertOrganization(certOrgName);
                        }

                        if (!StringUtils.equals("null", certPublicKey)) {
                            linkConfig.setCertPublicKey(certPublicKey);
                        }

                        linkConfig.setIgnoreBadCert(ignoreBadCert);
                    }
                    MEPClient.initialize(cordova.getActivity().getApplication());
                    MEPClient.setupDomain(domain, linkConfig);
                    //Unread Count listener should be added after sdk initialized.
                    setOnUnreadMessageListener();
                } catch (JSONException e) {

                }
            }
        });
    }

    private void showMEPWindow() {
        Log.d(TAG, "showMEPWindow called...");
        if (MEPClient.isLinked()) {
            Log.d(TAG, "MEP is linked and showMEPWindow...");
            MEPClient.showMEPWindow(cordova.getActivity());
        }
    }

    private void hideMEPWindow() {
        Log.d(TAG, "hideMEPWindow called...");
        if (MEPClient.isLinked()) {
            if (mFragmentPluginView != null && mPluginLayout != null) {
                mPluginLayout.removePluginOverlay(mFragmentPluginView.getOverlayId());
            }
            new Handler(Looper.getMainLooper()).post(new Runnable() {
                @Override
                public void run() {
                    if (mActivityList != null && !mActivityList.isEmpty()) {
                        Activity activity = mActivityList.get(0);
                        if (activity != null) {
                            activity.finishAndRemoveTask();
                        }
                    }
                }
            });
            MEPClient.destroyMEPWindow();
        }
    }

    private void destroyMEPWindow() {
        Log.d(TAG, "destroyMEPWindow called...");
        if (MEPClient.isLinked()) {
            if (mFragmentPluginView != null && mPluginLayout != null) {
                mPluginLayout.removePluginOverlay(mFragmentPluginView.getOverlayId());
            }
            new Handler(Looper.getMainLooper()).post(new Runnable() {
                @Override
                public void run() {
                    if (mActivityList != null && !mActivityList.isEmpty()) {
                        Activity activity = mActivityList.get(0);
                        if (activity != null) {
                            activity.finishAndRemoveTask();
                        }
                    }
                }
            });
            MEPClient.destroyMEPWindow();
        }
    }

    private void openChat(final JSONArray args, final CallbackContext callbackContext) {
        Log.d(TAG, "openChat called...");
        try {
            if (MEPClient.isLinked()) {
                String chatId = args.getString(0);
                String chatFeedSequenceStr = args.getString(1);
                long chatFeedSequence;
                try {
                    chatFeedSequence = Long.parseLong(chatFeedSequenceStr);
                } catch (NumberFormatException e) {
                    chatFeedSequence = 0;
                }
                MEPClient.openChat(chatId, chatFeedSequence, new ApiCallback<Void>() {
                    @Override
                    public void onCompleted(Void result) {
                        Log.d(TAG, "openChat successful...");
                        sendPluginResult(callbackContext, PluginResult.Status.OK, null);
                    }

                    @Override
                    public void onError(int errorCode, String errorMsg) {
                        Log.d(TAG, "openChat failed, errCode:" + errorCode + ", errMsg:" + errorMsg);
                        sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                                new JSONObject(getErrorInfo(errorCode, errorMsg)));
                    }
                });
            } else {
                Log.i(TAG, "MEP is not linked ...");
                sendPluginResult(callbackContext, PluginResult.Status.ERROR, new JSONObject(
                        getCordovaErrorInfo(MEPNotLinkedError, ErrorCodeUtil.getErrorMsg(MEPNotLinkedError))));
            }
        } catch (JSONException e) {
            sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                    new JSONObject(getErrorInfo(-1, e.getMessage())));
        }
    }

    private void initWithAccessToken(final JSONArray args, final CallbackContext callbackContext) {
        Log.d(TAG, "initWithAccessToken called...");
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    String accessToken = args.getString(0);
                    MEPClient.linkWithAccessToken(accessToken, new ApiCallback<Void>() {
                        @Override
                        public void onCompleted(Void result) {
                            Log.d(TAG, "initWithAccessToken successful...");
                            sendPluginResult(callbackContext, PluginResult.Status.OK, null);
                        }

                        @Override
                        public void onError(int errorCode, String errorMsg) {
                            Log.d(TAG, "initWithAccessToken failed, errCode:" + errorCode + ", errMsg:" + errorMsg);
                            sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                                    new JSONObject(getErrorInfo(errorCode, errorMsg)));
                        }
                    });
                } catch (Exception e) {
                    sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                            new JSONObject(getErrorInfo(-1, e.getMessage())));
                }
            }
        });
    }

    private void unlink() {
        Log.d(TAG, "unlink called...");
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                MEPClient.unlink(new ApiCallback<Void>() {
                    @Override
                    public void onCompleted(Void result) {
                        callOnLogoutCallback();
                    }

                    @Override
                    public void onError(int errorCode, String errorMsg) {

                    }
                });
            }
        });
    }

    private void showMEPWindowLite() {
        Log.d(TAG, "showMEPWindowLite called...");
        if (MEPClient.isLinked()) {
            Log.d(TAG, "MEP is linked and showMEPWindowLite...");
            MEPClient.showMEPWindowLite(cordova.getActivity());
        }
    }

    private void isLinked(CallbackContext callbackContext) {
        Log.d(TAG, "isLinked called...");
        if (MEPClient.isLinked()) {
            sendPluginResult(callbackContext, PluginResult.Status.OK, null);
        } else {
            sendPluginResult(callbackContext, PluginResult.Status.ERROR, null);
        }
    }

    private void isMEPNotification(JSONArray args, CallbackContext callbackContext) {
        Log.d(TAG, "isMEPNotification called...");
        try {
            Object object = args.get(0);
            JSONObject notificationPayload = null;
            if (object instanceof String) {
                notificationPayload = new JSONObject((String) object);
            } else {
                notificationPayload = (JSONObject) object;
            }
            Intent intent = json2Intent(notificationPayload);
            boolean result = MEPClient.isMEPNotification(intent);
            if (result) {
                sendPluginResult(callbackContext, PluginResult.Status.OK, null);
            } else {
                sendPluginResult(callbackContext, PluginResult.Status.ERROR, null);
            }
        } catch (JSONException e) {
            e.printStackTrace();
            sendPluginResult(callbackContext, PluginResult.Status.ERROR, null);
        }
    }

    private Intent json2Intent(JSONObject jsonObject) throws JSONException {
        Intent intent = new Intent();
        if (jsonObject != null) {
            Iterator<String> keys = jsonObject.keys();
            while (keys.hasNext()) {
                String key = keys.next();
                intent.putExtra(key, jsonObject.getString(key));
            }
        }

        return intent;
    }

    private void parseRemoteNotification(JSONArray args, final CallbackContext callbackContext) {
        Log.d(TAG, "parseRemoteNotification called...");
        try {
            if (!MEPClient.isLinked()) {
                sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                        new JSONObject(getErrorInfo(ErrorCodes.MEPNotLinkedError, "")));
                return;
            }
            Object data = args.get(0);
            JSONObject notificationPayload = null;
            if (data instanceof String) {
                notificationPayload = new JSONObject((String) data);
            } else if (data instanceof JSONObject) {
                notificationPayload = (JSONObject) data;
            }
            Intent intent = json2Intent(notificationPayload);
            if (MEPClient.isMEPNotification(intent)) {
                MEPClient.parseRemoteNotification(intent, new ApiCallback<Map<String, String>>() {
                    @Override
                    public void onCompleted(Map<String, String> result) {
                        // Change meet_id to session_id.
                        if (result != null && result.containsKey("meet_id")) {
                            String value = result.get("meet_id");
                            result.remove("meet_id");
                            result.put("session_id", value);
                        }
                        sendPluginResult(callbackContext, PluginResult.Status.OK, new JSONObject(result));
                    }

                    @Override
                    public void onError(int errorCode, String errorMsg) {
                        sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                                new JSONObject(getErrorInfo(errorCode, errorMsg)));
                    }
                });
            } else {
                sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                        new JSONObject(getErrorInfo(-1, "Not MEP notification!")));
            }
        } catch (JSONException e) {
            sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                    new JSONObject(getErrorInfo(-1, e.getMessage())));
        }
    }

    private void registerNotification(JSONArray args) {
        Log.d(TAG, "registerNotification called...");
        try {
            String deviceToken = args.getString(0);
            if (MEPClient.isLinked()) {
                MEPClient.registerNotification(deviceToken, cordova.getActivity().getPackageName(), "");
            } else {
                Log.i(TAG, "MEP is not linked...");
            }
        } catch (JSONException e) {

        }
    }

    private void onLogoutClickedCallback(JSONArray args, final CallbackContext callbackContext) {
        boolean hasCallback = false;
        try {
            hasCallback = args.getBoolean(0);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        ActionListener<Void> listener = hasCallback ? new ActionListener<Void>() {
            @Override
            public void onAction(View view, Void aVoid) {
                Log.d(TAG, "callOnLogoutButtonClickedCallback called...");
                sendPluginResult(mOnLogoutClickedCallback, PluginResult.Status.OK, null);
            }
        } : null;
        MEPClient.getClientDelegate().setOnLogoutButtonListener(listener);
        this.mOnLogoutClickedCallback = callbackContext;
    }

    private void onCloseButtonClickedCallback(JSONArray args, final CallbackContext callbackContext) {
        boolean hasCallback = false;
        try {
            hasCallback = args.getBoolean(0);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        ActionListener<Void> listener = hasCallback ? new ActionListener<Void>() {
            @Override
            public void onAction(View view, Void aVoid) {
                Log.d(TAG, "onCloseButtonClickedCallback called...");
                sendPluginResult(mOnCloseButtonClickedCallback, PluginResult.Status.OK, null);
            }
        } : null;
        MEPClient.getClientDelegate().setOnCloseButtonListener(listener);
        this.mOnCloseButtonClickedCallback = callbackContext;
    }

    private void onAddMemberInChatClicked(JSONArray args, final CallbackContext callbackContext) {
        boolean hasCallback = false;
        try {
            hasCallback = args.getBoolean(0);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        ActionListener<String> listener = hasCallback ? new ActionListener<String>() {
            @Override
            public void onAction(View view, String chatId) {
                JSONObject jsonObject = new JSONObject();
                try {
                    jsonObject.put("chat_id", chatId);
                } catch (JSONException e) {
                    e.printStackTrace();
                }

                sendPluginResult(mOnAddMemberInChatClickedCallback, PluginResult.Status.OK, jsonObject);
            }
        } : null;
        MEPClient.getClientDelegate().setOnAddChatMemberListener(listener);
        this.mOnAddMemberInChatClickedCallback = callbackContext;
    }

    private void onLogoutCallback(JSONArray args, final CallbackContext callbackContext) {
        boolean hasCallback = false;
        try {
            hasCallback = args.getBoolean(0);
        } catch (JSONException e) {
            e.printStackTrace();
        }

        MEPClientDelegate.OnUserLoggedOutListener listener = hasCallback
                ? new MEPClientDelegate.OnUserLoggedOutListener() {
            @Override
            public void onUserLoggedOut() {
                callOnLogoutCallback();
            }
        }
                : null;
        MEPClient.getClientDelegate().setOnUserLoggedOutListener(listener);
        this.mOnLogoutCallback = callbackContext;
    }

    private void callOnLogoutCallback() {
        Log.d(TAG, "callOnLogoutCallback called...");
        sendPluginResult(mOnLogoutCallback, PluginResult.Status.OK, null);
    }

    private void startMeet(JSONArray args, CallbackContext callbackContext) {
        Log.d(TAG, "startMeet called with args:" + args.toString());
        String topic = null;
        List<String> uniqueIds = null;
        String chatId = null;
        boolean autoJoinAudio = true;
        boolean autoStartVideo = false;
        JSONObject options = null;
        try {
            switch (args.length()) {
                case 4:
                    options = convertArgument2JSONObject(args.getString(3));
                    if (options != null) {
                        if (options.has("auto_join_audio")) {
                            autoJoinAudio = options.getBoolean("auto_join_audio");
                        }
                        if (options.has("auto_start_video")) {
                            autoStartVideo = options.getBoolean("auto_start_video");
                        }
                    }
                case 3:
                    chatId = args.getString(2);
                case 2:
                    if (!StringUtils.equals(args.getString(1), "null")) {
                        JSONArray idArray = args.getJSONArray(1);
                        if (idArray != null) {
                            uniqueIds = new ArrayList<>();
                            for (int i = 0, l = idArray.length(); i < l; i++) {
                                uniqueIds.add((String) idArray.get(i));
                            }
                        }
                    }
                case 1:
                    topic = args.getString(0);
            }
            if (StringUtils.isEmpty(topic) || StringUtils.equals(topic, "null")) {
                sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                        new JSONObject(getErrorInfo(-1, "Topic is empty!")));
                return;
            }

            MEPStartMeetOptions startMeetOptions = new MEPStartMeetOptions();
            startMeetOptions.setTopic(topic);
            if (!StringUtils.isEmpty(chatId) && !StringUtils.equals(chatId, "null")) {
                startMeetOptions.setChatID(chatId);
            }
            if (uniqueIds != null) {
                startMeetOptions.setUniqueIDs(uniqueIds);
            }
            if (options != null) {
                startMeetOptions.setAutoJoinAudio(autoJoinAudio);
                startMeetOptions.setAutoStartVideo(autoStartVideo);
            }

            MEPClient.startMeet(startMeetOptions, new ApiCallback<String>() {
                @Override
                public void onCompleted(String sessionId) {
                    JSONObject jsonObject = new JSONObject();
                    try {
                        jsonObject.put("session_id", sessionId);
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                    sendPluginResult(callbackContext, PluginResult.Status.OK, jsonObject);
                }

                @Override
                public void onError(int errorCode, String errorMsg) {
                    sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                            new JSONObject(getErrorInfo(errorCode, errorMsg)));
                }
            });
        } catch (JSONException e) {
            e.printStackTrace();
            sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                    new JSONObject(getErrorInfo(-1, e.getMessage())));
        }
    }

    private void scheduleMeet(JSONArray args, CallbackContext callbackContext) {
        Log.d(TAG, "scheduleMeet called with args:" + args.toString());
        String topic = null;
        List<String> uniqueIds = null;
        String chatId = null;
        long scheduleStartTime = 0;
        long scheduleEndTime = 0;
        JSONObject options = null;
        try {
            switch (args.length()) {
                case 4:
                    options = convertArgument2JSONObject(args.getString(3));
                    if (options != null) {
                        if (options.has("start_time")) {
                            scheduleStartTime = Long.parseLong(options.getString("start_time"));
                        }
                        if (options.has("end_time")) {
                            scheduleEndTime = Long.parseLong(options.getString("end_time"));
                        }
                    }
                case 3:
                    chatId = args.getString(2);
                case 2:
                    if (!StringUtils.equals(args.getString(1), "null")) {
                        JSONArray idArray = args.getJSONArray(1);
                        if (idArray != null) {
                            uniqueIds = new ArrayList<>();
                            for (int i = 0, l = idArray.length(); i < l; i++) {
                                uniqueIds.add((String) idArray.get(i));
                            }
                        }
                    }
                case 1:
                    topic = args.getString(0);
            }
            if (StringUtils.isEmpty(topic) || StringUtils.equals(topic, "null")) {
                sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                        new JSONObject(getErrorInfo(-1, "Topic is empty!")));
                return;
            }

            MEPScheduleMeetOptions scheduleMeetOptions = new MEPScheduleMeetOptions();
            scheduleMeetOptions.setTopic(topic);
            if (!StringUtils.isEmpty(chatId) && !StringUtils.equals(chatId, "null")) {
                scheduleMeetOptions.setChatID(chatId);
            }
            if (uniqueIds != null) {
                scheduleMeetOptions.setUniqueIDs(uniqueIds);
            }
            if (options != null) {
                scheduleMeetOptions.setStartTime(scheduleStartTime);
                scheduleMeetOptions.setEndTime(scheduleEndTime);
            }

            MEPClient.scheduleMeet(scheduleMeetOptions, new ApiCallback<String>() {
                @Override
                public void onCompleted(String sessionId) {
                    JSONObject jsonObject = new JSONObject();
                    try {
                        jsonObject.put("session_id", sessionId);
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                    sendPluginResult(callbackContext, PluginResult.Status.OK, jsonObject);
                }

                @Override
                public void onError(int errorCode, String errorMsg) {
                    sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                            new JSONObject(getErrorInfo(errorCode, errorMsg)));
                }
            });
        } catch (NumberFormatException | JSONException e) {
            e.printStackTrace();
            sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                    new JSONObject(getErrorInfo(-1, e.getMessage())));
        }
    }

    private void joinMeet(JSONArray args, CallbackContext callbackContext) {
        Log.d(TAG, "joinMeet called with args:" + args.toString());
        try {
            String sessionId = (String) args.get(0);
            if (!StringUtils.isEmpty(sessionId)) {
                MEPClient.joinMeet(sessionId, new ApiCallback<Void>() {
                    @Override
                    public void onCompleted(Void result) {
                        sendPluginResult(callbackContext, PluginResult.Status.OK, null);
                    }

                    @Override
                    public void onError(int errorCode, String errorMsg) {
                        sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                                new JSONObject(getErrorInfo(errorCode, errorMsg)));
                    }
                });
            }
        } catch (JSONException e) {
            e.printStackTrace();
            sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                    new JSONObject(getErrorInfo(-1, e.getMessage())));
        }
    }

    private void joinMeetAnonymously(JSONArray args, CallbackContext callbackContext) {
        Log.d(TAG, "joinMeetAnonymously called with args:" + args.toString());
        try {
            String password = null;
            String email = null;
            String username = null;
            String sessionId = null;
            switch (args.length()) {
                case 2:
                    JSONObject options = convertArgument2JSONObject(args.getString(1));
                    if (options != null) {
                        if (options.has("password")) {
                            password = options.getString("password");
                        }
                        if (options.has("email")) {
                            email = options.getString("email");
                        }
                        if (options.has("display_name")) {
                            username = options.getString("display_name");
                        }
                    }
                case 1:
                    sessionId = (String) args.get(0);
                    if (TextUtils.equals("null", sessionId)) {
                        sessionId = null;
                    }
                    break;
            }
            if (!StringUtils.isEmpty(sessionId)) {
                MEPClient.joinMeetAnonymously(sessionId, username, email, password, new ApiCallback<Void>() {
                    @Override
                    public void onCompleted(Void result) {
                        sendPluginResult(callbackContext, PluginResult.Status.OK, null);
                    }

                    @Override
                    public void onError(int errorCode, String errorMsg) {
                        sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                                new JSONObject(getErrorInfo(errorCode, errorMsg)));
                    }
                });
            }
        } catch (JSONException e) {
            e.printStackTrace();
            sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                    new JSONObject(getErrorInfo(-1, e.getMessage())));
        }
    }

    private void getUnreadMessageCountWithOption(JSONArray args, CallbackContext callbackContext) {
        Log.d(TAG, "getUnreadMessageCountWithOption called with args:" + args);
        if (!MEPClient.isLinked()) {
            Log.i(TAG, "MEP is not linked ...");
            sendPluginResult(callbackContext, PluginResult.Status.ERROR, new JSONObject(
                    getCordovaErrorInfo(MEPNotLinkedError, ErrorCodeUtil.getErrorMsg(MEPNotLinkedError))));
            return;
        }
        try {
            boolean hasCallback = false;
            String optString = "{\"type\": 0}";//Follow iOS logic
            int type = 0;
            if (args != null && args.length() > 1) {
                hasCallback = args.getBoolean(0);
                optString = args.getString(1);
            }
            JSONObject options = convertArgument2JSONObject(optString);
            if (options != null) {
                try {
                    type = Integer.parseInt(options.getString("type"));
                } catch (NumberFormatException e) {
                    e.printStackTrace();
                }
            }
            MEPChat.MEPChatType chatType;
            if (type == 5) {
                chatType = MEPChat.MEPChatType.LiveChat;
            } else if (type == 6) {
                chatType = MEPChat.MEPChatType.ServiceRequest;
            } else {
                sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                        new JSONObject(getErrorInfo(-1, String.format("type %d is not supported yet.", type))));
                return;
            }

            String chatTypeStr = chatType.name();
            if(!hasCallback) {
                if (mUnreadCountCallbackMap != null) {
                    mUnreadCountCallbackMap.remove(chatTypeStr);
                }
                if (mUnreadCountMap != null) {
                    mUnreadCountMap.remove(chatTypeStr);
                }
                return;
            }

            int count = MEPClient.getUnreadMessageCountForType(chatType);
            if (count < 0) {
                sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                        new JSONObject(getErrorInfo(-1, "Internal user doesn't support this API yet.")));
                return;
            }
            if (mUnreadCountCallbackMap != null) {
                mUnreadCountCallbackMap.put(chatTypeStr, callbackContext);
            }
            if (mUnreadCountMap != null) {
                mUnreadCountMap.put(chatTypeStr, count);
            }
            sendPluginResult(callbackContext, PluginResult.Status.OK, String.valueOf(count));
        } catch (JSONException e) {
            e.printStackTrace();
            sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                    new JSONObject(getErrorInfo(-1, e.getMessage())));
        }
    }

    private Map<String, Object> getErrorInfo(int errorCode, String errorMsg) {
        int convertedErrorCode = ErrorCodeUtil.convert2CordovaErrorCode(errorCode);
        return getCordovaErrorInfo(convertedErrorCode, errorMsg);
    }

    private Map<String, Object> getCordovaErrorInfo(int errorCode, String errorMsg) {
        Map<String, Object> result = new HashMap<>();
        result.put("error_code", errorCode);
        result.put("error_message", errorCode != 0 ? ErrorCodeUtil.getErrorMsg(errorCode) : errorMsg);

        return result;
    }

    private JSONObject convertArgument2JSONObject(String arg) {
        JSONObject jo = null;
        if (arg != null) {
            try {
                jo = new JSONObject(arg);
            } catch (JSONException e) {
                e.printStackTrace();
            }
        }

        return jo;
    }

    private void createNotificationChannel(String channelId) {
        // Create the NotificationChannel, but only on API 26+ because
        // the NotificationChannel class is new and not in the support library
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            int importance = NotificationManager.IMPORTANCE_DEFAULT;
            NotificationChannel channel = new NotificationChannel(channelId, channelId, importance);
            channel.setDescription(null);
            // Register the channel with the system; you can't change the importance
            // or other notification behaviors after this
            NotificationManager notificationManager = cordova.getActivity().getSystemService(NotificationManager.class);
            notificationManager.createNotificationChannel(channel);
        }
    }

    @Override
    public void onScrollChanged() {

    }

    private void showTimelineInDiv(JSONArray args, CallbackContext callbackContext) {
        Log.d(TAG, "showFragment() called");
        try {
            int argLength = args.length();
            JSONObject rect = args.getJSONObject(0);
            boolean isLite = true;
            if (argLength >= 2) {
                isLite = args.getBoolean(1);
            }
            float density = PluginUtil.getDensity();
            float left = rect.getInt("x") * density;
            float top = rect.getInt("y") * density;
            float width = rect.getInt("width") * density;
            float height = rect.getInt("height") * density;

            if (mFragmentPluginView != null) {
                mPluginLayout.removePluginOverlay(mFragmentPluginView.getOverlayId());
            }

            mPluginLayout.setDrawRect(new RectF(left, top, left + width, top + height));
            mFragmentPluginView = new FragmentPluginView(this.cordova, this.webView);
            mFragmentPluginView.setArea(top, left, width, height);
            mPluginLayout.addPluginOverlay(mFragmentPluginView);
            mFragmentPluginView.resizeFragment(!isLite);
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    private void showDashBoardInDiv(JSONArray args, CallbackContext callbackContext) {
        Log.d(TAG, "showDashBoardInDiv() called");
        Fragment fragment = MEPClient.createDashboardFragment();
        if (fragment == null) {
            Log.e(TAG, "internal user doesn't support API showClientDashboardInDiv, please make sure current user is client user");
            return;
        }

        showFragmentInDiv(args, fragment);
    }

    private void showServiceRequestInDiv(JSONArray args, CallbackContext callbackContext) {
        Log.d(TAG, "showServiceRequestInDiv() called");
        Fragment fragment = MEPClient.createServiceRequestFragment();
        if (fragment == null) {
            Log.e(TAG, "org not support service request or internal user doesn't support service request!");
            return;
        }

        showFragmentInDiv(args, fragment);
    }

    private void showLiveChatInDiv(JSONArray args, CallbackContext callbackContext) {
        Log.d(TAG, "showLiveChatInDiv() called");
        Fragment fragment = MEPClient.createLiveChatFragment();
        if (fragment == null) {
            Log.e(TAG, "org not support live chat or internal user doesn't support live chat!");
            return;
        }

        showFragmentInDiv(args, fragment);
    }

    private void showFragmentInDiv(JSONArray args, Fragment fragment) {
        Log.d(TAG, "showFragmentInDiv() called");
        try {
            if (fragment == null) {
                Log.e(TAG, "Fragment is null");
                return;
            }

            int argLength = args.length();
            JSONObject rect = args.getJSONObject(0);
            float density = PluginUtil.getDensity();
            float left = rect.getInt("x") * density;
            float top = rect.getInt("y") * density;
            float width = rect.getInt("width") * density;
            float height = rect.getInt("height") * density;

            if (mFragmentPluginView != null) {
                mPluginLayout.removePluginOverlay(mFragmentPluginView.getOverlayId());
            }

            mPluginLayout.setDrawRect(new RectF(left, top, left + width, top + height));
            mFragmentPluginView = new FragmentPluginView(this.cordova, this.webView);
            mFragmentPluginView.setArea(top, left, width, height);
            mPluginLayout.addPluginOverlay(mFragmentPluginView);
            mFragmentPluginView.resizeFragment(fragment);
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    private void onJoinMeetButtonClicked(final JSONArray array, final CallbackContext callbackContext) {
        Log.d(TAG, "Set onJoinMeetButtonClicked():" + callbackContext);
        boolean hasCallback = false;
        try {
            hasCallback = array.getBoolean(0);
        } catch (JSONException e) {
            e.printStackTrace();
        }

        ActionListener<Meet> listener = hasCallback ? new ActionListener<Meet>() {
            @Override
            public void onAction(View view, Meet meet) {
                Log.d(TAG, "onJoinMeetButtonClicked()!");
                if (meet != null && !StringUtils.isEmpty(meet.getID())) {
                    Log.d(TAG, "onJoinMeetButtonClicked(), meetId is " + meet.getID());
                    JSONObject jsonObject = new JSONObject();
                    try {
                        jsonObject.put("session_id", meet.getID());
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                    sendPluginResult(mOnJoinMeetButtonClickedCallback, PluginResult.Status.OK, jsonObject);
                } else {
                    Log.w(TAG, "onJoinMeetButtonClicked(), meet is null!");
                    sendPluginResult(mOnJoinMeetButtonClickedCallback, PluginResult.Status.ERROR,
                            new JSONObject(getErrorInfo(-1, "Meet is null")));
                }
            }
        } : null;

        MEPClient.getClientDelegate().setOnJoinMeetListener(listener);
        this.mOnJoinMeetButtonClickedCallback = callbackContext;
    }

    private void onCallButtonClicked(final JSONArray array, final CallbackContext callbackContext) {
        Log.d(TAG, "Set onCallButtonClicked():" + callbackContext);
        boolean hasCallback = false;
        try {
            hasCallback = array.getBoolean(0);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        MEPClientDelegate.OnCallButtonListener listener = hasCallback ? new MEPClientDelegate.OnCallButtonListener() {
            @Override
            public void onCallButtonClicked(MEPChat mepChat, User user) {
                Log.d(TAG, "onCallButtonClicked with chat:" + mepChat + " and user:" + user);
                if (mepChat != null) {
                    mepChat.fetchMembers(new ApiCallback<List<ChatMember>>() {
                        @Override
                        public void onCompleted(List<ChatMember> chatMembers) {
                            Log.d(TAG, "onCallButtonClicked and fetch chat member done!");
                            JSONObject jsonObject = new JSONObject();
                            try {
                                jsonObject.put("chat_id", mepChat.getId());
                                List<String> ids = new ArrayList<>();
                                for (ChatMember chatMember : chatMembers) {
                                    if (chatMember != null && !StringUtils.isEmpty(chatMember.getUniqueId())) {
                                        ids.add(chatMember.getUniqueId());
                                    }
                                }
                                jsonObject.put("unique_ids", new JSONArray(ids));
                            } catch (JSONException e) {
                                e.printStackTrace();
                            }

                            sendPluginResult(mOnCallButtonClickedCallback, PluginResult.Status.OK, jsonObject);
                        }

                        @Override
                        public void onError(int errorCode, String errorMsg) {
                            Log.w(TAG, "onCallButtonClicked and fetch chat member failed with errorCode:" + errorCode);
                            sendPluginResult(mOnCallButtonClickedCallback, PluginResult.Status.ERROR,
                                    new JSONObject(getErrorInfo(errorCode, errorMsg)));
                        }
                    });
                } else if (user != null) {
                    JSONObject jsonObject = new JSONObject();
                    try {
                        List<String> ids = new ArrayList<>();
                        ids.add(user.getUniqueId());
                        jsonObject.put("unique_ids", new JSONArray(ids));
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }

                    sendPluginResult(mOnCallButtonClickedCallback, PluginResult.Status.OK, jsonObject);
                } else {
                    Log.d(TAG, "onCallButtonClicked without chat");
                    sendPluginResult(mOnCallButtonClickedCallback, PluginResult.Status.OK, null);
                }
            }
        } : null;
        MEPClient.getClientDelegate().setOnCallButtonListener(listener);

        this.mOnCallButtonClickedCallback = callbackContext;
    }

    private void onMeetViewButtonClicked(final JSONArray array, final CallbackContext callbackContext) {
        Log.d(TAG, "Set onMeetViewButtonClicked():" + callbackContext);
        boolean hasCallback = false;
        try {
            hasCallback = array.getBoolean(0);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        ActionListener<Meet> listener = hasCallback ? new ActionListener<Meet>() {
            @Override
            public void onAction(View view, Meet meet) {
                Log.d(TAG, "onMeetViewButtonClicked()!");
                if (meet != null && !StringUtils.isEmpty(meet.getID())) {
                    Log.d(TAG, "onMeetViewButtonClicked(), meetId is " + meet.getID());
                    JSONObject jsonObject = new JSONObject();
                    try {
                        jsonObject.put("session_id", meet.getID());
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                    sendPluginResult(mOnMeetViewButtonClickedCallback, PluginResult.Status.OK, jsonObject);
                } else {
                    Log.w(TAG, "onMeetViewButtonClicked(), meet is null!");
                    sendPluginResult(mOnMeetViewButtonClickedCallback, PluginResult.Status.ERROR,
                            new JSONObject(getErrorInfo(-1, "Meet is null")));
                }
            }
        } : null;
        MEPClient.getClientDelegate().setOnViewMeetListener(listener);
        this.mOnMeetViewButtonClickedCallback = callbackContext;
    }

    private void onMeetEditButtonClicked(final JSONArray array, final CallbackContext callbackContext) {
        Log.d(TAG, "Set onMeetEditButtonClicked():" + callbackContext);
        boolean hasCallback = false;
        try {
            hasCallback = array.getBoolean(0);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        ActionListener<Meet> listener = hasCallback ? new ActionListener<Meet>() {
            @Override
            public void onAction(View view, Meet meet) {
                Log.d(TAG, "onMeetEditButtonClicked()!");
                if (meet != null && !StringUtils.isEmpty(meet.getID())) {
                    Log.d(TAG, "onMeetEditButtonClicked(), meetId is " + meet.getID());
                    JSONObject jsonObject = new JSONObject();
                    try {
                        jsonObject.put("session_id", meet.getID());
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                    sendPluginResult(mOnMeetEditButtonClickedCallback, PluginResult.Status.OK, jsonObject);
                } else {
                    Log.w(TAG, "onMeetEditButtonClicked(), meet is null!");
                    sendPluginResult(mOnMeetEditButtonClickedCallback, PluginResult.Status.ERROR,
                            new JSONObject(getErrorInfo(-1, "Meet is null")));
                }
            }
        } : null;
        MEPClient.getClientDelegate().setOnEditMeetListener(listener);
        this.mOnMeetEditButtonClickedCallback = callbackContext;
    }

    private void onInviteButtonInLiveMeetClicked(JSONArray array, CallbackContext callbackContext) {
        Log.d(TAG, "Set onInviteButtonInLiveMeetClicked():" + callbackContext);
        boolean hasCallback = false;
        try {
            hasCallback = array.getBoolean(0);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        ActionListener<Meet> listener = hasCallback ? new ActionListener<Meet>() {
            @Override
            public void onAction(View view, Meet meet) {
                Log.d(TAG, "onInviteButtonInLiveMeetClicked()!");
                if (meet != null && !StringUtils.isEmpty(meet.getID())) {
                    Log.d(TAG, "onInviteButtonInLiveMeetClicked(), meetId is " + meet.getID());
                    JSONObject jsonObject = new JSONObject();
                    try {
                        jsonObject.put("session_id", meet.getID());
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                    sendPluginResult(mOnInviteButtonInLiveMeetClickedCallback, PluginResult.Status.OK, jsonObject);
                } else {
                    Log.w(TAG, "onInviteButtonInLiveMeetClicked(), meet is null!");
                    sendPluginResult(mOnInviteButtonInLiveMeetClickedCallback, PluginResult.Status.ERROR,
                            new JSONObject(getErrorInfo(-1, "Meet is null")));
                }
            }
        } : null;
        MEPClient.getClientDelegate().setOnLiveMeetInviteListener(listener);
        this.mOnInviteButtonInLiveMeetClickedCallback = callbackContext;
    }

    private void setFeatureConfig(JSONArray array) {
        try {
            String configStr = (String) array.get(0);
            JSONObject config = new JSONObject(configStr);
            if (config.has("voice_message_enabled")) {
                boolean enabledVoiceMsg = config.getBoolean("voice_message_enabled");
                FeatureConfig.setVoiceMessageEnabled(enabledVoiceMsg);
            }
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    private void switchMainPage(JSONArray args) {
        try {
            boolean show = args.getBoolean(0);
            if (show) {
                Intent intent = new Intent();
                intent.setFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
                intent.setClass(cordova.getActivity(), cordova.getActivity().getClass());
                cordova.getActivity().startActivity(intent);
            } else {
                cordova.getActivity().moveTaskToBack(true);
            }
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    private void setActivityChangedListener(boolean enabled) {
        mActivityList = new ArrayList<>();
        if (callbacks == null) {
            callbacks = new Application.ActivityLifecycleCallbacks() {
                @Override
                public void onActivityCreated(@NonNull Activity activity, @Nullable Bundle savedInstanceState) {
                    if (mActivityList != null && !StringUtils.equals(activity.getClass().getName(),
                            cordova.getActivity().getClass().getName())) {
                        mActivityList.add(activity);
                    }
                }

                @Override
                public void onActivityStarted(@NonNull Activity activity) {

                }

                @Override
                public void onActivityResumed(@NonNull Activity activity) {

                }

                @Override
                public void onActivityPaused(@NonNull Activity activity) {
                    if (activity.isFinishing() && !StringUtils.equals(activity.getClass().getName(),
                            cordova.getActivity().getClass().getName()) && mActivityList.size() < 2) {
                        Intent intent = new Intent(cordova.getActivity(), cordova.getActivity().getClass());
                        intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT | Intent.FLAG_ACTIVITY_NEW_TASK);
                        cordova.getActivity().startActivity(intent);
                    }
                }

                @Override
                public void onActivityStopped(@NonNull Activity activity) {

                }

                @Override
                public void onActivitySaveInstanceState(@NonNull Activity activity, @NonNull Bundle outState) {

                }

                @Override
                public void onActivityDestroyed(@NonNull Activity activity) {
                    if (mActivityList != null) {
                        mActivityList.remove(activity);
                    }
                }
            };

            this.cordova.getActivity().getApplication().registerActivityLifecycleCallbacks(callbacks);
        }
    }

    private void sendPluginResult(CallbackContext callback, PluginResult.Status status, Object resultData) {
        if (callback == null) {
            return;
        }
        PluginResult pluginResult = null;
        if (resultData == null) {
            pluginResult = new PluginResult(status);
        } else if (resultData instanceof JSONObject) {
            pluginResult = new PluginResult(status, (JSONObject) resultData);
        } else if (resultData instanceof String) {
            pluginResult = new PluginResult(status, (String) resultData);
        }
        pluginResult.setKeepCallback(true);

        callback.sendPluginResult(pluginResult);
    }

    private void makeDivInteractive(JSONArray args) {
        try {
            int argLength = args.length();
            String divId = null;
            JSONObject rect = args.getJSONObject(0);
            float density = PluginUtil.getDensity();
            float left = rect.getInt("x") * density;
            float top = rect.getInt("y") * density;
            float width = rect.getInt("width") * density;
            float height = rect.getInt("height") * density;
            if (argLength > 1) {
                divId = args.getString(1);
            }

            if (mPluginLayout != null && divId != null) {
                mPluginLayout.addDivRect(divId, new RectF(left, top, left + width, top + height));
            }
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    private void makeDivNoninteractive(JSONArray args) {
        try {
            int argLength = args.length();
            String divId = null;
            if (argLength > 0) {
                divId = args.getString(0);
            }

            if (mPluginLayout != null && divId != null) {
                mPluginLayout.removeDivRect(divId);
            }
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    private void getUnreadMessageCount(CallbackContext callbackContext) {
        int count = MEPClient.getUnreadMessageCount();
        sendPluginResult(callbackContext, PluginResult.Status.OK, String.valueOf(count));
    }

    private void onUnreadMessageCountUpdated(JSONArray args, CallbackContext callbackContext) {
        Log.d(TAG, "Set onJoinMeetButtonClicked():" + callbackContext);
        boolean hasCallback = false;
        try {
            hasCallback = args.getBoolean(0);
        } catch (JSONException e) {
            e.printStackTrace();
        }

        if (mUnreadCountCallbackMap != null) {
            if (hasCallback) {
                mUnreadCountCallbackMap.put(UNREAD_ALL, callbackContext);
            } else {
                mUnreadCountCallbackMap.remove(UNREAD_ALL);
            }
        }
    }

    private void setOnUnreadMessageListener() {
        MEPClientDelegate.OnUnreadMessageListener listener = new MEPClientDelegate.OnUnreadMessageListener() {
            @Override
            public void onUnreadCountUpdated(int total) {
                //get SR/ACD unread count.
                if (mUnreadCountCallbackMap != null && !mUnreadCountCallbackMap.isEmpty()) {
                    for (String chatType : mUnreadCountCallbackMap.keySet()) {
                        CallbackContext unreadCountCallbackContext = mUnreadCountCallbackMap.get(chatType);
                        if (unreadCountCallbackContext != null) {
                            int count = total;
                            if (!StringUtils.equals(UNREAD_ALL, chatType)) {
                                count = MEPClient.getUnreadMessageCountForType(MEPChat.MEPChatType.valueOf(chatType));
                                //Check if this is LC or SR unread count update.
                                if (mUnreadCountMap != null && mUnreadCountMap.get(chatType) != null) {
                                    int lastCount = mUnreadCountMap.get(chatType);
                                    if (lastCount == count) {
                                        continue;
            }
                                    mUnreadCountMap.put(chatType, count);
        }
                            }
                            if (count < 0) {
                                sendPluginResult(unreadCountCallbackContext, PluginResult.Status.ERROR,
                                        new JSONObject(getErrorInfo(-1, "Internal user doesn't support this API yet.")));
                            } else {
                                sendPluginResult(unreadCountCallbackContext, PluginResult.Status.OK, String.valueOf(count));
                            }
                        }
                    }
                }
            }
        };

        MEPClient.getClientDelegate().setOnUnreadMessageListener(listener);
    }

    private void getLastActiveTimestamp(JSONArray args, CallbackContext callbackContext) {
        if (!MEPClient.isLinked()) {
            if (callbackContext != null) {
                sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                        new JSONObject(getErrorInfo(ErrorCodes.MEPNotLinkedError, "not linked error")));
            }

            return;
        }

        if (callbackContext != null) {
            long lastTimeStamp = MEPClient.getLastActiveTimestamp();
            sendPluginResult(callbackContext, PluginResult.Status.OK, String.valueOf(lastTimeStamp));
        }
    }

    private void canAddUserInChat(JSONArray args, CallbackContext callbackContext) {
        Log.d(TAG, "Set canAddUserInChat():" + callbackContext);
        boolean hasCallback = false;
        try {
            hasCallback = args.getBoolean(0);
        } catch (JSONException e) {
            e.printStackTrace();
        }

        MEPClientDelegate.OnAddUserInChatListener listener = hasCallback
                ? new MEPClientDelegate.OnAddUserInChatListener() {
            @Override
            public boolean canAddUserInChat(MEPChat chat) {
                if (mCanAddUserInChatCallback != null) {
                    sendPluginResult(mCanAddUserInChatCallback, PluginResult.Status.OK, chat.getId());
                }
                if (mCountDownLatch == null) {
                    mCountDownLatch = new CountDownLatch(1);
                }
                try {
                    mCountDownLatch.await();
                } catch (InterruptedException e) {
                    e.printStackTrace();
                } finally {
                    mCountDownLatch = null;
                }
                return mAddUserInChatResult;
            }
        }
                : null;

        MEPClient.getClientDelegate().setOnAddUserInChatListener(listener);
        this.mCanAddUserInChatCallback = callbackContext;
    }

    private void setCanAddUserInChatResult(JSONArray args, CallbackContext callbackContext) {
        try {
            mAddUserInChatResult = args.getBoolean(0);
        } catch (JSONException e) {
            e.printStackTrace();
        }

        if (mCountDownLatch != null) {
            mCountDownLatch.countDown();
        }
    }

    private void openLiveChat(JSONArray args, CallbackContext callbackContext) {
        Log.d(TAG, "openLiveChat with args:" + args);
        JSONObject options = null;
        try {
            options = convertArgument2JSONObject(args.getString(0));

            MEPClient.openLiveChat(new ApiCallback<Void>() {
                @Override
                public void onCompleted(Void result) {
                    Log.d(TAG, "openLiveChat success~");
                    sendPluginResult(callbackContext, PluginResult.Status.OK,
                            null);
                }

                @Override
                public void onError(int errorCode, String errorMsg) {
                    Log.d(TAG, "openLiveChat failed with errorCode:" + errorCode + ", errorMessage:" + errorMsg);
                    sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                            new JSONObject(getErrorInfo(errorCode, errorMsg)));
                }
            });
        } catch (JSONException e) {
            e.printStackTrace();
            sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                    new JSONObject(getErrorInfo(-1, e.getMessage())));
        }
    }

    private void openServiceRequest(JSONArray args, CallbackContext callbackContext) {
        Log.d(TAG, "openServiceRequest ...");
        MEPClient.openServiceRequest(new ApiCallback<Void>() {
            @Override
            public void onCompleted(Void result) {
                Log.d(TAG, "openServiceRequest success~");
                sendPluginResult(callbackContext, PluginResult.Status.OK,
                        null);
            }

            @Override
            public void onError(int errorCode, String errorMsg) {
                Log.d(TAG, "openServiceRequest failed with errorCode:" + errorCode + ", errorMessage:" + errorMsg);
                sendPluginResult(callbackContext, PluginResult.Status.ERROR,
                        new JSONObject(getErrorInfo(errorCode, errorMsg)));
            }
        });
    }
}
