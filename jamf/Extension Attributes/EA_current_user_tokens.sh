#!/bin/sh
#Get current signed in user

currentUser=$(ls -l /dev/console | awk '/ / { print $3 }')

# if we have the string "ENABLED" in the output, then the user has a SecureToken otherwise they do not
/usr/sbin/sysadminctl -secureTokenStatus $currentUser 2>&1 | grep "ENABLED" && result="ENABLED" || result="DISABLED"

echo "<result>$result</result>"