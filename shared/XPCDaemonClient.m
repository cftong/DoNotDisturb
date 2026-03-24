//
//  file: XPCDaemonClient.m
//  project: DND (shared)
//  description: talk to the daemon, via XPC (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "XPCUserProto.h"
#import "XPCDaemonClient.h"

#ifdef XPC_USER
#import "XPCUser.h"
#endif

// NSUserDefaults key for local preferences cache
// Used as fallback when daemon is not running
static NSString* const kLocalPrefsKey = @"cachedDaemonPreferences";

@implementation XPCDaemonClient

@synthesize xpcServiceConnection;

//save preferences to local cache (NSUserDefaults)
// merges incoming keys into the existing cache so partial updates
// (e.g. a single toggle) don't wipe out previously cached values
-(void)cachePreferencesLocally:(NSDictionary*)preferences
{
    if(nil == preferences || 0 == preferences.count)
    {
        return;
    }

    //load existing cache and merge
    NSMutableDictionary* merged = [NSMutableDictionary dictionary];
    NSDictionary* existing = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kLocalPrefsKey];
    if(nil != existing)
    {
        [merged addEntriesFromDictionary:existing];
    }

    //apply incoming keys (overwrites per-key)
    [merged addEntriesFromDictionary:preferences];

    //save merged result
    [[NSUserDefaults standardUserDefaults] setObject:merged forKey:kLocalPrefsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"cached preferences locally via NSUserDefaults (%lu keys)", (unsigned long)merged.count]);
}

//load preferences from local cache (NSUserDefaults)
-(NSDictionary*)loadCachedPreferences
{
    NSDictionary* cached = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kLocalPrefsKey];

    if(nil != cached)
    {
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded cached preferences from NSUserDefaults: %@", cached]);
    }

    return cached;
}

//init
// create XPC connection & set remote obj interface
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc/init
        xpcServiceConnection = [[NSXPCConnection alloc] initWithMachServiceName:DAEMON_MACH_SERVICE options:0];
        
        //set remote object interface
        self.xpcServiceConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCDaemonProtocol)];
    
        #ifdef XPC_USER
        
        //set exported object interface (protocol)
        self.xpcServiceConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCUserProtocol)];
        
        //set exported object
        // this will allow daemon to invoke user methods!
        self.xpcServiceConnection.exportedObject = [[XPCUser alloc] init];
        
        #endif
        
        //resume
        [self.xpcServiceConnection resume];
    }
    
    return self;
}

//ask daemon for QRC info
// name, uuid, key, key size, etc...
-(void)qrcRequest:(void (^)(NSData* qrcInfo))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, for qrc info");
    
    //request qrc info
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
          //err msg
          logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'qrcRequest' method on launch daemon (error: %@)", proxyError]);
          
    }] qrcRequest:^(NSData* qrcInfo)
    {
         //respond with info
         reply(qrcInfo);
    }];
    
    return;
}

//wait for phone to complete registration
// calls into framework that comms w/ server to wait for phone
-(void)recvRegistrationACK:(void (^)(NSDictionary* registrationInfo))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, for recv registration ack/info");
    
    //recv registration info
    // note: this will block until phone pings server
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
          //err msg
          logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'recvRegistrationACK' method on launch daemon (error: %@)", proxyError]);
          
    }] recvRegistrationACK:^(NSDictionary* registrationInfo)
    {
         //respond with alert
         reply(registrationInfo);
    }];
    
    return;
}

//get preferences
// note: synchronous
-(NSDictionary*)getPreferences:(NSString*)preference
{
    //preferences
    __block NSDictionary* preferences = nil;
    
    //wait sema
    dispatch_semaphore_t semaphore = NULL;
    
    //init sema
    semaphore = dispatch_semaphore_create(0);
    
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, for preferences");

    //request preferences
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'getPreferences' method on launch daemon (error: %@)", proxyError]);
        
        //signal sema
        dispatch_semaphore_signal(semaphore);
          
    }] getPreferences:preference reply:^(NSDictionary* preferencesFromDaemon)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got preferences: %@", preferencesFromDaemon]);
        
        //save
        preferences = preferencesFromDaemon;
        
        //signal sema
        dispatch_semaphore_signal(semaphore);
        
    }];
    
    //XPC is async
    // wait for preferences from daemon (2 second timeout — this runs on a background thread)
    if(0 != dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)))
    {
        //err msg
        logMsg(LOG_ERR, @"getPreferences: timed out waiting for daemon reply (2s) — daemon may not be running or XPC connection rejected");
    }

    //daemon returned prefs? cache them locally
    if(nil != preferences)
    {
        [self cachePreferencesLocally:preferences];
    }
    else
    {
        //daemon unavailable — fall back to local cache
        logMsg(LOG_DEBUG, @"getPreferences: daemon returned nil, falling back to local cache");
        preferences = [self loadCachedPreferences];
    }

    return preferences;
}

//update (save) preferences (fire-and-forget)
-(void)updatePreferences:(NSDictionary*)preferences
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, to update preferences");

    //always cache locally so prefs survive even if daemon is down
    [self cachePreferencesLocally:preferences];

    //update prefs via daemon
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
          //err msg
          logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'updatePreferences' method on launch daemon (error: %@)", proxyError]);

    }] updatePreferences:preferences];

    return;
}

//update (save) preferences, blocking until daemon confirms the save completed
// use when the caller may exit immediately after (e.g. windowWillClose:)
-(void)updatePreferencesSync:(NSDictionary*)preferences
{
    //semaphore to wait for daemon reply
    dispatch_semaphore_t semaphore = NULL;

    //flag: sync call succeeded
    __block BOOL syncSucceeded = NO;

    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, to update preferences (sync)");

    //always cache locally so prefs survive even if daemon is down
    [self cachePreferencesLocally:preferences];

    //init semaphore
    semaphore = dispatch_semaphore_create(0);

    //update prefs, waiting for reply
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'updatePreferencesSync' method on launch daemon (error: %@)", proxyError]);

        //unblock caller even on error
        dispatch_semaphore_signal(semaphore);

    }] updatePreferencesSync:preferences reply:^
    {
        //sync call succeeded
        syncSucceeded = YES;

        //unblock caller now that daemon has saved
        dispatch_semaphore_signal(semaphore);
    }];

    //wait for daemon to confirm save (5 second timeout)
    if(0 != dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)))
    {
        //err msg
        logMsg(LOG_ERR, @"updatePreferencesSync: timed out waiting for daemon reply (5s)");
    }

    //sync call failed or timed out?
    // fall back to fire-and-forget (daemon may be older and not have sync method)
    // note: local cache was already saved above, so just try the XPC send directly
    if(YES != syncSucceeded)
    {
        logMsg(LOG_DEBUG, @"updatePreferencesSync: falling back to async fire-and-forget XPC");

        //try async fire-and-forget (call proxy directly to avoid double-caching)
        [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
        {
            logMsg(LOG_ERR, [NSString stringWithFormat:@"fallback updatePreferences also failed (error: %@)", proxyError]);
        }] updatePreferences:preferences];

        //brief pause to give async message time to be delivered
        [NSThread sleepForTimeInterval:0.5];
    }

    return;
}

//delete event file
-(void)deleteEventFile:(NSString*)filePath
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"sending request, via XPC, to delete event file: %@", filePath]);

    //delete file via daemon
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
          //err msg
          logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'deleteEventFile' method on launch daemon (error: %@)", proxyError]);

    }] deleteEventFile:filePath];

    return;
}

@end
