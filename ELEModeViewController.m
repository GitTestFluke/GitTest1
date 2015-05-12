//
//  ELEModeViewController.m
//  elektra
//
//  Created by Jeff Sorrentino on 2/12/13.
//  Copyright (c) 2013 Dogfish Software. All rights reserved.
//

#import "ELEModeViewController.h"

#import "ELECaptureViewController.h"
#import "ELECoreDataStack.h"
#import "ELEEquipmentRootViewController.h"
#import "ELEHistoryViewController.h"
#import "ELELicenseManager.h"
#import "ELELockButton.h"
#import "ELEResourceCenterViewController.h"
#import "ELESettingsViewController.h"
#import "ELESideNavigationController.h"
#import "ELETeamViewController.h"
#import "ELEUserManager.h"
#import "ELEWorkOrderTableViewController.h"
#import "UILabel+Elektra.h"
#import "UIColor+Elektra.h"


@interface ELEModeViewController ()

// ELEModeViewController retains and reuses the same instances of the various mode
// view controllers so that they keep their state as the user switches between
// them. This approach isn't perfect, as the instances don't survive across
// separate launches of the app. If state preservation becomes more important,
// each controller should persist and restore its state as needed.
//
// Keeping these shared instances here (indirectly, through their parent
// navigation controllers) is a tad awkward. If these controllers are really
// going to be shared, they should probably implement +sharedViewController.
// While traditional, that approach doesn't work perfectly here because we
// probably want to reuse their parent navigation controllers as well (to
// preserve navigation state). If a cleaner approach presents itself, I'll
// revisit this and refactor the related code.
//
@property (nonatomic) UINavigationController *historyNavigationController;
@property (nonatomic) UINavigationController *equipmentNavigationController;
@property (nonatomic) UINavigationController *workOrdersNavigationController;
@property (nonatomic) UINavigationController *helpNavigationController;
@property (nonatomic) UINavigationController *settingsNavigationController;
@property (nonatomic) UINavigationController *teamNavigationController;
@property (nonatomic) UINavigationController *reportsNavigationController;
@property (nonatomic) UINavigationController *userAccountNavigationController;

@property (weak, nonatomic) IBOutlet UIButton *userFullNameButton;
@property (weak, nonatomic) IBOutlet UIButton *captureButton;
@property (weak, nonatomic) IBOutlet UIButton *historyButton;
@property (weak, nonatomic) IBOutlet ELELockButton *equipmentButton;
@property (weak, nonatomic) IBOutlet ELELockButton *workOrdersButton;
@property (weak, nonatomic) IBOutlet UIButton *teamButton;
@property (weak, nonatomic) IBOutlet UIButton *reportsButton;
@property (weak, nonatomic) IBOutlet UIButton *helpButton;
@property (weak, nonatomic) IBOutlet UIButton *settingsButton;
@property (weak, nonatomic) IBOutlet UIButton *signoutButton;

@property (readwrite) ELEModeViewControllerMode currentMode;

- (IBAction)signOutButtonAction:(id)sender;

@end

@implementation ELEModeViewController

#pragma mark - Initialization

+ (instancetype)new
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"ELEMainMenu_Storyboard" bundle:[NSBundle bundleForClass:[self class]]];
    return [storyboard instantiateInitialViewController];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(currentUserDidChange)
                                                 name:ELEUserManagerDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(currentOrganizationDidChange)
                                                 name:ELEUserManagerDidChangeOrganizationNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(licensedFeaturesDidChange)
                                                 name:ELELicenseManagerDidChangeNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)tearDownSubControllers
{
    // Nil out all the view controllers, this will cause a refresh to
    // recreate them.
    self.captureNavigationController = nil;
    self.historyNavigationController = nil;
    self.equipmentNavigationController = nil;
    self.workOrdersNavigationController = nil;
    self.helpNavigationController = nil;
    self.teamNavigationController = nil;
    self.settingsNavigationController = nil;
    self.reportsNavigationController = nil;
    self.userAccountNavigationController = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Update the enabled features
    [self updateEnabledFeaturesOnMainThread];
    
    //only truncating as for some reason set the min scale factor scales the font
    //bu the minimum does not seem to be respected. Setting to middle to catch a bit of the
    //first name and a bit of the last name
    self.userFullNameButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    UserAccount *currentUser = [[ELEUserManager sharedUserManager] currentUserAccountInContext:ELECoreDataStackContext];
    if (currentUser)
    {
        [self.userFullNameButton setTitle:currentUser.fullName
                                 forState:UIControlStateNormal];
    }
    else
    {
        [self.userFullNameButton setTitle:@""
                                 forState:UIControlStateNormal];
    }
}

#pragma mark - Button actions

- (IBAction)signOutButtonAction:(id)sender
{
    [[ELEUserManager sharedUserManager] confirmLogoutUser];
}

#pragma mark - user account notification

- (void)currentOrganizationDidChange
{
    [self rebuildNavigationStackOnMainThread];
}

