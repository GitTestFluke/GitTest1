//
//  ELESideNavigationController.h
//  SideNavigationTest
//
//  Created by Luke Adamson on 4/23/13.
//  Copyright (c) 2013 Dogfish Software. All rights reserved.
//

#import "ELESideNavigationController.h"

#import "ELEViewController.h"
#import "ELETableViewController.h"
#import "ELEActivityIndicatorView.h"

// Change this to YES for the nicer animation where the top view controller is
// animated offscreen before replacing it with the new view controller (like the
// Path app). However, if you do change it to YES, the left side view must be
// set up so that it looks ok while briefly filling the width of the full
// screen.
static BOOL ELESideNavigationControllerShouldUseFancierReplaceAnimation = YES;

@interface ELESideNavigationController ()

// Redeclare these as readwrite so we can set them internally, but have the
// compiler prevent users of ELESideNavigationController from setting them
// without using other public methods.
//
@property (nonatomic, readwrite) UIViewController *topViewController;
@property (readwrite) BOOL isLeftSideViewVisible;

@property UIView *topMaskView;

@property (nonatomic) ELEActivityIndicatorView *loadingActivityView;

@end

@implementation ELESideNavigationController

#pragma mark - Initialization

- (void)setupLeftSideViewController:(UIViewController *)leftSideViewController topViewController:(UIViewController *)topViewController
{
    self.leftSideViewController = leftSideViewController;
    if (self.leftSideViewController) {
        [self.leftSideViewController willMoveToParentViewController:self];
        [self addChildViewController:self.leftSideViewController];
        [self.leftSideViewController didMoveToParentViewController:self];
    }
    
    self.topViewController = topViewController;
    if (self.topViewController) {
        [self.topViewController willMoveToParentViewController:self];
        [self addChildViewController:self.topViewController];
        [self.topViewController didMoveToParentViewController:self];
        [self notifyTopViewControllerSwappingIn];
    }
    
    if (self.isViewLoaded) {
        
        // stop the activity indicator
        [self.loadingActivityView activityIndicatorStop];
        
        // size and add the top view controller
        [self.view addSubview:self.topViewController.view];
        self.topViewController.view.frame = self.view.bounds;
    }
}

#pragma mark - View lifecycle

- (void)loadView
{
    // We expect our parent view controller to set our size
    self.view = [UIView new];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.backgroundColor = [UIColor blackColor]; 
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Load and position top view controller's view
    if (self.topViewController) {
        // If the top view controller has been loaded then resize it.
        [self.view addSubview:self.topViewController.view];
        self.topViewController.view.frame = self.view.bounds;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Delay display of the loading view to give the app a bit of time to finish up.
    // Less jarring for the more common case of a quick startup.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.topViewController) {
            self.loadingActivityView = [[ELEActivityIndicatorView alloc] initWithView:self.view];
            [self.loadingActivityView activityIndicatorStart];
        }
    });
}

#pragma mark - Top view controller

- (void)setTopViewController:(UIViewController *)topViewController
{
    if (_topViewController != topViewController) {
        _topViewController = topViewController;
        
        if ([_topViewController isKindOfClass:[UINavigationController class]]) {
            // Enforce a common left-hand side navigation button to reveal the
            // left side view when the top view controller is a navigation
            // controller. This is a touch special purpose for my taste, but
            // eliminates duplicated code in the various view controller's
            // -viewDidLoad methods.
            UIButton *leftButton = [UIButton buttonWithType:UIButtonTypeCustom];
            leftButton.accessibilityLabel = NSLocalizedString(@"Switcher", @"Switcher");
            [leftButton setFrame:CGRectMake(0.0f, 0.0f, 45.0f, 45.0f)];
            [leftButton setImageEdgeInsets:UIEdgeInsetsMake(0, -15, 0, 0)];
            [leftButton addTarget:self action:@selector(toggleLeftSideViewVisibility) forControlEvents:UIControlEventTouchUpInside];
            [leftButton setImage:[UIImage imageNamed:@"list_icon"] forState:UIControlStateNormal];
            UIBarButtonItem *leftButtonItem = [[UIBarButtonItem alloc] initWithCustomView:leftButton];
            
            UINavigationController *topNavigationController = (UINavigationController *)_topViewController;
            
            if (topNavigationController.viewControllers.count > 0) {
                UIViewController *rootController = topNavigationController.viewControllers[0];
                rootController.navigationItem.leftBarButtonItem = leftButtonItem;
            }
            
            // Enforce a common looking navigation bar. Again, this is a little
            // more special purpose than I would ideally like here, but this
            // isn't supposed to be arbitrarily reusable framework code, and it
            // does cut down on some fussiness elsewhere.
            topNavigationController.navigationBar.barStyle = UIBarStyleBlack;
        }
    }
}

