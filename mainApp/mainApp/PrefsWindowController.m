//
//  file: PrefsWindowController.m
//  project: DND (main app)
//  description: preferences window controller
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Update.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "XPCDaemonClient.h"
#import "PrefsWindowController.h"
#import "UpdateWindowController.h"

#import <objc/runtime.h>

//associated object key for file path on buttons
static const void* kFilePathKey = &kFilePathKey;

@implementation PrefsWindowController

@synthesize toolbar;
@synthesize actionView;
@synthesize updateView;
@synthesize daemonComms;
@synthesize executePath;
@synthesize generalView;
@synthesize updateButton;
@synthesize updateWindowController;
@synthesize photoActionBtn;
@synthesize emailActionBtn;
@synthesize emailAddress;
@synthesize eventsView;
@synthesize eventsScrollView;
@synthesize noEventsLabel;

//init 'general' view
// add it, and make it selected
-(void)awakeFromNib
{
    //set title
    self.window.title = [NSString stringWithFormat:@"Do Not Disturb (v. %@)", getAppVersion()];

    //init daemon comms
    daemonComms = [[XPCDaemonClient alloc] init];

    //make 'general' selected
    [self.toolbar setSelectedItemIdentifier:TOOLBAR_GENERAL_ID];

    //set general prefs as default
    [self toolbarButtonHandler:nil];

    //enable touchID mode option
    // if: < 10.13.4 (check first!) && no touch bar
    if( (YES == [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 13, 4}]) &&
        (YES == hasTouchID()) )
    {
        //enable button
        ((NSButton*)[self.generalView viewWithTag:BUTTON_TOUCHID_MODE]).enabled = YES;
    }

    return;
}

//required for toolbar item enable/disable
-(BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
    return [toolbarItem isEnabled] ;
}

//toolbar view handler
// toggle view based on user selection
-(IBAction)toolbarButtonHandler:(id)sender
{
    //view
    NSView* view = nil;

    //height of toolbar
    float toolbarHeight = 0.0f;

    //when we've prev added a view
    // remove the prev view cuz adding a new one
    if(nil != sender)
    {
        //remove
        [[[self.window.contentView subviews] lastObject] removeFromSuperview];
    }

    //get (latest) prefs
    self.preferences = [self.daemonComms getPreferences:nil];

    //get height of toolbar
    toolbarHeight = [self toolbarHeight];

    //assign view
    switch(((NSToolbarItem*)sender).tag)
    {
        //general
        case TOOLBAR_GENERAL:
        {
            //set view
            view = self.generalView;

            //set 'passive mode' button state
            ((NSButton*)[view viewWithTag:BUTTON_PASSIVE_MODE]).state = [self.preferences[PREF_PASSIVE_MODE] boolValue];

            //set 'no icon' button state
            ((NSButton*)[view viewWithTag:BUTTON_NO_ICON_MODE]).state = [self.preferences[PREF_NO_ICON_MODE] boolValue];

            //set 'touch id' button state
            ((NSButton*)[view viewWithTag:BUTTON_TOUCHID_MODE]).state = [self.preferences[PREF_TOUCHID_MODE] boolValue];

            //set 'no remote tasking' button state
            ((NSButton*)[view viewWithTag:BUTTON_NO_REMOTE_TASKING]).state = [self.preferences[PREF_NO_REMOTE_TASKING] boolValue];

            //set 'start mode' button state
            ((NSButton*)[view viewWithTag:BUTTON_START_MODE]).state = [self.preferences[PREF_START_MODE] boolValue];

            break;
        }

        //action
        case TOOLBAR_ACTION:
        {
            //set view
            view = self.actionView;

            //set 'execute action' button state
            ((NSButton*)[view viewWithTag:BUTTON_EXECUTE_ACTION]).state = [self.preferences[PREF_EXECUTE_ACTION] boolValue];

            //set 'execute action'
            if(0 != [self.preferences[PREF_EXECUTE_PATH] length])
            {
                //set
                self.executePath.stringValue = self.preferences[PREF_EXECUTE_PATH];
            }

            //set state of 'execute action' to match
            self.executePath.enabled = [self.preferences[PREF_EXECUTE_ACTION] boolValue];

            //set 'monitor' button state
            ((NSButton*)[view viewWithTag:BUTTON_MONITOR_ACTION]).state = [self.preferences[PREF_MONITOR_ACTION] boolValue];

            //set 'photo action' button state
            ((NSButton*)[view viewWithTag:BUTTON_PHOTO_ACTION]).state = [self.preferences[PREF_PHOTO_ACTION] boolValue];

            //set 'USB monitor' button state
            ((NSButton*)[view viewWithTag:BUTTON_USB_MONITOR]).state = [self.preferences[PREF_USB_MONITOR] boolValue];

            //set 'email action' button state
            ((NSButton*)[view viewWithTag:BUTTON_EMAIL_ACTION]).state = [self.preferences[PREF_EMAIL_ACTION] boolValue];

            //set email address
            if(0 != [self.preferences[PREF_EMAIL_ADDRESS] length])
            {
                //set
                self.emailAddress.stringValue = self.preferences[PREF_EMAIL_ADDRESS];
            }

            //set state of email address field to match email action checkbox
            self.emailAddress.enabled = [self.preferences[PREF_EMAIL_ACTION] boolValue];

            break;
        }

        //events
        case TOOLBAR_EVENTS:
        {
            //set view
            view = self.eventsView;

            //load events
            [self loadEvents];

            break;
        }

        //update
        case TOOLBAR_UPDATE:
        {
            //set view
            view = self.updateView;

            //set 'no update' button state
            ((NSButton*)[view viewWithTag:BUTTON_NO_UPDATES_MODE]).state = [self.preferences[PREF_NO_UPDATES_MODE] boolValue];

            break;
        }

        default:
            return;
    }

    //set frame rect
    view.frame = CGRectMake(0, toolbarHeight, self.window.contentView.frame.size.width, self.window.contentView.frame.size.height-toolbarHeight);

    //add to window
    [self.window.contentView addSubview:view];

    return;
}

