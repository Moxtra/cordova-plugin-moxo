package com.moxtra.mepplugin;

import android.view.ViewGroup;

import org.apache.cordova.CallbackContext;
import org.json.JSONArray;

public interface IPluginView {
  boolean getVisible();
  boolean getClickable();
  String getOverlayId();
  ViewGroup getView();
  int getViewDepth();
  void onDestroy();
  void onStart();
  void onStop();
  void onPause(boolean multitasking);
  void onResume(boolean multitasking);
  void remove(JSONArray args, final CallbackContext callbackContext);
  void attachToWebView(JSONArray args, final CallbackContext callbackContext);
  void detachFromWebView(JSONArray args, final CallbackContext callbackContext);
}
