//
//  MoxtraMeetIntegration.m
//
//  Created by Gitesh on 26/4/2017.
//
//

#import "MoxtraIntegration.h"
#import "MXDelegateMapper.h"
#import "MoxtraOverlayWindow.h"
#import "MoxtraAspects.h"
#import <MEPSDK/MEPSDK.h>
#import <Cordova/NSDictionary+CordovaPreferences.h>

const static NSString *pluginName = @"cordova-plugin-moxo.Moxtra";

const static NSString *uniqueIdKey = @"unique_ids";
const static NSString *chatIdKey = @"chat_id";
const static NSString *sessionIdKey = @"session_id";
const static NSString *autoJoinAudioKey = @"auto_join_audio";
const static NSString *autoStartVideoKey = @"auto_start_video";
const static NSString *meetStartDateKey = @"start_time";
const static NSString *meetEndDateKey = @"end_time";
const static NSString *joinMeetAnonymouslyDisplayNameKey = @"display_name";
const static NSString *joinMeetAnonymouslyEmailKey = @"email";
const static NSString *joinMeetAnonymouslyPasswordKey = @"password";
const static NSString *openLiveChatChannelKey = @"channel_id";
const static NSString *openLiveChatMessageKey = @"message";

const static NSString *voiceMessageConfigKey = @"voice_message_enabled";

const static NSString *errorCodeKey = @"error_code";
const static NSString *errorMessageKey = @"error_message";

static NSString *invalidCbkId = @"INVALID";

const NSMutableDictionary *delegateMap;

@interface MoxtraUnreadCountMap: NSObject
@property (nonatomic, assign) MEPChatType chatType;
@property (nonatomic, strong) NSString *callbackId;
@property (nonatomic, assign) NSInteger lastCount;
+ (instancetype)mapWithChatType:(MEPChatType)type
                     callbackId:(NSString *)callbackId
                      lastCount:(NSInteger)count;
@end
@implementation MoxtraUnreadCountMap
+ (instancetype)mapWithChatType:(MEPChatType)type
                     callbackId:(NSString *)callbackId
                      lastCount:(NSInteger)count {
    MoxtraUnreadCountMap *map = [[MoxtraUnreadCountMap alloc] init];
    map.chatType = type;
    map.callbackId = callbackId;
    map.lastCount = count;
    return map;
}
@end

@interface MoxtraViewController: UIViewController
@property (nonatomic, readwrite, strong) NSArray* supportedOrientations;
@end
@implementation MoxtraViewController

- (instancetype)init {
    if (self = [super init]) {
        self.supportedOrientations = [self parseInterfaceOrientations:
            [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UISupportedInterfaceOrientations"]];
    }
    return self;
}
// CB-12098
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
- (NSUInteger)supportedInterfaceOrientations
#else
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
#endif
{
    NSUInteger ret = 0;

    if ([self supportsOrientation:UIInterfaceOrientationPortrait]) {
        ret = ret | (1 << UIInterfaceOrientationPortrait);
    }
    if ([self supportsOrientation:UIInterfaceOrientationPortraitUpsideDown]) {
        ret = ret | (1 << UIInterfaceOrientationPortraitUpsideDown);
    }
    if ([self supportsOrientation:UIInterfaceOrientationLandscapeRight]) {
        ret = ret | (1 << UIInterfaceOrientationLandscapeRight);
    }
    if ([self supportsOrientation:UIInterfaceOrientationLandscapeLeft]) {
        ret = ret | (1 << UIInterfaceOrientationLandscapeLeft);
    }

    return ret;
}

- (BOOL)supportsOrientation:(UIInterfaceOrientation)orientation
{
    return [self.supportedOrientations containsObject:[NSNumber numberWithInt:(int)orientation]];
}

- (NSArray*)parseInterfaceOrientations:(NSArray*)orientations
{
    NSMutableArray* result = [[NSMutableArray alloc] init];

    if (orientations != nil) {
        NSEnumerator* enumerator = [orientations objectEnumerator];
        NSString* orientationString;

        while (orientationString = [enumerator nextObject]) {
            if ([orientationString isEqualToString:@"UIInterfaceOrientationPortrait"]) {
                [result addObject:[NSNumber numberWithInt:UIInterfaceOrientationPortrait]];
            } else if ([orientationString isEqualToString:@"UIInterfaceOrientationPortraitUpsideDown"]) {
                [result addObject:[NSNumber numberWithInt:UIInterfaceOrientationPortraitUpsideDown]];
            } else if ([orientationString isEqualToString:@"UIInterfaceOrientationLandscapeLeft"]) {
                [result addObject:[NSNumber numberWithInt:UIInterfaceOrientationLandscapeLeft]];
            } else if ([orientationString isEqualToString:@"UIInterfaceOrientationLandscapeRight"]) {
                [result addObject:[NSNumber numberWithInt:UIInterfaceOrientationLandscapeRight]];
            }
        }
    }
    // default
    if ([result count] == 0) {
        [result addObject:[NSNumber numberWithInt:UIInterfaceOrientationPortrait]];
    }

    return result;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return [UIApplication sharedApplication].statusBarStyle;
}
@end

@interface MoxtraIntegration()<MEPClientDelegate>
@property (nonatomic, copy) NSString *baseDomain;

@property (nonatomic, copy) NSString *certOrgName;
@property (nonatomic, copy) NSString *certPublicKey;
@property (nonatomic, assign) BOOL ignoreBadCert;

@property (nonatomic, copy) NSString *logoutCbkId;
@property (nonatomic, copy) NSString *logoutClickedCbkId;
@property (nonatomic, copy) NSString *joinMeetBtnCbkId;
@property (nonatomic, copy) NSString *callBtnCbkId;
@property (nonatomic, copy) NSString *addMemberBtnCbkId;
@property (nonatomic, copy) NSString *viewMeetBtnCbkId;
@property (nonatomic, copy) NSString *editMeetBtnCbkId;
@property (nonatomic, copy) NSString *inviteBtnInLiveMeetCbkId;
@property (nonatomic, copy) NSString *unreadCountUpdatedCbkId;

@property (nonatomic, strong) NSString *waiting;
@property (nonatomic, strong) NSNumber *canAddUser;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, MoxtraUnreadCountMap*> *unreadCountMaps;
@property (nonatomic, assign) CGRect rect;
@property (nonatomic, strong) UIViewController *webWindowRootVC;
@property (nonatomic, strong) MoxtraOverlayWindow *webWindow;
@property (nonatomic, strong) MoxtraOverlayWindow *mepWindow;
@end

@implementation MoxtraIntegration

- (void)pluginInitialize {
    NSDictionary* settings = self.commandDelegate.settings;
    if ([settings cordovaBoolSettingForKey:@"SupportMoxoDivAPI" defaultValue:YES]) {
        self.webView.backgroundColor = [UIColor clearColor];
        self.webView.scrollView.backgroundColor = [UIColor clearColor];
        self.webView.opaque = NO;
        [self.webView removeFromSuperview];


        MoxtraOverlayWindow *window = [[MoxtraOverlayWindow alloc] init];
        self.webWindowRootVC = [[MoxtraViewController alloc] init];
        window.rootViewController = self.webWindowRootVC;
        window.backgroundColor = [UIColor clearColor];
        window.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
        window.forPlugin = @(1);
        [self.webWindowRootVC.view addSubview:self.webView];
        [window showAnimated:NO];
        self.webWindow = window;
    }
}


- (MoxtraOverlayWindow *)mepWindow {
    if (!_mepWindow) {
        _mepWindow = [[MoxtraOverlayWindow alloc] init];
        _mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel];
    }
    return _mepWindow;
}
#pragma mark - Functions
- (void)setupDomain:(CDVInvokedUrlCommand*)command
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupDomain:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    
    self.baseDomain = [command.arguments objectAtIndex:0];
    self.certOrgName = [command.arguments objectAtIndex:1];
    self.certPublicKey = [command.arguments objectAtIndex:2];
    self.ignoreBadCert = [[command.arguments objectAtIndex:3] boolValue];
    
    if ([self.baseDomain isEqual:[NSNull null]])
        self.baseDomain = @"";
    if ([self.certOrgName isEqual:[NSNull null]])
        self.certOrgName = @"";
    if ([self.certPublicKey isEqual:[NSNull null]])
        self.certPublicKey = @"";
    
    
    MEPLinkConfig *linkConfig = [MEPLinkConfig new];
    linkConfig.certOrganization = self.certOrgName;
    linkConfig.certPublicKey = self.certPublicKey;
    linkConfig.ignoreBadCert = self.ignoreBadCert;
    [[MEPClient sharedInstance] setupWithDomain:self.baseDomain linkConfig:linkConfig];
}