- (void)currentUserDidChange
{
    if (![[ELEUserManager sharedUserManager] isUserSignedIn])
    {
        //if the user is signing out, then rebuild the view controller stack to ensure everything is reset
        [self rebuildNavigationStackOnMainThread];
    }
    else
    {
        // otherwise, check the feature enabled state
        [self updateEnabledFeaturesOnMainThread];
    }
}

- (void)rebuildNavigationStackOnMainThread
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self rebuildNavigationStack];
    });
}

- (void) rebuildNavigationStack
{
    if (self.isViewLoaded)
    {
        [self tearDownSubControllers];
        
        //go back to the default view controller, unless the currently displayed mode
        //could stay up
        NSArray *modes = @[@(ELEModeViewControllerModeUserAccount), @(ELEModeViewControllerModeHelp), @(ELEModeViewControllerModeSettings)];
        if (![modes containsObject: @(self.currentMode)])
        {
            self.currentMode = ELEModeViewControllerModeDefault;
            UINavigationController *defaultNav = [self navigationViewControllerForMode:self.currentMode];
            [self.ele_sideNavigationController setTopViewController:defaultNav animation:ELESideNavigationControllerAnimationStandard completion:nil];
        }
    }
}

#pragma mark - Licensed feature handling

- (void)licensedFeaturesDidChange
{
    if (![self isModeEnabled:self.currentMode] || [self showingDisabledViewController]) {
        // If the current tab is not enabled, then boot the user to the
        // default tab by rebuilding the stack.
        [self rebuildNavigationStackOnMainThread];
    }
    else {
        // If the current tab is NOT a tab that has been disabled then
        // only nil out the subcontrollers that have been disabled,
        // which does not require being on the main thread.
        if (![[ELELicenseManager sharedManager] equipmentEnabled]) {
            self.equipmentNavigationController = nil;
        }
        if (![[ELELicenseManager sharedManager] workOrderEnabled]) {
            self.workOrdersNavigationController = nil;
        }
    }
    
    // in either case, update the enabled state of the buttons
    [self updateEnabledFeaturesOnMainThread];
    
    // And dismiss any disabled modals
    [self dismissDisabledModalViewControllerOnMainThread];
}

- (NSArray*)currentViewControllerStack
{
    // check the stack of the current navigation controller
    UINavigationController *currentNavigationController = (id)[self.ele_sideNavigationController topViewController];
    if (![currentNavigationController isKindOfClass:[UINavigationController class]]) {
        return nil;
    }
    return currentNavigationController.viewControllers;
}

- (BOOL)showingDisabledViewController
{
    return [[ELELicenseManager sharedManager] showingDisabledViewController:[self currentViewControllerStack]];
}

- (void)dismissDisabledModalViewControllerOnMainThread
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // check the stack of the current navigation controller
        UIViewController *rootVC = self.ele_sideNavigationController;
        UINavigationController *modalNavigationController = (id)[rootVC presentedViewController];
        if ([modalNavigationController isKindOfClass:[UINavigationController class]] &&
            [[ELELicenseManager sharedManager] showingDisabledViewController:modalNavigationController.viewControllers]) {
            [rootVC dismissViewControllerAnimated:NO completion:nil];
        }
    });
}

- (BOOL)isModeEnabled:(ELEModeViewControllerMode) mode
{
    switch (mode)
    {
        case ELEModeViewControllerModeEquipment:
            return [[ELELicenseManager sharedManager] equipmentEnabled];
            
        case ELEModeViewControllerModeWorkOrders:
            return [[ELELicenseManager sharedManager] workOrderEnabled];
            
        default:
            return YES;
    }
}

- (void)updateEnabledFeaturesOnMainThread
{
    // If not on the main thread then dispatch to main thread
    if (![NSThread currentThread].isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateEnabledFeaturesOnMainThread];
            return;
        });
    }
    
    // Enable state for licensed features
    self.equipmentButton.locked = ![[ELELicenseManager sharedManager] equipmentEnabled];
    self.workOrdersButton.locked = ![[ELELicenseManager sharedManager] workOrderEnabled];
}

#pragma mark - Changing modes

// Button tap events will be delivered to first responder and handled here
- (IBAction)modeButtonTapped:(UIButton *)sender
{
    ELEModeViewControllerMode mode = sender.tag;
    [self switchToMode: mode animated:YES completion:nil];
}

- (void) switchToMode:(ELEModeViewControllerMode) mode animated:(BOOL) animated completion:(void (^)(void))completion
{
#if DEBUG
    NSAssert(mode >= 0 && mode < ELEModeViewControllerModeCount, @"Unsupported mode: %@", @(mode));
#endif
    
    ELESideNavigationController *controller = [self ele_sideNavigationController];
    BOOL isPresentingModal = (controller.presentedViewController != nil);
    ELESideNavigationControllerAnimation animation = (animated && !isPresentingModal) ?
        ELESideNavigationControllerAnimationStandard :ELESideNavigationControllerAnimationNone;

    __weak typeof (self) weakSelf = self;
    [self.ele_sideNavigationController setTopViewController: [self navigationViewControllerForMode: mode]
                                                  animation: animation
                                                 completion:^
     {
         //OD: make sure to set the current mode before the completion block is called
         //in case this change was done with no animation, in which case the completion block
         //would get called right away (before mode is set outside of this block)
         weakSelf.currentMode = mode;
         
         if (isPresentingModal && animated) {
             // If currently showing a modal and the call requested an animated change, then
             // dismiss the modal after switching the view controller unanimated.
             [controller dismissViewControllerAnimated:YES completion:completion];
         }
         else if (completion)
         {
             // Otherwise, just call the completion if there is one
             completion();
         }
     }];
    
    self.currentMode = mode;
    
}

