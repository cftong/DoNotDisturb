//
//  file: Utilities.h
//  project: DND (shared)
//  description: various helper/utility functions (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#ifndef Utilities_h
#define Utilities_h

@import AVFoundation;

#import <AppKit/AppKit.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/pwr_mgt/IOPM.h>
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

NS_ASSUME_NONNULL_BEGIN

//enum of lid states
typedef NS_ENUM(int, LidState)
{
    stateUnavailable = -1,
    stateOpen = 0,
    stateClosed = 1
};

/* FUNCTIONS */

//get app's version
// extracted from Info.plist
NSString* _Nullable getAppVersion(void);

//get path to (main) app
// login item is in app bundle, so parse up to get main app
NSString* _Nullable getMainAppPath(void);

//get name of logged in user
NSString* _Nullable getConsoleUser(void);

//verify that an app bundle is
// a) signed
// b) signed with signing auth
OSStatus verifyApp(NSString* path, NSString* _Nullable signingAuth);

//get state of lid
int getLidState(void);

//get process name
// either via app bundle, or path
NSString* _Nullable getProcessName(NSString* path);

//given a pid
// get process's path
NSString* _Nullable getProcessPath(pid_t pid);

//given a process path and user
// return array of all matching pids
NSMutableArray* _Nullable getProcessIDs(NSString* _Nullable processPath, int userID);

//wait until a window is non nil
// then make it modal
void makeModal(NSWindowController* windowController);

//check if an instance of an app is already running
BOOL isAppRunning(NSString* bundleID);

//set dir's|file's group/owner
BOOL setFileOwner(NSString* path, NSNumber* groupID, NSNumber* ownerID, BOOL recursive);

//exec a process with args
// if 'shouldWait' is set, wait and return stdout/in and termination status
NSMutableDictionary* _Nullable execTask(NSString* binaryPath, NSArray* arguments, BOOL shouldWait);

//toggle login item
// either add (install) or remove (uninstall)
BOOL toggleLoginItem(NSURL* loginItem, int toggleFlag);

//touchID capable?
BOOL hasTouchID(void);

//get current console user
NSString* _Nullable currentConsoleUser(SCDynamicStoreRef _Nullable store);

//macOS Mojave+
// gotta request camera access
void requestCameraAccess(void);

//check if (true) dark mode
BOOL isDarkMode(void);

NS_ASSUME_NONNULL_END

#endif