- (void)linkWithAccessToken:(CDVInvokedUrlCommand*)command
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self linkWithAccessToken:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    
    NSString *accessToken = [command.arguments objectAtIndex:0];
    
    if ([accessToken isEqual:[NSNull null]])
        accessToken = @"";
    
    [[MEPClient sharedInstance] linkUserWithAccessToken:accessToken completionHandler:^(NSError * _Nullable errorOrNil) {
        CDVPluginResult *pluginResult = nil;
        if (!errorOrNil)
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            
        }
        else{
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self universalErrorFromMEP:errorOrNil]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)showMEPWindow:(CDVInvokedUrlCommand*)command
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showMEPWindow:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
    [self.webWindow resignKeyWindow];
    [self.mepWindow resignKeyWindow];
    [[MEPClient sharedInstance] showMEPWindow];
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if ([window isKindOfClass:NSClassFromString(@"MEPMainWindow")]) {
            window.windowLevel = UIWindowLevelStatusBar - 0.3;
        }
    }
}

- (void)showMEPWindowLite:(CDVInvokedUrlCommand*)command
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showMEPWindowLite:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
    [[MEPClient sharedInstance] showMEPWindowLite];
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if ([window isKindOfClass:NSClassFromString(@"MEPMainWindow")]) {
            window.windowLevel = UIWindowLevelStatusBar - 0.3;
        }
    }
}

- (void)hideMEPWindow:(CDVInvokedUrlCommand*)command
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideMEPWindow:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;

    [[MEPClient sharedInstance] hideMEPWindow];
    if (self.mepWindow) {
        self.webWindow.hitThrough = CGRectZero;
        [self.mepWindow dismissAnimated:YES];
    }
    [self.webWindow makeKeyWindow];
}

- (void)destroyMEPWindow:(CDVInvokedUrlCommand*)command
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self destroyMEPWindow:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    
    [[MEPClient sharedInstance] dismissMEPWindow];
    if (self.mepWindow) {
        self.webWindow.hitThrough = CGRectZero;
        [self.mepWindow dismissAnimated:YES];
        self.mepWindow = nil;
        [self.webWindow makeKeyWindow];
    }
}

- (void)showMEPWindowInDiv:(CDVInvokedUrlCommand *)command
{
    NSDictionary *rectdic = [command.arguments objectAtIndex:0];
    BOOL isLite = [[command.arguments objectAtIndex:1] boolValue];
    CGRect rect = CGRectMake([rectdic[@"x"] integerValue], [rectdic[@"y"] integerValue], [rectdic[@"width"] integerValue], [rectdic[@"height"] integerValue]);
    self.rect = rect;
    self.webWindow.hitThrough = self.rect;
    
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showMEPWindowInDiv:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    
    if (self.mepWindow.rootViewController == nil) {
        NSError *error;
        UIViewController *timelineViewController = [[MEPClient sharedInstance] createTimelineViewController:!isLite];
        [timelineViewController aspect_hookSelector:NSSelectorFromString(@"showAddButton") withOptions:MoxtraAspectPositionInstead usingBlock:^BOOL(){
            return NO;
        } error:&error];
        self.mepWindow.rootViewController = timelineViewController;
        
        //Hook presentation
        [timelineViewController aspect_hookSelector:NSSelectorFromString(@"mx_presentLikePushViewController:completion:")
                                        withOptions:MoxtraAspectPositionBefore
                                         usingBlock:^(){
            [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                self.mepWindow.frame = self.webWindow.frame;
            } completion:nil];
            [self.webWindow resignKeyWindow];
            [self.mepWindow makeKeyAndVisible];
            self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 2;
            self.mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
        } error:&error];
        
        //Hook dismiss
        [timelineViewController aspect_hookSelector:NSSelectorFromString(@"viewWillAppear:")
                                        withOptions:MoxtraAspectPositionBefore
                                         usingBlock:^(){
            [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                self.mepWindow.frame =  self.mepWindow.frame = CGRectMake(CGRectGetMinX(rect), CGRectGetMinY(rect)+20, CGRectGetWidth(rect), CGRectGetHeight(rect));
            } completion:^(BOOL finished) {
                self.mepWindow.rootViewController.view.frame = self.mepWindow.bounds;
                [self.webWindow makeKeyAndVisible];
                [self.mepWindow resignKeyWindow];
                self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
                self.mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 2;
            }];
        } error:&error];
    }
    self.mepWindow.frame = CGRectMake(CGRectGetMinX(rect), CGRectGetMinY(rect)+20, CGRectGetWidth(rect), CGRectGetHeight(rect));
    self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
    self.mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 2;
    [self.mepWindow showAnimated:YES];
}

