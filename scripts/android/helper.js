var fs = require("fs");
var path = require("path");

function writeFile(file, contents) {
  fs.writeFileSync(file, contents);
}

function readFile(file) {
  return fs.readFileSync(file, "utf-8");
}

function fileExists(file) {
  return fs.existsSync(file);
}

function getCordovaMainActivity() {
  return path.join("platforms", "android", "CordovaLib", "src", "org", "apache", "cordova", "CordovaActivity.java");
}

function getCordovaBuildGradle() {
  return path.join("platforms", "android", "CordovaLib", "build.gradle");
}

function getCordovaAndroidManifest() {
  return path.join("platforms", "android", "app", "src", "main", "AndroidManifest.xml");
}

function getGradlePrepertiesFile() {
  return path.join("platforms", "android", "gradle.properties");
}

function changeExtendActivity(activity) {
  var match = activity.match(/^(\s*)import android\.app\.Activity;/m);
  var addImport = "import android.support.v4.app.FragmentActivity;";
  var changeActivity = "extends FragmentActivity";
  if (match) {
    modifiedLine = match[0] + '\n' + addImport;
    activity = activity.replace(/^(\s*)import android\.app\.Activity;/m, modifiedLine);
  }

  match = activity.match(/extends Activity/m);
  if (match) {
    activity = activity.replace(/extends Activity/m, changeActivity);
  }
  return activity;
}

