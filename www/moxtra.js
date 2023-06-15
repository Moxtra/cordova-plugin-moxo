var exec = require("cordova/exec");
var pluginName = 'Moxtra';
var helper = require("./Helper");
var mepwindowDiv = null;

var getCallbackParameters = function (callback, params) {
    if (cordova.platformId === 'android') {
        params.unshift(callback?true:false);
    }

    return params;
}

/** @namespace */
var moxtra = {
    /**
     * Setup domain
     * Notice: This API MUST be invoked first before 'link'
     *
     * @param {string} baseDomain        - Your server domain
     * @param {string} certOrgName       - SSL cert organization name. Optional, default is null. 
     * @param {string} certPublicKey     - SSL cert public key. Optional, default is null. 
     * certPublicKey sample: "-----BEGIN PUBLIC KEY-----\n
     * YOUR PUBLIC KEY 
     * \n-----END PUBLIC KEY-----\n"
     * @param {boolean} ignoreBadCert    Ignore bad SSL cert or not. Default is true.
     */
    setupDomain : function(baseDomain, certOrgName, certPublicKey, ignoreBadCert) {
         cordova.exec(function () {}, function(){}, pluginName, 'setupDomain', [baseDomain, certOrgName, certPublicKey, ignoreBadCert]);
    },

    /**
     * Link MEP account with the access token.
     * @param {string}   accessToken - MEP login credential.
     * @param {function} success     - Callback invoked when link succeed.
     * @param {function} failure     - Callback invoked when link failed, with parameter like below:
     * {
     *      "error_code":0  //error code 
     *      "error_message": 'No network' //Detail error message
     * }
     */
    linkWithAccessToken : function(accessToken, success, failure) {
        cordova.exec(success, failure, pluginName, 'linkWithAccessToken', [accessToken]);
    },

    /**
     * Show a MEP window
     * Display MEP on top of your screen, it includes four tabs: Conversations, Contacts, Calendar, Settings
     * This function will use existing window instance if has one, that means page won't reflect setting changes, eg.voice_message_enabled
     */
    showMEPWindow : function() {
        cordova.exec(function () {}, function(){}, pluginName, 'showMEPWindow', []);
    },

    /**
     * Show a lite MEP window
     * A lite MEP window only includes: Conversations
     * This function will use existing window instance if has one, that means page won't reflect setting changes, eg.voice_message_enabled
     */
    showMEPWindowLite : function() {
        cordova.exec(function () {}, function(){}, pluginName, 'showMEPWindowLite', []);
    },

    /**
     * Hide MEP window
     */
    hideMEPWindow : function() {
        if (mepwindowDiv != null) {
            while(mepwindowDiv.parentNode) {
                helper.dettachTransparentClass(mepwindowDiv);
                mepwindowDiv = mepwindowDiv.parentNode;
            }
        }
        cordova.exec(function () {}, function(){}, pluginName, 'hideMEPWindow', []);
        mepwindowDiv = null;
        var style = document.getElementById('mepwindowcss');
        if (style != null) {
            style.parentNode.removeChild(style);
        }
    },

    /**
     * Destroy the MEP window.
     */
    destroyMEPWindow : function() {
        if (mepwindowDiv != null) {
            while(mepwindowDiv.parentNode) {
                helper.dettachTransparentClass(mepwindowDiv);
                mepwindowDiv = mepwindowDiv.parentNode;
            }
        }
        cordova.exec(function () {}, function(){}, pluginName, 'destroyMEPWindow', []);
        mepwindowDiv = null;
        var style = document.getElementById('mepwindowcss');
        if (style != null) {
            style.parentNode.removeChild(style);
        }
    },

    /**
      * Show MEP window in a specific web element
      * This function will use existing window instance if has one, that means page won't reflect setting changes, eg.voice_message_enabled
      * @param {HTMLDivElement} div   - The element where you want to embed MEP window, required to be transparent.
      *
      *
     */
    showMEPWindowInDiv : function(div) {
        var top = 0, left = 0;
        var width = div.offsetWidth, height = div.offsetHeight;
        var element = div;
        mepwindowDiv = element;
        do {
            top += element.offsetTop  || 0;
            left += element.offsetLeft || 0;
            element = element.offsetParent;
        } while(element);
        var style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = '.mepwindow { background: transparent !important; }';
        style.setAttribute('id', "mepwindowcss");
        while (div.parentNode) {
          helper.attachTransparentClass(div,style)
          div = div.parentNode;
        }
        var rect={"x":left, "y":top, "width": width, "height":height}
        cordova.exec(function () {}, function(){}, pluginName, 'showMEPWindowInDiv', [rect,true]);
    },

    /**
      * Show client dashboard window in a specific web element
      * This function will use existing window instance if has one, that means page won't reflect setting changes, eg.voice_message_enabled
      * Note: This function only works for client user since internal user doesn't have dashboard.
      *
      * @param {HTMLDivElement} div   - The element where you want to embed MEP window, required to be transparent.
     */
    showClientDashboardInDiv : function(div) {
        var top = 0, left = 0;
        var width = div.offsetWidth, height = div.offsetHeight;
        var element = div;
        mepwindowDiv = element;
        do {
            top += element.offsetTop  || 0;
            left += element.offsetLeft || 0;
            element = element.offsetParent;
        } while(element);
        var style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = '.mepwindow { background: transparent !important; }';
        style.setAttribute('id', "mepwindowcss");
        while (div.parentNode) {
            helper.attachTransparentClass(div,style)
            div = div.parentNode;
        }
        var rect={"x":left, "y":top, "width": width, "height":height}
        cordova.exec(function () {}, function(){},  pluginName, 'showClientDashboardInDiv', [rect]);
    },

    /**
     * Make web element interactive when it is showing on MEP window
     * @param {HTMLDivElement} div   - The element which needs to be interactive
     *
    */
    makeDivInteractive:function(div) {
        var top = 0, left = 0;
        var width = div.offsetWidth, height = div.offsetHeight;
        var element = div;
        do {
            top += element.offsetTop  || 0;
            left += element.offsetLeft || 0;
            element = element.offsetParent;
        } while(element);
        var rect={"x":left, "y":top, "width": width, "height":height}
        var divId = div.id || "";
        cordova.exec(function () {}, function(){}, pluginName, 'makeDivInteractive', [rect, divId]);
    },

    /**
    * Make web element noninteractive when it will be hidden or removed from MEP window.
    * IMPORTANT: This method is required to be triggered as a pair with makeDivInteractive, otherwise touch event on screen will be unpredictable.
    */
    makeDivNoninteractive:function(div) {
        var divId = div.id || "";
        cordova.exec(function () {}, function(){}, pluginName, 'makeDivNoninteractive', [divId]);
    },

    /**
     * Open chat with chat ID and scroll to the specified feed if present.
     *
     * @param {string}   chatID       - The chat to open.
     * @param {string}   feedSequence - The sequence of the scrolling target feed.
     * @param {function} success      - Callback invoked when open succeed.
     * @param {function} failure      - Callback invoked when open failed, with parameter like below:
     * {
     *      "error_code":4  //error code 
     *      "error_message": 'no network' //Detail error message
     * }
     */
    openChat : function(chatId, feedSequence, success, failure) {
        cordova.exec(success, failure, pluginName, 'openChat', [chatId, feedSequence]);
    },

    /** 
     * Show client live chat page 
     * Note: This function only works for client user since internal user doesn't have live chat.
     * @param {options}  reserved     - Reserved parameter, you could pass null for now.
     * @param {function} success      - Callback invoked when show succeed
     * @param {function} failure      - Callback invoked when show failed, with parameter like below:
     * {
     *      "error_code":4  //error code 
     *      "error_message": 'no network' //Detail error message
     * }
     */ 
    openLiveChat: function(options, success, failure) {
        cordova.exec(success, failure, pluginName, 'openLiveChat', [options]); 
    },

    /** 
     * Show client service reqeusts page 
     * Note: This function only works for client user since internal user doesn't have service reqeusts. 
     * @param {function} success      - Callback invoked when show succeed
     * @param {function} failure      - Callback invoked when show failed, with parameter like below:
     * {
     *      "error_code":4  //error code 
     *      "error_message": 'no network' //Detail error message
     * }
     */ 
    openServiceRequest: function(success, failure) {
        cordova.exec(success, failure, pluginName, 'openServiceRequest', []); 
    },

    /**
     * Start a meet with specific topic and members. Meeting screen will show up once meeting started succeed
     *
     * @param {string}   topic          - The meeting's topic, required
     * @param {array}    uniqueIds      - Unique id array of meeting members you intended to invite,optional.
     * @param {string}   chatId         - Id of the chat where you want to place meeting related messages,
     * @param {object}   options        - Additional options when start a meeting, optional. Supported key-values list below:
     * {
     *      "auto_join_audio": true,     //Boolean value, to join audio automaticaly or not, default is true.
     *      "auto_start_video": true     //Boolean value, to start video automaticaly or not, default is false.
     * }
     * @param {function} success        - Callback invoked when start succeed, with parameter like below:
     * {
     *      "session_id":"745831"  //meeting session id 
     * }
     * @param {function} failure      - Callback invoked when start failed, with parameter like below:
     * {
     *      "error_code":4  //error code 
     *      "error_message": 'no network' //Detail error message
     * }
     */
    startMeet: function(topic, uniqueIds, chatId, options, success, failure) {
        cordova.exec(success, failure, pluginName, 'startMeet', [topic, uniqueIds, chatId, options]);
    },

    /**
     * Start a meet with specific topic and members. Meeting screen will show up once meeting started succeed
     *
     * @param {string}   topic       - The meeting's topic, required
     * @param {array}    uniqueIds   - Unique id array of meeting members you intended to invite,optional
     * @param {string}   chatId      - Id of the chat where you want to place meeting related messages,optional.
     * @param {object}   options     - Additional options when schedule a meeting. Supported key-values list below:
     * {
     *      "start_time": "1584693257208"   //String value, planning meeting start time, required.
     *      "end_time":   "1584693557208"    //String value, Planning meeting end time, required.
     * }
     * @param {function} success     - Callback invoked when start succeed, with parameter like below:
     * {
     *      "session_id":"745831"  //meeting session id 
     * }
     * @param {function} failure      - Callback invoked when schedule failed, with parameter like below:
     * {
     *      "error_code":4  //error code 
     *      "error_message": 'no network' //Detail error message
     * }
     */
    scheduleMeet: function(topic, uniqueIds, chatId, options, success, failure) {
        cordova.exec(success, failure, pluginName, 'scheduleMeet', [topic, uniqueIds, chatId, options]);
    },

    /**
     * Join a scheduled meeting as participant or start scheduled meeting as host.
     * @param {string}   sessionId    - The meeting's session id, required.
     * @param {function} success      - Callback invoked when join succeed.
     * @param {function} failure      - Callback invoked when join failed, with parameter like below:
     * {
     *      "error_code":5  //error code 
     *      "error_message": 'object not found' //Detail error message
     * }
     */
    joinMeet: function(sessionId, success, failure) {
        cordova.exec(success, failure, pluginName, 'joinMeet', [sessionId]);
    },

    /**
     * Join a meeting anonymously.
     * @param {string}   sessionId    - The meeting's session id, required.
     * @param {object}   options      - Additional options when join a meeting anonymously. If currently there is a logged in user, options will be ignored. Supported key-values list below:
     * {
     *      "display_name": "Kate Bell"       //String value, as your name when join meeting , optional.
     *      "email":   "katebell@moxo.com"    //String value, as your email when join meeting , optional.
     * }
     * @param {function} success      - Callback invoked when join succeed.
     * @param {function} failure      - Callback invoked when join failed, with parameter like below:
     * {
     *      "error_code":5  //error code
     *      "error_message": 'object not found' //Detail error message
     * }
     */
    joinMeetAnonymously: function(sessionId, options, success, failure) {
            cordova.exec(success, failure, pluginName, 'joinMeetAnonymously', [sessionId,options]);
    },
    
    /**
     * Get current user's unread messages count
     * @param {function} success      - Callback invoked when get succeed, with an integer parameter which represents current unread messages count
     * @param {function} failure      - Callback invoked when get failed, with parameter like below:
     * {
     *      "error_code":3  //error code
     *      "error_message": 'sdk not initialized' //Detail error message
     * }
     */
    getUnreadMessageCount : function(success, failure) {
        cordova.exec(success, failure, pluginName, 'getUnreadMessageCount', []);
    },

    /**
     * Register your device token for push notification 
     *
     * @param {string} deviceToken - The device token.
     */
    registerNotification : function(deviceToken) {
        cordova.exec(function () {}, function () {}, pluginName, 'registerNotification', [deviceToken]);
    },

    /**
     * Verify notification is from MEP or not.
     *
     * @param {string}   notificationPayload - The notification payload with json string format.
     * @param {function} callback            - Callback that returns the notification is from mep or not, includes a boolean parameter.
     */
    isMEPNotification : function(notificationPayload, callback) {
        cordova.exec(function (){callback(true);}, function () {callback(false);}, pluginName, 'isMEPNotification', [notificationPayload]);
    },

    /**
     * Parse the notification to extract related info.
     *
     * @param {string}   notificationPayload    - The notification payload in json string format.
     * @param {function} success                - Callback invoked when parsing succeed, with parameter like below:
     * {
     *      //For chat: 
     *      "chat_id": "CBPErkesrtOeFfURA6gusJAD"  
     *      "feed_sequence": 191
     * 
     *      //For meet:
     *      "session_id": "255576178"  
     * }
     * @param {function} failure                - Callback invoked when parsing failed, with parameter like below:
     * {
     *      "error_code": 0  
     *      "error_message": "No network" //Detail error message
     * }
     */
    parseRemoteNotification : function(notificationPayload, success, failure) {
        cordova.exec(success, failure, pluginName, 'parseRemoteNotification', [notificationPayload]);
    },

    /**
     * Request MEP link state.
     *
     * @param {function} callback  - Callback that returns the MEP is linked or not, includes a boolean parameter.
     */
    isLinked : function(callback) {
        cordova.exec(function (){callback(true);}, function () {callback(false);}, pluginName, 'isLinked', []);
    },

    /**
     * Unlink the account from the MEP service.
     */
    unlink : function() {
        if (mepwindowDiv != null) {
            while(mepwindowDiv.parentNode) {
                helper.dettachTransparentClass(mepwindowDiv);
                mepwindowDiv = mepwindowDiv.parentNode;
            }
        }
        cordova.exec(function (){}, function () {}, pluginName, 'unlink', []);
        mepwindowDiv = null;
    },

    /**
    * Set the callback when user log out. 
    * Log out manually or kicked out by server, both cases will trigger the callback.
    * @param {function} callback   - Would be invoked when user get logout.
    */
    onLogout : function(callback) {
        cordova.exec(callback, callback, pluginName, 'onLogout', getCallbackParameters(callback, []));
    },

    /**
    * Set the callback when user clicked the join meeting button from timeline、calendar、 chat or ringer page
    *
    * @param {function} callback   - Would be invoked when user clicked any join meeting button from timeline、calendar chat、or ringer page, with parameter like below:
    * {
    *      "session_id": id of the meeting which user intend to join
    * }
    */
    onJoinMeetButtonClicked : function(callback) {
        cordova.exec(callback, callback, pluginName, 'onJoinMeetButtonClicked', getCallbackParameters(callback, []));
    },

    /**
    * Set the callback when user clicked the call button from timeline、calendar or chat
    *
    * @param {function} callback   - Would be invoked when user clicked any call button from timeline、calendar or chat, with parameter like below:
    * {
    *      "chat_id": id of the chat where call button clicked if is triggered from chat page 
    *      "unique_ids": An array which includes all chat member's unique_id if is triggered from chat page 
    * }
    */
    onCallButtonClicked : function(callback) {
        cordova.exec(callback, callback, pluginName, 'onCallButtonClicked', getCallbackParameters(callback, []));
    },

    /**
    * Set the callback when user clicked the view button of meeting
    *
    * @param {function} callback   - Would be invoked when user clicked view button of specific meeting, with parameter like below:
    * {
    *      "session_id": id of the meeting which user intend to view
    * }
    */
    onMeetViewButtonClicked : function(callback) {
        cordova.exec(callback, callback, pluginName, 'onMeetViewButtonClicked', getCallbackParameters(callback, []));
    },

    /**
    * Set the callback when user clicked the edit button of meeting 
    *
    * @param {function} callback   - Would be invoked when user clicked edit button of specific meeting, with parameter like below:
    * {
    *      "session_id": id of the meeting which user intend to view
    * }
    */
    onMeetEditButtonClicked : function(callback) {
        cordova.exec(callback, callback, pluginName, 'onMeetEditButtonClicked', getCallbackParameters(callback, []));
    },

    /**
    * Set the callback when user clicked the add member button inside the chat. 
    *
    * @param {function} callback   - Would be invoked when user clicked the add button, with parameter like below:
    * {
    *      "chat_id": id of the chat where call button clicked
    * }
    */
    onAddMemberInChatClicked : function(callback) {
         cordova.exec(callback, callback, pluginName, 'onAddMemberInChatClicked', getCallbackParameters(callback, []));
    },

    /**
    * Set the callback when user clicked the close button on top left of MEP window. If not set, sdk will do nothing.
    *
    * @param {function} callback   - Would be invoked when user clicked the close button.
    */
    onCloseButtonClicked : function(callback) {
        cordova.exec(callback, callback, pluginName, 'onCloseButtonClicked', getCallbackParameters(callback, []));
    },

    /**
    * Set the callback when user clicked the invite button in live meet.
    * If not set, the invite button will not show in live meet.
    *
    * @param {function} callback   - Would be invoked when user clicked any invite button in live meet, with parameter like below:
    * {
    *      "session_id": id of the meeting.
    * }
    */
    onInviteButtonInLiveMeetClicked : function(callback) {
        cordova.exec(callback, callback, pluginName, 'onInviteButtonInLiveMeetClicked', getCallbackParameters(callback, []));
    },

    /**
    * Set the callback when unread messages count updated
    *
    * @param {function} callback   - Would be invoked when user unread messages count updated, with an integer parameter which represents unread messages count post update
    */
    onUnreadMessageCountUpdated : function(callback) {
        cordova.exec(callback, callback, pluginName, 'onUnreadMessageCountUpdated', getCallbackParameters(callback, []));
    },

    /**
    * Set the feature configuration.
    *
    * @param {Object}   featureConfig    - The feature configuration.
    * Below are the json key/default value/description list:
    *  json key                       default value       description
    *  voice_message_enabled          true                Enable/Disable voice message feature. Default is enabled.
    */
    setFeatureConfig : function(featureConfig) {
        cordova.exec(function() {}, function() {}, pluginName, 'setFeatureConfig', [featureConfig]);
    }, 

    /**
    * For android only: switch main activity between other activities.
    *
    * @param {boolean}   show    - true to show main activity, and false to move main activity to background.
    */
    switchMainPage: function(show) {
        cordova.exec(function() {}, function() {}, pluginName, 'switchMainPage', [show]);
    },

    /**
     * Get current user's last active timestamp
     * @param {function} success      - Callback invoked when get succeed, with an unix timestamp in milliseconds
     * @param {function} failure      - Callback invoked when get failed, with parameter like below:
     * {
     *      "error_code":3  //error code
     *      "error_message": 'sdk not initialized' //Detail error message
     * }
     */
     getLastActiveTimestamp: function(success, failure) {
        cordova.exec(success, failure, pluginName, 'getLastActiveTimestamp', []);
    },

    /**
    * Set the callback when add user button in chat needs show/hide
    *
    * @param {function<bool>} callback   -  Would be invoked only when all pre-conditions satisfied. For example, the chat must be a group chat and current user has privilege to invite new member.
    * Parameter like below:
    * {
    *      "chat_id": id of the chat where add user button in
    * }
    */
     canAddUserInChat: function(callback) {
        if (callback != null) {
            cordova.exec(function(event) {
                var result = callback(event);
                cordova.exec(function () {}, function () {}, pluginName, 'setCanAddUserInChatResult', [result]);
            }, callback, pluginName, 'canAddUserInChat', getCallbackParameters(callback, []));
        } else {
            cordova.exec(callback, callback, pluginName, 'canAddUserInChat', getCallbackParameters(callback, []));
        }
    },

     /**
     * Listen current user's unread messages per type.
     * @param {object}   options     - Additional options when get unread count message. Supported key-values list below:
     * {
     *      "type": 5   //Which type of chat you intend to filter, 5 represents live chat, 6 represents service request.
     * }
     * @note This API only supports type 5(live chat) or type 6(service request) yet
     * @param {function} success      - Callback invoked when get succeed, with an integer parameter which represents corresponding unread messages count
     * @param {function} failure      - Callback invoked when get failed, with parameter like below:
     * {
     *      "error_code":3  //error code
     *      "error_message": 'sdk not initialized' //Detail error message
     * }
     */
      getUnreadMessageCountWithOption : function(option, success, failure) {
        cordova.exec(success, failure, pluginName, 'getUnreadMessageCountWithOption', getCallbackParameters(success, [option]));
     },

     /**
      * Show service request page in a specific web element
      * This function will use existing window instance if has one, that means page won't reflect setting changes, eg.voice_message_enabled
      * @param {HTMLDivElement} div   - The element where you want to embed service request page, required to be transparent.
      * 
     */
    showServiceRequestInDiv : function(div) {
        var top = 0, left = 0;
        var width = div.offsetWidth, height = div.offsetHeight;
        var element = div;
        mepwindowDiv = element;
        do {
            top += element.offsetTop  || 0;
            left += element.offsetLeft || 0;
            element = element.offsetParent;
        } while(element);
        var style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = '.mepwindow { background: transparent !important; }';
        style.setAttribute('id', "mepwindowcss");
        while (div.parentNode) {
            helper.attachTransparentClass(div,style)
            div = div.parentNode;
        }
        var rect={"x":left, "y":top, "width": width, "height":height}
        cordova.exec(function () {}, function(){},  pluginName, 'showServiceRequestInDiv', [rect]);
    },

    /**
      * Show live chat list page in a specific web element
      * This function will use existing window instance if has one, that means page won't reflect setting changes, eg.voice_message_enabled
      * @param {HTMLDivElement} div   - The element where you want to embed live chat listpage, required to be transparent.
      * 
     */
    showLiveChatInDiv : function(div) {
        var top = 0, left = 0;
        var width = div.offsetWidth, height = div.offsetHeight;
        var element = div;
        mepwindowDiv = element;
        do {
            top += element.offsetTop  || 0;
            left += element.offsetLeft || 0;
            element = element.offsetParent;
        } while(element);
        var style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = '.mepwindow { background: transparent !important; }';
        style.setAttribute('id', "mepwindowcss");
        while (div.parentNode) {
            helper.attachTransparentClass(div,style)
            div = div.parentNode;
        }
        var rect={"x":left, "y":top, "width": width, "height":height}
        cordova.exec(function () {}, function(){},  pluginName, 'showLiveChatInDiv', [rect]);
    }
};

module.exports = moxtra;