- (void)showClientDashboardInDiv:(CDVInvokedUrlCommand *)command
{
    NSDictionary *rectdic = [command.arguments objectAtIndex:0];
    CGRect rect = CGRectMake([rectdic[@"x"] integerValue], [rectdic[@"y"] integerValue], [rectdic[@"width"] integerValue], [rectdic[@"height"] integerValue]);
    self.rect = rect;
    self.webWindow.hitThrough = self.rect;
    
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showClientDashboardInDiv:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    
    if (self.mepWindow.rootViewController == nil) {
        UIViewController *dashboardController = [[MEPClient sharedInstance] createDashboardViewController];
        if (dashboardController == nil && [MEPClient sharedInstance].isLinked) {
            NSLog(@"internal user doesn't support API showClientDashboardInDiv, please make sure current user is client user");
            return;
        }
        self.mepWindow.rootViewController = dashboardController;
        
        //Hook presentation
        NSError *error;
        [dashboardController aspect_hookSelector:NSSelectorFromString(@"mx_presentLikePushViewController:completion:")
                                        withOptions:MoxtraAspectPositionBefore
                                         usingBlock:^(){
            [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                self.mepWindow.frame = self.webWindow.frame;
            } completion:nil];
            [self.webWindow resignKeyWindow];
            [self.mepWindow makeKeyAndVisible];
            self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 2;
            self.mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
        } error:&error];
        
        [dashboardController aspect_hookSelector:NSSelectorFromString(@"mx_presentStackViewController:animated:completion:") withOptions:MoxtraAspectPositionBefore usingBlock:^(){
            [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                self.mepWindow.frame = self.webWindow.frame;
            } completion:^(BOOL finished) {
                [dashboardController.presentedViewController aspect_hookSelector:NSSelectorFromString(@"dismissMXViewControllerAnimated:completion:") withOptions:MoxtraAspectPositionBefore usingBlock:^(){
                    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                        self.mepWindow.frame =  self.mepWindow.frame = CGRectMake(CGRectGetMinX(rect), CGRectGetMinY(rect)+20, CGRectGetWidth(rect), CGRectGetHeight(rect));
                    } completion:^(BOOL finished) {
                        [self.webWindow makeKeyAndVisible];
                        [self.mepWindow resignKeyWindow];
                        self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
                        self.mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 2;
                    }];
                } error:nil];

            }];
            [self.webWindow resignKeyWindow];
            [self.mepWindow makeKeyAndVisible];
            self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 2;
            self.mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
        } error:&error];
        
        //Hook dismiss
        [dashboardController aspect_hookSelector:NSSelectorFromString(@"viewWillAppear:")
                                        withOptions:MoxtraAspectPositionBefore
                                         usingBlock:^(){
            [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                self.mepWindow.frame =  self.mepWindow.frame = CGRectMake(CGRectGetMinX(rect), CGRectGetMinY(rect)+20, CGRectGetWidth(rect), CGRectGetHeight(rect));
            } completion:^(BOOL finished) {
                [self.webWindow makeKeyAndVisible];
                [self.mepWindow resignKeyWindow];
                self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
                self.mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 2;
            }];
        } error:&error];
    }
    self.mepWindow.frame = CGRectMake(CGRectGetMinX(rect), CGRectGetMinY(rect)+20, CGRectGetWidth(rect), CGRectGetHeight(rect));
    self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
    self.mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 2;
    [self.mepWindow showAnimated:YES];
}

- (void)showLiveChatInDiv:(CDVInvokedUrlCommand *)command {
    NSDictionary *rectdic = [command.arguments objectAtIndex:0];
    CGRect rect = CGRectMake([rectdic[@"x"] integerValue], [rectdic[@"y"] integerValue], [rectdic[@"width"] integerValue], [rectdic[@"height"] integerValue]);
    self.rect = rect;
    self.webWindow.hitThrough = self.rect;
    
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showLiveChatInDiv:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    
    if (self.mepWindow.rootViewController == nil) {
        UIViewController *liveChatController = [[MEPClient sharedInstance] createLiveChatController];
        if (liveChatController == nil) {
            return;
        }
        self.mepWindow.rootViewController = liveChatController;
        
        //Hook presentation
        NSError *error;
        [liveChatController aspect_hookSelector:NSSelectorFromString(@"mx_presentLikePushViewController:completion:")
                                        withOptions:MoxtraAspectPositionBefore
                                         usingBlock:^(){
            [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                self.mepWindow.frame = self.webWindow.frame;
            } completion:nil];
            [self.webWindow resignKeyWindow];
            [self.mepWindow makeKeyAndVisible];
            self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 2;
            self.mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
        } error:&error];
        
        [liveChatController aspect_hookSelector:NSSelectorFromString(@"mx_presentStackViewController:animated:completion:") withOptions:MoxtraAspectPositionBefore usingBlock:^(){
            [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                self.mepWindow.frame = self.webWindow.frame;
            } completion:^(BOOL finished) {
                [liveChatController.presentedViewController aspect_hookSelector:NSSelectorFromString(@"dismissMXViewControllerAnimated:completion:") withOptions:MoxtraAspectPositionBefore usingBlock:^(){
                    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                        self.mepWindow.frame =  self.mepWindow.frame = CGRectMake(CGRectGetMinX(rect), CGRectGetMinY(rect)+20, CGRectGetWidth(rect), CGRectGetHeight(rect));
                    } completion:^(BOOL finished) {
                        [self.webWindow makeKeyAndVisible];
                        [self.mepWindow resignKeyWindow];
                        self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
                        self.mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 2;
                    }];
                } error:nil];

            }];
            [self.webWindow resignKeyWindow];
            [self.mepWindow makeKeyAndVisible];
            self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 2;
            self.mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
        } error:&error];
        
        //Hook dismiss
        [liveChatController aspect_hookSelector:NSSelectorFromString(@"viewWillAppear:")
                                        withOptions:MoxtraAspectPositionBefore
                                         usingBlock:^(){
            [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                self.mepWindow.frame =  self.mepWindow.frame = CGRectMake(CGRectGetMinX(rect), CGRectGetMinY(rect)+20, CGRectGetWidth(rect), CGRectGetHeight(rect));
            } completion:^(BOOL finished) {
                [self.webWindow makeKeyAndVisible];
                [self.mepWindow resignKeyWindow];
                self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
                self.mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 2;
            }];
        } error:&error];
    }
    self.mepWindow.frame = CGRectMake(CGRectGetMinX(rect), CGRectGetMinY(rect)+20, CGRectGetWidth(rect), CGRectGetHeight(rect));
    self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
    self.mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 2;
    [self.mepWindow showAnimated:YES];
}