- (void)setTopViewController:(UIViewController *)topViewController animation:(ELESideNavigationControllerAnimation)animation completion:(void (^)(void))completion;
{
    if (topViewController)
    {
        // When asked to set the top view controller to the same value it already
        // has, just hide the left side view (if visible).
        if (self.topViewController == topViewController) {
            if (self.isLeftSideViewVisible) {
                [self hideLeftSideViewAnimated:(animation != ELESideNavigationControllerAnimationNone) completion:completion];
            }
            else if (completion) {
                completion();
            }
        }
        
        // The following code tests against each of the four different animation
        // types first, and then against whether the left side view is visible or
        // hidden. In most cases, the behavior for when the left side view is
        // visible is simply to hide it and then do the same thing that would have
        // been done if it was hidden in the first place.
        
        else if (animation == ELESideNavigationControllerAnimationNone) {
            
            if (self.isLeftSideViewVisible) {
                [self hideLeftSideViewAnimated:NO completion:nil];
            }
            [self replaceTopViewControllerWithViewController:topViewController];
            if (completion) {
                completion();
            }
            
        } else if (animation == ELESideNavigationControllerAnimationStandard) {
            
            if (self.isLeftSideViewVisible) {
                
                void (^replaceAndHideBlock)() = ^{
                    [self replaceTopViewControllerWithViewController:topViewController];
                    [self hideLeftSideViewAnimated:YES completion:completion];
                };
                
                if (ELESideNavigationControllerShouldUseFancierReplaceAnimation) {
                    [UIView animateWithDuration:0.2 animations:^{
                        // Animate top view offscreen to the right before replacing
                        // it with the new top view controller and sliding it back
                        // onscreen. This is a nicer effect than instantaneously
                        // replacing the top view controller while the old one is
                        // still visible to the user.
                        CGRect newTopViewFrame = self.topViewController.view.frame;
                        newTopViewFrame.origin.x = CGRectGetMaxX(self.view.bounds);
                        self.topViewController.view.frame = newTopViewFrame;
                    } completion:^(BOOL finished) {
                        replaceAndHideBlock();
                    }];
                } else {
                    replaceAndHideBlock();
                }
            } else {
                // When the left side view is hidden, replacing the top view
                // controller with the standard animation is the same as replacing
                // it with no animation. In the future, it might make sense to add
                // a crossfade transition here.
                [self replaceTopViewControllerWithViewController:topViewController];
                if (completion) {
                    completion();
                }
            }
            
        } else if (animation == ELESideNavigationControllerAnimationCover) {
            
            void (^coverAnimationBlock)() = ^{
                UIViewController *oldTopViewController = self.topViewController;
                [self notifyTopViewControllerSwappingOut];

                // Add new top view controller
                self.topViewController = topViewController;
                [self.topViewController willMoveToParentViewController: self];
                [self addChildViewController:self.topViewController];
                
                // Add view for new top view controller
                [self.view addSubview:self.topViewController.view];
                CGRect newTopViewFrame = self.view.bounds;
                newTopViewFrame.origin.y = CGRectGetMaxY(self.view.bounds);
                self.topViewController.view.frame = newTopViewFrame;
                
                [self.topViewController didMoveToParentViewController:self];
                [self notifyTopViewControllerSwappingIn];
                
                [UIView animateWithDuration:0.3 animations:^{
                    self.topViewController.view.frame = self.view.bounds;
                } completion:^(BOOL finished) {
                    // Remove view and controller for old top view controller
                    [oldTopViewController.view removeFromSuperview];
                    
                    [self willMoveToParentViewController:nil];
                    [self.view removeFromSuperview];
                    [self removeFromParentViewController];
                    if (completion) {
                        completion();
                    }
                }];
            };
            
            if (self.isLeftSideViewVisible) {
                [self hideLeftSideViewAnimated:YES completion:^{
                    coverAnimationBlock();
                }];
            } else {
                coverAnimationBlock();
            }
            
        } else if (animation == ELESideNavigationControllerAnimationUncover) {
            
            void (^uncoverAnimationBlock)() = ^{
                UIViewController *oldTopViewController = self.topViewController;
                
                [self notifyTopViewControllerSwappingOut];

                // Add new top view controller
                self.topViewController = topViewController;
                [self.topViewController willMoveToParentViewController: self];
                [self addChildViewController:self.topViewController];
                
                // Add view for new top view controller
                [self.view insertSubview:self.topViewController.view belowSubview:oldTopViewController.view];
                self.topViewController.view.frame = self.view.bounds;
                
                [self.topViewController didMoveToParentViewController:self];
                [self notifyTopViewControllerSwappingIn];
                
                [UIView animateWithDuration:0.3 animations:^{
                    // Slide old top view down offscreen
                    CGRect newFrameForOldTopView = self.view.bounds;
                    newFrameForOldTopView.origin.y = CGRectGetMaxY(self.view.bounds);
                    oldTopViewController.view.frame = newFrameForOldTopView;
                } completion:^(BOOL finished) {
                    // Remove view and controller for old top view controller
                    [oldTopViewController.view removeFromSuperview];
                    
                    [self willMoveToParentViewController:nil];
                    [self.view removeFromSuperview];
                    [self removeFromParentViewController];
                    if (completion) {
                        completion();
                    }
                }];
            };
            
            if (self.isLeftSideViewVisible) {
                [self hideLeftSideViewAnimated:YES completion:^{
                    uncoverAnimationBlock();
                }];
            } else {
                uncoverAnimationBlock();
            }
            
        } else {
            [NSException raise:NSInvalidArgumentException format:@"%s: Unknown animation for changing the top view controller: %@", __PRETTY_FUNCTION__, @(animation)];
        }
    }
    else
    {
        [self replaceTopViewControllerWithViewController: nil];
        if (completion) {
            completion();
        }
    }
}

