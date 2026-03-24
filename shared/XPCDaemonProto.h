//
//  file: XPCDaemonProtocol.h
//  project: DND (shared)
//  description: methods exported by the daemon
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@protocol XPCDaemonProtocol

//process qrc request from client
-(void)qrcRequest:(void (^)(NSData * _Nullable))reply;

//wait for phone to complete registration
// calls into framework that comms w/ server to wait for phone
-(void)recvRegistrationACK:(void (^)(NSDictionary* _Nullable registrationInfo))reply;

//get preferences
-(void)getPreferences:(NSString* _Nullable)preference reply:(void (^)(NSDictionary* _Nullable preferences))reply;

//update preferences (fire-and-forget)
-(void)updatePreferences:(NSDictionary*)preferences;

//update preferences and call reply when saved to disk
// use this when the caller needs to know the save completed (e.g. before app exits)
-(void)updatePreferencesSync:(NSDictionary*)preferences reply:(void (^)(void))reply;

//delete event file
-(void)deleteEventFile:(NSString*)filePath;

@end

NS_ASSUME_NONNULL_END

