
#import "MoxtraOverlayWindow.h"



@implementation UIViewController(MHOverlayWindow)

- (BOOL)isFloating;
{
    return NO;
}

@end


@implementation MoxtraOverlayWindow
{
	MoxtraOverlayWindow *_keepAlive;
	UIWindow *_previousKeyWindow;
}

+ (float)defaultWindowLevel
{
    return UIWindowLevelStatusBar - 0.1;

}

+ (MoxtraOverlayWindow*)reuseableWindow
{
    for ( UIWindow *window in [UIApplication sharedApplication].windows )
    {
        if( [window isMemberOfClass:[MoxtraOverlayWindow class]] )
        {
            MoxtraOverlayWindow *overlayWindow = (MoxtraOverlayWindow*)window;
            if( [overlayWindow isIdle] )
                return overlayWindow;
        }
    }
    
    return nil;
}

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
		self.windowLevel = [[self class] defaultWindowLevel];
		self.userInteractionEnabled = YES;
		self.backgroundColor = [UIColor clearColor];
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
	}
	return self;
}

- (UIWindow *)findKeyWindow
{
//    for (UIWindow *window in [UIApplication sharedApplication].windows)
//    {
//        if (window.windowLevel == UIWindowLevelNormal && ![[window class] isEqual:[self class]])
//            return window;
//    }
//    return nil;
    return [UIApplication sharedApplication].keyWindow;
}

- (BOOL)hasRemoteWindow
{
    __block BOOL hasRemoteWindow = NO;
    [[UIApplication sharedApplication].windows enumerateObjectsUsingBlock:^(__kindof UIWindow * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if([NSStringFromClass(obj.class) isEqualToString:@"UIRemoteKeyboardWindow"])
        {
            *stop = YES;
            hasRemoteWindow = YES;
        }
    }];
    
    return hasRemoteWindow;
}

- (void)forceHideKeyboard
{
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 0.2, 29)];
    [self addSubview:textField];
    [textField becomeFirstResponder];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [textField resignFirstResponder];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [textField removeFromSuperview];
    });
}

- (void)dealloc
{
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *v = nil;
    v = [super hitTest:point withEvent:event];
    if ([v isKindOfClass:NSClassFromString(@"_UIAlertControllerActionView")]) {
        return v;
    }
    if (!CGRectEqualToRect(self.hitThrough, CGRectZero)) {
        if (!CGRectEqualToRect(self.canHit, CGRectZero)) {
            if (CGRectContainsPoint(self.canHit, point)) {
                return v;
            }
        }
        if (CGRectContainsPoint(self.hitThrough, point)) {
            return nil;
        }
    }
    if (v == self.rootViewController.view)
        return nil;
    
    if( self == v )
        return nil;
    return v;
}

- (void)showWithoutHideKeyboard
{
    _keepAlive = self;
    
    if (![self isKeyWindow])
    {
        _previousKeyWindow = [self findKeyWindow];
        [self makeKeyAndVisible];
    }
}

- (void)showAnimated:(BOOL)animated
{
	_keepAlive = self;

	if (![self isKeyWindow])
	{
		_previousKeyWindow = [self findKeyWindow];
		[self makeKeyAndVisible];
	}

    self.alpha = 0.0f;
    [UIView animateWithDuration:animated ? 0.2 : 0.0 animations:^
     {
         if( [self hasRemoteWindow] )
         {
             [self forceHideKeyboard];
         }
         self.alpha = 1.0f;
     }];
}

- (void)showAnimated:(BOOL)animated withComplete:(void (^)(void))complete;
{
    _keepAlive = self;
    
    if (![self isKeyWindow])
    {
        _previousKeyWindow = [self findKeyWindow];
        [self makeKeyAndVisible];
    }
    
    self.alpha = 0.0f;
    [UIView animateWithDuration:animated ? 0.2 : 0.0 animations:^
     {
         self.alpha = 1.0f;
         if( [self hasRemoteWindow] )
         {
             [self forceHideKeyboard];
         }
     } completion:^(BOOL finished) {
         
         if (complete)
             complete();
     }];
}

- (void)dismissAnimated:(BOOL)animated
{
	if (animated)
	{
        UIViewController *controllerWillToDismiss = self.rootViewController;
		[UIView animateWithDuration:0.2 animations:^
		{
            self.alpha = 0.0f;
		}
		completion:^(BOOL finished)
		{
            if([controllerWillToDismiss isEqual:self.rootViewController])
            {
                [self dismissDidComplete];
            }
		}];
	}
	else
	{
		[self dismissDidComplete];
	}
}

- (void)dismissAnimated:(BOOL)animated withComplete:(void (^)(void))complete
{
    if (animated)
	{
        UIViewController *controllerWillToDismiss = self.rootViewController;
		[UIView animateWithDuration:0.2 animations:^
         {
             self.alpha = 0.2f;
         }
        completion:^(BOOL finished)
         {
             if([controllerWillToDismiss isEqual:self.rootViewController])
             {
                 [self dismissDidComplete];
             }
             if(complete)
                 complete();
             
         }];
	}
	else
	{
        [self dismissDidComplete];
        if(complete)
            complete();
		
	}

}

- (void)dismissDidComplete
{
	[_previousKeyWindow makeKeyAndVisible];
    _keepAlive.rootViewController = nil;
	_keepAlive = nil;
    //fix bug. Sometimes this window is not dealloced.
    //We need to asign the window level below the app's window.
    [self setWindowLevel:UIWindowLevelNormal-1];
}

- (BOOL)isIdle
{
    return _keepAlive == nil;
}

- (BOOL)canPresentViewController
{
    if( [self isIdle] )
    {
        return NO;
    }
    
    UIView *rootView = self.rootViewController.view;
    UIView *hittestedView = [rootView hitTest:CGPointMake(CGRectGetMidX(rootView.bounds), CGRectGetMidY(rootView.bounds)) withEvent:nil];
    if( hittestedView == nil || hittestedView == rootView )
    {
        if( self.rootViewController.presentedViewController != nil )
            return YES;
        return NO;
    }
    
    return YES;
}

/*
- (void)drawRect:(CGRect)rect 
{
	CGContextRef context = UIGraphicsGetCurrentContext();

	const CGFloat components[8] = { 0.0f, 0.0f, 0.0f, 0.2f, 0.0f, 0.0f, 0.0f, 0.55f };
	const CGFloat locations[2] = { 0.0f, 1.0f };

	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGGradientRef gradient = CGGradientCreateWithColorComponents(space, components, locations, 2);
	CGColorSpaceRelease(space);

	CGPoint center = CGPointMake(self.bounds.size.width/2.0f, self.bounds.size.height/2.0f);
	float radius = MIN(self.bounds.size.width, self.bounds.size.height);
	CGContextDrawRadialGradient(context, gradient, center, 0, center, radius, kCGGradientDrawsAfterEndLocation);
	CGGradientRelease(gradient);
}
*/

@end

@implementation MoxtraCDVNavigationController

- (instancetype)initWithRootViewController:(UIViewController *)rootViewController {
    if (self = [super initWithRootViewController:rootViewController]) {
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
