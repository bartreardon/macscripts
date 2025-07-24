#!/bin/bash

# injector

# inject boot scripts into unbooted OS X system for thin clinet deployment
# run from bootted USB drive/recovery partition

# get boot volume (only works when not booted to the current boot volume)
bootVol=$(df | grep $(bless -info --getboot) | awk '{printf $9; i = 10; while ($i != "") { printf " "$i; i++ }}')

mkdir "$bootVol/etc/injector"

# copy assets to boot volume
# can be script to add admin user, set conditions for software install etc.v

cp /Install/addmacadmin.sh "$bootVol/etc/injector/"
chmod a+x "$bootVol/etc/injector/addmacadmin.sh"
cp /Install/addmacadmin.plist "$bootVol/Library/LaunchDaemons/addmacadmin.plist"

cp -R /Install "$bootVol/etc/injector/"

sleep 0.5

touch "$bootVol/var/db/.AppleSetupDone"

shutdown -r now

# end injector
# here is a comment
