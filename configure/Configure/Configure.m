//
//  file: Configure.m
//  project: DND (config)
//  description: configure DND, install/uninstall
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Configure.h"
#import "Utilities.h"

@import Foundation;
@import ServiceManagement;

@implementation Configure

//invokes appropriate install || uninstall logic
-(BOOL)configure:(NSInteger)parameter
{
    //return var
    BOOL wasConfigured = NO;

    //install
    if(ACTION_INSTALL_FLAG == parameter)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"installing...");

        //already installed?
        // perform (partial) uninstall first
        if(YES == [self isInstalled])
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"already installed, so uninstalling (partially)...");

            //uninstall (partial)
            if(YES != [self uninstall:UNINSTALL_PARTIAL])
            {
                //bail
                goto bail;
            }

            //dbg msg
            logMsg(LOG_DEBUG, @"(partially) uninstalled");
        }

        //install
        if(YES != [self install])
        {
            //bail
            goto bail;
        }

        //dbg msg
        logMsg(LOG_DEBUG, @"installed!");
    }
    //uninstall
    else if(ACTION_UNINSTALL_FLAG == parameter)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"uninstalling...");

        //uninstall (full)
        if(YES != [self uninstall:UNINSTALL_FULL])
        {
            //bail
            goto bail;
        }

        //dbg msg
        logMsg(LOG_DEBUG, @"uninstalled!");
    }

    //no errors
    wasConfigured = YES;

bail:

    return wasConfigured;
}

//determine if installed
// checks if app exists in /Applications or daemon binary exists in install directory
-(BOOL)isInstalled
{
    //flag
    BOOL installed = NO;

    //app path
    NSString* appPath = nil;

    //daemon binary
    NSString* daemonBinary = nil;

    //init path to app
    appPath = [@"/Applications" stringByAppendingPathComponent:APP_NAME];

    //check for installed components
    // daemon bundle now lives inside the app, so only check for the app
    installed = (YES == [[NSFileManager defaultManager] fileExistsAtPath:appPath]);

    return installed;
}

//install
// runs privileged shell script to copy files; the main app registers the daemon
// and login item via SMAppService when it first launches from /Applications/
-(BOOL)install
{
    //return/status var
    BOOL wasInstalled = NO;

    //run privileged shell script (copies Do Not Disturb.app to /Applications/,
    // and Do Not Disturb.bundle to /Library/Objective-See/DND/)
    // the script also launches the main app, which registers the daemon via SMAppService
    if(YES != [self runScript:CMDLINE_FLAG_INSTALL fullUninstall:NO])
    {
        //err msg
        logMsg(LOG_ERR, @"install script failed");

        //bail
        goto bail;
    }

    //happy
    wasInstalled = YES;

bail:

    return wasInstalled;
}

//uninstall
-(BOOL)uninstall:(BOOL)full
{
    //return/status var
    BOOL wasUninstalled = NO;

    //path to login item
    NSString* loginItem = nil;

    //SMAppService for daemon unregistration
    SMAppService* daemonService = nil;

    //semaphore to wait for async unregister
    dispatch_semaphore_t sema = nil;

    //unregister error
    __block NSError* unregError = nil;

    //init path to login item
    loginItem = [NSString pathWithComponents:@[@"/", @"Applications", APP_NAME, @"Contents", @"Library", @"LoginItems", [NSString stringWithFormat:@"%@.app", LOGIN_ITEM_NAME]]];

    //uninstall login item first
    // can't do this in script since it needs to be executed as logged in user (not root)
    if(YES != toggleLoginItem([NSURL fileURLWithPath:loginItem], ACTION_UNINSTALL_FLAG))
    {
        //err msg (non-fatal)
        logMsg(LOG_ERR, @"failed to uninstall login item");
    }
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"uninstalled login item (%@)", loginItem]);
    }

    //unregister the launch daemon via SMAppService
    daemonService = [SMAppService daemonServiceWithPlistName:LAUNCH_DAEMON_PLIST];
    if(nil != daemonService)
    {
        sema = dispatch_semaphore_create(0);

        [daemonService unregisterWithCompletionHandler:^(NSError* err) {
            unregError = err;
            dispatch_semaphore_signal(sema);
        }];

        //wait for unregister to complete (with timeout)
        dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));

        if(nil != unregError)
        {
            //log but don't fail -- may not have been registered
            logMsg(LOG_ERR, [NSString stringWithFormat:@"SMAppService unregister returned error (non-fatal): %@", unregError]);
        }
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"unregistered launch daemon via SMAppService");
        }
    }

    //run privileged shell script to remove files
    if(YES != [self runScript:CMDLINE_FLAG_UNINSTALL fullUninstall:full])
    {
        //err msg
        logMsg(LOG_ERR, @"uninstall script failed");

        //bail
        goto bail;
    }

    //happy
    wasUninstalled = YES;

