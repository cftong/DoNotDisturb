//
//  file: Lid.h
//  project: DND (launch daemon)
//  description: monitor and alert logic for lid open events (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Utilities.h"

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

/* METHODS */

//register for notifications
-(BOOL)register4Notifications;

//register for notifications
-(void)unregister4Notifications;

//proces lid open event
-(void)processEvent:(NSDate*)timestamp user:(NSString*)user;

//execute action
-(int)executeAction:(NSString*)path user:(NSString*)user;

@end