//invoked when user toggles button
// update preferences for that button, and possibly perform (immediate) action
-(IBAction)togglePreference:(id)sender
{
    //preferences
    NSMutableDictionary* preferences = nil;

    //button state
    NSNumber* state = nil;

    //init
    preferences = [NSMutableDictionary dictionary];

    //get button state
    state = [NSNumber numberWithBool:((NSButton*)sender).state];

    //set appropriate preference
    switch(((NSButton*)sender).tag)
    {
        //passive mode
        case BUTTON_PASSIVE_MODE:
        {
            //set pref
            preferences[PREF_PASSIVE_MODE] = state;

            break;
        }

        //(no) icon mode
        // login item will be restarted below
        case BUTTON_NO_ICON_MODE:
        {
            //set pref
            preferences[PREF_NO_ICON_MODE] = state;

            break;
        }

        //touch id mode
        case BUTTON_TOUCHID_MODE:
        {
            //set pref
            preferences[PREF_TOUCHID_MODE] = state;

            break;
        }

        //start mode
        // also toggle here...
        case BUTTON_START_MODE:
        {
            //set pref
            preferences[PREF_START_MODE] = state;

            //toggle login item in background
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                //toggle
                if(YES != toggleLoginItem([NSURL fileURLWithPath:[((AppDelegate*)[[NSApplication sharedApplication] delegate]) path2LoginItem]], [preferences[PREF_START_MODE] intValue]))
                {
                    //err msg
                    logMsg(LOG_ERR, @"failed to toggle login item");
                }
            });

            break;
        }

        //execute action
        // also toggle state of path
        case BUTTON_EXECUTE_ACTION:
        {
            //set
            preferences[PREF_EXECUTE_ACTION] = state;

            //set path field state to match
            self.executePath.enabled = state.boolValue;

            break;
        }

        //monitor mode
        case BUTTON_MONITOR_ACTION:
        {
            //set pref
            preferences[PREF_MONITOR_ACTION] = state;

            break;
        }

        //no camera
        case BUTTON_NO_REMOTE_TASKING:
        {
            //set pref
            preferences[PREF_NO_REMOTE_TASKING] = state;

            break;
        }

        //(no) update mode
        case BUTTON_NO_UPDATES_MODE:
        {
            //set pref
            preferences[PREF_NO_UPDATES_MODE] = state;

            break;
        }

        //photo action
        case BUTTON_PHOTO_ACTION:
        {
            //set pref
            preferences[PREF_PHOTO_ACTION] = state;

            break;
        }

        //email action
        // also toggle state of email address field
        case BUTTON_EMAIL_ACTION:
        {
            //set pref
            preferences[PREF_EMAIL_ACTION] = state;

            //set email address field state to match
            self.emailAddress.enabled = state.boolValue;

            break;
        }

        //USB monitor
        case BUTTON_USB_MONITOR:
        {
            //set pref
            preferences[PREF_USB_MONITOR] = state;

            break;
        }
    }

    //tell daemon to update preferences
    [daemonComms updatePreferences:preferences];

    //restart login item if user toggle'd icon state
    // note: this has to be done after the prefs are written out by the daemon
    if(BUTTON_NO_ICON_MODE == ((NSButton*)sender).tag)
    {
        //restart login item
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            //restart
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) startLoginItem:YES];
        });
    }

    return;
}

