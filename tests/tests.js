var mep_domain = 'https://baz.grouphour.com';
var client_id = "ODg5YWQzMjk";
var unique_id = "brad.rm";
var org_id = "Pz532Kto7JgJ1PyKr80MHJ0";
var client_secret = "MzY3NDc5ZWY";
exports.defineAutoTests = function () {
  jasmine.DEFAULT_TIMEOUT_INTERVAL = 2000;
  function getAccessToken() {
    var xmlHttp = new XMLHttpRequest();
    var tokenDomain = mep_domain + "/v1/oauth/token?" + `client_id=${client_id}&client_secret=${client_secret}&grant_type=http://www.moxtra.com/auth_uniqueid&uniqueid=${unique_id}&timestamp=${Date.now()}&orgid=${org_id}`
    console.log(tokenDomain);
    xmlHttp.open( "POST", tokenDomain, false );
    xmlHttp.send( null );
    if (xmlHttp.status == 200) {
        var result = JSON.parse(xmlHttp.responseText);
        return result.access_token;
    }
    return "";
  };
  describe('Plugin ready', function () {
      it('plugin should exist', function () {
          expect(window.Moxtra).toBeDefined();
      });
      //Functions defined
      it('setupDomain should defined', function () {
        expect(typeof window.Moxtra.setupDomain).toEqual('function');
      });
      it('linkWithAccessToken should defined', function () {
        expect(typeof window.Moxtra.linkWithAccessToken).toEqual('function');
      });
      it('showMEPWindow should defined', function () {
        expect(typeof window.Moxtra.showMEPWindow).toEqual('function');
      });
      it('showMEPWindowLite should defined', function () {
        expect(typeof window.Moxtra.showMEPWindowLite).toEqual('function');
      });
      it('hideMEPWindow should defined', function () {
        expect(typeof window.Moxtra.hideMEPWindow).toEqual('function');
      });
      it('destroyMEPWindow should defined', function () {
        expect(typeof window.Moxtra.destroyMEPWindow).toEqual('function');
      });
      it('openChat should defined', function () {
        expect(typeof window.Moxtra.openChat).toEqual('function');
      });
      it('registerNotification should defined', function () {
        expect(typeof window.Moxtra.registerNotification).toEqual('function');
      });
      it('isMEPNotification should defined', function () {
        expect(typeof window.Moxtra.isMEPNotification).toEqual('function');
      });
      it('parseRemoteNotification should defined', function () {
        expect(typeof window.Moxtra.parseRemoteNotification).toEqual('function');
      });
      it('isLinked should defined', function () {
        expect(typeof window.Moxtra.isLinked).toEqual('function');
      });  
      it('unlink should defined', function () {
        expect(typeof window.Moxtra.unlink).toEqual('function');
      });  
      it('onLogout should defined', function () {
        expect(typeof window.Moxtra.onLogout).toEqual('function');
      });  
      it('onCloseButtonClicked should defined', function () {
        expect(typeof window.Moxtra.onCloseButtonClicked).toEqual('function');
      });  
  });

  describe('linkWithAccessToken tests', function () {
    beforeAll(function() {
      window.Moxtra.setupDomain(mep_domain,null,null,null);
    });

    it('linkWithAccessToken with null token',function(done){
      window.Moxtra.linkWithAccessToken(null,function(success){
        expect(success).toBeNull();
        done();
      },function(error){
        expect(error).toBeDefined();
        done();
      });
    },90000);

    it('linkWithAccessToken with invalid token',function(done){
      window.Moxtra.linkWithAccessToken("anyvalidtoken",function(success){
        expect(success).toBeNull();
        done();
      },function(error){
        expect(error).toBeDefined();
        done();
      });
    },90000);

    it('linkWithAccessToken with valid token',function(done){
      //get a token first
      var token = getAccessToken();
      console.log("token got : " + token);
      window.Moxtra.linkWithAccessToken(token,function(success){
        console.log("login success");
        expect(success).toBeDefined();
        done();
      },function(error){
        console.log("login failed" + error);
        expect(error).toBeNull();
        done();
      });
    },90000);
  });

  describe('openChat tests without link', function() {
    //Before link
    beforeAll(function(done){
        window.Moxtra.onLogout(function() {
            done();
        },90000);
        window.Moxtra.unlink();
    },90000);
    it('open chat with valid id,sequence null',function(done) {
       window.Moxtra.openChat("CBPErkesrtOeFfURA6gusJAD",null,function(success){
           expect(success).toBeNull();
           done();
       },function(error) {
           expect(error).toBeDefined();
           done();
       });
    });
  });

  describe('openChat tests post link', function(){
      function linkAndDone(done) {
        window.Moxtra.setupDomain(mep_domain,null,null,null);
        var token = getAccessToken();
        console.log('Token got:' + token);
        window.Moxtra.linkWithAccessToken(token,function(success){
          console.log('login success');
          done();
        },function(error){
          console.log('login failed' + error);
          done();
        });
      }
      //Link SDK first
      beforeAll(function(done) {
        linkAndDone(done);
      },90000);
      afterEach(function(){
        window.Moxtra.hideMEPWindow();
      });

      it('open chat with id null,sequence null',function(test) {
        window.Moxtra.openChat(null,null,function(success){
          expect(success).toBeNull();
          test();
        },function(error) {
          expect(error).toBeDefined();
          test();
        });
      },90000);
      it('open chat with invalid id,sequence null',function(done) {
        window.Moxtra.openChat("invalid_chat_id",null,function(success){
          expect(success).toBeNull();
          done();
        },function(error) {
          expect(error).toBeDefined();
          done();
        });
      },90000);

      it('open chat with valid id,invalid sequence ',function(done) {
        window.Moxtra.showMEPWindow();
        window.Moxtra.openChat("CBPErkesrtOeFfURA6gusJAD","invalid",function(success){
          expect(success).toBeDefined();
          done();
        },function(error) {
          expect(error).toBeNull();
          done();
        });
      },90000);

      it('open chat with valid id,valid sequence ',function(done) {
        window.Moxtra.showMEPWindow();
        window.Moxtra.openChat("CBPErkesrtOeFfURA6gusJAD","44",function(success){
          expect(success).toBeDefined();
          done();
        },function(error) {
          expect(error).toBeNull();
          done();
        });
      },90000);
  });

  describe('is MEP notification token tests', function(){
    it('parse non-mep notification',function(done){
      var samplePayload = '{"aps":{"alert":{"body":"hello","title":"You have a new message"},"sound":"default","badge":1},"custom1":"custom information"}';
      window.Moxtra.isMEPNotification(samplePayload,function(success){
        expect(success).toEqual(false);
        done();
      });
    });

    it('parse mep notification',function(done){
      var samplePayload = '{"aps":{"alert":{"body":"cheng4: hi","action_loc_key":"BCA"},"sound":"default"},"request":{"object":{"board":{"id":"CBb5xBIyDu9h8P5GwKd0JifH","feeds":[{"sequence":191}]}}},"id":"26","moxtra":"","category":"message","board_id":"CBb5xBIyDu9h8P5GwKd0JifH"}';
      if (cordova.platformId == 'android') {
        samplePayload = '{"registration_ids": ["Cs1ASF-Up"],"data": {"moxtra":"", "action_loc_key": "BCA","loc_key": "BCM", "arg1": "RM009","arg2": "this is a test message","arg3": "","badge": 25, "sound": "default", "board_id": "B5liMA6Frf4DEu4k40P6B1A","feed_sequence": 2644,"user_id": "","request": {"object":{"board":{"id":"B5liMA6Frf4DEu4k40P6B1A","feeds":[{"sequence":2644}]}}},"board_name": "Project 002","board_feed_unread_count": 13},"priority": "high"}';
      }
      window.Moxtra.isMEPNotification(samplePayload,function(success){
        expect(success).toEqual(true);
        done();
      });
    });
  });

  describe('parse notification tests',function(){
    it('parse a non-mep notificaiton payload',function(done){
      var samplePayload = '{"aps":{"alert":{"body":"hello","title":"You have a new message"},"sound":"default","badge":1},"custom1":"custom information"}';
      window.Moxtra.parseRemoteNotification(samplePayload,function(data){
        expect(data).toBeNull();
        done();
      },function(errordata){
        expect(errordata).toBeDefined();
        done();
      });
    });
    it('parse an invalid mep notification payload',function(done){
      var samplePayload = '{"aps":{"alert":{"body":"cheng4: hi","action_loc_key":"BCA"},"sound":"default"},"request":{},"id":"26","moxtra":"","category":"message","board_id":"CBb5xBIyDu9h8P5GwKd0JifH"}';
      window.Moxtra.parseRemoteNotification(samplePayload,function(data){
        expect(data).toBeNull();
        done();
      },function(errordata){
        expect(errordata).toBeDefined();
        done();
      });
    });
    it('parse valid mep notification payload',function(done){
      var samplePayload = '{"aps":{"alert":{"body":"cheng4: hi","action_loc_key":"BCA"},"sound":"default"},"request":{"object":{"board":{"id":"CBPErkesrtOeFfURA6gusJAD","feeds":[{"sequence":191}]}}},"id":"359","moxtra":"","category":"message","board_id":"CBPErkesrtOeFfURA6gusJAD","moxtra":""}';
      if (cordova.platformId == 'android') {
        samplePayload = '{"registration_ids": ["Cs1ASF-Up"],"data": {"moxtra":"", "action_loc_key": "BCA","loc_key": "BCM", "arg1": "RM009","arg2": "this is a test message","arg3": "","badge": 25, "sound": "default", "board_id": "B5liMA6Frf4DEu4k40P6B1A","feed_sequence": 2644,"user_id": "","request": {"object":{"board":{"id":"B5liMA6Frf4DEu4k40P6B1A","feeds":[{"sequence":2644}]}}},"board_name": "Project 002","board_feed_unread_count": 13},"priority": "high"}';
      }
      window.Moxtra.parseRemoteNotification(samplePayload,function(data){
        expect(data).toBeDefined();
        done();
      },function(errordata){
        expect(errordata).toBeNull();
        done();
      });
    });
  });

  describe('isLinked tests',function() {
    it('not linked before link',function(done) {
       window.Moxtra.onLogout(function() {
               window.Moxtra.isLinked(function(linked){
                 expect(linked).toBe(false);
                 done();
               });
       });
       window.Moxtra.unlink();
    },90000);
    it('linked after link',function(done){
      window.Moxtra.setupDomain(mep_domain,null,null,null);
      var token = getAccessToken();
      window.Moxtra.linkWithAccessToken(token,function(success){
        window.Moxtra.isLinked(function(linked){
          expect(linked).toBe(true);
          done();
        });
      },function(error){
        expect(error).toBeNull();
        done();
      });
    },90000);
    it('not linked after unlink',function(done){
      window.Moxtra.onLogout(function() {
          window.Moxtra.isLinked(function(linked){
              expect(linked).toBe(false);
              done();
            });
      });
      window.Moxtra.unlink();
    },90000);
  });
};

exports.defineManualTests = function(contentEl, createActionButton) {

  createActionButton('Simple Test', function() {
    console.log(JSON.stringify(foo, null, '\t'));
  });

  createActionButton('Complex Test', function() {
    contentEl.innerHTML = "sdada";
  });
};

