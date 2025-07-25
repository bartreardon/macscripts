#!/bin/bash

# check Safari version
SAFARIVERSION=$(defaults read /Applications/Safari.app/Contents/Info.plist CFBundleShortVersionString | awk -F"." '{print $1}')
WHITELIST="some.domain.com"

# only run if safari version is 11 or greater
if [[ ${SAFARIVERSION} < 11 ]]; then
    exit 0
fi

for user in $(dscl . list /Users | grep -v ^_.*); do
    # if user id is < 500 or there is no home folder then skip over
    if [[ ! $(id -u ${user}) -gt 500 ]] || [[ ! -d /Users/${user} ]]; then
        continue
    fi

    PREFDB="/Users/${user}/Library/Safari/PerSitePreferences.db"

    # PerSitePreferences.db won'r exist if there's been no prefrences set ever - need to create one
    if [[ ! -f ${PREFDB} ]]; then
        echo "no PerSitePreferences.db was detected"
        exit 0
    fi

    PREFVALUE=`echo "select preference_value from preference_values where domain = '${WHITELIST}';" | sqlite3 ${PREFDB}`

    if [[ $PREFVALUE == "" ]]; then
        echo "Need to set whitelist for ${user}"
        echo "INSERT INTO preference_values (domain, preference, preference_value) VALUES ('${WHITELIST}', 'PerSitePreferencesAutoplay', 0);" | sqlite3 ${PREFDB}
    else
        echo "whitelist already set for ${user}"
    fi
done
