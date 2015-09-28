//
//  AppDelegate.h
//  elektra
//
//  Created by Jeff Sorrentino on 2/12/13.
//  Copyright (c) 2013 Dogfish Software. All rights reserved.
// asdasdassdddds
//asdasdasd

//asdasdasdas
//asdascxzczcasd
//ashwini1223331
#import <UIKit/UIKit.h>

// Change Change Change
#define sharedAppDelegate ((ElektraAppDelegate *)[[UIApplication sharedApplication] delegate])

extern NSString *ELEShareLiveEnabledKey;
extern NSString *ELEHasLoggedInKey;
extern NSString *ELEForceUploadFailureMessage;
extern NSString *ELEHideDebuggingErrorAlertKey;

//The "Fluke" organization is tied to various reference data
static NSString * const kFlukeOrganizationId = @"1861F13A-BC50-11E2-9678-15B654818C3B";

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

@class ELESideNavigationController;

@interface ElektraAppDelegate : NSObject <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic, readonly) ELESideNavigationController *sideNavigationController;

/**
 *  start the registration process to push notifications
 */
- (void)registerForRemoteNotification;

// Live Share
//
- (void)declineLiveShareCall;

// Only for use in debugging
- (void)simulateIncomingLiveShareCall;

//
+(void)setApplicationIconBadgeNumber:(NSUInteger)badgeNumber;

// Use a class method on the app delegate to present a view controller.  This will allow for unit testing
// with a mock and will keep a consistent means of presenting modal view controllers.
+ (void) presentViewController:(UIViewController*)viewController animated:(BOOL)animated completion:(void (^)(void))completion;


@end
