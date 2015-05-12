//
//  AppDelegate.m
//  elektra
//
//  Created by Jeff Sorrentino on 2/12/13.
//  Copyright (c) 2013 Dogfish Software. All rights reserved.
//

#import "ElektraAppDelegate.h"

#import "AFNetworkActivityIndicatorManager.h"
#import "BaseEntity+utilities.h"
#import "ELEAnalyticsManager.h"
#import "ELECallViewController.h"
#import "ELECaptureViewController.h"
#import "ELECoreDataStack.h"
#import "ELEDataFileManager.h"
#import "ELEFlukeAPIDataSyncManager.h"
#import "ELELicenseManager.h"
#import "ELELiveShareSession.h"
#import "ELESideNavigationController.h"
#import "ELESmartViewTransitionManager.h"
#import "ELETutorialManager.h"
#import "ELEUserManager.h"
#import "FLKDeviceManager.h"
#import "FLKImportManager.h"
#import "TOYServiceHatchController.h"
#import "TOYServiceHatchControllerDelegate.h"

NSString *ELEDeviceTokenKey = @"deviceTokenKey";
NSString *ELEShareLiveEnabledKey = @"shareLiveEnabled";
NSString *ELEHasLoggedInKey = @"hasLoggedInKey";
NSString *ELEForceUploadFailureMessage = @"ELEForceUploadFailureMessage";
NSString *ELEHideDebuggingErrorAlertKey = @"ELEHideDebuggingErrorAlertKey";

SystemSoundID shareLiveCallSoundId;

@interface ElektraAppDelegate ()

/**
 *  per apple documentation registering for remote notification can be
 *  a long process if no network is available. So keeping track of this
 *  status so we don't send multiple request to register the device.
 */
@property BOOL      registeringForPush;

// Live share
@property NSString *liveShareSessionId;
@property UIAlertView *liveShareAlertView;

@property ELELiveShareSession *liveShareSession;

@property BOOL finishedLaunching;
@property (nonatomic, readwrite) ELESideNavigationController *sideNavigationController;

@end

@implementation ElektraAppDelegate

+ (void)initialize
{
    if (self == [ElektraAppDelegate class])
    {
#ifdef DEBUG
        
        //calling lcl_configure_by_identifier during unit test cause other test to hang
        //when trying to log (unsure why) when running those test with xctool
        //so turning that off for tests
        if (![NSBundle bundleWithIdentifier: @"com.dogfishsoftware.unit-test"])
        {
            lcl_configure_by_identifier("*", lcl_vWarning);
            
            //        lcl_configure_by_identifier("LiveShare", lcl_vDebug);
            //        lcl_configure_by_identifier("PushNotification", lcl_vDebug);
            //        lcl_configure_by_identifier("DeviceManagement", lcl_vInfo);
            //        lcl_configure_by_identifier("CoreBluetooth", lcl_vDebug);
            //        lcl_configure_by_identifier("CoreData", lcl_vDebug);
            //        lcl_configure_by_identifier("DataSync", lcl_vInfo);
            //        lcl_configure_by_identifier("UserManager", lcl_vDebug);
            //        lcl_configure_by_identifier("CoreDataImport", lcl_vDebug);
            //        lcl_configure_by_identifier("ThermalImage", lcl_vInfo);
            //        lcl_configure_by_identifier("TutorialManager", lcl_vDebug);
            //        lcl_configure_by_identifier("Capture", lcl_vDebug);
            
            //to get more info for one component, follow this syntax
            //  lcl_configure_by_identifier(lcl_cGlobal , lcl_vDebug);
        }
#else
        lcl_configure_by_identifier("*", lcl_vError);
#endif
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self setupInitialViews];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        // Call the instantiator to setup the context on the background thread
        [[ELECoreDataStack sharedInstance] managedObjectContext];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Then call back to the main thread to finish launching.
            // Note: this will also keep SpringBoard from crashing the app b/c of something
            // other than data migration (handled by the call to create the main context).
            [self finishLaunching:launchOptions];
            self.finishedLaunching = YES;
        });
        
    });
    
    return YES;
}

