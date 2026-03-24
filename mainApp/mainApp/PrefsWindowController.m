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
@synthesize ntfyView;
@synthesize ntfyActionBtn;
@synthesize ntfyServer;
@synthesize ntfyTopic;
@synthesize ntfyAuthType;
@synthesize ntfyToken;
@synthesize ntfyUsername;
@synthesize ntfyPassword;
@synthesize ntfyTokenLabel;
@synthesize ntfyUsernameLabel;
@synthesize ntfyPasswordLabel;

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

    //enable Apple Watch mode option (macOS 10.12+)
    if([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 12, 0}])
    {
        //enable button
        ((NSButton*)[self.generalView viewWithTag:BUTTON_APPLEWATCH_MODE]).enabled = YES;
    }

    return;
}

//required for toolbar item enable/disable
-(BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
    return [toolbarItem isEnabled] ;
}

//show events tab programmatically
-(void)showEventsTab
{
    //select events in toolbar
    [self.toolbar setSelectedItemIdentifier:TOOLBAR_EVENTS_ID];

    //find and invoke the events toolbar item
    for(NSToolbarItem* item in self.toolbar.items)
    {
        if([item.itemIdentifier isEqualToString:TOOLBAR_EVENTS_ID])
        {
            [self toolbarButtonHandler:item];
            break;
        }
    }
}

//toolbar view handler
// toggle view based on user selection
// shows the view immediately, then fetches prefs from daemon in background
-(IBAction)toolbarButtonHandler:(id)sender
{
    //view
    NSView* view = nil;

    //height of toolbar
    float toolbarHeight = 0.0f;

    //current toolbar tag
    NSInteger currentTag = ((NSToolbarItem*)sender).tag;

    //when we've prev added a view
    // remove the prev view cuz adding a new one
    if(nil != sender)
    {
        //remove
        [[[self.window.contentView subviews] lastObject] removeFromSuperview];
    }

    //get height of toolbar
    toolbarHeight = [self toolbarHeight];

    //determine which view to show
    switch(currentTag)
    {
        case TOOLBAR_GENERAL:
            view = self.generalView;
            break;

        case TOOLBAR_ACTION:
            view = self.actionView;
            break;

        case TOOLBAR_EVENTS:
            view = self.eventsView;
            //load events (local file system, not XPC — no blocking)
            [self loadEvents];
            break;

        case TOOLBAR_UPDATE:
            view = self.updateView;
            break;

        case TOOLBAR_NTFY:
            //build view lazily
            if(nil == self.ntfyView)
            {
                [self buildNtfyView];
            }
            view = self.ntfyView;
            break;

        default:
            return;
    }

    //set frame rect
    view.frame = CGRectMake(0, toolbarHeight, self.window.contentView.frame.size.width, self.window.contentView.frame.size.height-toolbarHeight);

    //add to window (show immediately, prefs will be applied async)
    [self.window.contentView addSubview:view];

    //fetch preferences from daemon in background, then apply to UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        //get (latest) prefs from daemon (may block briefly if daemon is slow or unavailable)
        NSDictionary* prefs = [self.daemonComms getPreferences:nil];

        //failed?
        if(nil == prefs)
        {
            logMsg(LOG_ERR, @"failed to get preferences from daemon — daemon may not be running");
            return;
        }

        //apply prefs to UI on main thread
        dispatch_async(dispatch_get_main_queue(), ^{

            //save
            self.preferences = prefs;

            //apply to current view
            [self applyPreferencesToView:currentTag];
        });
    });

    return;
}