function addDependency(gradle) {
  var match = gradle.match(/\bdependencies\s*\{[^\{\}]+\}(?![^\{]+\})/gm);
  if (match) {
    var second = match[0];
    second = second.replace(/\bdependencies\s*\{/m, "dependencies {\n   implementation \"com.android.support:support-fragment:28.0.0\" \/\/Added by Moxtra");
    gradle = gradle.replace(match, second);
  } else {
    gradle = gradle + "\n\n" + "dependencies {\n   implementation \"com.android.support:support-fragment:28.0.0\" \/\/Added by Moxtra\n }\n";
  }

  return gradle;
}

function contentMatch(content, regex) {
  var match = content.match(regex);
  if (match) {
    return true;
  }
  return false;
}

function replaceContent(originContent, replaceContent, regex) {
  return originContent.replace(regex, replaceContent);
}

function processManifest(isInstall) {
  /*
  var filePath = getCordovaAndroidManifest();
  var content = readFile(filePath);
  var manifestContent = content.match(/^(\s*)<manifest(\n|.)*?>/gm);
  var appContent = content.match(/^(\s*)<application(\n|.)*?>/gm);
  var activityContent = content.match(/^(\s*)<activity(\n|.)*?>/gm);
  var found = false;

  if (manifestContent) {
    found = contentMatch(manifestContent[0], /xmlns:tools=\"http:\/\/schemas\.android\.com\/tools\"/g);
    if (isInstall && !found) {
      //Add xmlns:tools
      var replaced = replaceContent(manifestContent[0], " xmlns:tools=\"http:\/\/schemas\.android\.com\/tools\">", />/g);
      content = replaceContent(content, replaced, manifestContent[0]);
    } else if (!isInstall && found) {
      //Remove xmlns:tools
      var replaced = replaceContent(manifestContent[0], "", /(\s*)xmlns:tools=\"http:\/\/schemas\.android\.com\/tools\"\n?/g);
      content = replaceContent(content, replaced, manifestContent[0]);
    }
  }

  if (appContent) {
    found = contentMatch(appContent[0], /tools:replace=\"android:appComponentFactory\"/g);
    var appComponentFactory = appContent[0];
    if (isInstall && !found) {
      //Add tools:replace
      appComponentFactory = replaceContent(appContent[0], " tools:replace=\"android:appComponentFactory\">", />/g);
      content = replaceContent(content, appComponentFactory, appContent[0]);
    } else if (!isInstall && found) {
      //Remove tools:replace
      appComponentFactory = replaceContent(appContent[0], "", /(\s*)tools:replace=\"android:appComponentFactory\"\n?/g);
      content = replaceContent(content, appComponentFactory, appContent[0]);
    }

    found = contentMatch(appComponentFactory, /android:appComponentFactory=\"moxtra\"/g);
    if (isInstall && !found) {
      //Add android:appComponentFactory
      var appComponentFactoryValue = replaceContent(appComponentFactory, " android:appComponentFactory=\"moxtra\">", />/g);
      content = replaceContent(content, appComponentFactoryValue, appComponentFactory);
    } else if (!isInstall && found) {
      //Remove android:appComponentFactory
      var appComponentFactoryValue = replaceContent(appComponentFactory, "", /(\s*)android:appComponentFactory=\"moxtra\"\n?/g);
      content = replaceContent(content, appComponentFactoryValue, appComponentFactory);
    }
  } else {
    console.log("appContent[0] null");
  }

  if (activityContent) {
    found = false;
    for (var i = 0; i < activityContent.length; i++) {
      if (contentMatch(activityContent[i], /android:name=\"MainActivity\"/g)) {
        found = contentMatch(activityContent[i], /android:theme=\"@style\/Theme\.AppCompat\.NoActionBar\"/g);
        if (isInstall && !found) {
          //Add AppCompat theme 
          var replacedValue = replaceContent(activityContent[i], "android:theme=\"@style\/Theme\.AppCompat\.NoActionBar\"", /android:theme=\".*?\"/g);
          content = replaceContent(content, replacedValue, activityContent[i]);
        } else if (!isInstall && found) {
          //Remove AppCompat theme  
          var replacedValue = replaceContent(activityContent[i], "android:theme=\"@android:style\/Theme\.DeviceDefault\.NoActionBar\"", /android:theme=\".*?"\n?/g);
          content = replaceContent(content, replacedValue, activityContent[i]);
        }
        break;
      } else {
        console.log("no MainActivity found!");
      }
    }
  } else {
    console.log("activityContent[0] null");
  }

  writeFile(filePath, content);
    */
}

module.exports = {

  modifyCordovaActivity: function() {
    var filePath = getCordovaMainActivity();
    if (!fileExists(filePath)) {
      return;
    }
    var mainActivity = readFile(filePath);
    mainActivity = changeExtendActivity(mainActivity);
    writeFile(filePath, mainActivity);
  },

  restoreCordovaActivity: function() {
    var filePath = getCordovaMainActivity();
    if (!fileExists(filePath)) {
      return;
    }

    var extendsActivity = "extends Activity";
    var mainActivity = readFile(filePath);

    mainActivity = mainActivity.replace(/\nimport(.*?)FragmentActivity;/m, '');
    mainActivity = mainActivity.replace(/extends FragmentActivity/m, extendsActivity);
    writeFile(filePath, mainActivity);
  },

  modifyCordovaBuildGradle: function() {
    var filePath = getCordovaBuildGradle();
    if (!fileExists(filePath)) {
      return;
    }

    var gradlefile = readFile(filePath);
    gradlefile = addDependency(gradlefile);
    writeFile(filePath, gradlefile);
  },

  restoreCordovaBuildGradle: function() {
    var filePath = getCordovaBuildGradle();
    if (!fileExists(filePath)) {
      return;
    }

    var gradlefile = readFile(filePath);

    // remove any lines we added
    gradlefile = gradlefile.replace(/(?:^|\r?\n)(.*)Added by Moxtra*?(?=$|\r?\n)/g, '');

    writeFile(filePath, gradlefile);
  },

  modifyCordovaAndroidManifest: function() {
    var filePath = getCordovaAndroidManifest();

    if (!fileExists(filePath)) {
      return;
    }

    processManifest(true);
  },

  restoreCordovaAndroidManifest: function() {
    var filePath = getCordovaAndroidManifest();

    if (!fileExists(filePath)) {
      return;
    }

    processManifest(false);
  },

  check_before_compile: function() {
    var mainActivityPath = getCordovaMainActivity();
    var gradleProperties = getGradlePrepertiesFile();
    if (!fileExists(mainActivityPath) || !fileExists(gradleProperties)) {
      return;
    }

    var gradlePropertiesContent = readFile(gradleProperties);
    var mainActivityContent = readFile(mainActivityPath);
    if (contentMatch(gradlePropertiesContent, /android\.useAndroidX=true/gm)) {
      //Modify Main Activity import
      mainActivityContent = mainActivityContent.replace("android.support.v4.app.FragmentActivity", "androidx.fragment.app.FragmentActivity");
      writeFile(mainActivityPath, mainActivityContent);
    }
  }
};