- (void)showServiceRequestInDiv:(CDVInvokedUrlCommand *)command {
    NSDictionary *rectdic = [command.arguments objectAtIndex:0];
    CGRect rect = CGRectMake([rectdic[@"x"] integerValue], [rectdic[@"y"] integerValue], [rectdic[@"width"] integerValue], [rectdic[@"height"] integerValue]);
    self.rect = rect;
    self.webWindow.hitThrough = self.rect;
    
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showLiveChatInDiv:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    void(^restoreWebwindow)(void) = ^(){
        [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
            self.mepWindow.frame =  self.mepWindow.frame = CGRectMake(CGRectGetMinX(rect), CGRectGetMinY(rect)+20, CGRectGetWidth(rect), CGRectGetHeight(rect));
        } completion:^(BOOL finished) {
            [self.webWindow makeKeyAndVisible];
            [self.mepWindow resignKeyWindow];
            self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
            self.mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 2;
        }];
    };
    
    if (self.mepWindow.rootViewController == nil) {
        UIViewController *srController = [[MEPClient sharedInstance] createServiceRequestController];
        if (srController == nil) {
            return;
        }
        self.mepWindow.rootViewController = srController;
        
        //Hook presentation
        NSError *error;
        [srController aspect_hookSelector:NSSelectorFromString(@"mx_presentStackViewController:animated:completion:") withOptions:MoxtraAspectPositionAfter usingBlock:^(id<MoxtraAspectInfo> info, UINavigationController *controller){
            controller.modalPresentationStyle = UIModalPresentationOverFullScreen;
            NSObject *coordinator = controller.presentationController.delegate;
            [coordinator aspect_hookSelector:@selector(presentationControllerDidDismiss:) withOptions:MoxtraAspectPositionBefore usingBlock:restoreWebwindow error:nil];
            [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                self.mepWindow.frame = self.webWindow.frame;
            } completion:^(BOOL finished) {
                if ([srController.presentedViewController isKindOfClass:NSClassFromString(@"MXNavigationController")]) {
                    //Hook first view controller
                    UINavigationController *navi = (UINavigationController *)srController.presentedViewController;
                    [navi.viewControllers.firstObject aspect_hookSelector:NSSelectorFromString(@"dismissMXViewControllerAnimated:completion:") withOptions:MoxtraAspectPositionBefore usingBlock:restoreWebwindow error:nil];
                }
                [srController.presentedViewController aspect_hookSelector:NSSelectorFromString(@"dismissMXViewControllerAnimated:completion:") withOptions:MoxtraAspectPositionBefore usingBlock:restoreWebwindow error:nil];

            }];
            [self.webWindow resignKeyWindow];
            [self.mepWindow makeKeyAndVisible];
            self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 2;
            self.mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
        } error:&error];
    }
    self.mepWindow.frame = CGRectMake(CGRectGetMinX(rect), CGRectGetMinY(rect)+20, CGRectGetWidth(rect), CGRectGetHeight(rect));
    self.webWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 1;
    self.mepWindow.windowLevel = [MoxtraOverlayWindow defaultWindowLevel] - 2;
    [self.mepWindow showAnimated:YES];
}

- (void)makeDivInteractive:(CDVInvokedUrlCommand *)command {
    NSDictionary *rectdic = [command.arguments objectAtIndex:0];
    //for iphonex, we need add extra safe bar height
    CGRect rect;
    if (@available(iOS 11.0, *)) {
        rect = CGRectMake([rectdic[@"x"] integerValue], [rectdic[@"y"] integerValue], [rectdic[@"width"] integerValue], [rectdic[@"height"] integerValue] + self.webView.safeAreaInsets.top);
    } else {
        rect = CGRectMake([rectdic[@"x"] integerValue], [rectdic[@"y"] integerValue], [rectdic[@"width"] integerValue], [rectdic[@"height"] integerValue]);
    }
    self.webWindow.canHit = rect;
}

- (void)makeDivNoninteractive:(CDVInvokedUrlCommand *)command {
    self.webWindow.canHit = CGRectZero;
}

- (void)openChat:(CDVInvokedUrlCommand*)command
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self openChat:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    
    NSString *chatID = [command.arguments objectAtIndex:0];
    NSString *sequenceStr = [command.arguments objectAtIndex:1];
    
    if ([chatID isEqual:[NSNull null]])
        chatID = @"";
    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    f.numberStyle = NSNumberFormatterDecimalStyle;
    NSNumber *feedSequence = [f numberFromString:sequenceStr];
    
    [[MEPClient sharedInstance] openChat:chatID withFeedSequence:feedSequence
                       completionHandler:^(NSError * _Nullable error) {
                           CDVPluginResult *pluginResult = nil;
                           if (!error)
                           {
                               pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                           }
                           else{
                               pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self universalErrorFromMEP:error]];
                           }
                           [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
                       }];
}

- (void)openLiveChat:(CDVInvokedUrlCommand*)command
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self openLiveChat:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    NSNumber *channelId = nil;
    NSString *message = nil;
    if (command.arguments.count && [command.arguments.firstObject isKindOfClass:[NSDictionary class]]) {
        NSDictionary *option = (NSDictionary *)command.arguments.firstObject;
        channelId = (NSNumber *)[option objectForKey:openLiveChatChannelKey];
        message = [option objectForKey:openLiveChatMessageKey];
    }
    void (^openLiveChatHandler)(NSError *error) = ^void(NSError *error) {
        CDVPluginResult *pluginResult = nil;
        if (!error)
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        else{
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self universalErrorFromMEP:error]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
    };
    
    if (channelId) {
        [[MEPClient sharedInstance] openLiveChatWithChannelId:[channelId integerValue] message:message completion:openLiveChatHandler];
    } else {
        [[MEPClient sharedInstance] openLiveChatWithCompletion:openLiveChatHandler];
    }
}