//apply loaded preferences to the UI controls for the given toolbar tab
// must be called on main thread
-(void)applyPreferencesToView:(NSInteger)toolbarTag
{
    switch(toolbarTag)
    {
        //general
        case TOOLBAR_GENERAL:
        {
            NSView* view = self.generalView;

            //set 'passive mode' button state
            ((NSButton*)[view viewWithTag:BUTTON_PASSIVE_MODE]).state = [self.preferences[PREF_PASSIVE_MODE] boolValue];

            //set 'no icon' button state
            ((NSButton*)[view viewWithTag:BUTTON_NO_ICON_MODE]).state = [self.preferences[PREF_NO_ICON_MODE] boolValue];

            //set 'touch id' button state
            ((NSButton*)[view viewWithTag:BUTTON_TOUCHID_MODE]).state = [self.preferences[PREF_TOUCHID_MODE] boolValue];

            //set 'Apple Watch' button state
            ((NSButton*)[view viewWithTag:BUTTON_APPLEWATCH_MODE]).state = [self.preferences[PREF_APPLEWATCH_MODE] boolValue];

            //set 'no remote tasking' button state
            ((NSButton*)[view viewWithTag:BUTTON_NO_REMOTE_TASKING]).state = [self.preferences[PREF_NO_REMOTE_TASKING] boolValue];

            //set 'start mode' button state
            ((NSButton*)[view viewWithTag:BUTTON_START_MODE]).state = [self.preferences[PREF_START_MODE] boolValue];

            break;
        }

        //action
        case TOOLBAR_ACTION:
        {
            NSView* view = self.actionView;

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

        //update
        case TOOLBAR_UPDATE:
        {
            NSView* view = self.updateView;

            //set 'no update' button state
            ((NSButton*)[view viewWithTag:BUTTON_NO_UPDATES_MODE]).state = [self.preferences[PREF_NO_UPDATES_MODE] boolValue];

            break;
        }

        //ntfy
        case TOOLBAR_NTFY:
        {
            //set 'ntfy action' checkbox state
            self.ntfyActionBtn.state = [self.preferences[PREF_NTFY_ACTION] boolValue];

            //set server field
            if(0 != [self.preferences[PREF_NTFY_SERVER] length])
            {
                self.ntfyServer.stringValue = self.preferences[PREF_NTFY_SERVER];
            }

            //set topic field
            if(0 != [self.preferences[PREF_NTFY_TOPIC] length])
            {
                self.ntfyTopic.stringValue = self.preferences[PREF_NTFY_TOPIC];
            }

            //set auth type popup
            NSInteger authType = [self.preferences[PREF_NTFY_AUTH_TYPE] integerValue];
            [self.ntfyAuthType selectItemAtIndex:authType];
            [self updateNtfyAuthFields:authType];

            //set token field
            if(0 != [self.preferences[PREF_NTFY_TOKEN] length])
            {
                self.ntfyToken.stringValue = self.preferences[PREF_NTFY_TOKEN];
            }

            //set username field
            if(0 != [self.preferences[PREF_NTFY_USERNAME] length])
            {
                self.ntfyUsername.stringValue = self.preferences[PREF_NTFY_USERNAME];
            }

            //set password field
            if(0 != [self.preferences[PREF_NTFY_PASSWORD] length])
            {
                self.ntfyPassword.stringValue = self.preferences[PREF_NTFY_PASSWORD];
            }

            //enable/disable server, topic, and auth popup based on checkbox state
            BOOL ntfyEnabled = [self.preferences[PREF_NTFY_ACTION] boolValue];
            self.ntfyServer.enabled = ntfyEnabled;
            self.ntfyTopic.enabled = ntfyEnabled;
            self.ntfyAuthType.enabled = ntfyEnabled;

            //enable/disable auth-specific fields and sync label colors
            [self updateNtfyAuthFields:authType];

            break;
        }

        default:
            break;
    }
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

        //Apple Watch mode
        case BUTTON_APPLEWATCH_MODE:
        {
            //set pref
            preferences[PREF_APPLEWATCH_MODE] = state;

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

        //ntfy action
        // also toggle state of all ntfy fields
        case BUTTON_NTFY_ACTION:
        {
            //set pref
            preferences[PREF_NTFY_ACTION] = state;

            //enable/disable server, topic, and auth popup directly
            BOOL ntfyEnabled = state.boolValue;
            self.ntfyServer.enabled = ntfyEnabled;
            self.ntfyTopic.enabled = ntfyEnabled;
            self.ntfyAuthType.enabled = ntfyEnabled;

            //delegate auth-specific field enable/colors to shared helper
            // reads ntfyActionBtn.state which was already updated by the button toggle
            [self updateNtfyAuthFields:[self.ntfyAuthType indexOfSelectedItem]];

            break;
        }
    }

    //capture sender tag before going off main thread
    NSInteger senderTag = ((NSButton*)sender).tag;

    //send preference update to daemon in background (avoids blocking main thread)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"sending preference update to daemon: %@", preferences]);

        //tell daemon to update preferences
        [daemonComms updatePreferencesSync:preferences];

        //dbg msg
        logMsg(LOG_DEBUG, @"preference update sent to daemon (sync call returned)");

        //restart login item if user toggle'd icon state
        // note: this has to be done after the prefs are written out by the daemon
        if(BUTTON_NO_ICON_MODE == senderTag)
        {
            //restart
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) startLoginItem:YES];
        }
    });

    return;
}

