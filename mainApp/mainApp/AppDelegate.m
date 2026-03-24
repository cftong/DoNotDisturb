//
//  file: AppDelegate.m
//  project: DND (main app)
//  description: application delegate
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Update.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "Do_Not_Disturb-Swift.h"

@import ServiceManagement;

@implementation AppDelegate

@synthesize aboutWindowController;
@synthesize prefsWindowController;
@synthesize welcomeWindowController;

//center window
// also make front, init title bar, etc
-(void)awakeFromNib
{
    //welcome?
    // kick off phone sync ui logic flow
    if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:CMDLINE_FLAG_WELCOME])
    {
        //alloc
        welcomeWindowController = [[WelcomeWindowController alloc] initWithWindowNibName:@"Welcome"];
        
        //center
        [self.welcomeWindowController.window center];
        
        //key and front
        [self.welcomeWindowController.window makeKeyAndOrderFront:self];
    }
    
    //otherewise show prefs
    else
    {
        //register launch daemon via SMAppService first
        // so daemon is available when the prefs window tries to connect
        [self registerDaemon];

        //show preferences window
        [self showPreferences:nil];

        //center
        [self.prefsWindowController.window center];

        //key and front
        [self.prefsWindowController.window makeKeyAndOrderFront:self];

        //events flag?
        // switch to events tab
        if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:CMDLINE_FLAG_EVENTS])
        {
            [self.prefsWindowController showEventsTab];
        }

        //start login item in background
        // method checks first to make sure only one instance is running
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
           //start
           [self startLoginItem:NO];
        });
    }
    
    //make app active
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//build/return path to login item
-(NSString*)path2LoginItem
{
    //return path
    return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"/Contents/Library/LoginItems/%@.app", LOGIN_ITEM_NAME]];
}

//start the (helper) login item
-(BOOL)startLoginItem:(BOOL)shouldRestart
{
    //status var
    BOOL result = NO;
    
    //path to login item app
    NSString* loginItem = nil;
    
    //path to login item binary
    NSString* loginItemBinary = nil;
    
    //login item's pid
    NSNumber* loginItemPID = nil;
    
    //task results
    NSDictionary* taskResults = nil;
    
    //init path to login item app
    loginItem = [self path2LoginItem];
                 
    //init path to binary
    loginItemBinary = [NSString pathWithComponents:@[loginItem, @"Contents", @"MacOS", LOGIN_ITEM_NAME]];
    
    //get pid(s) of login item for user
    loginItemPID = [getProcessIDs(loginItemBinary, getuid()) firstObject];
        
    //already running and no restart?
    if( (nil != loginItemPID) &&
        (YES != shouldRestart) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"login item already running and 'shouldRestart' not set, so no need to start it");
        
        //happy
        result = YES;
        
        //bail
        goto bail;
    }
    
    //running?
    // kill, as restart flag set
    else if(nil != loginItemPID)
    {
        //kill it
        if(-1 == kill(loginItemPID.intValue, SIGKILL))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to kill login item (%d): %d", loginItemPID.intValue, errno]);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"killed login item (%@)", loginItemPID]);
        
        //nap
        [NSThread sleepForTimeInterval:0.5];
    }
   
    //dbg msg
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"did not find running instance of login item\n");
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"starting login item\n");
    
    //start (helper) login item
    // 'open -g' prevents focus loss
    taskResults = execTask(OPEN, @[@"-g", loginItem], NO);
    if( (nil == taskResults[EXIT_CODE]) ||
        (0 != [taskResults[EXIT_CODE] intValue]) )
    {
        //bail
        goto bail;
    }
    
    //happy
    result = YES;
    
bail:

    return result;
}

//automatically close when user closes last window
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

//'preferences' menu item handler
// alloc and show preferences window
-(IBAction)showPreferences:(id)sender
{
    //alloc prefs window controller
    if(nil == self.prefsWindowController)
    {
        //alloc
        prefsWindowController = [[PrefsWindowController alloc] initWithWindowNibName:@"Preferences"];
    }
    
    //center
    [self.prefsWindowController.window center];

    //show it
    [self.prefsWindowController showWindow:self];
    
    //make it key window
    [[self.prefsWindowController window] makeKeyAndOrderFront:self];
    
    return;
}

