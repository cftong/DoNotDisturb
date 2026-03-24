//
//  file: XPCDaemonClient
//  project: DND (shared)
//  description: talk to the daemon, via XPC (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

#import "XPCDaemonProto.h"

NS_ASSUME_NONNULL_BEGIN

@interface XPCDaemonClient : NSObject
{

}

/* PROPERTIES */

//xpc connection
@property (atomic, strong, readwrite, nullable) NSXPCConnection* xpcServiceConnection;

/* METHODS */

//ask daemon for QRC info
// name, uuid, key, key size, etc...
-(void)qrcRequest:(void (^)(NSData* _Nullable qrcInfo))reply;

//wait for phone to complete registration
// calls into framework that comms w/ server to wait for phone
-(void)recvRegistrationACK:(void (^)(NSDictionary* _Nullable registrationInfo))reply;

//get preferences
// note: synchronous
-(NSDictionary* _Nullable)getPreferences:(NSString* _Nullable)preference;

//update (save) preferences (fire-and-forget)
-(void)updatePreferences:(NSDictionary*)preferences;

//update (save) preferences and block until daemon confirms save
// use when the caller may exit immediately after (e.g. windowWillClose:)
-(void)updatePreferencesSync:(NSDictionary*)preferences;

//delete event file
-(void)deleteEventFile:(NSString*)filePath;

@end

NS_ASSUME_NONNULL_END
