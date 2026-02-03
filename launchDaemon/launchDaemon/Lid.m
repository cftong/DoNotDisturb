//  file: Lid.m
//  project: DND (launch daemon)
//  description: monitor and alert logic for lid open events

// code inspired by:
//  https://github.com/zarigani/ClamshellWake/blob/master/ClamshellWake.cpp
//  https://github.com/dustinrue/ControlPlane/blob/master/Source/LaptopLidEvidenceSource.m

// note: manually get state from terminal via:
//       ioreg -r -k AppleClamshellState -d 4 | grep AppleClamshellState

#import "Lid.h"
#import "Consts.h"
#import "Logging.h"
#import "Monitor.h"
#import "AuthEvent.h"
#import "Utilities.h"
#import "XPCListener.h"
#import "Preferences.h"
#import "UserAuthMonitor.h"

#import "XPCUserProto.h"


/* GLOBALS */

//last state
// sometimes multiple notifications are delivered!?
LidState lastLidState;

//lid obj
extern Lid* lid;

//user auth event listener
extern UserAuthMonitor* userAuthMonitor;

//preferences obj
extern Preferences* preferences;

//XPC listener
extern XPCListener* xpcListener;

//callback for power/lid events
static void pmDomainChange(void *refcon, io_service_t service, uint32_t messageType, void *messageArgument)
{
    //lid state
    int lidState = stateUnavailable;
    
    //sleep bit
    int sleepState = -1;
    
    //preferences
    NSDictionary* currentPrefs = nil;
    
    //timestamp
    NSDate* timestamp = nil;
    
    //init timestamp
    timestamp = [NSDate date];
    
    //ignore any messages that are related to lid state
    if(kIOPMMessageClamshellStateChange != messageType)
    {
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"got 'kIOPMMessageClamshellStateChange' message");
    
    //get prefs
    currentPrefs = [preferences get:nil];

    //if user explicity set disabled
    // bail here, to ignore everything
    if(YES == [currentPrefs[PREF_IS_DISABLED] boolValue])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"client disabled DND, so ignoring lid event");
        
        //bail
        goto bail;
    }
    
    //get state
    lidState = ((int) messageArgument & kClamshellStateBit);
    
    //get sleep state
    sleepState = !!(((int)messageArgument & kClamshellSleepBit));
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"lid state: %@ (sleep bit: %d)", (lidState) ? @"closed" : @"open", sleepState]);
    
    //(new) open?
    // OS sometimes delivers 2x events, so ignore same same
    if( (stateOpen == lidState) &&
        (stateOpen != lastLidState) )
    {
        //ignore if lid isn't really open
        // on reboot, OS may deliver 'open' message if external monitors are connected
        if(stateOpen != getLidState())
        {
            //bail
            goto bail;
        }
        
        //update 'prev' state
        lastLidState = stateOpen;
        
        //dbg msg
        // log to file
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"[NEW EVENT] lid state: open (sleep state: %d)", sleepState]);
        
        //touch id mode?
        // wait up to 10 seconds, and ignore event if user auth'd via biometrics
        if(YES == [currentPrefs[PREF_TOUCHID_MODE] boolValue])
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"'touch id' mode enabled, waiting up to 10 seconds for biometric auth event");
            
            //user auth'd via touchID?
            // will wait for up to 10 seconds
            if(YES == authViaTouchID())
            {
                //dbg msg
                // log to file
                logMsg(LOG_DEBUG|LOG_TO_FILE, @"user authenticated via touchID, so ignoring event");
                
                //bail
                // will ignore the event
                goto bail;
            }
            
            //dbg msg
            logMsg(LOG_DEBUG, @"no touch id auth event found, so will process event");
        }
        
        //process event
        // report to user, execute actions, etc
        [lid processEvent:timestamp user:getConsoleUser() eventType:@"lid"];
    }
    
    //(new) close?
    // OS sometimes delivers 2x events, so ignore same same
    else if( (stateClosed == lidState) &&
             (stateClosed != lastLidState) )
    {
        //update 'prev' state
        lastLidState = stateClosed;
        
        //dbg msg
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"[NEW EVENT] lid state: closed (sleep state: %d)", sleepState]);
    }
    