- (void)openServiceRequest:(CDVInvokedUrlCommand*)command
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self openServiceRequest:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    
    [[MEPClient sharedInstance] openServiceReqeustWithCompletion:^(NSError * _Nullable error) {
        CDVPluginResult *pluginResult = nil;
        if (!error)
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        else{
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self universalErrorFromMEP:error]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
    }];
}

- (void)openInboxWorkspace:(CDVInvokedUrlCommand*)command {
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self openInboxWorkspace:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    
    [[MEPClient sharedInstance] openInboxWorkspaceWithCompletion:^(NSError * _Nullable error) {
        CDVPluginResult *pluginResult = nil;
        if (!error)
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        else{
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self universalErrorFromMEP:error]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
    }];
}


- (void)joinMeet:(CDVInvokedUrlCommand *)command {
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self joinMeet:command];
        });
    }
    
    NSString *meetId = [command.arguments objectAtIndex:0];
    if ([meetId isEqual:[NSNull null]])
        meetId = @"";
    [[MEPClient sharedInstance] joinMeetWithMeetID:meetId completionHandler:^(NSError * _Nullable errorOrNil) {
        CDVPluginResult *pluginResult = nil;
        if (!errorOrNil)
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        else{
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self universalErrorFromMEP:errorOrNil]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
    }];
}

- (void)joinMeetAnonymously:(CDVInvokedUrlCommand *)command {
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self joinMeetAnonymously:command];
        });
    }
    
    NSString *meetId = [command.arguments objectAtIndex:0];
    if ([meetId isEqual:[NSNull null]])
        meetId = @"";
    NSString *displayName = nil;
    NSString *email = nil;
    NSString *password = nil;
    NSDictionary *options_dic = [command.arguments objectAtIndex:1];
    if (options_dic && ![options_dic isEqual:[NSNull null]]) {
        displayName = [[options_dic objectForKey:joinMeetAnonymouslyDisplayNameKey] stringValue];
        email = [[options_dic objectForKey:joinMeetAnonymouslyEmailKey] stringValue];
        password = [[options_dic objectForKey:joinMeetAnonymouslyPasswordKey] stringValue];
    }
    if (password.length) {
        [[MEPClient sharedInstance] joinMeetAnonymouslyWithMeetID:meetId password:password displayName:displayName email:email completionHandler:^(NSError * _Nullable errorOrNil) {
            CDVPluginResult *pluginResult = nil;
            if (!errorOrNil)
            {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            }
            else{
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self universalErrorFromMEP:errorOrNil]];
            }
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
        }];
    } else {
        [[MEPClient sharedInstance] joinMeetAnonymouslyWithMeetID:meetId displayName:displayName email:email completionHandler:^(NSError * _Nullable errorOrNil) {
            CDVPluginResult *pluginResult = nil;
            if (!errorOrNil)
            {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            }
            else{
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self universalErrorFromMEP:errorOrNil]];
            }
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
        }];
    }
}

- (void)startMeet:(CDVInvokedUrlCommand*)command
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self startMeet:command];
        });
    }
    NSString *topic = [command.arguments objectAtIndex:0];
    NSArray *unique_ids = [command.arguments objectAtIndex:1];
    NSString *chat_id = [command.arguments objectAtIndex:2];
    NSDictionary *options_dic = [command.arguments objectAtIndex:3];
    MEPStartMeetOptions *options = [[MEPStartMeetOptions alloc] init];
    options.chatID = chat_id;
    options.topic = topic;
    options.uniqueIDs = unique_ids;
    if (options_dic && ![options_dic isEqual:[NSNull null]]) {
        options.autoJoinAudio = [[options_dic objectForKey:autoJoinAudioKey] boolValue];
        options.autoStartVideo = [[options_dic objectForKey:autoStartVideoKey] boolValue];
    } else {
        options.autoJoinAudio = YES;
        options.autoStartVideo = NO;
    }
    if (![MEPClient sharedInstance].isLinked) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self universalErrorFromMEP:[NSError errorWithDomain:MEPSDKErrorDomain code:3 userInfo:Nil]]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
        return;
    }
    [[MEPClient sharedInstance] startMeetWithOption:options completionHandler:^(NSError * _Nullable errorOrNil, NSString * _Nonnull meetIDOrNil) {
        CDVPluginResult *pluginResult = nil;
        if (!errorOrNil)
        {
            NSDictionary *response = [NSDictionary dictionaryWithObject:meetIDOrNil ? meetIDOrNil : @"" forKey:sessionIdKey];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:response];
        }
        else{
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self universalErrorFromMEP:errorOrNil]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
    }];
}

- (void)getUnreadMessageCount:(CDVInvokedUrlCommand *)command {
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self getUnreadMessageCount:command];
        });
    }
    if (![MEPClient sharedInstance].isLinked) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self universalErrorFromMEP:[NSError errorWithDomain:MEPSDKErrorDomain code:3 userInfo:Nil]]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
        return;
    }
    NSInteger unreadCount = [[MEPClient sharedInstance] getUnreadMessageCount];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsNSInteger:unreadCount];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
}

- (void)getUnreadMessageCountWithOption:(CDVInvokedUrlCommand *)command {
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self getUnreadMessageCountWithOption:command];
        });
    }
    if (![MEPClient sharedInstance].isLinked) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self universalErrorFromMEP:[NSError errorWithDomain:MEPSDKErrorDomain code:3 userInfo:Nil]]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
        return;
    }
    NSDictionary *options_dic = [command.arguments objectAtIndex:0];
    if (options_dic && [options_dic objectForKey:@"type"]) {
        NSUInteger type = [[options_dic objectForKey:@"type"] integerValue];
        if (type != MEPChatTypeLiveChat && type != MEPChatTypeServiceRequest) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:@{errorCodeKey : @(0), errorMessageKey : [NSString stringWithFormat:@"type %lu is not supported yet.",(unsigned long)type]}];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
        }
        if ([command.callbackId isEqualToString:invalidCbkId]) {
            [self cleanUnreadCountMapForType:type];
            return;
        }
        NSUInteger result = [[MEPClient sharedInstance] getUnreadMessageCountWithType:type];
        if (result == -1) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:@{errorCodeKey : @(0), errorMessageKey : @"internal user doesn't support this API yet."}];
            [self cleanUnreadCountMapForType:type];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
        } else {
            //Register for subsequent callbacks
            [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(YES) forKey:NSStringFromSelector(@selector(client:didUpdateUnreadCount:))];
            
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsNSInteger:result];
            [pluginResult setKeepCallbackAsBool:YES];
            MoxtraUnreadCountMap *map = [MoxtraUnreadCountMap mapWithChatType:type callbackId:command.callbackId lastCount:result];
            [self.unreadCountMaps setObject:map forKey:@(type)];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    }
}

