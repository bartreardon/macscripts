#!/bin/bash

DEFAULTS=/usr/bin/defaults
CLIENT_IDENTIFIER="/Library/Preferences/ManagedInstalls ClientIdentifier"
CURRENT_CI=$($DEFAULTS read $CLIENT_IDENTIFIER)
NEW_CI="ManagedSoftware"
BOOTSTRAP_CI="bootstrap"
STARTUP_CHECK_FILE=/Users/Shared/.com.googlecode.munki.checkandinstallatstartup

if [[ $CURRENT_CI == $BOOTSTRAP_CI && ! -f $STARTUP_CHECK_FILE ]]; then
	echo "we need to change the ient identifier"
	$DEFAULTS write $CLIENT_IDENTIFIER $NEW_CI
fi

exit 1