bail:
    
    return;
}

//check if user auth'd
// a) within last 10 seconds
// b) via biometrics (touchID)
BOOL authViaTouchID()
{
    //result
    __block BOOL touchIDAuth = NO;
    
    //user auth events monitor
    UserAuthMonitor* userAuthMonitor = nil;
    
    //notifcation
    __block id userAuthObserver = nil;
    
    //auth event
    __block AuthEvent* authEvent = nil;
    
    //wait semaphore
    dispatch_semaphore_t semaphore = 0;

    //init user auth monitor
    userAuthMonitor = [[UserAuthMonitor alloc] init];
    
    //init sema
    semaphore = dispatch_semaphore_create(0);
    
    //kick off monitor for user auth events
    // do in background, as it should never return
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
    
    //register listener for user auth events
    // executes block to process auth events as they come in
    userAuthObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AUTH_NOTIFICATION object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
    {
        //grab event
        authEvent = notification.userInfo[AUTH_NOTIFICATION];
        if(YES != [authEvent isKindOfClass:[AuthEvent class]])
        {
            //ignore
            return;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got user auth event: %@", authEvent]);
        
        //ignore unsuccessful auth id attempts
        if(noErr != authEvent.result)
        {
            //ignore
            return;
        }
            
        //set touch id flag
        touchIDAuth = authEvent.wasTouchID;
        
        //signal sema
        // either way, got an auth event and touch id flag has been set
        dispatch_semaphore_signal(semaphore);
        
    }];
    
    //monitor
    if(YES != [userAuthMonitor start])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to initialize user auth monitoring (for touchID events)"]);
    }
    
    });
    
    //wait for touch id auth
    // ...up to five seconds
    dispatch_semaphore_wait(semaphore, dispatch_time(0, 10*NSEC_PER_SEC));

    //tell user auth monitor to stop
    [userAuthMonitor stop];
    
    //remove auth observer
    [[NSNotificationCenter defaultCenter] removeObserver:userAuthObserver];
    
    return touchIDAuth;
}

@implementation Lid

@synthesize userObserver;
@synthesize dismissObserver;
@synthesize undeliveredAlerts;
@synthesize persistentUSBMonitor;

//init
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //init
        dispatchQ = NULL;
        
        //init
        notificationPort = NULL;
        
        //init
        notification = 0;
        
        //alloc array for alerts
        undeliveredAlerts = [NSMutableArray array];
        
        //init to current state
        lastLidState = getLidState();
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"initial lid state: %d", lastLidState]);

        //register listener for dismiss alerts
        // when it fires, invoke (user) XPC method to dismiss alert
        self.dismissObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DISMISS_NOTIFICATION object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
        {
            //connected login item?
            if(nil != xpcListener.loginItem)
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"'DISMISS_NOTIFICATION' triggered, will send XPC msg to user (login item) to dismiss any alerts");
                
                //send XPC msg to dismiss
                [[xpcListener.loginItem remoteObjectProxy] alertDismiss];
            }
            else
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"no client (login item) is connected, so nothing to dismiss...");
            }
        }];
        
        //register listener for new client/user (login item)
        // when it fires, invoke (user) XPC method to deliver any alerts that occured when user wasn't logged in
        self.userObserver = [[NSNotificationCenter defaultCenter] addObserverForName:USER_NOTIFICATION object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"'USER_NOTIFICATION' triggered, will send XPC msg to user (login item) to display %lu undelivered alerts", self.undeliveredAlerts.count]);
            
            //sync to access
            @synchronized(self.undeliveredAlerts)
            {
                //send each alert to user
                for(NSDictionary* alert in self.undeliveredAlerts)
                {
                    //send XPC msg to user, to display alert
                    [[xpcListener.loginItem remoteObjectProxy] alertShow:alert];
                    
                    //dbg msg
                    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"(re)delivered alert: %@", alert]);
                }
                
                //remove all
                [self.undeliveredAlerts removeAllObjects];
            }
            
        }];
    }

    return self;
}