- (void)finishLaunching:(NSDictionary *)launchOptions
{
    // Please group added code into submethods so that this method does not become the Magna Carta

    // Uncomment this is if you need to debug push notifications that are used
    // to launch the app. You need to first install your latest code on the
    // device that will receive the notifications. Then, make sure the app isn't
    // running on the device (stop it in Xcode or otherwise kill it), then do
    // whatever is required so the device will receive the push notification.
    // Once it does, tap on the notification to launch the app. The following
    // sleep call should keep the app suspended long enough that you can then
    // use Xcode's Debug->Attach to Process menu (this is assuming the device is
    // still connected to your Mac) to attach to the running process before it
    // finishes sleeping. After you've connected in Xcode, just wait for it to
    // finish sleeping, and presto! You're debugging an app which was launched
    // outside of Xcode by receiving a push notification.
    //
    // [NSThread sleepForTimeInterval:15];

    // Register defaults
    NSMutableDictionary *defaultValues = [NSMutableDictionary dictionary];
    defaultValues[ELEDeviceTokenKey] = @"";
    defaultValues[ELEShareLiveEnabledKey] = @"YES";
    defaultValues[ELEHasLoggedInKey] = @"NO";
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
    

    // If there is no environment setting this should mean that the app is launched for the first time
    if (![ELEEnvironment hasEnvironmentSetting]) {
        [self setSettingsForFirstAppLaunch];
    }
    
    [ELEEnvironment selectDefaultEnvironment];
    
    // The ELEEnvironment has been setup, therefore the Analytics manager has been setup, record the launch options
    [ELEAnalyticsManager captureLaunchMethod:launchOptions];
    
    //start the tutorial downloads does not have to be done right away
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [ELETutorialManager sharedManager];
    }];
    
    // This flag is used to tell whether we're IN THE MIDDLE of registering for push notifications before allowing the user to try again
    self.registeringForPush = NO;
    
    // Check if we've launched because of a push notification
    NSDictionary* userInfo = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
    if (userInfo) {
        // we received a push notification so act on it
        lcl_log(lcl_cPushNotifications , lcl_vInfo, @"Received a push notification");
    }
    
    // Add the mode view controller
    ELEModeViewController *modeViewController = [ELEModeViewController new];
    [self.sideNavigationController setupLeftSideViewController:modeViewController topViewController:modeViewController.defaultViewController];
    
    [self installServiceHatch];
    
    [ELESmartViewTransitionManager registerForShowingTransitionMessageIfNeeded];
    
    //a user must be signed in to an account in order to use the app
    [[ELEFlukeAPIDataSyncManager sharedInstance] launchAndSignIn];
    
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];

    [self processPushNotificationsIfNeededForApplication:[UIApplication sharedApplication] launchOptions:launchOptions];
}

#pragma mark - PUSH notification methods
- (void)registerForRemoteNotification
{
    //per apple documentation, calling registerUserNotificationSettings
    //mulitple times is not an issue and won't go to the servers if
    //a token was already retrieved.
    // check if we're already waiting for it to be accepted
    if (!self.registeringForPush)
    {
        self.registeringForPush = YES;
        
        // Register for push notifications
        UIApplication *application = [UIApplication sharedApplication];
        
        if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
            // If running iOS 8 and building with Xcode 6, need to use the new method for registering for notifications
            UIUserNotificationType notificationTypes = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:notificationTypes categories:nil];
            [application registerUserNotificationSettings:settings];
        }
        else
        {
            // If running Xcode 5.1 (iOS 7 SDK) or running iOS 7 need to sign up using a different path
            UIRemoteNotificationType notificationTypes = UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound;
            [application registerForRemoteNotificationTypes:notificationTypes];
        }
    }
}

- (NSString *)getPushNotificationAlertString:(NSDictionary *)remoteNotification
{
    NSString *message;
    
    // When a localized push notification comes in, there is a parameter called 'loc-key' which is the localized key
    // if it's there, then the aps.alert is a localized one and includes a dictionary of parameters
    id alertParam = [remoteNotification valueForKeyPath:@"aps.alert"];
    if ([alertParam isKindOfClass:[NSString class]]) {
        message = [remoteNotification valueForKeyPath:@"aps.alert"];
    } else {
        // we got a dictionary from a push
        NSString *locKeyString = [remoteNotification valueForKeyPath:@"aps.alert.loc-key"];
        if (locKeyString) {
            NSDictionary *parameters = [remoteNotification objectForKey:@"aps"];
            NSDictionary *locParamaeters = [parameters objectForKey:@"alert"];
            
            NSArray *messArg = [locParamaeters objectForKey:@"loc-args"];
            if ([messArg count] > 0) {
                NSString *callerName = [messArg objectAtIndex:0];
                message = [NSString stringWithFormat:NSLocalizedString(locKeyString, @""), callerName];
            }
            
        }
    }
    return message;
}

