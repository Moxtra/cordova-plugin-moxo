
/*
 * A window that appears on top of everything else, including the status bar.
 *
 * To add controls to this window, create a new UIViewController and set it
 * as the window's rootViewController. That will automatically take care of 
 * rotation events, and so on.
 *
 * The MHOverlayWindow object keeps itself (and the root view controller) alive
 * until dismissed.
 */

@interface UIViewController(MHOverlayWindow)

- (BOOL)isFloating;

@end

@interface MoxtraOverlayWindow : UIWindow
@property (nonatomic, assign) CGRect hitThrough;
@property (nonatomic, assign) CGRect canHit;
@property (nonatomic, strong) NSNumber *forPlugin;
+ (float)defaultWindowLevel;
+ (MoxtraOverlayWindow*)reuseableWindow;

- (void)showAnimated:(BOOL)animated;
- (void)showAnimated:(BOOL)animated withComplete:(void (^)(void))complete;
- (void)showWithoutHideKeyboard;
- (void)dismissAnimated:(BOOL)animated;
- (void)dismissAnimated:(BOOL)animated withComplete:(void (^)(void))complete;
- (BOOL)isIdle;
- (BOOL)canPresentViewController;
@end


@interface MoxtraCDVNavigationController: UINavigationController
@property (nonatomic, readwrite, strong) NSArray* supportedOrientations;
@end
