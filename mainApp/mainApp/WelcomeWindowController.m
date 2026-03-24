//
//  file: WelcomeWindowController.m
//  project: DND (main app)
//  description: 'welcome' window logic/controller
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "WelcomeWindowController.h"

#define VIEW_WELCOME 0
#define VIEW_DONE 1

@implementation WelcomeWindowController

@synthesize welcomeViewController;

//window delegate method
// init ui stuff and show first view
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //center
    [self.window center];
    
    //not in mojave dark mode?
    // make window color white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }
    
    //when supported
    // indicate title bar is transparent (too)
    if([self.window respondsToSelector:@selector(titlebarAppearsTransparent)])
    {
        //set transparency
        self.window.titlebarAppearsTransparent = YES;
    }
    
    //set title
    self.window.title = [NSString stringWithFormat:@"Do Not Disturb (v. %@)", getAppVersion()];
    
    //show first view
    [self buttonHandler:nil];

    return;
}


//button handler for all views
// show next view, sometimes, with view specific logic
-(IBAction)buttonHandler:(id)sender
{
    //set next view
    switch(((NSButton*)sender).tag)
    {
        //welcome
        case VIEW_WELCOME:
        {
            //remove prev. subview
            [[[self.window.contentView subviews] lastObject] removeFromSuperview];
            
            //set view
            [self.window.contentView addSubview:self.welcomeView];
            
            //make 'next' button first responder
            // calling this without a timeout sometimes fails :/
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                
                //set first responder
                [self.window makeFirstResponder:[self.welcomeView viewWithTag:VIEW_DONE]];
                
            });
            
            break;
        }
            
        //done - request camera access and exit
        case VIEW_DONE:
        {
            //bye!
            [self terminate];
            
            break;
        }
    }
    return;
}

//exit app
// performing any actions
-(void)terminate
{
    //before exiting
    // ask for camera
    requestCameraAccess();
    
    //exit
    [NSApp terminate:nil];
}

@end
