//
//  ViewController.m
//  cine
//
//  Created by Nikhil Khanna on 2/21/15.
//  Copyright (c) 2015 TreeHacks. All rights reserved.
//

#import "ViewController.h"
#import <AFNetworking/AFNetworking.h>
#import <PubNub/PubNub.h>
#import <PubNub/PNConfiguration.h>
#import <PubNub/PNChannel.h>
#import <PubNub/PNObservationCenter.h>
#import <PubNub/PNMessage.h>
#import "PNImports.h"
#import "PNMessage+Protected.h"
#import "PubNub+Protected.h"

#define pauseMessage @" ** Toggled Pause **"

//theirs
//10.19.190.142
//justin

//ours
//10.19.186.162
//john

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *textField;

@property PNChannel* currentChannel;
@property BOOL paused;
@property int previousOffset;
@property int UID;
@property NSString* ipAddress;
@property NSDate* lastPauseTime;
@property NSString* userName;
@property NSString* currentShowID;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.ipAddress = @"10.19.186.162";
    self.userName = @"Nikhil";
    self.paused = false;
    self.previousOffset = -1;
    self.UID = arc4random_uniform(NSIntegerMax);
    self.lastPauseTime = [NSDate date];
    [self clearChatMessage];
    
    [PubNub setDelegate:self];
    PNConfiguration* config = [PNConfiguration configurationForOrigin:@"pubsub.pubnub.com" publishKey:@"pub-c-801f07a5-e818-4617-9a92-6618a320091d" subscribeKey:@"sub-c-a2c74070-b9b3-11e4-bdc7-02ee2ddab7fe" secretKey:@"sec-c-OTZlYWEyYjItYTE5ZC00MmNjLWIwNmYtZWQ3MTdhMTU2MDA5"];
    [PubNub setConfiguration:config];
    [PubNub connect];
    
    PNChannel* channel = [PNChannel channelWithName:@"a" shouldObservePresence:YES];

    
    /**PubNub obersvation calls*/
    [[PNObservationCenter defaultCenter] addClientConnectionStateObserver:self withCallbackBlock:^(NSString *origin, BOOL connected, PNError *connectionError){
        if (connected)
        {
            NSLog(@"OBSERVER: Successful Connection!");
            
            [PubNub subscribeOn:@[channel]];
            self.currentChannel  = channel;
            // #2 Subscribe if client connects successfully
        }
        else if (!connected || connectionError)
        {
            NSLog(@"OBSERVER: Error, Connection Failed!");
        }
    }];
    
}

/**PubNub delegate methods*/
// #1 Delegate looks for subscribe events
- (void)pubnubClient:(PubNub *)client didSubscribeOnChannels:(NSArray *)channels {
    NSLog(@"DELEGATE: Subscribed to channel:%@", channels);
    self.currentChannel = channels[0];
    NSTimer* myTimer = [NSTimer scheduledTimerWithTimeInterval: 5 target: self
                                                      selector: @selector(queryPaused:) userInfo: nil repeats: YES];
    
}
// #2 Delegate looks for message receive events
- (void)pubnubClient:(PubNub *)client didReceiveMessage:(PNMessage *)message {
    NSLog(@"DELEGATE: Message received. %@", [NSString stringWithFormat:@"%@", message.message]);
    NSDictionary* messageDict = message.message;
    
    if(message.message[@"msg"] != nil) {
        NSString* paramURL = [NSString stringWithFormat:@"http://nikhilkhanna.github.io/?chat=%@&name=%@", message.message[@"msg"], self.userName];
        NSLog(@"paramurl: %@", paramURL);
        paramURL = [self urlencode:paramURL];
        //NSLog(@"%@", paramURL);
        
        NSString* reqURL = [NSString stringWithFormat:@"http://%@:8080/itv/startURL?url=%@", self.ipAddress, paramURL];
        //NSLog(reqURL);
        
        AFHTTPRequestOperationManager* manager = [AFHTTPRequestOperationManager manager];
        [manager GET:reqURL parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
            NSLog(@"chatRecieved");
            [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(clearChatMessage) userInfo:nil repeats:NO];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"chatFailed");
        }];
    }
    
    if([messageDict[@"msg"] isEqualToString:pauseMessage] && ![[NSNumber numberWithInt:self.UID] isEqualToNumber:messageDict[@"id"]]) {
        [self goToOffset:messageDict[@"offset"]];
        [self pauseTV];
    }
}