- (UINavigationController*) navigationViewControllerForMode:(ELEModeViewControllerMode) mode
{
    switch (mode)
    {
        case ELEModeViewControllerModeCapture:
            return self.captureNavigationController;
            
        case ELEModeViewControllerModeHistory:
            return self.historyNavigationController;
            
        case ELEModeViewControllerModeEquipment:
            return self.equipmentNavigationController;
            
        case ELEModeViewControllerModeWorkOrders:
            return self.workOrdersNavigationController;
            
        case ELEModeViewControllerModeTeam:
            return self.teamNavigationController;
            
        case ELEModeViewControllerModeReports:
            return self.reportsNavigationController;
            
        case ELEModeViewControllerModeHelp:
            return self.helpNavigationController;
            
        case ELEModeViewControllerModeUserAccount:
            return self.userAccountNavigationController;
            
        case ELEModeViewControllerModeSettings:
            return self.settingsNavigationController;
            
        default:
            NSAssert(false, @"invalid controller ID");
            return self.settingsNavigationController;
    }
}

#pragma mark - load and instantiate the view controllers on demand

- (UIViewController *)defaultViewController
{
    return self.captureNavigationController;
}

- (UINavigationController *)captureNavigationController
{
    if (_captureNavigationController == nil) {
        
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"ELECapture_Storyboard" bundle:[NSBundle bundleForClass:[self class]]];
        _captureNavigationController = [storyboard instantiateViewControllerWithIdentifier:@"captureViewNavigationController"];
    }
    return _captureNavigationController;
}

- (UINavigationController *)historyNavigationController
{
    if (_historyNavigationController == nil) {
        ELEHistoryViewController *historyViewController = [[ELEHistoryViewController alloc] initWithNibName:@"ELEDataWithToolsViewController" bundle:[NSBundle bundleForClass:[self class]]];
        _historyNavigationController = [[UINavigationController alloc] initWithRootViewController:historyViewController];
    }
    return _historyNavigationController;
}

- (UINavigationController *)equipmentNavigationController
{
    if (_equipmentNavigationController == nil) {
        ELEEquipmentRootViewController *equipmentRootViewController = [[ELEEquipmentRootViewController alloc] init];
        _equipmentNavigationController = [[UINavigationController alloc] initWithRootViewController:equipmentRootViewController];
    }
    return _equipmentNavigationController;
}

- (UINavigationController *)workOrdersNavigationController
{
    if (_workOrdersNavigationController == nil) {
        ELEWorkOrderTableViewController *workOrdersViewController = [[ELEWorkOrderTableViewController alloc] initWithParentContext:nil];
        _workOrdersNavigationController = [[UINavigationController alloc] initWithRootViewController:workOrdersViewController];
        workOrdersViewController.creationAllowed = YES;
    }
    return _workOrdersNavigationController;
}

- (UINavigationController *)teamNavigationController
{
    if (_teamNavigationController == nil) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"team" bundle:[NSBundle bundleForClass:[self class]]];
        _teamNavigationController = [storyboard instantiateInitialViewController];
    }
    return _teamNavigationController;
}

- (UINavigationController *)reportsNavigationController
{
    if (_reportsNavigationController == nil) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"ReportsStoryboard" bundle:[NSBundle bundleForClass:[self class]]];
        _reportsNavigationController = [storyboard instantiateViewControllerWithIdentifier:@"ReportsNavController"];
    }
    return _reportsNavigationController;
}

- (UINavigationController *)helpNavigationController
{
    if (_helpNavigationController == nil) {
        ELEResourceCenterViewController *helpViewController = [[ELEResourceCenterViewController alloc] initWithNibName:@"ELEResourceCenterViewController" bundle:[NSBundle bundleForClass:[self class]]];
        _helpNavigationController = [[UINavigationController alloc] initWithRootViewController:helpViewController];
    }
    return _helpNavigationController;
}

- (UINavigationController *)settingsNavigationController
{
    if (_settingsNavigationController == nil) {
        _settingsNavigationController = [[UINavigationController alloc] initWithRootViewController:[ELESettingsViewController new]];
    }
    return _settingsNavigationController;
}

- (UINavigationController *)userAccountNavigationController
{
    if (_userAccountNavigationController == nil) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"team" bundle:nil];
        UIViewController* controller = [storyboard instantiateViewControllerWithIdentifier:@"ELEUserAccountWithTeamsViewController"];
        _userAccountNavigationController = [[UINavigationController alloc] initWithRootViewController:controller];
    }
    return _userAccountNavigationController;
}

@end
