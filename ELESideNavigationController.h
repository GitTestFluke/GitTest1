//
//  ELESideNavigationController.h
//  SideNavigationTest
//
//  Created by Luke Adamson on 4/23/13.
//  Copyright (c) 2013 Dogfish Software. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, ELESideNavigationControllerAnimation) {
    ELESideNavigationControllerAnimationNone,
    ELESideNavigationControllerAnimationStandard, // Old view slides off to right, then slides back to left as new view
    ELESideNavigationControllerAnimationCover,    // New view slides up from bottom to cover old view
    ELESideNavigationControllerAnimationUncover   // Old view slides down from top revealing new view behind it
};

@class ELEActionSheet;

@interface ELESideNavigationController : UIViewController

// Designated initializer
- (void)setupLeftSideViewController:(UIViewController *)leftSideViewController topViewController:(UIViewController *)topViewController;

// Top view controller
@property (nonatomic, readonly) UIViewController *topViewController;
- (void)setTopViewController:(UIViewController *)topViewController animation:(ELESideNavigationControllerAnimation)animation completion:(void (^)(void))completion;

// Left view controller
@property UIViewController *leftSideViewController;
@property (readonly) BOOL isLeftSideViewVisible;
- (void)showLeftSideViewAnimated:(BOOL)animated completion:(void (^)(void))completion;
- (void)hideLeftSideViewAnimated:(BOOL)animated completion:(void (^)(void))completion;
- (void)toggleLeftSideViewVisibilityAnimated:(BOOL)animated completion:(void (^)(void))completion;
- (void)toggleLeftSideViewVisibility; // Animated

@end

@interface UIViewController (ELESideNavigationController)

// Returns the nearest parent view controller which is an instance of
// ELESideNavigationController (or the nearest parent of the presenting view
// controller if the receiver is being presented with UIKit's
// -presentViewController:animated:completion:).
//
// This method name has been prefixed with ele_ because it is extending all
// instances of Apple's UIViewController class. It's a good practice to prefix
// such method names so they don't accidentally shadow Apple's private methods.

- (ELESideNavigationController *)ele_sideNavigationController;

@end