//automatically called when 'enter' is hit or field loses focus
// save values that were entered in text field
// sends async to avoid blocking main thread; windowWillClose: does a final sync save
-(void)controlTextDidEndEditing:(NSNotification *)notification
{
    //prefs to save
    NSDictionary* prefs = nil;

    //execute path?
    if([notification object] == self.executePath)
    {
        prefs = @{PREF_EXECUTE_PATH:self.executePath.stringValue, PREF_EXECUTE_USER:getConsoleUser()};
    }

    //email address?
    else if([notification object] == self.emailAddress)
    {
        prefs = @{PREF_EMAIL_ADDRESS:self.emailAddress.stringValue};
    }

    //ntfy server?
    else if([notification object] == self.ntfyServer)
    {
        prefs = @{PREF_NTFY_SERVER:self.ntfyServer.stringValue};
    }

    //ntfy topic?
    else if([notification object] == self.ntfyTopic)
    {
        prefs = @{PREF_NTFY_TOPIC:self.ntfyTopic.stringValue};
    }

    //ntfy token?
    else if([notification object] == self.ntfyToken)
    {
        prefs = @{PREF_NTFY_TOKEN:self.ntfyToken.stringValue};
    }

    //ntfy username?
    else if([notification object] == self.ntfyUsername)
    {
        prefs = @{PREF_NTFY_USERNAME:self.ntfyUsername.stringValue};
    }

    //ntfy password?
    else if([notification object] == self.ntfyPassword)
    {
        prefs = @{PREF_NTFY_PASSWORD:self.ntfyPassword.stringValue};
    }

    //send to daemon in background if we have something to save
    if(nil != prefs)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.daemonComms updatePreferences:prefs];
        });
    }

    return;
}