- (void)getLastActiveTimestamp:(CDVInvokedUrlCommand *)command {
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self getLastActiveTimestamp:command];
        });
    }
    if (![MEPClient sharedInstance].isLinked) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self universalErrorFromMEP:[NSError errorWithDomain:MEPSDKErrorDomain code:3 userInfo:Nil]]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
        return;
    }
    NSDate *lastActive = [[MEPClient sharedInstance] lastActiveDate];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsNSInteger:[lastActive timeIntervalSince1970] * 1000];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void)scheduleMeet:(CDVInvokedUrlCommand*)command
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self startMeet:command];
        });
    }
    NSString *topic = [command.arguments objectAtIndex:0];
    NSArray *unique_ids = [command.arguments objectAtIndex:1];
    NSString *chat_id = [command.arguments objectAtIndex:2];
    NSDictionary *options_dic = [command.arguments objectAtIndex:3];
    MEPScheduleMeetOptions *options = [[MEPScheduleMeetOptions alloc] init];
    options.chatID = chat_id;
    options.topic = topic;
    if ([unique_ids isKindOfClass:[NSArray class]]) {
        options.uniqueIDs = unique_ids;
    } else if ([options.uniqueIDs isKindOfClass:[NSString class]]) {
        options.uniqueIDs = @[unique_ids];
    }
    if (options_dic && [[[options_dic objectForKey:meetStartDateKey] stringValue] length] && [[[options_dic objectForKey:meetEndDateKey] stringValue] length]) {
        options.meetStartDate = [NSDate dateWithTimeIntervalSince1970:[[options_dic objectForKey:meetStartDateKey] longValue]/1000];
        options.meetEndDate = [NSDate dateWithTimeIntervalSince1970:[[options_dic objectForKey:meetEndDateKey] longValue]/1000];
    } else {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self universalErrorFromMEP:[self genericError]]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
        return;
    }
    [[MEPClient sharedInstance] scheduleMeetWithOption:options completionHandler:^(NSError * _Nullable errorOrNil, NSString * _Nonnull meetIDOrNil) {
        CDVPluginResult *pluginResult = nil;
        if (!errorOrNil)
        {
            NSDictionary *response = [NSDictionary dictionaryWithObject:meetIDOrNil ? meetIDOrNil : @"" forKey:sessionIdKey];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:response];
        }
        else{
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self universalErrorFromMEP:errorOrNil]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId ];
    }];
}

- (void)registerNotification:(CDVInvokedUrlCommand*)command
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self registerNotification:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    
    NSString *deviceToken = [command.arguments objectAtIndex:0];
    
    if ([deviceToken isEqual:[NSNull null]])
        deviceToken = @"";
    
    NSData *tokenData = [self dataFromHexString:deviceToken];
    [[MEPClient sharedInstance] registerNotificationWithDeviceToken:tokenData];
}

- (void)isMEPNotification:(CDVInvokedUrlCommand*)command
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self isMEPNotification:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    
    NSString *notificationPayload = [command.arguments objectAtIndex:0];
    
    if ([notificationPayload isEqual:[NSNull null]])
        notificationPayload = @"";
    
    NSData *notificationPayloadData = [notificationPayload dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *notificationPayloadDic = [NSJSONSerialization JSONObjectWithData:notificationPayloadData options:NSJSONReadingMutableContainers error:nil];

    BOOL isMEPNotification = [[MEPClient sharedInstance] isMEPNotification:notificationPayloadDic];
    
    CDVPluginResult *pluginResult = nil;
    if (isMEPNotification)
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    else{
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)parseRemoteNotification:(CDVInvokedUrlCommand*)command
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self parseRemoteNotification:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    
    NSString *notificationPayload = [command.arguments objectAtIndex:0];
    
    if ([notificationPayload isEqual:[NSNull null]])
        notificationPayload = @"";
    
    NSData *notificationPayloadData = [notificationPayload dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *notificationPayloadDic = [NSJSONSerialization JSONObjectWithData:notificationPayloadData options:0 error:nil];

    [[MEPClient sharedInstance] parseRemoteNotification:notificationPayloadDic completionHandler:^(NSError * _Nullable error, NSDictionary * _Nullable info) {
        CDVPluginResult *pluginResult = nil;
        if (!error)
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:info];
        }
        else{
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self universalErrorFromMEP:error]];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)isLinked:(CDVInvokedUrlCommand*)command
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self isLinked:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    
    BOOL isLinked = [[MEPClient sharedInstance] isLinked];
    CDVPluginResult *pluginResult = nil;
    if (isLinked)
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        
    }
    else{
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)unlink:(CDVInvokedUrlCommand*)command
{
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self unlink:command];
        });
    }
    
    [MEPClient sharedInstance].delegate = self;
    
    [[MEPClient sharedInstance] unlink];
}

- (void)setFeatureConfig:(CDVInvokedUrlCommand *)command {
    if (![NSThread isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setFeatureConfig:command];
        });
    }
    if ([command.arguments objectAtIndex:0] && [[command.arguments objectAtIndex:0] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *configs = [command.arguments objectAtIndex:0];
        if ([configs objectForKey:voiceMessageConfigKey]) {
            [MEPFeatureConfig sharedInstance].voiceMessageEnabled = [[configs objectForKey:voiceMessageConfigKey] boolValue];
        }
    }
}

- (void)canAddUserInChat:(CDVInvokedUrlCommand*)command {
    [MEPFeatureConfig sharedInstance].canAddUserInChat = ^BOOL(MEPChat *chat) {
        self.waiting = @"YES";
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:chat.chatID];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        while (self.waiting) {
            [[NSRunLoop currentRunLoop] acceptInputForMode:NSDefaultRunLoopMode beforeDate:NSDate.distantFuture];
        }
        return [self.canAddUser boolValue];
    };
}

- (void)setCanAddUserInChatResult:(CDVInvokedUrlCommand*)command {
    if (command.arguments.count && [[command.arguments objectAtIndex:0] isKindOfClass:[NSNumber class]]) {
        self.canAddUser = (NSNumber *)[command.arguments objectAtIndex:0];
        self.waiting = nil;
    } else {
        [NSException raise:@"Invalid parameter" format: @"Expecting a boolean result"];
    }
}

