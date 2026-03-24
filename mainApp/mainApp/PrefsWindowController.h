//
//  file: PrefsWindowController.h
//  project: DND (main app)
//  description: preferences window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;

#import "XPCDaemonClient.h"
#import "UpdateWindowController.h"

/* CONSTS */

//general view
#define TOOLBAR_GENERAL 0

//action view
#define TOOLBAR_ACTION 1

//events view
#define TOOLBAR_EVENTS 2

//update view
#define TOOLBAR_UPDATE 3

//ntfy view
#define TOOLBAR_NTFY 4

//tool bar id for 'general'
#define TOOLBAR_GENERAL_ID @"general"

//tool bar id for 'events'
#define TOOLBAR_EVENTS_ID @"events"

//tool bar id for 'ntfy'
#define TOOLBAR_NTFY_ID @"ntfy"

//passive mode button
#define BUTTON_PASSIVE_MODE 1

//no icon mode button
#define BUTTON_NO_ICON_MODE 2

//touch id mode button
#define BUTTON_TOUCHID_MODE 3

//start mode button
#define BUTTON_START_MODE 4

//execute action button
#define BUTTON_EXECUTE_ACTION 5

//monitor button
#define BUTTON_MONITOR_ACTION 6

//no remote tasking button
#define BUTTON_NO_REMOTE_TASKING 7

//no updates button
#define BUTTON_NO_UPDATES_MODE 8

//photo action button
#define BUTTON_PHOTO_ACTION 9

//email action button
#define BUTTON_EMAIL_ACTION 10

//USB monitor button
#define BUTTON_USB_MONITOR 11

//Apple Watch mode button
#define BUTTON_APPLEWATCH_MODE 12

//ntfy action button
#define BUTTON_NTFY_ACTION 13

@interface PrefsWindowController : NSWindowController <NSTextFieldDelegate, NSToolbarDelegate>

/* PROPERTIES */

//daemon comms object
@property (retain, nonatomic)XPCDaemonClient* daemonComms;

//preferences
@property(nonatomic, retain)NSDictionary* preferences;

//toolbar
@property (weak) IBOutlet NSToolbar *toolbar;

//general prefs view
@property (weak) IBOutlet NSView *generalView;

//action view
@property (weak) IBOutlet NSView *actionView;

//execute path
@property (weak) IBOutlet NSTextField *executePath;

//photo action checkbox
@property (weak) IBOutlet NSButton *photoActionBtn;

//email action checkbox
@property (weak) IBOutlet NSButton *emailActionBtn;

//email address field
@property (weak) IBOutlet NSTextField *emailAddress;

/* NTFY VIEW */

//ntfy view (built programmatically)
@property (strong, nonatomic) NSView *ntfyView;

//ntfy action checkbox
@property (strong, nonatomic) NSButton *ntfyActionBtn;

//ntfy server field
@property (strong, nonatomic) NSTextField *ntfyServer;

//ntfy topic field
@property (strong, nonatomic) NSTextField *ntfyTopic;

//ntfy auth type popup
@property (strong, nonatomic) NSPopUpButton *ntfyAuthType;

//ntfy token field
@property (strong, nonatomic) NSTextField *ntfyToken;

//ntfy username field
@property (strong, nonatomic) NSTextField *ntfyUsername;

//ntfy password field
@property (strong, nonatomic) NSSecureTextField *ntfyPassword;

//ntfy token label
@property (strong, nonatomic) NSTextField *ntfyTokenLabel;

//ntfy username label
@property (strong, nonatomic) NSTextField *ntfyUsernameLabel;

//ntfy password label
@property (strong, nonatomic) NSTextField *ntfyPasswordLabel;

/* EVENTS VIEW */

//events view
@property (strong) IBOutlet NSView *eventsView;

//events scroll view
@property (weak) IBOutlet NSScrollView *eventsScrollView;

//no events label
@property (weak) IBOutlet NSTextField *noEventsLabel;

/* UPDATE VIEW */

//update view
@property (weak) IBOutlet NSView *updateView;

//update button
@property (weak) IBOutlet NSButton *updateButton;

//update indicator (spinner)
@property (weak) IBOutlet NSProgressIndicator *updateIndicator;

//update label
@property (weak) IBOutlet NSTextField *updateLabel;

//update window controller
@property(nonatomic, retain)UpdateWindowController* updateWindowController;

/* METHODS */

//toolbar button handler
-(IBAction)toolbarButtonHandler:(id)sender;

//button handler for all preference buttons
-(IBAction)togglePreference:(id)sender;

//show events tab
-(void)showEventsTab;

@end
