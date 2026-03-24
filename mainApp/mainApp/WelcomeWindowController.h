//
//  file: WelcomeWindowController.h
//  project: DND (main app)
//  description: 'welcome' window logic/controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;

#import <objc/message.h>

@interface WelcomeWindowController : NSWindowController

/* PROPERTIES */

//welcome view
@property (strong) IBOutlet NSView *welcomeView;

//welcome view controller
@property(nonatomic, retain)NSViewController* welcomeViewController;

/* METHODS */

@end