//'about' menu item handler
// alloc/show about window
-(IBAction)showAbout:(id)sender
{
    //alloc/init settings window
    if(nil == self.aboutWindowController)
    {
        //alloc/init
        aboutWindowController = [[AboutWindowController alloc] initWithWindowNibName:@"AboutWindow"];
    }
    
    //center window
    [[self.aboutWindowController window] center];
    
    //show it
    [self.aboutWindowController showWindow:self];
    
    //invoke function in background that will make window modal
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //make modal
        makeModal(self.aboutWindowController);
        
    });
    
    return;
}

//register the launch daemon via SMAppService
// the daemon bundle must be at Contents/Library/LaunchDaemons/ inside this app bundle
// if already registered, returns NO with kSMErrorAlreadyRegistered (harmless)
-(void)registerDaemon
{
    //error
    NSError* error = nil;

    //daemon service
    SMAppService* daemonService = nil;

    //init service
    daemonService = [SMAppService daemonServiceWithPlistName:LAUNCH_DAEMON_PLIST];
    if(nil == daemonService)
    {
        //err msg
        logMsg(LOG_ERR, @"registerDaemon: failed to create SMAppService");
        return;
    }

    //register (idempotent; system may prompt user for approval on first call)
    if(![daemonService registerAndReturnError:&error])
    {
        //kSMErrorAlreadyRegistered is harmless
        if(nil != error && kSMErrorAlreadyRegistered == error.code)
        {
            logMsg(LOG_DEBUG, @"registerDaemon: already registered");
        }
        else
        {
            //may require user approval in System Settings (Login Items)
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"registerDaemon: SMAppService register error (may need user approval): %@", error]);
        }
    }
    else
    {
        logMsg(LOG_DEBUG, @"registerDaemon: launch daemon registered via SMAppService");
    }

    //check if daemon needs user approval in System Settings
    if(SMAppServiceStatusRequiresApproval == daemonService.status)
    {
        logMsg(LOG_DEBUG, @"registerDaemon: daemon requires user approval, prompting user");

        //alert user on main thread
        dispatch_async(dispatch_get_main_queue(), ^{

            //alert
            NSAlert* alert = [[NSAlert alloc] init];

            //set message
            alert.messageText = @"Background Service Approval Required";

            //set informative text
            alert.informativeText = @"Do Not Disturb needs its background service to be enabled in System Settings.\n\nPlease enable \"Do Not Disturb\" in:\nSystem Settings → General → Login Items & Extensions";

            //add 'Open System Settings' button
            [alert addButtonWithTitle:@"Open System Settings"];

            //add 'Later' button
            [alert addButtonWithTitle:@"Later"];

            //show alert
            NSModalResponse response = [alert runModal];

            //user wants to open System Settings?
            if(NSAlertFirstButtonReturn == response)
            {
                [SMAppService openSystemSettingsLoginItems];
            }
        });
    }

    return;
}

//paste support
// see: https://stackoverflow.com/a/3176930
- (void) sendEvent:(NSEvent *)event {
    if ([event type] == NSEventTypeKeyDown) {
        if (([event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == NSEventModifierFlagCommand) {
            if ([[event charactersIgnoringModifiers] isEqualToString:@"x"]) {
                if ([self sendAction:@selector(cut:) to:nil from:self])
                    return;
            }
            else if ([[event charactersIgnoringModifiers] isEqualToString:@"c"]) {
                if ([self sendAction:@selector(copy:) to:nil from:self])
                    return;
            }
            else if ([[event charactersIgnoringModifiers] isEqualToString:@"v"]) {
                if ([self sendAction:@selector(paste:) to:nil from:self])
                    return;
            }
    
            else if ([[event charactersIgnoringModifiers] isEqualToString:@"a"]) {
                if ([self sendAction:@selector(selectAll:) to:nil from:self])
                    return;
            }
        }
    }
    [super sendEvent:event];
}

@end
