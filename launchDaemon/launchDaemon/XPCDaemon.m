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

//update preferences (fire-and-forget)
-(void)updatePreferences:(NSDictionary *)prefs
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: update preferences (%@)", prefs]);

    //call into prefs obj to update
    if(YES != [preferences update:prefs])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to save preferences to %@", PREFS_FILE]);
    }

    return;
}

//update preferences and reply when done
// caller blocks on the reply so it knows the save completed before it exits
-(void)updatePreferencesSync:(NSDictionary *)prefs reply:(void (^)(void))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: update preferences (sync) (%@)", prefs]);

    //call into prefs obj to update
    if(YES != [preferences update:prefs])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to save preferences to %@", PREFS_FILE]);
    }

    //signal caller that save is complete
    reply();

    return;
}

//delete event file
-(void)deleteEventFile:(NSString*)filePath
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: delete event file (%@)", filePath]);

    //sanity check: ensure path is within the photos directory
    NSString* photosDir = [INSTALL_DIRECTORY stringByAppendingPathComponent:@"photos"];
    if(NO == [filePath hasPrefix:photosDir])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"refusing to delete file outside photos directory: %@", filePath]);
        return;
    }

    //delete file
    NSError* error = nil;
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete event file %@: %@", filePath, error]);
    }

    return;
}

@end
