//
//  file: AppDelegate.h
//  project: DND (main app)
//  description: application delegate (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;

#import "XPCDaemonClient.h"
#import "PrefsWindowController.h"
#import "UpdateWindowController.h"
#import "WelcomeWindowController.h"
#import "3rdParty/HyperlinkTextField.h"

// Forward declaration for Swift class
@class AboutWindowController;

@interface AppDelegate : NSApplication <NSApplicationDelegate>

/* PROPERTIES */

//welcome view controller
@property(nonatomic, retain)WelcomeWindowController* welcomeWindowController;

//about window controller
@property(nonatomic, retain)AboutWindowController* aboutWindowController;

//preferences window controller
@property(nonatomic, retain)PrefsWindowController* prefsWindowController;

/* METHODS */

//start the (helper) login item
-(BOOL)startLoginItem:(BOOL)shouldRestart;

//build/return path to login item
-(NSString*)path2LoginItem;

//register the launch daemon via SMAppService
-(void)registerDaemon;

@end

