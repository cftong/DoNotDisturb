//
//  file: XPCDaemon.m
//  project: DND (launch daemon)
//  description: interface for user XPC methods
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "XPCDaemon.h"
#import "Preferences.h"

//global prefs obj
extern Preferences* preferences;

@implementation XPCDaemon

//init
// set connection to unknown
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        
    }
    
    return self;
}

//XPC method
// returns preferences to client
-(void)getPreferences:(NSString*)preference reply:(void (^)(NSDictionary* preferences))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: get preferences (pref: %@)", preference]);
    
    //get current prefs
    reply([preferences get:preference]);
    
    return;
}

//XPC method
// returns QRC data to client (stubbed - server framework removed)
-(void)qrcRequest:(void (^)(NSData *))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: qrc request (stubbed)");

    reply(nil);

    return;
}

//XPC method:
// wait for phone to complete registrations (stubbed - server framework removed)
-(void)recvRegistrationACK:(void (^)(NSDictionary* registrationInfo))reply;
{
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: recv registration ack/info (stubbed)");

    reply(nil);

    return;
}

//update preferences
-(void)updatePreferences:(NSDictionary *)prefs
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: update preferences (%@)", preferences]);
    
    //call into prefs obj to update
    if(YES != [preferences update:prefs])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to save preferences to %@", PREFS_FILE]);
    }
    
    return;
}

@end
