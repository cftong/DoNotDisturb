//
//  file: XPCUser.m
//  project: DND (login item)
//  description: user XPC methods
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Camera.h"
#import "Consts.h"
#import "Logging.h"
#import "XPCUser.h"
#import "AppDelegate.h"
#import <UserNotifications/UserNotifications.h>

//notification identifier used to remove all DND alerts
static NSString* const kDNDNotificationIdentifier = @"ca.tarapore.dnd.alert";

@implementation XPCUser

//show an alert
-(void)alertShow:(NSDictionary*)alert
{
    //formatter
    NSDateFormatter* dateFormat = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request from daemon: alert show");
    
    //alloc formatter
    dateFormat = [[NSDateFormatter alloc] init];
    
    //set date format
    [dateFormat setDateFormat:@"MM/dd/yyyy HH:mm:ss"];
    
    //build notification content
    UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
    content.title = @"Do Not Disturb Alert";
    content.body = [NSString stringWithFormat:@"Lid Opened: %@", [dateFormat stringFromDate:alert[ALERT_TIMESTAMP]]];
    content.sound = [UNNotificationSound defaultSound];

    //use a fixed identifier so we can remove it via alertDismiss
    UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:kDNDNotificationIdentifier
                                                                          content:content
                                                                          trigger:nil];
    
    //show alert on main thread
    dispatch_async(dispatch_get_main_queue(), ^{

        //deliver notification
        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError* error)
        {
            if(nil != error)
            {
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to deliver notification: %@", error]);
            }
        }];
        
        //init/show touch bar
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) initTouchBar];
       
    });
    
    return;
}

//dismiss alert(s)
-(void)alertDismiss
{
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request from daemon: alert dismiss");
    
    //dismiss alerts on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        
        //remove all delivered DND notifications
        [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
        
        //set app delegate's touch bar to nil
        // will hide/unset the touch bar alert....
        ((AppDelegate*)[[NSApplication sharedApplication] delegate]).touchBar = nil;
        
    });
    
    return;
}

//XPC method
// capture an image from the webcam
-(void)captureImage:(void (^)(NSData *))reply
{
    //image data
    NSData* image = nil;
    
    //camera obj
    Camera* camera = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request from daemon: capture picture");
    
    //init camera
    camera = [[Camera alloc] init];
    
    //grab image
    image = [camera captureImage];

    //get current prefs
    reply(image);
    
    return;
}

//'UNUserNotificationCenterDelegate' method
// always show the notification even when the app is in the foreground
-(void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}

//'UNUserNotificationCenterDelegate' method
// handle notification click - open main app to events tab
-(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler
{
    //path to main app
    NSString* mainAppPath = nil;

    //get path to main app (parent of login item)
    // loginItem is at: MainApp.app/Contents/Library/LoginItems/LoginItem.app
    mainAppPath = [[[[[[NSBundle mainBundle] bundlePath]
                      stringByDeletingLastPathComponent]  // LoginItems/
                     stringByDeletingLastPathComponent]   // Library/
                    stringByDeletingLastPathComponent]    // Contents/
                   stringByDeletingLastPathComponent];    // MainApp.app

    //open main app with -events flag
    NSWorkspaceOpenConfiguration* config = [NSWorkspaceOpenConfiguration configuration];
    config.arguments = @[@"-events"];

    [[NSWorkspace sharedWorkspace] openApplicationAtURL:[NSURL fileURLWithPath:mainAppPath]
                                          configuration:config
                                      completionHandler:nil];

    //dismiss the notification after handling click
    [[UNUserNotificationCenter currentNotificationCenter] removeDeliveredNotificationsWithIdentifiers:@[response.notification.request.identifier]];

    completionHandler();
}

@end