//register for notifications
-(BOOL)register4Notifications
{
    //return var
    BOOL registered = NO;
    
    //status var
    kern_return_t status = kIOReturnError;
    
    //root domain for power management
    io_service_t powerManagementRD = MACH_PORT_NULL;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"registering for lid notifications");
    
    //make sure state is ok
    if(stateUnavailable == getLidState())
    {
        //err msg
        logMsg(LOG_ERR, @"failed to get lid state, so aborting lid notifications registration");
        
        //error
        goto bail;
    }

    //create queue
    dispatchQ = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    if(NULL == dispatchQ)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to create dispatch queue for lid notifications");
        
        //error
        goto bail;
    }
    
    //set target
    dispatch_set_target_queue(dispatchQ, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    
    //create notification port
    notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
    if(NULL == notificationPort)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to create notification port for lid notifications");
        
        //error
        goto bail;
    }
    
    //set dispatch queue
    IONotificationPortSetDispatchQueue(notificationPort, dispatchQ);
    
    //get matching service for power management root domain
    powerManagementRD = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPMrootDomain"));
    if(0 == powerManagementRD)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to get power management root domain for lid notifications");
        
        //error
        goto bail;
    }
    
    //add interest notification
    status = IOServiceAddInterestNotification(notificationPort, powerManagementRD, kIOGeneralInterest,
                                     pmDomainChange, &lidState, &notification);
    if(KERN_SUCCESS != status)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to get add interest notifcation for lid notifications (error: 0x:%x)", status]);
        
        //error
        goto bail;
    }
    
    //happy
    registered = YES;

bail:

    //release
    if(MACH_PORT_NULL != powerManagementRD)
    {
        //release
        IOObjectRelease(powerManagementRD);
        
        //unset
        powerManagementRD = MACH_PORT_NULL;
    }
    
    return registered;
}

//unregister for notifications
-(void)unregister4Notifications
{
    //dbg msg
    logMsg(LOG_DEBUG, @"unregistering lid notifications");
    
    //release notification
    if(0 != notification)
    {
        //release
        IOObjectRelease(notification);
        
        //unset
        notification = 0;
        
        //dbg msg
        logMsg(LOG_DEBUG, @"released service interest notification");
    }
    
    //destroy notification port
    if(NULL != notificationPort)
    {
        //set queue to NULL
        IONotificationPortSetDispatchQueue(notificationPort, NULL);
        
        //unset dispatch queue
        dispatchQ = NULL;

        //destroy port
        IONotificationPortDestroy(notificationPort);
        
        //unset
        notificationPort = NULL;
        
        //dbg msg
        logMsg(LOG_DEBUG, @"destroyed notification port");
    }
    
    return;
}