- (void)notifyTopViewControllerSwappingOut
{
    // Notify the topview that it's being swapped out
    if ([self.topViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *workingController = (UINavigationController *)self.topViewController;
        if ([workingController.topViewController respondsToSelector:@selector(didSwapOutTopViewController)]) {
            ELEViewController *topController = (ELEViewController *)workingController.topViewController;
            [topController didSwapOutTopViewController];
        }
        if ([workingController.topViewController isKindOfClass:[ELEViewController class]]) {
            ELEViewController *topController = (ELEViewController *)workingController.topViewController;
            [topController.helper topViewControllerStopViewTimer];
        } else if ([workingController.topViewController isKindOfClass:[ELETableViewController class]]) {
            ELETableViewController *topController = (ELETableViewController *)workingController.topViewController;
            [topController.helper topViewControllerStopViewTimer];
        }
    }
}

- (void)notifyTopViewControllerSwappingIn
{
    // Notify the topview that it's being swapped IN
    if ([self.topViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *workingController = (UINavigationController *)self.topViewController;
        if ([workingController.topViewController respondsToSelector:@selector(didSwapInTopViewController)]) {
            ELEViewController *topController = (ELEViewController *)workingController.topViewController;
            [topController didSwapInTopViewController];
        }
        if ([workingController.topViewController isKindOfClass:[ELEViewController class]]) {
            ELEViewController *topController = (ELEViewController *)workingController.topViewController;
            [topController.helper topViewControllerStartViewTimer];
        } else if ([workingController.topViewController isKindOfClass:[ELETableViewController class]]) {
            ELETableViewController *topController = (ELETableViewController *)workingController.topViewController;
            [topController.helper topViewControllerStartViewTimer];
        }
    }
}

- (void)replaceTopViewControllerWithViewController:(UIViewController *)viewController
{
    CGRect topViewFrame = self.topViewController.view.frame;
    
    [self notifyTopViewControllerSwappingOut];
    
    // Remove view and controller for current top view controller
    [self.topViewController willMoveToParentViewController: nil];
    [self.topViewController.view removeFromSuperview];
    [self.topViewController removeFromParentViewController];
    
    // Add new top view controller
    self.topViewController = viewController;
    
    if (self.topViewController)
    {
        [self.topViewController willMoveToParentViewController: self];
        [self addChildViewController:self.topViewController];
        
        // Add view for new top view controller
        self.topViewController.view.frame = topViewFrame;
        [self.view addSubview:self.topViewController.view];
        
        [self.topViewController didMoveToParentViewController:self];
        [self notifyTopViewControllerSwappingIn];
    }
}

#pragma mark - Left view controller

- (void)showLeftSideViewAnimated:(BOOL)animated completion:(void (^)(void))completion;
{
    if (self.isLeftSideViewVisible) {
        return;
    }
    
    [self.topViewController.view endEditing:YES];
    
    [self loadLeftSideViewIfNeeded];
    
    CGRect newTopViewFrame = self.topViewController.view.frame;
    newTopViewFrame.origin.x = CGRectGetMaxX(self.view.bounds) - 50;
    
    // Add mask view over the top view which triggers hiding the left side view
    // when the mask is tapped. This also prevents taps from reaching the top
    // view while the left side view is visible.
    self.topMaskView = [[UIView alloc] initWithFrame:self.topViewController.view.frame];
    [self.topMaskView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleLeftSideViewVisibility)]];
    [self.view insertSubview:self.topMaskView aboveSubview:self.topViewController.view];
    
    void (^frameChangeBlock)() = ^{
        self.topViewController.view.frame = newTopViewFrame;
        self.topMaskView.frame = newTopViewFrame;
    };
    
    if (animated) {
        [UIView animateWithDuration:0.3 animations:^{
            frameChangeBlock();
            self.isLeftSideViewVisible = YES;
        } completion:^(BOOL finished) {
            if (completion) {
                completion();
            }
        }];
    } else {
        frameChangeBlock();
        self.isLeftSideViewVisible = YES;
        
        if (completion) {
            completion();
        }
    }
}

