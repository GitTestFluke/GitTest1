//
//  ELEModeViewController.h
//  elektra
//
//  Created by Jeff Sorrentino on 2/12/13.
//  Copyright (c) 2013 Dogfish Software. All rights reserved.
// reviewed by sunny test

#import <UIKit/UIKit.h>


typedef NS_ENUM(NSInteger, ELEModeViewControllerMode) {
    ELEModeViewControllerModeCapture,
    ELEModeViewControllerModeHistory,
    ELEModeViewControllerModeEquipment,
    ELEModeViewControllerModeWorkOrders,
    ELEModeViewControllerModeTeam,
    ELEModeViewControllerModeReports,
    ELEModeViewControllerModeHelp,
    ELEModeViewControllerModeSettings,
    ELEModeViewControllerModeUserAccount,
    ELEModeViewControllerModeCount,
    ELEModeViewControllerModeDefault = ELEModeViewControllerModeCapture
};

@interface ELEModeViewController : UIViewController

@property (nonatomic, readonly) UIViewController *defaultViewController;
@property (nonatomic, readonly) ELEModeViewControllerMode currentMode;
@property (nonatomic) UINavigationController *captureNavigationController;

- (void) switchToMode:(ELEModeViewControllerMode) mode animated:(BOOL) animated completion:(void (^)(void))completion;
- (UINavigationController*) navigationViewControllerForMode:(ELEModeViewControllerMode) mode;
@end