//the 'controlTextDidEndEditing' notification might not fire
// if a text field is first responder when the window closes;
// force end editing first so delegate fires, then batch-save all field values
-(void)windowWillClose:(NSNotification *)notification
{
    //prefs to save
    NSMutableDictionary* prefs = nil;

    //force any active text field to commit its value
    // this triggers controlTextDidEndEditing: for the active field synchronously
    [self.window endEditingFor:nil];

    //init with execute path fields (always present via IBOutlet)
    // guard against nil/empty to avoid overwriting a previously saved path with ""
    prefs = [NSMutableDictionary dictionary];
    if(nil != self.executePath && 0 != self.executePath.stringValue.length)
    {
        prefs[PREF_EXECUTE_PATH] = self.executePath.stringValue;
        prefs[PREF_EXECUTE_USER] = getConsoleUser();
    }

    //add email address if non-empty
    if(nil != self.emailAddress && 0 != self.emailAddress.stringValue.length)
    {
        prefs[PREF_EMAIL_ADDRESS] = self.emailAddress.stringValue;
    }

    //add ntfy fields only if the ntfy view was built and the value is non-empty
    // (guards against overwriting saved prefs when the tab was never visited)
    if(nil != self.ntfyServer && 0 != self.ntfyServer.stringValue.length)
    {
        prefs[PREF_NTFY_SERVER] = self.ntfyServer.stringValue;
    }
    if(nil != self.ntfyTopic && 0 != self.ntfyTopic.stringValue.length)
    {
        prefs[PREF_NTFY_TOPIC] = self.ntfyTopic.stringValue;
    }
    if(nil != self.ntfyToken && 0 != self.ntfyToken.stringValue.length)
    {
        prefs[PREF_NTFY_TOKEN] = self.ntfyToken.stringValue;
    }
    if(nil != self.ntfyUsername && 0 != self.ntfyUsername.stringValue.length)
    {
        prefs[PREF_NTFY_USERNAME] = self.ntfyUsername.stringValue;
    }
    if(nil != self.ntfyPassword && 0 != self.ntfyPassword.stringValue.length)
    {
        prefs[PREF_NTFY_PASSWORD] = self.ntfyPassword.stringValue;
    }

    //save prefs (only if there's something to save)
    // cachePreferencesLocally: inside updatePreferences: writes to NSUserDefaults
    // immediately, so prefs survive even if the app exits before the XPC completes.
    // Use fire-and-forget to avoid blocking the main thread (which causes a rainbow
    // ball when the daemon is dead and the sync timeout is hit)
    if(0 != prefs.count)
    {
        [self.daemonComms updatePreferences:prefs];
    }

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


//build the ntfy settings view programmatically
-(void)buildNtfyView
{
    //view frame matches other tab views (width will be adjusted by toolbarButtonHandler)
    self.ntfyView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 300)];

    //current y position (top-down layout, using flipped-style math)
    CGFloat y = 260;
    CGFloat labelWidth = 110;
    CGFloat fieldX = 130;
    CGFloat fieldWidth = 310;
    CGFloat rowH = 26;
    CGFloat rowGap = 8;

    //helper block: make a right-aligned label
    NSTextField* (^makeLabel)(NSString*, CGFloat) = ^NSTextField*(NSString* text, CGFloat yPos)
    {
        NSTextField* lbl = [[NSTextField alloc] initWithFrame:NSMakeRect(10, yPos, labelWidth, rowH)];
        lbl.stringValue = text;
        lbl.alignment = NSTextAlignmentRight;
        lbl.editable = NO;
        lbl.bordered = NO;
        lbl.drawsBackground = NO;
        lbl.font = [NSFont systemFontOfSize:13.0];
        return lbl;
    };

    //helper block: make a text field
    NSTextField* (^makeField)(CGFloat, BOOL) = ^NSTextField*(CGFloat yPos, BOOL secure)
    {
        NSTextField* fld;
        if(secure)
        {
            fld = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(fieldX, yPos, fieldWidth, rowH)];
        }
        else
        {
            fld = [[NSTextField alloc] initWithFrame:NSMakeRect(fieldX, yPos, fieldWidth, rowH)];
        }
        fld.delegate = self;
        fld.font = [NSFont systemFontOfSize:13.0];
        return fld;
    };

    // --- Enable ntfy checkbox ---
    self.ntfyActionBtn = [[NSButton alloc] initWithFrame:NSMakeRect(fieldX, y, fieldWidth, rowH)];
    [self.ntfyActionBtn setButtonType:NSButtonTypeSwitch];
    self.ntfyActionBtn.title = @"Enable ntfy notifications";
    self.ntfyActionBtn.tag = BUTTON_NTFY_ACTION;
    self.ntfyActionBtn.font = [NSFont systemFontOfSize:13.0];
    [self.ntfyActionBtn setAction:@selector(togglePreference:)];
    [self.ntfyActionBtn setTarget:self];
    [self.ntfyView addSubview:self.ntfyActionBtn];

    y -= rowH + rowGap + 4;

    // --- Server ---
    [self.ntfyView addSubview:makeLabel(@"Server:", y)];
    self.ntfyServer = makeField(y, NO);
    self.ntfyServer.placeholderString = @"https://ntfy.sh";
    [self.ntfyView addSubview:self.ntfyServer];

    y -= rowH + rowGap;

    // --- Topic ---
    [self.ntfyView addSubview:makeLabel(@"Topic:", y)];
    self.ntfyTopic = makeField(y, NO);
    self.ntfyTopic.placeholderString = @"my-dnd-alerts";
    [self.ntfyView addSubview:self.ntfyTopic];

    y -= rowH + rowGap + 4;

    // --- Auth Type ---
    [self.ntfyView addSubview:makeLabel(@"Auth:", y)];
    self.ntfyAuthType = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(fieldX, y, 180, rowH) pullsDown:NO];
    [self.ntfyAuthType addItemsWithTitles:@[@"None", @"Token", @"Username / Password"]];
    self.ntfyAuthType.font = [NSFont systemFontOfSize:13.0];
    [self.ntfyAuthType setAction:@selector(ntfyAuthTypeChanged:)];
    [self.ntfyAuthType setTarget:self];
    [self.ntfyView addSubview:self.ntfyAuthType];

    y -= rowH + rowGap;

    // --- Token ---
    self.ntfyTokenLabel = makeLabel(@"Token:", y);
    [self.ntfyView addSubview:self.ntfyTokenLabel];
    self.ntfyToken = makeField(y, NO);
    self.ntfyToken.placeholderString = @"tk_...";
    [self.ntfyView addSubview:self.ntfyToken];

    y -= rowH + rowGap;

    // --- Username ---
    self.ntfyUsernameLabel = makeLabel(@"Username:", y);
    [self.ntfyView addSubview:self.ntfyUsernameLabel];
    self.ntfyUsername = makeField(y, NO);
    self.ntfyUsername.placeholderString = @"username";
    [self.ntfyView addSubview:self.ntfyUsername];

    y -= rowH + rowGap;

    // --- Password ---
    self.ntfyPasswordLabel = makeLabel(@"Password:", y);
    [self.ntfyView addSubview:self.ntfyPasswordLabel];
    self.ntfyPassword = (NSSecureTextField*)makeField(y, YES);
    self.ntfyPassword.placeholderString = @"password";
    [self.ntfyView addSubview:self.ntfyPassword];

    return;
}

