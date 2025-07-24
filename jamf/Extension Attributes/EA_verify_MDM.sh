#!/bin/sh
#replace with MDM profile ID
mdmEnrollmentProfileID="00000000-0000-0000-0000-000000000000"
enrolled=`/usr/bin/profiles -C | /usr/bin/grep "$mdmEnrollmentProfileID"`

if [ "$enrolled" != "" ]; then
    echo "<result>Enrolled</result>"
else
    echo "<result>Not Enrolled</result>"
fi