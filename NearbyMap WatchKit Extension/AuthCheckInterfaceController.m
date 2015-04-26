//
//  AuthCheckInterfaceController.m
//  NearbyMap
//
//  Created by Yos Hashimoto on 2015/03/13.
//  Copyright (c) 2015年 Newton Japan. All rights reserved.
//

#import "AuthCheckInterfaceController.h"


@interface AuthCheckInterfaceController()

@end


@implementation AuthCheckInterfaceController

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    
    // Configure interface objects here.
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];

	[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerJob) userInfo:nil repeats:NO];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

- (void)timerJob {
	
	if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
		[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerJob) userInfo:nil repeats:NO];
	}
	else {
		[self popController];
	}
}


@end