- (void)hideLeftSideViewAnimated:(BOOL)animated completion:(void (^)(void))completion;
{
    if (!self.isLeftSideViewVisible) {
        return;
    }
    
    CGRect newTopViewFrame = self.topViewController.view.frame;
    newTopViewFrame.origin.x = CGRectGetMinX(self.view.bounds);
    
    void (^frameChangeBlock)() = ^{
        self.topViewController.view.frame = newTopViewFrame;
        [self.topMaskView removeFromSuperview];
        self.topMaskView = nil;
    };
    
    if (animated) {
        [UIView animateWithDuration:0.3 animations:^{
            frameChangeBlock();
            self.isLeftSideViewVisible = NO;
        } completion:^(BOOL finished) {
            [self.leftSideViewController.view removeFromSuperview];
            
            if (completion) {
                completion();
            }
        }];
    } else {
        frameChangeBlock();
        self.isLeftSideViewVisible = NO;
        [self.leftSideViewController.view removeFromSuperview];
        
        if (completion) {
            completion();
        }
    }
}

- (void)toggleLeftSideViewVisibilityAnimated:(BOOL)animated completion:(void (^)(void))completion;
{
    if (self.isLeftSideViewVisible) {
        [self hideLeftSideViewAnimated:animated completion:completion];
    } else {
        [self showLeftSideViewAnimated:animated completion:completion];
    }
}

- (void)toggleLeftSideViewVisibility
{
    [self toggleLeftSideViewVisibilityAnimated:YES completion:nil];
}

- (void)loadLeftSideViewIfNeeded
{
    if ([self.leftSideViewController isViewLoaded] == NO || self.leftSideViewController.view.superview == nil) {
        [self.view insertSubview:self.leftSideViewController.view atIndex:0];
        self.leftSideViewController.view.frame = self.view.bounds;
    }
}

@end

@implementation UIViewController (ELESideNavigationController)

- (ELESideNavigationController *)ele_sideNavigationController;
{
    UIViewController *viewController = self;
    while (viewController != nil) {
        if ([viewController isKindOfClass:[ELESideNavigationController class]]) {
            return (ELESideNavigationController *)viewController;
        }
        viewController = viewController.parentViewController;
    }
    return [self.presentingViewController ele_sideNavigationController];
}

@end