//automatically called when 'enter' is hit
// save values that were entered in text field
-(void)controlTextDidEndEditing:(NSNotification *)notification
{
    //execute path?
    if([notification object] == self.executePath)
    {
        //send to daemon
        // will update preferences
        [self.daemonComms updatePreferences:@{PREF_EXECUTE_PATH:self.executePath.stringValue, PREF_EXECUTE_USER:getConsoleUser()}];
    }

    //email address?
    else if([notification object] == self.emailAddress)
    {
        //send to daemon
        [self.daemonComms updatePreferences:@{PREF_EMAIL_ADDRESS:self.emailAddress.stringValue}];
    }

    return;
}

//the 'controlTextDidEndEditing' notification might not fire
// so always capture/save the all values from text fields here...
-(void)windowWillClose:(NSNotification *)notification
{
    //prefs to save
    NSMutableDictionary* prefs = nil;

    //init
    prefs = [NSMutableDictionary dictionaryWithDictionary:@{PREF_EXECUTE_PATH:self.executePath.stringValue, PREF_EXECUTE_USER:getConsoleUser()}];

    //add email address if field exists
    if(nil != self.emailAddress)
    {
        prefs[PREF_EMAIL_ADDRESS] = self.emailAddress.stringValue;
    }

    //send to daemon
    // will update preferences
    [self.daemonComms updatePreferences:prefs];

    return;
}

//'check for update' button handler
-(IBAction)check4Update:(id)sender
{
    //update obj
    Update* update = nil;

    //disable button
    self.updateButton.enabled = NO;

    //reset
    self.updateLabel.stringValue = @"";

    //show/start spinner
    [self.updateIndicator startAnimation:self];

    //init update obj
    update = [[Update alloc] init];

    //check for update
    // 'updateResponse newVersion:' method will be called when check is done
    [update checkForUpdate:^(NSUInteger result, NSString* newVersion) {

        //process response
        [self updateResponse:result newVersion:newVersion];

    }];

    return;
}

//process update response
// error, no update, update/new version
-(void)updateResponse:(NSInteger)result newVersion:(NSString*)newVersion
{
    //re-enable button
    self.updateButton.enabled = YES;

    //stop/hide spinner
    [self.updateIndicator stopAnimation:self];

    switch (result)
    {
        //error
        case -1:

            //set label
            self.updateLabel.stringValue = @"error: update check failed";

            break;

        //no updates
        case 0:

            //dbg msg
            logMsg(LOG_DEBUG, @"no updates available");

            //set label
            self.updateLabel.stringValue = @"no new versions";

            break;

        //new version
        case 1:

            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"a new version (%@) is available", newVersion]);

            //alloc update window
            updateWindowController = [[UpdateWindowController alloc] initWithWindowNibName:@"UpdateWindow"];

            //configure
            [self.updateWindowController configure:[NSString stringWithFormat:@"a new version (%@) is available!", newVersion] buttonTitle:@"Update"];

            //center window
            [[self.updateWindowController window] center];

            //show it
            [self.updateWindowController showWindow:self];

            //invoke function in background that will make window modal
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

                //make modal
                makeModal(self.updateWindowController);

            });

            break;
    }

    return;
}