#pragma mark - Callbacks
- (void)client:(MEPClient *)client didTapClose:(id _Nullable)sender
{
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [pluginResult setKeepCallbackAsBool:true];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.logoutClickedCbkId];
}

- (void)clientDidLogout:(MEPClient *)client
{
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [pluginResult setKeepCallbackAsBool:true];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.logoutCbkId];
}

- (void)client:(MEPClient *)client didTapJoinMeet:(MEPMeet *)meet {
    if (meet) {
        NSMutableDictionary *resposne = [[NSMutableDictionary alloc] init];
        [resposne setObject:meet.meetID forKey:sessionIdKey];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resposne];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.joinMeetBtnCbkId];
    } else {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{sessionIdKey : @""}];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.joinMeetBtnCbkId];
    }
}

- (void)client:(MEPClient *)client didTapCall:(MEPChat *)chat withPeer:(MEPUser *)peerOrNil {
    if (chat) {
        [chat getMembersWithCompletion:^(NSError * _Nullable errorOrNil, NSArray<MEPUser *> * _Nullable members) {
            NSMutableArray *unique_ids = [[NSMutableArray alloc] init];
            for (MEPUser *user in members) {
                [unique_ids addObject:user.uniqueId];
            }
            NSMutableDictionary *resposne = [[NSMutableDictionary alloc] init];
            [resposne setObject:unique_ids forKey:uniqueIdKey];
            [resposne setObject:chat.chatID forKey:chatIdKey];
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resposne];
            [pluginResult setKeepCallbackAsBool:true];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callBtnCbkId];
        }];
    } else if (peerOrNil){
        NSMutableDictionary *resposne = [[NSMutableDictionary alloc] init];
        [resposne setObject:@[peerOrNil.uniqueId] forKey:uniqueIdKey];
        [resposne setObject:@"" forKey:chatIdKey];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resposne];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callBtnCbkId];
    } else {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{chatIdKey : @"", uniqueIdKey : @""}];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callBtnCbkId];
    }
}

- (void)client:(MEPClient *)client didTapAddMemberInChat:(NSString *)chatID {
    if (chatID) {
        NSMutableDictionary *resposne = [[NSMutableDictionary alloc] init];
        [resposne setObject:chatID forKey:chatIdKey];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resposne];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.addMemberBtnCbkId];
    } else {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{chatIdKey : @"", uniqueIdKey : @""}];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.addMemberBtnCbkId];
    }
}

- (void)client:(MEPClient *)client didTapViewMeet:(nonnull MEPMeet *)meet {
    if (meet) {
        NSMutableDictionary *resposne = [[NSMutableDictionary alloc] init];
        [resposne setObject:meet.meetID forKey:sessionIdKey];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resposne];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.viewMeetBtnCbkId];
    } else {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{sessionIdKey : @""}];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.viewMeetBtnCbkId];
    }
}

- (void)client:(MEPClient *)client didTapEditMeet:(nonnull MEPMeet *)meet {
    if (meet) {
        NSMutableDictionary *resposne = [[NSMutableDictionary alloc] init];
        [resposne setObject:meet.meetID forKey:sessionIdKey];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resposne];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.editMeetBtnCbkId];
    } else {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{sessionIdKey : @""}];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.editMeetBtnCbkId];
    }
}

- (void)client:(MEPClient *)client didTapInviteInLiveMeet:(MEPMeet *)meet {
    if (meet) {
        NSMutableDictionary *resposne = [[NSMutableDictionary alloc] init];
        [resposne setObject:meet.meetID forKey:sessionIdKey];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resposne];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.inviteBtnInLiveMeetCbkId];
    } else {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{sessionIdKey : @""}];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.inviteBtnInLiveMeetCbkId];
    }
}

- (void)client:(MEPClient *)client didUpdateUnreadCount:(NSUInteger)unreadCount {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsNSInteger:unreadCount];
    [pluginResult setKeepCallbackAsBool:true];
    if (self.unreadCountUpdatedCbkId) {
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.unreadCountUpdatedCbkId];
    }
    //Get unread count per type
    [self.unreadCountMaps enumerateKeysAndObjectsUsingBlock:^(NSNumber *type, MoxtraUnreadCountMap *map, BOOL *stop) {
        NSInteger unreadCount = 0;
        if ([type integerValue] == MEPChatTypeLiveChat || [type integerValue] == MEPChatTypeServiceRequest) {
            unreadCount = [[MEPClient sharedInstance] getUnreadMessageCountWithType:[type integerValue]];
            //Return when no changes.
            if (unreadCount == map.lastCount)
                return;
        }
        if (unreadCount == -1) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:@{errorCodeKey : @(0), errorMessageKey : @"internal user doesn't support this API yet."}];
            [self cleanUnreadCountMapForType:[type integerValue]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:map.callbackId];
        } else {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsNSInteger:unreadCount];
            map.lastCount = unreadCount;
            [pluginResult setKeepCallback:@(YES)];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:map.callbackId];
        }
    }];
}

#pragma mark - Bind callbacks
- (void)onLogout:(CDVInvokedUrlCommand *)command {
    if ([command.callbackId isEqualToString:invalidCbkId]) {
        self.logoutCbkId = nil;
    } else {
        self.logoutCbkId = command.callbackId;
    }
}

- (void)onLogoutClicked:(CDVInvokedUrlCommand *)command {
    if ([command.callbackId isEqualToString:invalidCbkId]) {
        self.logoutClickedCbkId = nil;
    } else {
        self.logoutClickedCbkId = command.callbackId;
    }
}

- (void)onJoinMeetButtonClicked:(CDVInvokedUrlCommand *)command {
    if ([command.callbackId isEqualToString:invalidCbkId]) {
        self.joinMeetBtnCbkId = nil;
        [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(NO) forKey:NSStringFromSelector(@selector(client:didTapJoinMeet:))];
    } else {
        self.joinMeetBtnCbkId = command.callbackId;
        [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(YES) forKey:NSStringFromSelector(@selector(client:didTapJoinMeet:))];
    }
}

- (void)onCallButtonClicked:(CDVInvokedUrlCommand *)command {
    if ([command.callbackId isEqualToString:invalidCbkId]) {
        self.callBtnCbkId = nil;
        [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(NO) forKey:NSStringFromSelector(@selector(client:didTapCall:withPeer:))];
    } else {
        self.callBtnCbkId = command.callbackId;
        [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(YES) forKey:NSStringFromSelector(@selector(client:didTapCall:withPeer:))];
    }
}