bail:

    return wasUninstalled;
}

//no-op: privileged helper tool architecture removed; kept for AppDelegate.m compatibility
-(void)removeHelper
{
    return;
}

//run configure.sh with admin privileges via osascript
// the script lives in this app bundle's Resources directory
// passes the Resources path so the script knows where the bundled files are
-(BOOL)runScript:(NSString*)action fullUninstall:(BOOL)full
{
    //result
    BOOL result = NO;

    //resources path
    NSString* resourcesPath = nil;

    //path to script
    NSString* scriptPath = nil;

    //osascript command
    NSString* osascriptCmd = nil;

    //results
    NSDictionary* taskResult = nil;

    //exit code
    int exitCode = -1;

    //get the Resources directory
    resourcesPath = [[NSBundle mainBundle] resourcePath];

    //get path to configure.sh in this app's Resources
    scriptPath = [resourcesPath stringByAppendingPathComponent:@"configure.sh"];
    if(![[NSFileManager defaultManager] fileExistsAtPath:scriptPath])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"configure.sh not found at %@", scriptPath]);

        //bail
        goto bail;
    }

    //make script executable
    [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions:@0755} ofItemAtPath:scriptPath error:nil];

    //build osascript command
    // 'do shell script' prompts for admin password and runs the script as root
    // argv passed to the script: resources_path action [full_flag]
    // note: paths are single-quote wrapped; internal single quotes are escaped as '\''
    //       double quotes are escaped as \" to prevent breaking the outer AppleScript string
    {
        //escape single quotes (shell) then double quotes (AppleScript string delimiter)
        NSString* escapedScript = [[scriptPath
            stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]
            stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];

        NSString* escapedResources = [[resourcesPath
            stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]
            stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];

        NSString* escapedAction = [[action
            stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]
            stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];

        if(YES == full)
        {
            osascriptCmd = [NSString stringWithFormat:
                            @"do shell script \"'%@' '%@' '%@' '1'\" with administrator privileges",
                            escapedScript, escapedResources, escapedAction];
        }
        else
        {
            osascriptCmd = [NSString stringWithFormat:
                            @"do shell script \"'%@' '%@' '%@'\" with administrator privileges",
                            escapedScript, escapedResources, escapedAction];
        }
    }

    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"running: configure.sh %@ (full=%d)", action, full]);

    //exec osascript
    taskResult = execTask(@"/usr/bin/osascript", @[@"-e", osascriptCmd], YES);

    //grab exit code
    if(nil != taskResult[EXIT_CODE])
    {
        exitCode = [taskResult[EXIT_CODE] intValue];
    }

    //check result
    if(0 != exitCode)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"configure.sh failed (exit: %d) stderr: %@",
                         exitCode,
                         taskResult[STDERR] ? [[NSString alloc] initWithData:taskResult[STDERR] encoding:NSUTF8StringEncoding] : @"(none)"]);

        //bail
        goto bail;
    }

    //dbg msg
    logMsg(LOG_DEBUG, @"configure.sh completed successfully");

    //happy
    result = YES;

bail:

    return result;
}

@end
