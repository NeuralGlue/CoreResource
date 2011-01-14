//
//  CoreTestAppDelegate.h
//  CoreTest
//
//  Created by Mike Laurence on 1/14/10.
//  Copyright Punkbot LLC 2010. All rights reserved.
//

#import "CoreManager.h"

@interface CoreTestAppDelegate : GHUnitIPhoneAppDelegate {
    UIWindow *window;
    UINavigationController *navigationController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navigationController;

@end