- (void)processPushNotificationsIfNeededForApplication:(UIApplication *)application launchOptions:(NSDictionary *)launchOptions
{
    // Handle launches due to Live Share push notifications
    if (launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] &&
        [[ELEUserManager sharedUserManager] currentUserAccountInContext:ELECoreDataStackContext])
    {
        NSDictionary *remoteNotification = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
        NSString *sessionId = remoteNotification[@"liveShareSessionId"];
        if ([sessionId isKindOfClass:[NSNumber class]]) {
            sessionId = [(NSNumber *)sessionId stringValue];
        }
        NSString *message = [self getPushNotificationAlertString:remoteNotification];
        [self processIncomingLiveShareCallToApplication:application withSessionId:sessionId message:message];
    }
}

// Delegation methods
#ifdef __IPHONE_8_0
- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    lcl_log(lcl_cPushNotifications, lcl_vTrace, @"");
    //register to receive notifications
    [application registerForRemoteNotifications];
}
#endif

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    lcl_log(lcl_cPushNotifications , lcl_vDebug, @"");

    [[ELEUserManager sharedUserManager] registerDevice:deviceToken];
    self.registeringForPush = NO;
}

- (void) application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    //simulator do not support push notification (error 3010), so only log other errors
    lcl_log_if(lcl_cPushNotifications , lcl_vError,error.code != 3010, @"\n registration for push notifications failed with error: %@\n", error.description);
    self.registeringForPush = NO;
}

- (void) application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    lcl_log(lcl_cPushNotifications , lcl_vDebug, @"%@", userInfo);
    NSString *sessionId = userInfo[@"liveShareSessionId"];
    if ([sessionId isKindOfClass:[NSNumber class]]) {
        sessionId = [(NSNumber *)sessionId stringValue];
    }
    NSString *message = [self getPushNotificationAlertString:userInfo];
    [self processIncomingLiveShareCallToApplication:application withSessionId:sessionId message:message];
}

- (BOOL) application: (UIApplication*) application
             openURL: (NSURL*) url
   sourceApplication: (NSString*) sourceApplication
          annotation: (id) annotation {
    
    if ([url.pathExtension.lowercaseString isEqualToString:@"zip"]) {
        [self processZipImport:url];
        return YES;
    }
    
    return NO;
}

- (void)processZipImport:(NSURL *)zipURL
{
    ELEModeViewController *modeViewController = [self.sideNavigationController modeViewController];
    ELEModeViewControllerMode mode = ELEModeViewControllerModeHistory;
    
    [modeViewController switchToMode:mode animated:YES completion:^{
        if (modeViewController.currentMode == mode) {
            UINavigationController *navigationController = (UINavigationController *)self.sideNavigationController.topViewController;
            [FLKImportManager processZipImport:zipURL showProgressOnViewController:navigationController.topViewController];
        }
    }];
}

- (void)processIncomingLiveShareCallToApplication:(UIApplication *)application withSessionId:(NSString *)sessionId message:(NSString *)message
{
    if ([[ELEUserManager sharedUserManager] currentUserAccountInContext:ELECoreDataStackContext])
    {
        [ElektraAppDelegate setApplicationIconBadgeNumber:0];
        
        self.liveShareSessionId = sessionId;
        
        self.liveShareAlertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ShareLive™", @"ShareLive™") message:message delegate:self cancelButtonTitle:NSLocalizedString(@"Decline", @"Decline") otherButtonTitles:NSLocalizedString(@"Accept", @"Accept"), nil];
        [self.liveShareAlertView show];
        
        //Start the ringing
        if (shareLiveCallSoundId == 0) {
            
            [self shouldEnableShareLiveSound:YES];
            
        }
        
        AudioServicesPlaySystemSound(shareLiveCallSoundId);


    }
}

#pragma mark - Global variables

+ (void)setApplicationIconBadgeNumber:(NSUInteger)badgeNumber
{
    BOOL canBadge = YES;
    UIApplication *application = [UIApplication sharedApplication];
    if ([application respondsToSelector:@selector(currentUserNotificationSettings)]) {
        UIUserNotificationSettings* notificationSettings = [[UIApplication sharedApplication] currentUserNotificationSettings];
        canBadge = (notificationSettings.types & UIUserNotificationTypeBadge) == UIUserNotificationTypeBadge;
    }
    if (canBadge) {
        [application setApplicationIconBadgeNumber:badgeNumber];
    }
}