- (void)onAddMemberInChatClicked:(CDVInvokedUrlCommand *)command {
    if ([command.callbackId isEqualToString:invalidCbkId]) {
        self.addMemberBtnCbkId = nil;
        [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(NO) forKey:NSStringFromSelector(@selector(client:didTapAddMemberInChat:))];
    } else {
        self.addMemberBtnCbkId = command.callbackId;
        [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(YES) forKey:NSStringFromSelector(@selector(client:didTapAddMemberInChat:))];
    }
}

- (void)onMeetViewButtonClicked:(CDVInvokedUrlCommand *)command {
    if ([command.callbackId isEqualToString:invalidCbkId]) {
        self.viewMeetBtnCbkId = nil;
        [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(NO) forKey:NSStringFromSelector(@selector(client:didTapViewMeet:))];
    } else {
        self.viewMeetBtnCbkId = command.callbackId;
        [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(YES) forKey:NSStringFromSelector(@selector(client:didTapViewMeet:))];
    }
}

- (void)onMeetEditButtonClicked:(CDVInvokedUrlCommand *)command {
    if ([command.callbackId isEqualToString:invalidCbkId]) {
        self.editMeetBtnCbkId = nil;
        [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(NO) forKey:NSStringFromSelector(@selector(client:didTapEditMeet:))];
    } else {
        self.editMeetBtnCbkId = command.callbackId;
        [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(YES) forKey:NSStringFromSelector(@selector(client:didTapEditMeet:))];
    }
}

- (void)onInviteButtonInLiveMeetClicked:(CDVInvokedUrlCommand *)command {
    if ([command.callbackId isEqualToString:invalidCbkId]) {
        self.inviteBtnInLiveMeetCbkId = nil;
        [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(NO) forKey:NSStringFromSelector(@selector(client:didTapInviteInLiveMeet:))];
    } else {
        self.inviteBtnInLiveMeetCbkId = command.callbackId;
        [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(YES) forKey:NSStringFromSelector(@selector(client:didTapInviteInLiveMeet:))];
    }
}

- (void)onCloseButtonClicked:(CDVInvokedUrlCommand *)command {
    if ([command.callbackId isEqualToString:invalidCbkId]) {
        self.logoutClickedCbkId = nil;
        [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(NO) forKey:NSStringFromSelector(@selector(client:didTapClose:))];
    } else {
        self.logoutClickedCbkId = command.callbackId;
        [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(YES) forKey:NSStringFromSelector(@selector(client:didTapClose:))];
    }
}

- (void)onUnreadMessageCountUpdated:(CDVInvokedUrlCommand *)command {
    if ([command.callbackId isEqualToString:invalidCbkId]) {
        self.unreadCountUpdatedCbkId = nil;
        [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(NO) forKey:NSStringFromSelector(@selector(client:didUpdateUnreadCount:))];
    } else {
        self.unreadCountUpdatedCbkId = command.callbackId;
        [[MXDelegateMapper sharedMapper].delegateMapper setObject:@(YES) forKey:NSStringFromSelector(@selector(client:didUpdateUnreadCount:))];
    }
}

#pragma mark - Delegate Map

- (BOOL)respondsToSelector:(SEL)aSelector {
    BOOL respond = [[[MXDelegateMapper sharedMapper].delegateMapper objectForKey:NSStringFromSelector(aSelector)] boolValue];
    if (aSelector == @selector(client:didTapCall:withPeer:)
        || aSelector == @selector(client:didTapEditMeet:)
        || aSelector == @selector(client:didTapAddMemberInChat:)
        || aSelector == @selector(client:didTapJoinMeet:)
        || aSelector == @selector(client:didTapViewMeet:)
        || aSelector == @selector(client:didTapInviteInLiveMeet:)
        || aSelector == @selector(client:didUpdateUnreadCount:)
        || aSelector == @selector(client:didTapClose:)) {
        return respond;
    } else if (aSelector == @selector(clientDidLogout:)) {
        return YES;
    }
    return [[self class] instancesRespondToSelector:aSelector];
}

#pragma mark - Unread message count
- (NSMutableDictionary *)unreadCountMaps {
    if (_unreadCountMaps == nil) {
        _unreadCountMaps = [[NSMutableDictionary alloc] init];
    }
    return _unreadCountMaps;
}

- (void)cleanUnreadCountMapForType:(NSInteger)type {
    if ([self.unreadCountMaps objectForKey:@(type)]) {
        [self.unreadCountMaps removeObjectForKey:@(type)];
    }
}
#pragma mark - Helper
- (NSData *)dataFromHexString:(NSString *)string
{
    NSMutableData *stringData = [[NSMutableData alloc] init];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    int i;
    for (i=0; i < [string length] / 2; i++) {
        byte_chars[0] = [string characterAtIndex:i*2];
        byte_chars[1] = [string characterAtIndex:i*2+1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [stringData appendBytes:&whole_byte length:1];
    }
    return stringData;
}

- (NSError *)genericError {
    return [NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:nil];
}

- (NSDictionary *)universalErrorFromMEP:(NSError *)error {
    NSInteger code;
    NSString *message;
    switch (error.code) {
        case MEPUnkownError:
        {
            code = 0;
            message = error.localizedDescription;
        }
            break;
        case MEPDomainsError:
        {
            code = 1;
            message = @"invalid domain";
        }
            break;
        case MEPInvalidAccountError:
        {
            code = 2;
            message = @"invalid access token";
        }
            break;
        case MEPNotLinkedError:
        {
            code = 3;
            message = @"sdk not initialized";
        }
            break;
        case MEPNetworkError:
        {
            code = 4;
            message = @"no network";
        }
            break;
        case MEPObjectNotFoundError:
        {
            code = 5;
            message = @"object not found";
        }
            break;
        case MEPAuthorizedError:
        {
            code = 6;
            message = @"account not authorized";
        }
            break;
        case MEPAccountDisabled:
        {
            code = 7;
            message = @"account disabled";
        }
            break;
        case MEPAccountLocked:
        {
            code = 8;
            message = @"account lockedd";
        }
            break;
        case MEPMeetEndedError:
        {
            code = 9;
            message = @"meet ended";
        }
            break;
        case MEPPermissionError:
        {
            code = 10;
            message = @"no permission";
        }
            break;
        default:
        {
            code = 0;
            message = @"something went wrong";
        }
            break;
    }
    return @{errorCodeKey : @(code), errorMessageKey : message};
}
@end
