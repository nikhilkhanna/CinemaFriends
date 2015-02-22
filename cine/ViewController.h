//
//  ViewController.h
//  cine
//
//  Created by Nikhil Khanna on 2/21/15.
//  Copyright (c) 2015 TreeHacks. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <PubNub/PubNub.h>
@interface ViewController : UIViewController <PNDelegate>

-(IBAction)sendMessage:(id)sender;

@end