- (void)setupInitialViews
{
    // Apply application-wide appearance properties
    [[UINavigationBar appearance] setBackgroundImage:[UIImage imageNamed:@"nav-bar-background"] forBarMetrics:UIBarMetricsDefault];
    [[UINavigationBar appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}];
    
    // Create the window, the root view controller, and its child controllers.
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    self.sideNavigationController = [ELESideNavigationController new];
    self.window.rootViewController = self.sideNavigationController;
    
    [self.window makeKeyAndVisible];
}

- (void)shouldEnableShareLiveSound:(BOOL)enableSound{
    
    if (enableSound) {
        
        NSString *soundPath=[[NSBundle bundleForClass:[self class]] pathForResource:@"ping" ofType:@"aiff"];
        
        if (soundPath != nil) {
            AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:soundPath],&shareLiveCallSoundId);
        }
        
    }else{
        
        if (shareLiveCallSoundId != 0) {
            AudioServicesDisposeSystemSoundID(shareLiveCallSoundId);
            shareLiveCallSoundId = 0;
        }
    }
 
}

- (void)installServiceHatch
{
    TOYServiceHatchController *serviceHatchController = [TOYServiceHatchController sharedServiceHatchController];
    [serviceHatchController installInWindow:self.window];
    serviceHatchController.delegate = [TOYServiceHatchControllerDelegate sharedInstance];
}

- (void)setSettingsForFirstAppLaunch
{
    // If app is launched for the first time we don't want to show announcemnt messages to the user
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:ELEReportSyncAnnouncementAlertSeenKey];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    [ELEAnalyticsManager stopCapturing];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    [ELEAnalyticsManager stopCapturing];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    [ELEAnalyticsManager startCapturing];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [ELEAnalyticsManager startCapturing];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    //force a synchronize before the app shuts down (one of the few case where
    //this should be called)
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [ELEAnalyticsManager stopCapturing];
}

#pragma mark - backdoor methods for calabash automation

- (NSString*)calabashSetEnvironment:(NSString *)environmentName
{
    @try
    {
        [ELEEnvironment selectEnvironmentNamed:environmentName];
        return [NSString stringWithFormat:@"Environment is set to %@", environmentName];
    }
    @catch (NSException *exception)
    {
        return exception.reason;
    }
}

- (NSString*)calabashEnableSimulatedDevices:(NSString *)enable
{
    if ([enable caseInsensitiveCompare:@"YES"] == NSOrderedSame)
    {
        [FLKDeviceManager enableSimulatedDevices:YES];
        return @"Simulated devices are enabled";
    }
    else if ([enable caseInsensitiveCompare:@"NO"] == NSOrderedSame)
    {
        [FLKDeviceManager enableSimulatedDevices:NO];
        return @"Simulated devices are disabled";
    }
    else
    {
        return @"Must pass parameter of YES or NO";
    }
}

- (NSString*)calabashEnableShareLive:(NSString *)enable
{
    void (^enableShareLive)(BOOL) = ^(BOOL enable) {
        id value = enable ? @"YES" : @"NO";
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:value forKey:ELEShareLiveEnabledKey];
    };
    
    if ([enable caseInsensitiveCompare:@"YES"] == NSOrderedSame)
    {
        enableShareLive(YES);
        [[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:ELEShareLiveEnabledKey];
        return @"ShareLive is enabled";
    }
    else if ([enable caseInsensitiveCompare:@"NO"] == NSOrderedSame)
    {
        enableShareLive(NO);
        return @"ShareLive is disabled";
    }
    else
    {
        return @"Must pass parameter of YES or NO";
    }
}

- (NSString*)calabashEnableForceUploadFailureMessage:(NSString *)enable
{
    void (^enableForceUploadFailureMessage)(BOOL) = ^(BOOL enable) {
        id value = enable ? @"YES" : @"NO";
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:value forKey:ELEForceUploadFailureMessage];
        [userDefaults synchronize];
    };
    
    if ([enable caseInsensitiveCompare:@"YES"] == NSOrderedSame)
    {
        enableForceUploadFailureMessage(YES);
        return @"Force upload failure message is enabled";
    }
    else if ([enable caseInsensitiveCompare:@"NO"] == NSOrderedSame)
    {
        enableForceUploadFailureMessage(NO);
        return @"Force upload failure message is disabled";
    }
    else
    {
        return @"Must pass parameter of YES or NO";
    }
}

- (NSString*)calabashEnableWorkOrders:(NSString *)enable
{
    return [self calabashEnableFeature:ELEWorkOrderLicensedFeatureId enable:enable];
}