//process event (lid open or USB insertion)
// report to user, execute cmd, send alert to server, etc
-(void)processEvent:(NSDate*)timestamp user:(NSString*)user eventType:(NSString*)eventType
{
    //monitor obj
    Monitor* monitor = nil;

    //current prefs
    NSDictionary* currentPrefs = nil;
    
    //alert
    NSDictionary* alert;

    //init alert
    alert = @{ALERT_TIMESTAMP:timestamp};
    
    //get current prefs
    currentPrefs = [preferences get:nil];

    //only add events to queue
    // when client is not running in passive mode
    if(YES != [currentPrefs[PREF_PASSIVE_MODE] boolValue])
    {
        //connected client? (login item)
        // deliver alert via XPC, to user
        if(nil != xpcListener.loginItem)
        {
            //send to client
            // this will fail (but we'll handle) if no clients are connected
            [[xpcListener.loginItem remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
              {
                  //err msg
                  logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to invoke USER XPC method: 'alertShow' (error: %@)", proxyError]);
                  
                  //save undelivered alert
                  @synchronized(self.undeliveredAlerts)
                  {
                      //save
                      [self.undeliveredAlerts addObject:alert];
                  }
                  
                  //dbg msg
                  logMsg(LOG_DEBUG, [NSString stringWithFormat:@"saved %@, will deliver when user (login item) connects", alert]);
                  
              }] alertShow:alert];
        }
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"no client (login item) is connected, so won't locally deliver alert");
        }
    }
    //passive mode
    // just log a msg about this fact
    else
    {
        //dbg msg
        // also log to file
        logMsg(LOG_DEBUG|LOG_TO_FILE, @"client in passive mode, so won't display");
    }
    
    //monitor
    // start with first, as other actions might take a bit...
    if(YES == [currentPrefs[PREF_MONITOR_ACTION] boolValue])
    {
        //dbg msg
        logMsg(LOG_DEBUG|LOG_TO_FILE, @"enabling monitoring (processes, usb, logins, etc.)");
        
        //alloc/init
        monitor = [[Monitor alloc] init];
        
        //kick off monitoring
        if(YES != [monitor start:MONITORING_TIMEOUT])
        {
            //err msg
            logMsg(LOG_ERR|LOG_TO_FILE, @"failed to start monitoring");
        }
    }

    //execute cmd?
    if( (YES == [currentPrefs[PREF_EXECUTE_ACTION] boolValue]) &&
        (0 != [currentPrefs[PREF_EXECUTE_PATH] length] ) )
    {
        //dbg msg
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"executing: %@ as %@", currentPrefs[PREF_EXECUTE_PATH], currentPrefs[PREF_EXECUTE_USER]]);

        //exec payload
        if(0 != [self executeAction:currentPrefs[PREF_EXECUTE_PATH] user:currentPrefs[PREF_EXECUTE_USER]])
        {
            //err msg
            logMsg(LOG_ERR|LOG_TO_FILE, [NSString stringWithFormat:@"failed to execute %@", currentPrefs[PREF_EXECUTE_PATH]]);
        }
    }

    //capture photo?
    if(YES == [currentPrefs[PREF_PHOTO_ACTION] boolValue])
    {
        //dbg msg
        logMsg(LOG_DEBUG|LOG_TO_FILE, @"photo capture action enabled, requesting image from login item");

        //connected login item?
        if(nil != xpcListener.loginItem)
        {
            //request image via XPC
            [[xpcListener.loginItem remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to invoke USER XPC method: 'captureImage' (error: %@)", proxyError]);

            }] captureImage:^(NSData* imageData)
            {
                //photos directory
                NSString* photosDir = nil;

                //photo path
                NSString* photoPath = nil;

                //date formatter
                NSDateFormatter* formatter = nil;

                //error
                NSError* error = nil;

                //sanity check
                if(nil == imageData || 0 == imageData.length)
                {
                    //err msg
                    logMsg(LOG_ERR|LOG_TO_FILE, @"failed to capture image (no data returned)");
                    return;
                }

                //init photos dir
                photosDir = [INSTALL_DIRECTORY stringByAppendingPathComponent:@"photos"];

                //create photos directory if needed
                if(YES != [[NSFileManager defaultManager] fileExistsAtPath:photosDir])
                {
                    if(YES != [[NSFileManager defaultManager] createDirectoryAtPath:photosDir withIntermediateDirectories:YES attributes:nil error:&error])
                    {
                        //err msg
                        logMsg(LOG_ERR|LOG_TO_FILE, [NSString stringWithFormat:@"failed to create photos directory: %@", error]);
                        return;
                    }
                }

                //init formatter
                formatter = [[NSDateFormatter alloc] init];
                [formatter setDateFormat:@"yyyyMMdd_HHmmss"];

                //build photo path (includes event type)
                photoPath = [photosDir stringByAppendingPathComponent:[NSString stringWithFormat:@"photo_%@_%@.jpg", [formatter stringFromDate:timestamp], eventType]];

                //save photo
                if(YES != [imageData writeToFile:photoPath options:NSDataWritingAtomic error:&error])
                {
                    //err msg
                    logMsg(LOG_ERR|LOG_TO_FILE, [NSString stringWithFormat:@"failed to save photo to %@: %@", photoPath, error]);
                }
                else
                {
                    //dbg msg
                    logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"saved photo to %@", photoPath]);
                }
            }];
        }
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"no client (login item) is connected, so cannot capture photo");
        }
    }

    //send email notification?
    if( (YES == [currentPrefs[PREF_EMAIL_ACTION] boolValue]) &&
        (0 != [currentPrefs[PREF_EMAIL_ADDRESS] length]) )
    {
        //email address
        NSString* emailAddr = currentPrefs[PREF_EMAIL_ADDRESS];

        //date formatter
        NSDateFormatter* formatter = nil;

        //email body
        NSString* emailBody = nil;

        //shell command
        NSString* shellCmd = nil;

        //results
        NSDictionary* results = nil;

        //dbg msg
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"email notification enabled, sending to %@", emailAddr]);

        //init formatter
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];

        //determine event description for email
        NSString* eventDesc = ([eventType isEqualToString:@"usb"]) ? @"USB Insertion" : @"Lid Open";

        //build email body
        emailBody = [NSString stringWithFormat:@"DND Alert: %@ Detected\n\nTimestamp: %@\nHostname: %@\nUser: %@\nEvent Type: %@",
                     eventDesc,
                     [formatter stringFromDate:timestamp],
                     [[NSHost currentHost] localizedName],
                     user ?: USER_UNKNOWN,
                     eventDesc];

        //build shell command
        shellCmd = [NSString stringWithFormat:@"echo '%@' | /usr/bin/mail -s 'DND Alert: %@ Detected' '%@'",
                    emailBody, eventDesc, emailAddr];

        //execute
        results = execTask(@"/bin/sh", @[@"-c", shellCmd], YES);

        //check result
        if(nil != results[EXIT_CODE] && 0 == [results[EXIT_CODE] intValue])
        {
            //dbg msg
            logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"sent email notification to %@", emailAddr]);
        }
        else
        {
            //err msg
            logMsg(LOG_ERR|LOG_TO_FILE, [NSString stringWithFormat:@"failed to send email notification to %@: %@", emailAddr, results]);
        }
    }

    return;
}

