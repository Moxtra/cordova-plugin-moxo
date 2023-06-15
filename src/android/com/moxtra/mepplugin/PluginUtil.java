package com.moxtra.mepplugin;

import android.content.res.Resources;

public class PluginUtil {
  public static float getDensity() {
    return Resources.getSystem().getDisplayMetrics().density;
  }

}
