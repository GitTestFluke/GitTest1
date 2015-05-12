//
//  ELELockButton.m
//  elektra
//
//  Created by Shannon Young on 4/9/15.
//  Copyright (c) 2015 Dogfish Software Corporation. All rights reserved.
//

#import "ELELockButton.h"

@implementation ELELockButton


- (void)setLocked:(BOOL)locked {
    [self willChangeValueForKey: @"locked"];
    _locked = locked;
    self.lockIcon.locked = locked;
    if (self.lockIcon == nil) {
        // If there isn't a lock icon then change alpha
        self.alpha = locked ? 0.3 : 1.0;
        [self setNeedsDisplay];
    }
    [self didChangeValueForKey:@"locked"];
}

- (NSString *)accessibilityValue {
    return [self.lockIcon accessibilityLabel];
}

@end
