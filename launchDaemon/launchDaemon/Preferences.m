//
//  file: Preferences.m
//  project: DND (launch daemon)
//  description: store/retrieve user preferences
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Lid.h"
#import "Consts.h"
#import "Logging.h"
#import "Preferences.h"

/* GLOBALS */

//lid obj
extern Lid* lid;

@implementation Preferences

@synthesize preferences;

//init
// loads prefs
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //prefs exist?
        // load them from disk
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE]])
        {
            //load
            if(YES != [self load])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to loads preferences from %@", PREFS_FILE]);
                
                //unset
                self = nil;
                
                //bail
                goto bail;
            }
        }
        //no prefs (yet)
        // just initialze empty dictionary
        else
        {
            //init
            preferences = [NSMutableDictionary dictionary];
        }
    }
    
bail:
    
    return self;
}

//load prefs from disk
-(BOOL)load
{
    //flag
    BOOL loaded = NO;
    
    //load
    preferences = [NSMutableDictionary dictionaryWithContentsOfFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE]];
    if(nil == self.preferences)
    {
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded preferences: %@", self.preferences]);
    
    //happy
    loaded = YES;
    
bail:
    
    return loaded;
}

//get all prefs
// or a specific one...
-(NSDictionary*)get:(NSString*)preference
{
    //current preferences
    NSDictionary* currentPrefs = nil;
    
    //none specified?
    // just will return all
    if(nil == preference)
    {
        //all
        currentPrefs = self.preferences;
    }
    //grab just the one user requested
    else
    {
        //now grab requested pref
        if(nil != self.preferences[preference])
        {
            //grab
            currentPrefs = @{preference:self.preferences[preference]};
        }
    }
    
    return currentPrefs;
}

//set & save
// directly override value
-(void)set:(NSString*)key value:(id)value
{
    //set
    self.preferences[key] = value;
    
    //save
    if(YES != [self save])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to save preferences");
        
        //bail
        goto bail;
    }
    
bail:
    
    return;
}

//update prefs
// handles logic for specific prefs & then saves
-(BOOL)update:(NSDictionary*)updates
{
    //flag
    BOOL updated = NO;

    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"updating preferences (%@)", updates]);
    
    //user setting state?
    // toggle the state of the daemon (lid) watcher too
    if(nil != updates[PREF_IS_DISABLED])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"client toggling state: %@", updates[PREF_IS_DISABLED]]);
        
        //disable?
        if(YES == [updates[PREF_IS_DISABLED] boolValue])
        {
            //dbg msg
            // and log to file
            logMsg(LOG_DEBUG|LOG_TO_FILE, @"disabling...");
            
            //unregister for lid notifications
            [lid unregister4Notifications];

            //dbg msg
            logMsg(LOG_DEBUG, @"unregistered for lid change notifications");

            //broadcast dismiss to dismiss any alerts
            [[NSNotificationCenter defaultCenter] postNotificationName:DISMISS_NOTIFICATION object:nil userInfo:nil];
        }
        
        //enable?
        else
        {
            //dbg msg
            // and log to file
            logMsg(LOG_DEBUG|LOG_TO_FILE, @"enabling...");
            
            //register for lid notifications
            [lid register4Notifications];
        
            //dbg msg
            logMsg(LOG_DEBUG, @"registered for lid change notifications");
        }
    }
    
    //handle screen lock state (transient, not persisted)
    if(nil != updates[PREF_SCREEN_LOCKED])
    {
        //screen locked?
        if(YES == [updates[PREF_SCREEN_LOCKED] boolValue])
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"screen locked, checking if USB monitoring should start");

            //start USB monitor if pref is enabled
            [lid startUSBMonitor];
        }
        //screen unlocked
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"screen unlocked, stopping USB monitoring");

            //stop USB monitor
            [lid stopUSBMonitor];
        }

        //strip transient key before persisting
        NSMutableDictionary* mutableUpdates = [updates mutableCopy];
        [mutableUpdates removeObjectForKey:PREF_SCREEN_LOCKED];
        updates = mutableUpdates;

        //if nothing left to persist, we're done
        if(0 == updates.count)
        {
            updated = YES;
            goto bail;
        }
    }

    //sync prefs
    @synchronized(self.preferences)
    {

    //updating list of registered devices?
    // it's a dictionary so requires an extra merge
    if( (nil != updates[PREF_REGISTERED_DEVICES]) &&
        (nil != self.preferences[PREF_REGISTERED_DEVICES]) )
    {
        //merge
        [self.preferences[PREF_REGISTERED_DEVICES] addEntriesFromDictionary:updates[PREF_REGISTERED_DEVICES]];
    }

    //for all other prefs or for 1st device
    // just merge in new prefs into existing ones
    else
    {
        //merge
        [self.preferences addEntriesFromDictionary:updates];
    }

    }//sync
    
    //save
    if(YES != [self save])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to save preferences");
        
        //bail
        goto bail;
    }
    
    //happy
    updated = YES;
    
bail:
    
    return updated;
}

//save to disk
-(BOOL)save
{
    //save
    return [self.preferences writeToFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE] atomically:YES];
}

//for pretty print
-(NSString *)description
{
    //prefs dictionary
    return self.preferences.description;
}

@end