- (NSString*)calabashEnableEquipment:(NSString *)enable
{
    return [self calabashEnableFeature:ELEEquipmentLicensedFeatureId enable:enable];
}

- (NSString*)calabashEnableFeature:(NSString*)featureId enable:(NSString *)enable
{
    NSArray *choices = [[ELELicenseManager sharedManager] serviceHatchChoices];
    if ([choices containsObject:enable]) {
        NSString *title = [[ELELicenseManager sharedManager] serviceHatchNameForFeatureId:featureId];
        [[ELELicenseManager sharedManager] setServiceHatchValue:enable featureId:featureId];
        return [NSString stringWithFormat:@"%@ is %@", title, enable];
    }
    else {
        return [NSString stringWithFormat:@"Must pass parameter of %@", [choices componentsJoinedByString:@", "]];
    }
}

- (NSString*)calabashResetTestAccount
{
    [[ELEUserManager sharedUserManager] resetTestAccount];
    return @"Reset test account message sent";
}

#pragma mark - UIAlertViewDelegate
//using the did dismiss so the alert is already gone when we try to show the call controller
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView == self.liveShareAlertView) {
        self.liveShareAlertView = nil;

        if (buttonIndex == 1 /* Accept */) {
            [self acceptLiveShareCall];
        } else {
            [self declineLiveShareCall];
        }
        
        //Dispose the ringing
        [self shouldEnableShareLiveSound:NO];
    }
}

- (void)acceptLiveShareCall
{
    //grab the top level view controller and present the incoming call controller
    UIStoryboard *captureStoryBoard = [UIStoryboard storyboardWithName:@"ELECapture_Storyboard" bundle:[NSBundle bundleForClass:[self class]]];
    
    ELECallViewController *callController = [captureStoryBoard instantiateViewControllerWithIdentifier: @"ELECallViewController"];
    callController.shareLiveSession = [[ELELiveShareSession alloc] initCalleeSessionWithSessionId:self.liveShareSessionId];
    callController.callEndCompletionBlock = ^(ELECallViewController* controller){
        [controller dismissViewControllerAnimated:YES completion:nil];
    };
    
    [ElektraAppDelegate presentViewController: callController animated: YES completion:nil];
}

- (void)declineLiveShareCall
{
    self.liveShareSession = [[ELELiveShareSession alloc] initCalleeSessionWithSessionId:self.liveShareSessionId];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(liveShareSessionDidDisconnect:) name:ELELiveShareSessionDidDisconnectNotification object:self.liveShareSession];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(liveShareSessionDidDisconnect:) name:ELELiveShareSessionDidFailToConnectNotification object:self.liveShareSession];
    [self.liveShareSession decline];

}

- (void)liveShareSessionDidDisconnect:(NSNotification *)notification
{
    self.liveShareSession = nil;
}

- (void)switchToCaptureModeIfNeeded
{
    ELESideNavigationController *sideNavigationController = (ELESideNavigationController *)(self.window.rootViewController);
    UINavigationController *navigationController = (UINavigationController *)(sideNavigationController.topViewController);
    UIViewController *rootControllerOfTopController = (ELECaptureViewController *)(navigationController.viewControllers[0]);

    BOOL isInCaptureMode = [rootControllerOfTopController isKindOfClass:[ELECaptureViewController class]];

    if (!isInCaptureMode) {
        ELEModeViewController *modeViewController = (ELEModeViewController *)[sideNavigationController leftSideViewController];
        UINavigationController *captureNavigationController = modeViewController.captureNavigationController;
        [sideNavigationController setTopViewController:captureNavigationController animation:ELESideNavigationControllerAnimationNone completion:nil];
    }
}

- (void)simulateIncomingLiveShareCall
{
    lcl_log(lcl_cLiveShare , lcl_vDebug,@"Simulating incoming Live Share call");

    self.liveShareSessionId = nil;
    [self acceptLiveShareCall];
}

+ (void)presentViewController:(UIViewController*)viewController animated:(BOOL)animated completion:(void (^)(void))completion
{
    // Apple keeps changing their rules about presenting view controllers.  Lets just be sure we are presenting on
    // the topmost view controller.
    UIViewController *presentingViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    while (presentingViewController.presentedViewController != nil) {
        presentingViewController = presentingViewController.presentedViewController;
    }
    [presentingViewController presentViewController:viewController animated:animated completion:completion];
}

@end
