//
//  file: Const.h
//  project: DND (shared)
//  description: #defines and what not
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#ifndef Const_h
#define Const_h

//app name
#define APP_NAME @"Do Not Disturb.app"

//vendor id string
#define OBJECTIVE_SEE_VENDOR "com.objectiveSee"

//installer (helper) ID
#define INSTALLER_HELPER_ID @"ca.tarapore.dnd.installer.helper"

//main app bundle id
#define MAIN_APP_ID @"ca.tarapore.dnd"

//login helper ID
#define HELPER_ID @"ca.tarapore.dnd.helper"

//launch daemon name
#define LAUNCH_DAEMON_BINARY @"Do Not Disturb"

//launch daemon plist
#define LAUNCH_DAEMON_PLIST @"ca.tarapore.dnd.plist"

//installer (app) ID
#define INSTALLER_ID @"ca.tarapore.dnd.installer"

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Dharmesh Tarapore (7KGHU7S762)"

//team identifier (works for both Apple Development and Developer ID certs)
#define SIGNING_TEAM_ID @"7KGHU7S762"

//sentry crash reporting URL
#define CRASH_REPORTING_URL @"https://b6e82fd3037642edbc63b1ded9be53d3:87738f112d454de5a89a9864aae73b23@sentry.io/289135"

//iOS companion app URL
#define IOS_APP_URL @"https://itunes.apple.com/us/app/do-not-disturb-companion/id1345055731?mt=8"

//button title: upgrade
#define ACTION_UPGRADE @"Upgrade"

//button title: close
#define ACTION_CLOSE @"Close"

//button title: next
#define ACTION_NEXT @"Next »"

//frame shift
// for status msg to avoid activity indicator
#define FRAME_SHIFT 45

//flag to close
#define ACTION_CLOSE_FLAG -1

//flag to uninstall
#define ACTION_UNINSTALL_FLAG 0

//flag to install
#define ACTION_INSTALL_FLAG 1

//next
#define ACTION_NEXT_FLAG 2

//flag for partial uninstall
// leave preferences file, etc.
#define UNINSTALL_PARTIAL 0

//flag for full uninstall
#define UNINSTALL_FULL 1

//path to pkill
#define PKILL @"/usr/bin/pkill"

//path to xattr
#define XATTR @"/usr/bin/xattr"

//path to log
#define LOG @"/usr/bin/log"

//path to open
#define OPEN @"/usr/bin/open"

//apps folder
#define APPS_FOLDER @"/Applications"

//console
#define PATH_CONSOLE "/dev/console"

//install directory
#define INSTALL_DIRECTORY @"/Library/Objective-See/DND"

//preferences file
#define PREFS_FILE @"preferences.plist"

//client no status
#define STATUS_CLIENT_UNKNOWN -1

//client disabled
#define STATUS_CLIENT_DISABLED 0

//client enabled
#define STATUS_CLIENT_ENABLED 1

//daemon mach name
#define DAEMON_MACH_SERVICE @"ca.tarapore.dndDaemon"

//user (login item) mach name
#define USER_MACH_SERVICE @"ca.tarapore.dndUser"

//product url
#define PRODUCT_URL @"https://objective-see.com/products/dnd.html"

//support us button tag
#define BUTTON_SUPPORT_US 100

//more info button tag
#define BUTTON_MORE_INFO 101

//cancel button
#define BUTTON_CANCEL 100

//config button
#define BUTTON_CONFIG 101

//patreon url
#define PATREON_URL @"https://www.patreon.com/bePatron?c=701171"

//product version url
#define PRODUCT_VERSIONS_URL @"https://objective-see.com/products.json"

//login item name
#define LOGIN_ITEM_NAME @"Do Not Disturb Helper"

//client ID
#define PREF_CLIENT_ID @"clientID"

//registered device name
#define PREF_REGISTERED_DEVICES @"registeredDevices"

//prefs
// status
#define PREF_IS_DISABLED @"disabled"

//prefs
// passive mode
#define PREF_PASSIVE_MODE @"passiveMode"

//prefs
// icon mode
#define PREF_NO_ICON_MODE @"noIconMode"