- (void)goToOffset:(NSNumber*) offset {
    int correctionAmount = 2;
    NSNumber* correctedOffset = [NSNumber numberWithInt:[offset intValue]-correctionAmount];
    NSString* url = [NSString stringWithFormat:@"http://%@:8080/dvr/play?uniqueId=%@&playFrom=offset&offset=%@", self.ipAddress, self.currentShowID, offset];
    AFHTTPRequestOperationManager* manager = [AFHTTPRequestOperationManager manager];
    [manager GET:url parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"jumpedToOffset");
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"failed");
    }];
}

/**pubnub delegate methods*/
- (void)pubnubClient:(PubNub *)client didConnectToOrigin:(NSString *)origin {
    NSLog(@"DELEGATE: Connected to  origin: %@", origin);
}

-(IBAction)sendMessage:(id)sender {
    [self sendChatMessage:self.textField.text];
}

-(void)tellOthersToTogglePause:(int)offset {
    NSDictionary* messageDict = @{@"id": [NSNumber numberWithInt:self.UID], @"msg": pauseMessage, @"offset": [NSNumber numberWithInt:offset]};
    [PubNub sendMessage:messageDict toChannel:self.currentChannel compressed:NO withCompletionBlock:^(PNMessageState state, id data) {
        if(state == PNMessageSent) {
            NSLog(@"OBSERVER: Sent Message!");
            
        } else {
            NSLog(@"Failed to send message");
        }
    }];
}

-(void)pauseTV {
    AFHTTPRequestOperationManager* manager = [AFHTTPRequestOperationManager manager];
    NSString* url = [NSString stringWithFormat:@"http://%@:8080/remote/processKey?key=pause", self.ipAddress];
    self.lastPauseTime = [NSDate date];
    [manager GET:url parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"suceeded");
        self.paused = !self.paused;
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"failed");
    }];
}

-(void)queryPaused:(NSTimer *)timer {
    AFHTTPRequestOperationManager* manager = [AFHTTPRequestOperationManager manager];
    NSString* url = [NSString stringWithFormat:@"http://%@:8080/tv/getTuned?", self.ipAddress];
    [manager GET:url parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary* res = responseObject;
        NSString* offsetString = res[@"offset"];
        self.currentShowID = res[@"uniqueId"];
        int offset = [offsetString intValue];
        
        if(-([self.lastPauseTime timeIntervalSinceNow]) > 4) {
            
            //client just paused after ahving it be resumed
            if(offset == self.previousOffset && !self.paused) {
                self.lastPauseTime = [NSDate date];
                self.paused = true;
                [self tellOthersToTogglePause:offset];
            }
            
            //client just resumed after having it be paused
            if(offset != self.previousOffset && self.paused) {
                self.lastPauseTime = [NSDate date];
                self.paused = false;
                [self tellOthersToTogglePause:offset];
            }
        }
        
        self.previousOffset = offset;
        NSLog(@"%d", offset);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"failed");
    }];
}

-(void)getMovieInfo:(NSTimer *) timer {
    AFHTTPRequestOperationManager* manager = [AFHTTPRequestOperationManager manager];
    NSString* url = [NSString stringWithFormat:@"http://%@:8080/tv/getTuned?", self.ipAddress];
    [manager GET:url parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary* res = responseObject;
        NSString* offset = res[@"offset"];
        NSString* duration = res[@"duration"];
        NSString* title = res[@"title"];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"failed");
    }];
}

- (NSString *)urlencode:(NSString*) stringToEncode {
    NSString *encodedString = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
                                                                                  NULL,
                                                                                  (CFStringRef)stringToEncode,
                                                                                  NULL,
                                                                                  (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                  kCFStringEncodingUTF8 ));
//    return encodedString;
    //NSString *escapedString = [stringToEncode stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
    return encodedString;
}

- (void)sendChatMessage:(NSString *)message {
    NSString* realmessage = [NSString stringWithFormat:@"%@", message];
    NSDictionary* messageDict = @{@"id": [NSNumber numberWithInt:self.UID], @"msg": realmessage};
    [PubNub sendMessage:messageDict toChannel:self.currentChannel compressed:NO withCompletionBlock:^(PNMessageState state, id data) {
        if(state == PNMessageSent) {
            NSLog(@"OBSERVER: Sent Message!");
            
        } else {
            NSLog(@"Failed to send message");
        }
    }];
}

- (void)clearChatMessage {
    NSString* url = [NSString stringWithFormat:@"http://%@:8080/itv/stopITV", self.ipAddress];
    AFHTTPRequestOperationManager* manager = [AFHTTPRequestOperationManager manager];
    [manager GET:url parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"clearedchat");
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"failedtoclear");
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
