//
//  file: Configure.h
//  project: DND (config)
//  description: configure DND, install/uninstall (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface Configure : NSObject
{

}

/* METHODS */

//determine if extension is installed
-(BOOL)isInstalled;

//invokes appropriate install || uninstall logic
-(BOOL)configure:(NSInteger)parameter;

//install
-(BOOL)install;

//uninstall
-(BOOL)uninstall:(BOOL)full;

//no-op: kept for AppDelegate.m compatibility
-(void)removeHelper;

@end

NS_ASSUME_NONNULL_END
