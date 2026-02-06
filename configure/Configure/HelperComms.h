//
//  file: HelperComms.h
//  project: DND (shared)
//  description: talk to daemon (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

#import "XPCProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface HelperComms : NSObject

//remote deamon proxy object
@property(nonatomic, retain, nullable) id <XPCProtocol> daemon;

//xpc connection
@property (atomic, strong, readwrite, nullable) NSXPCConnection* xpcServiceConnection;

/* METHODS */

//install
// takes flag to indicate full/partial
-(void)install:(void (^)(NSNumber* _Nullable))reply;

//uninstall
// takes flag to indicate full/partial
-(void)uninstall:(BOOL)full reply:(void (^)(NSNumber* _Nullable))reply;

//remove
-(void)remove;

@end

NS_ASSUME_NONNULL_END