//load captured events (photos) into the events scroll view
-(void)loadEvents
{
    //photos directory
    NSString* photosDir = nil;

    //file manager
    NSFileManager* fileManager = nil;

    //photo files
    NSArray* photoFiles = nil;

    //document view
    NSView* documentView = nil;

    //row height
    CGFloat rowHeight = 90.0;

    //y offset for rows
    CGFloat yOffset = 0.0;

    //init
    fileManager = [NSFileManager defaultManager];

    //set photos path
    photosDir = [INSTALL_DIRECTORY stringByAppendingPathComponent:@"photos"];

    //grab document view
    documentView = self.eventsScrollView.documentView;

    //clear existing subviews
    for(NSView* subview in [documentView.subviews copy])
    {
        [subview removeFromSuperview];
    }

    //get photo files
    photoFiles = [fileManager contentsOfDirectoryAtPath:photosDir error:nil];

    //filter to jpg files only
    photoFiles = [photoFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.jpg'"]];

    //sort descending (newest first)
    photoFiles = [photoFiles sortedArrayUsingComparator:^NSComparisonResult(NSString* a, NSString* b) {
        return [b compare:a];
    }];

    //no photos?
    if(0 == photoFiles.count)
    {
        //show 'no events' label
        self.noEventsLabel.hidden = NO;

        //set document view frame to zero height
        [documentView setFrame:NSMakeRect(0, 0, self.eventsScrollView.contentSize.width, 0)];

        return;
    }

    //hide 'no events' label
    self.noEventsLabel.hidden = YES;

    //iterate over photo files
    for(NSString* photoFile in photoFiles)
    {
        //full path
        NSString* fullPath = [photosDir stringByAppendingPathComponent:photoFile];

        //row view
        NSView* rowView = [[NSView alloc] initWithFrame:NSMakeRect(0, yOffset, documentView.frame.size.width, rowHeight)];
        rowView.autoresizingMask = NSViewWidthSizable;

        //load image
        NSImage* image = [[NSImage alloc] initWithContentsOfFile:fullPath];

        //clickable thumbnail button (instead of plain image view)
        NSButton* thumbButton = [[NSButton alloc] initWithFrame:NSMakeRect(10, 15, 80, 60)];
        [thumbButton setButtonType:NSButtonTypeMomentaryChange];
        [thumbButton setBordered:NO];
        [thumbButton setImage:image];
        [thumbButton setImageScaling:NSImageScaleProportionallyUpOrDown];
        [thumbButton setAction:@selector(openEvent:)];
        [thumbButton setTarget:self];

        //associate file path with button
        objc_setAssociatedObject(thumbButton, kFilePathKey, fullPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        //add thumbnail to row
        [rowView addSubview:thumbButton];

        //parse timestamp from filename (photo_YYYYMMDD_HHmmss.jpg or photo_YYYYMMDD_HHmmss_type.jpg)
        NSString* timestamp = @"";
        NSString* eventType = @"lid";

        //strip prefix and extension to get the variable part
        NSString* baseName = [[photoFile stringByDeletingPathExtension] substringFromIndex:6]; // strip "photo_"

        //split by underscore
        NSArray* parts = [baseName componentsSeparatedByString:@"_"];

        //parse timestamp parts
        if(parts.count >= 2)
        {
            NSString* datePart = parts[0]; // YYYYMMDD
            NSString* timePart = parts[1]; // HHmmss

            if(datePart.length == 8 && timePart.length == 6)
            {
                //format as readable timestamp
                timestamp = [NSString stringWithFormat:@"%@-%@-%@ %@:%@:%@",
                    [datePart substringWithRange:NSMakeRange(0, 4)],
                    [datePart substringWithRange:NSMakeRange(4, 2)],
                    [datePart substringWithRange:NSMakeRange(6, 2)],
                    [timePart substringWithRange:NSMakeRange(0, 2)],
                    [timePart substringWithRange:NSMakeRange(2, 2)],
                    [timePart substringWithRange:NSMakeRange(4, 2)]];
            }

            //third part is event type (if present)
            if(parts.count >= 3)
            {
                eventType = parts[2];
            }
        }

        //map event type to display string
        NSString* eventTypeDisplay = @"Lid Open";
        if([eventType isEqualToString:@"usb"])
        {
            eventTypeDisplay = @"USB Insertion";
        }

        //timestamp label
        NSTextField* label = [[NSTextField alloc] initWithFrame:NSMakeRect(100, 40, 200, 24)];
        label.stringValue = timestamp;
        label.font = [NSFont systemFontOfSize:14.0];
        label.editable = NO;
        label.bordered = NO;
        label.drawsBackground = NO;
        [rowView addSubview:label];

        //event type label
        NSTextField* typeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(100, 18, 200, 20)];
        typeLabel.stringValue = eventTypeDisplay;
        typeLabel.font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightMedium];
        typeLabel.editable = NO;
        typeLabel.bordered = NO;
        typeLabel.drawsBackground = NO;
        typeLabel.textColor = [NSColor secondaryLabelColor];
        [rowView addSubview:typeLabel];

        //delete button
        NSButton* deleteButton = [[NSButton alloc] initWithFrame:NSMakeRect(rowView.frame.size.width - 90, 30, 70, 24)];
        deleteButton.title = @"Delete";
        deleteButton.bezelStyle = NSBezelStyleRounded;
        deleteButton.font = [NSFont systemFontOfSize:11.0];
        deleteButton.autoresizingMask = NSViewMinXMargin;
        [deleteButton setAction:@selector(deleteEvent:)];
        [deleteButton setTarget:self];

        //associate file path with delete button
        objc_setAssociatedObject(deleteButton, kFilePathKey, fullPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        //add delete button to row
        [rowView addSubview:deleteButton];

        //add row to document view
        [documentView addSubview:rowView];

        //bump y offset
        yOffset += rowHeight;
    }

    //set document view frame height
    [documentView setFrame:NSMakeRect(0, 0, self.eventsScrollView.contentSize.width, yOffset)];

    return;
}

//handle click on thumbnail -- open image in default viewer
-(void)openEvent:(id)sender
{
    //get file path
    NSString* filePath = objc_getAssociatedObject(sender, kFilePathKey);

    //open
    if(nil != filePath)
    {
        [[NSWorkspace sharedWorkspace] openFile:filePath];
    }

    return;
}

//handle delete button -- remove photo file and refresh
-(void)deleteEvent:(id)sender
{
    //get file path
    NSString* filePath = objc_getAssociatedObject(sender, kFilePathKey);

    //delete file via daemon (requires elevated permissions)
    if(nil != filePath)
    {
        [self.daemonComms deleteEventFile:filePath];
    }

    //refresh events view
    [self loadEvents];

    return;
}


//get height of toolbar
// based on: https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Toolbars/Tasks/DeterminingOverflow.html#//apple_ref/doc/uid/20000859-SW2
-(float)toolbarHeight
{
    //height
    float toolbarHeight = 0.0;

    //toolbar
    NSToolbar *toolbar = nil;

    //frame
    NSRect windowFrame;

    //get toolbard
    toolbar = [self.window toolbar];

    //toolbar not found or not visible?
    if( (nil == toolbar) ||
        (YES != toolbar.isVisible) )
    {
        //bail
        goto bail;
    }

    //get window frame
    windowFrame = [NSWindow contentRectForFrameRect:[self.window frame] styleMask:[self.window styleMask]];

    //calc height
    toolbarHeight = NSHeight(windowFrame) - NSHeight([[self.window contentView] frame]);

bail:

    return toolbarHeight;
}

@end
