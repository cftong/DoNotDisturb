//
//  file: Lid.h
//  project: DND (launch daemon)
//  description: monitor and alert logic for lid open events (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Utilities.h"
#import "USBMonitor.h"

@import Foundation;

#import <IOKit/IOKitLib.h>
#import <IOKit/pwr_mgt/IOPM.h>

/* FUNCTIONS */

//check if user auth'd
// a) within last 10 seconds
// b) via biometrics (touchID)
BOOL authViaTouchID(void);

/* CLASS INTERFACE */

@interface Lid : NSObject
{
    //lid state
    LidState lidState;
    
    //dispatch queue
    dispatch_queue_t dispatchQ;
    
    //notification port
    IONotificationPortRef notificationPort;
    
    //notification object
    io_object_t notification;
    
}

/* PROPERTIES */

//observer for dismiss alerts
@property(nonatomic, retain)id dismissObserver;

//observer for new client/user (login item)
@property(nonatomic, retain)id userObserver;

//undelivered alerts
@property(nonatomic, retain)NSMutableArray* undeliveredAlerts;

//persistent USB monitor (active while screen is locked)
@property (nonatomic, retain) USBMonitor* persistentUSBMonitor;

/* METHODS */

//register for notifications
-(BOOL)register4Notifications;

//register for notifications
-(void)unregister4Notifications;

//process event (lid open or USB insertion)
-(void)processEvent:(NSDate*)timestamp user:(NSString*)user eventType:(NSString*)eventType;

//start USB monitoring (called when screen locks)
-(void)startUSBMonitor;

//stop USB monitoring (called when screen unlocks)
-(void)stopUSBMonitor;

//execute action
-(int)executeAction:(NSString*)path user:(NSString*)user;

@end