//start USB monitoring
// called when screen locks and USB monitoring is enabled
-(void)startUSBMonitor
{
    //current prefs
    NSDictionary* currentPrefs = nil;

    //get prefs
    currentPrefs = [preferences get:nil];

    //check if USB monitoring is enabled
    if(YES != [currentPrefs[PREF_USB_MONITOR] boolValue])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"USB monitoring preference not enabled, not starting");
        return;
    }

    //already running?
    if(nil != self.persistentUSBMonitor)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"USB monitor already running");
        return;
    }

    //dbg msg
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"starting USB monitor (screen locked)");

    //alloc/init
    self.persistentUSBMonitor = [[USBMonitor alloc] init];

    //set handler
    self.persistentUSBMonitor.deviceInsertedHandler = ^(NSString* deviceName)
    {
        //dbg msg
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"USB device inserted while locked: %@", deviceName]);

        //process as USB event
        [self processEvent:[NSDate date] user:getConsoleUser() eventType:@"usb"];
    };

    //start
    if(YES != [self.persistentUSBMonitor start])
    {
        //err msg
        logMsg(LOG_ERR|LOG_TO_FILE, @"failed to start USB monitor");

        //unset
        self.persistentUSBMonitor = nil;
    }

    return;
}

//stop USB monitoring
// called when screen unlocks
-(void)stopUSBMonitor
{
    //not running?
    if(nil == self.persistentUSBMonitor)
    {
        return;
    }

    //dbg msg
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"stopping USB monitor (screen unlocked)");

    //stop
    [self.persistentUSBMonitor stop];

    //unset
    self.persistentUSBMonitor = nil;

    return;
}

//execute action
// note: executed with user's permissions
-(int)executeAction:(NSString*)path user:(NSString*)user
{
    //results
    NSDictionary* results = nil;
    
    //result
    int result = -1;
    
    //exec script
    // su -c <user> <path>
    results = execTask(@"/usr/bin/su", @[user, @"-c", path], YES);
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"executed %@ as %@, results:%@", path, user, results]);
    
    //grab result
    if(nil != results[EXIT_CODE])
    {
        //grab
        result = [results[EXIT_CODE] intValue];
    }
    
bail:
    
    return result;
}

@end