//prefs
// touchID mode
#define PREF_TOUCHID_MODE @"touchIDMode"

//prefs
// Apple Watch mode
#define PREF_APPLEWATCH_MODE @"appleWatchMode"

//prefs
// start mode
#define PREF_START_MODE @"startMode"

//pref
// execute action
#define PREF_EXECUTE_ACTION @"executeAction"

//pref
// execution path
#define PREF_EXECUTE_PATH @"executePath"

//pref
// execution user
#define PREF_EXECUTE_USER @"executeUser"

//pref
// monitor stuff
#define PREF_MONITOR_ACTION @"monitorAction"

//pref
// no remote tasking
#define PREF_NO_REMOTE_TASKING @"noRemoteTasking"

//pref
// photo capture action
#define PREF_PHOTO_ACTION @"photoAction"

//pref
// email notification action
#define PREF_EMAIL_ACTION @"emailAction"

//pref
// email address for notifications
#define PREF_EMAIL_ADDRESS @"emailAddress"

//pref
// USB monitoring
#define PREF_USB_MONITOR @"usbMonitor"

//pref
// screen locked (transient, not persisted)
#define PREF_SCREEN_LOCKED @"screenLocked"

//prefs
// update mode
#define PREF_NO_UPDATES_MODE @"noUpdatesMode"

//log file
#define LOG_FILE_NAME @"DND.log"

//log max size (7MB)
#define LOG_MAX_SIZE (7 * 1024 * 1024)

//alert key
// timestamp
#define ALERT_TIMESTAMP @"timestamp"

//key for device name
#define KEY_DEVICE_NAME @"deviceName"

//key for host name
#define KEY_HOST_NAME @"hostName"

/* LOGIN ITEM */

//command line install
#define CMDLINE_FLAG_INSTALL @"-install"

//welcome flag
#define CMDLINE_FLAG_WELCOME @"-welcome"

//command line uninstall
#define CMDLINE_FLAG_UNINSTALL @"-uninstall"

//events flag (open to events tab)
#define CMDLINE_FLAG_EVENTS @"-events"

//signature status
#define KEY_SIGNATURE_STATUS @"signatureStatus"

//signing auths
#define KEY_SIGNING_AUTHORITIES @"signingAuthorities"

//file belongs to apple?
#define KEY_SIGNING_IS_APPLE @"signedByApple"

//file signed with apple dev id
#define KEY_SIGNING_IS_APPLE_DEV_ID @"signedWithDevID"

//from app store
#define KEY_SIGNING_IS_APP_STORE @"fromAppStore"

//error URL
#define KEY_ERROR_URL @"errorURL"

//flag for error popup
#define KEY_ERROR_SHOULD_EXIT @"shouldExit"

//general error URL
#define FATAL_ERROR_URL @"https://objective-see.com/errors.html"

//key for stdout output
#define STDOUT @"stdOutput"

//key for stderr output
#define STDERR @"stdError"

//key for exit code
#define EXIT_CODE @"exitCode"

//key for error msg
#define KEY_ERROR_MSG @"errorMsg"

//key for error sub msg
#define KEY_ERROR_SUB_MSG @"errorSubMsg"

//passphrase for CSR
// no, this isn't sensitive
#define CSR_PASSPHRASE @"csr"

//0st sync view
#define SYNC_VIEW_ZERO 0

//1st sync view
#define SYNC_VIEW_ONE 1

//2nd sync view
#define SYNC_VIEW_TWO 2

//3rd sync view
#define SYNC_VIEW_THREE 3

//key for QRC dictionary
#define KEY_PHONE_NUMBER @"phone#"

//auth event notification
#define AUTH_NOTIFICATION @"ca.tarapore.dnd.authNotification"

//dismiss event notification
#define DISMISS_NOTIFICATION @"ca.tarapore.dnd.dismissNotification"

//new user/client notification
#define USER_NOTIFICATION @"ca.tarapore.dnd.userNotification"

//monitoring timeout
#define MONITORING_TIMEOUT 60*3

//unknown user
#define USER_UNKNOWN @"unknown"

#endif

