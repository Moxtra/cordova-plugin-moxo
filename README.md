![moxo](https://assets-global.website-files.com/612ecbcc615e87b0b9b38524/62037243f5ede375a8705a34_Moxo-Website-Button.svg)

[ [Introduce](#introduce) &bull; [Preparation](#preparation) &bull; [Installation](#installation) &bull; [Initialization](#initialization) &bull; [Sample Code](#sample-code) &bull; [API Doc](#api-doc)]

## Introduce

**cordova-plugin-moxo** is a [moxo sdk](https://www.moxo.com/platform/sdks) cordova wrapper. Provide Moxo OneStop capabilities to your mobile app built on [Cordova](https://cordova.apache.org/)

### Supported Platforms

* iOS 13.0+
* Android 4.4+

## Preparation

Below sdk or tools are required before start to use cordova-plugin-moxo

* Node.js v14+
* Cordova v10.0.0+

### Android

* Android Studio
* Android SDK v19+

### iOS

* Xcode v14.1+
* Cocoapod v1.11.0+

For more cordova set up details, please ref to [cordova official site](https://cordova.apache.org/#getstarted)

## Installation

```sh
npm install @moxtradeveloper/cordova-plugin-moxo
```

## Initialization

### Login

Before login, we need to get access token, by Moxo RestAPI:

```js
// Get access token
var xmlHttp = new XMLHttpRequest();
var tokenDomain = 'https://myenv.moxo.com/v1/core/oauth/token';
var body = {
  client_id: 'my_clientid',
  org_id: 'my_orgid',
  unique_id: 'my_uniqueid',
  client_secret: 'my_clientsecret'
} 
xmlHttp.open( "POST", tokenDomain, false );
xmlHttp.setRequestHeader("Content-Type", "application/json;charset=UTF-8");
xmlHttp.send( JSON.stringify(body) );
var result = JSON.parse(xmlHttp.responseText);
const token = result.access_token;  
```

Then initialize moxo sdk and login with access token:

```js
// Setup domain
window.Moxtra.setupDomain('myenv.moxo.com');
//Login and show moxo engagement platform window
window.Moxtra.linkWithAccessToken(token,function(success) {
  if (success) {
    console.log(`Link success`);
    window.Moxtra.showMEPWindow();
  }
},function(error) {
    console.log(`Link failed!:${err}`);
});

```

### Show/Hide MEP window

After login successful, we can show/hide MEP window directly.

```js
window.Moxtra.showMEPWindow();
window.Moxtra.hideMEPWindow();
```

or even we could show MEP window in a web element

```js
var div = window.document.getElementById("mepwindow")
window.Moxtra.showMEPWindowInDiv(div)

window.Moxtra.showClientDashboardInDiv(div);
//Note: showClientDashboardInDiv is only for client user 
```

If you not using any div related API(showMEPWindowInDiv, showServiceRequestInDiv, etc) and getting some issues with page navigation, presentation, please try add below preference to your app's config.xml file

```js
<preference name="SupportMoxoDivAPI" value="false" />
```

## Sample Code

### Open existing chat

If user is logged in, call open chat API to open existing chat. If not logged in or chat does not exists, API will return error with error code and error message.

```js
window.Moxtra.openChat(chatId, null, function() {
  console.log(`Open chat success`);
}, function(error) {
  console.log(`Open chat failed!:${err}`);
})
```

### Notification

To enable notification feature, you'll need to integrate a notification plugin first, here we take [cordova-plugin-firebase-messaging](https://www.npmjs.com/package/cordova-plugin-firebase-cloud-messaging), which can help to get device token and notification payload.

#### Register notification

Through **cordova-plugin-firebase-messaging** `requestPermission()`, post user agreement, notification will be enabled for your app.
And when notification registration done, device token can be get from the callback of `getToken()`.
Then pass `token` to moxo function `window.Moxtra.registerNotification()` will register notification service to Moxtra server.

```js
window.cordova.plugins.firebase.messaging.requestPermission().then(function() {
    if (isiOS) {
        console.log("iOS Request Token...");
        //iOS
        window.cordova.plugins.firebase.messaging.getToken("apns-string").then(function(token) {
            console.log("APNS hex device token: ", token);
            window.Moxtra.registerNotification(token);
        });
    } else {
        //Android
        console.log("Android Request Token...");
        window.cordova.plugins.firebase.messaging.getToken().then(function(token) {
            console.log("Android device token: ", token);
                window.Moxtra.registerNotification(token);
            });
    }
});
```

#### Handle notification

Once notification arrived,  **cordova-plugin-firebase-messaging** function `onBackgroundMessage` or `onMessage` will be triggered with notification payload data.
Then pass payload to moxo function `parseRemoteNotification()` like below

```js
parseRemoteNotificationSuccess(info) {
    console.log("Parse Succeed:", JSON.stringify(payload));
    //Notification handling...
},
parseRemoteNotificationFailure(error) {
    console.log("Parse Failed");
    //Error handling...
},
window.cordova.plugins.firebase.messaging.onBackgroundMessage(function(payload) {
    console.log("Got notification in background: ", JSON.stringify(payload));
    window.Moxtra.parseRemoteNotification(payload,this.parseRemoteNotificationSuccess,this.parseRemoteNotificationFailure)
}),
window.cordova.plugins.firebase.messaging.onMessage(function(payload) {
    console.log("Got notification in foreground: ", JSON.stringify(payload));
    window.Moxtra.parseRemoteNotification(payload,this.parseRemoteNotificationSuccess,this.parseRemoteNotificationFailure)
})
```

If is a Moxtra notification, then success callback of the ``parseRemoteNotification()`` would be triggered with info parameter. Usually info contains ``'chat_id'`` or ``'meet_id'``, depends one which kind of notification you received.

To do more, you can invoke function `openChat(chat_id)` to open target chat directly.

#### Sample notification payload

##### iOS

```json
{
    "aps": {
        "alert": {
            "body": "cheng4: hi",
            "action_loc_key": "BCA"
        },
        "sound": "default"
    },
    "request": {
        "object": {
            "board": {
                "id": "CBPErkesrtOeFfURA6gusJAD",
                "feeds": [{
                    "sequence": 191
                }]
            }
        }
    },
    "id": "359",
    "moxtra": "",
    "category": "message",
    "board_id": "CBPErkesrtOeFfURA6gusJAD",
    "moxtra": ""
}
```

##### Android

```json
[
  {
    "count": "7",
    "sound": "default",
    "title": "rm1 Zhang",
    "message": "rm1 Zhang: 1",
    "additionalData": {
       "feed_sequence": "3234",
       "action_loc_key": "BCA",
       "board_feed_unread_count": "3",
       "moxtra": "",
       "user_id": "CUxceIGfpXcHBna163lfFMD0",
       "arg1": "rm1 Zhang",
       "arg2": "1",
       "arg3": "",
       "loc_key": "BCM",
       "request": {
         "object": {
        "board": {
           "id": "CBPErkesrtOeFfURA6gusJAD",
           "feeds": [{
              "sequence": 3234
                    }]
                 }
               }
        },
       "board_id": "CBPErkesrtOeFfURA6gusJAD",
       "coldstart": false,
       "board_name": "rm1 Zhang",
       "foreground": true
    }
}]
```

## API Doc
[API doc](https://htmlpreview.github.io/?https://github.com/Moxtra/cordova-plugin-moxo/blob/main/docs/moxtra.html)
