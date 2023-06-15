//
//  MoxtraIntegration.h
//
//  Created by Gitesh on 26/4/2017.
//
//

#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>

@interface MoxtraIntegration : CDVPlugin

- (void)setupDomain:(CDVInvokedUrlCommand*)command;

- (void)linkWithAccessToken:(CDVInvokedUrlCommand*)command;

- (void)showMEPWindow:(CDVInvokedUrlCommand*)command;

- (void)showMEPWindowLite:(CDVInvokedUrlCommand*)command;

- (void)hideMEPWindow:(CDVInvokedUrlCommand*)command;

- (void)destroyMEPWindow:(CDVInvokedUrlCommand*)command;

- (void)showMEPWindowInDiv:(CDVInvokedUrlCommand*)command;

- (void)showClientDashboardInDiv:(CDVInvokedUrlCommand*)command;

- (void)openChat:(CDVInvokedUrlCommand*)command;

- (void)registerNotification:(CDVInvokedUrlCommand*)command;

- (void)isMEPNotification:(CDVInvokedUrlCommand*)command;

- (void)parseRemoteNotification:(CDVInvokedUrlCommand*)command;

- (void)isLinked:(CDVInvokedUrlCommand*)command;

- (void)unlink:(CDVInvokedUrlCommand*)command;

- (void)onLogout:(CDVInvokedUrlCommand *)command;

- (void)onLogoutClicked:(CDVInvokedUrlCommand *)command;

@end
