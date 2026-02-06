//
//  file: XPCUser.h
//  project: DND (login item)
//  description: user XPC methods (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

#import "XPCUserProto.h"

NS_ASSUME_NONNULL_BEGIN

@interface XPCUser : NSObject <XPCUserProtocol, NSUserNotificationCenterDelegate>
{

}

@end

NS_ASSUME_NONNULL_END