//update visibility/state of auth-specific fields based on selected auth type
-(void)updateNtfyAuthFields:(NSInteger)authType
{
    BOOL ntfyEnabled = self.ntfyActionBtn.state == NSControlStateValueOn;

    //token fields visible only for token auth
    self.ntfyToken.enabled = ntfyEnabled && (authType == NTFY_AUTH_TOKEN);
    self.ntfyTokenLabel.textColor = (ntfyEnabled && authType == NTFY_AUTH_TOKEN) ? [NSColor labelColor] : [NSColor disabledControlTextColor];

    //basic auth fields visible only for basic auth
    self.ntfyUsername.enabled = ntfyEnabled && (authType == NTFY_AUTH_BASIC);
    self.ntfyPassword.enabled = ntfyEnabled && (authType == NTFY_AUTH_BASIC);
    self.ntfyUsernameLabel.textColor = (ntfyEnabled && authType == NTFY_AUTH_BASIC) ? [NSColor labelColor] : [NSColor disabledControlTextColor];
    self.ntfyPasswordLabel.textColor = (ntfyEnabled && authType == NTFY_AUTH_BASIC) ? [NSColor labelColor] : [NSColor disabledControlTextColor];

    return;
}

//handle ntfy auth type popup change
-(IBAction)ntfyAuthTypeChanged:(id)sender
{
    NSInteger authType = [self.ntfyAuthType indexOfSelectedItem];

    //update field states
    [self updateNtfyAuthFields:authType];

    //save pref in background (windowWillClose: does a final sync save before exit)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.daemonComms updatePreferences:@{PREF_NTFY_AUTH_TYPE:@(authType)}];
    });

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
