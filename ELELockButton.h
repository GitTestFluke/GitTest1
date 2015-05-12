//
//  ELELockButton.h
//  elektra
//
//  Created by Shannon Young on 4/9/15.
//  Copyright (c) 2015 Dogfish Software Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ELELockIcon.h"

@interface ELELockButton : UIButton

@property (weak, nonatomic) IBOutlet ELELockIcon *lockIcon;

@property (nonatomic, getter=isLocked) BOOL locked;

@end
