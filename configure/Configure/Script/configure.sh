#!/bin/bash

#
#  file: configure.sh
#  project: DND (configure)
#  description: install/uninstall (privileged file operations only)
#  note: daemon registration is handled by SMAppService in Configure.m
#        this script is run with admin privileges via osascript
#
#  usage: configure.sh <resources_path> <-install|-uninstall> [1 for full uninstall]
#
#  created by Patrick Wardle
#  copyright (c) 2018 Objective-See. All rights reserved.
#

RESOURCES_DIR="${1}"
ACTION="${2}"
FULL_UNINSTALL="${3}"

INSTALL_DIRECTORY="/Library/Objective-See/DND"

#validate resources path
if [ -z "$RESOURCES_DIR" ] || [ ! -d "$RESOURCES_DIR" ]; then
    echo "ERROR: resources path not provided or does not exist: $RESOURCES_DIR"
    exit 1
fi

#install
if [ "${ACTION}" == "-install" ]; then

    echo "installing from $RESOURCES_DIR"

    #install main app (daemon bundle is already embedded inside it at Contents/Library/LaunchDaemons/)
    # SMAppService will register the daemon from inside the app bundle
    mv "$RESOURCES_DIR/Do Not Disturb.app" /Applications/

    #set correct ownership on the embedded daemon bundle so launchd accepts it
    chown -R root:wheel "/Applications/Do Not Disturb.app/Contents/Library/LaunchDaemons"

    #remove quarantine xattrs
    xattr -rc "/Applications/Do Not Disturb.app"

    echo "main app installed"

    #launch main app as the logged-in console user (not root)
    # the main app will register the launch daemon via SMAppService on first launch
    # use launchctl asuser to correctly adopt the user session (sudo has no tty here)
    consoleUID=$(id -u "$(stat -f "%Su" /dev/console)" 2>/dev/null)
    if [ -n "$consoleUID" ] && [ "$consoleUID" != "0" ]; then
        launchctl asuser "$consoleUID" open -g "/Applications/Do Not Disturb.app" &
    else
        open -g "/Applications/Do Not Disturb.app" &
    fi

    echo "install complete"
    exit 0

#uninstall
elif [ "${ACTION}" == "-uninstall" ]; then

    echo "uninstalling"

    #kill main app
    # ...it might be open
    killall "Do Not Disturb" 2> /dev/null

    #full uninstall?
    # tell daemon to perform uninstall logic (delete IDs, etc)
    if [[ "${FULL_UNINSTALL}" -eq "1" ]]; then
        "/Applications/Do Not Disturb.app/Contents/Library/LaunchDaemons/Do Not Disturb.bundle/Contents/MacOS/Do Not Disturb" "-uninstall" 2>/dev/null
    fi

    echo "removing files"

    #uninstall & remove main app
    rm -rf "/Applications/Do Not Disturb.app"

    #full uninstall?
    # delete DND's folder with everything
    if [[ "${FULL_UNINSTALL}" -eq "1" ]]; then
        rm -rf "$INSTALL_DIRECTORY"

        #no other objective-see tools?
        # then delete that directory too
        baseDir=$(dirname "$INSTALL_DIRECTORY")

        if [ ! "$(ls -A "$baseDir")" ]; then
            rm -rf "$baseDir"
        fi

    #partial uninstall
    # daemon bundle is inside the app (removed above), prefs stay in INSTALL_DIRECTORY
    else
        : #nothing extra to remove
    fi

    #kill login item and helper
    killall "Do Not Disturb" 2> /dev/null
    killall "Do Not Disturb Helper" 2> /dev/null

    echo "uninstall complete"
    exit 0
fi

#invalid args
echo "ERROR: run w/ '-install' || '-uninstall'"
exit 1
