#!/bin/zsh

#
# Process the list of labels, download directly from the Installomator git repo
# process the labels and report the version number
# Will also record the last run in a file and compare against the last known version
# If there is a new version, a report is generated with the updated labels and what version is the latest
# 


# labels we want to process
labels=(
    "microsoftoffice365"
    "python"
    "microsoftedge"
    "alfred"
    "caffeine"
    "citrixworkspace"
    "coconutbattery"
    "adobecreativeclouddesktop"
    "cyberduck"
    "docker"
    "easyfind"
    "firefoxpkg"
    "gimp"
    "handbrake"
    "iterm2"
    "itsycal"
    "krita"
    "latexit"
    "macadminspython"
    "mendeleyreferencemanager"
    "miniconda"
    "rectangle"
    "sourcetree"
    "suspiciouspackage"
    "vlc"
    "zotero"
    "zulujdk17"
    "displaylinkmanager"
    "drawio"
    "googlechrome"
    "jetbrainsintellijideace"
    "r"
    "microsoftvisualstudiocode"
    "webex"
    "microsoftword"
    "xquartz"
)

brokenLabels=(
    "acorn"
    "adium"
    "bibdesk"
    "franz"
    "texshop"
    "gitfinder"
    "texshop"
    "realvncviewer"
)

RAWInstallomatorURL="https://raw.githubusercontent.com/Installomator/Installomator/main"

appListFile="/Users/Shared/applist.txt"
mailMessageFile="/Users/Shared/mailmessage.txt"

# backup existing file
if [[ -e ${appListFile} ]]; then
    cp "${appListFile}" "${appListFile}-$(date '+%Y-%d-%m')"
else
    touch "${appListFile}"
fi

# remove any previous mail message
if [[ -e "${mailMessageFile}" ]]; then
    rm "${mailMessageFile}"
fi

# load functions from Installomator
functionsPath="/var/tmp/functions.sh"
curl -sL ${RAWInstallomatorURL}/fragments/functions.sh -o "${functionsPath}"
source "${functionsPath}"

# additional functions
writeMailMessageFile() {
    echo "${1}" | tee -a "$mailMessageFile"
}

labelFromInstallomator() {
    echo "${RAWInstallomatorURL}/fragments/labels/$1.sh"
}

# Installomator settings
LOGGING=INFO
log_priority=INFO
declare -A levels=(DEBUG 0 INFO 1 WARN 2 ERROR 3 REQ 4)

# process each label
for label in $labels; do
    echo "Processing label $label ..."

    # get label fragment from Installomator repo
    fragment=$(curl -sL $(labelFromInstallomator $label))
    if [[ "$fragment" == *"404"* ]]; then
        writeMailMessageFile "🚨 no fragment for label $label 🚨"
        continue
    fi
    
    # trim the first lines and anything from ;; onward since we want to eval the label, not use it in a switch statement
    # this assumes the first line after the pattern is `name=`
    fragment=$(echo "$fragment" | sed -n '/name=/,$p' | sed -e '/;;/,$d')

    eval $fragment
    if [[ ! $? == 0 ]]; then
        # something went wrong
        writeMailMessageFile "🚨 ERROR: There was an issue processing fragment for label $label 🚨"
    fi
    
    if [[ -n $name ]]; then
        previousVersion=$(grep -e "^${name} " ${appListFile} | awk '{print $NF}')
        # read -s -k '?Press any key to continue.'
        if [[ -n "$appNewVersion" ]]; then
            if [[ "$previousVersion" != "$appNewVersion" ]]; then
                if [[ -z $previousVersion ]]; then 
                    writeMailMessageFile "⭐️ New App $name -> $appNewVersion"
                    # app not found - add to the  appListFile 
                    echo "$name $appNewVersion" >> ${appListFile}
                else
                    writeMailMessageFile "📡 Updating $name from $previousVersion -> $appNewVersion"
                    # update the  appListFile 
                    sed -i "" "s/^$name .*/$name $appNewVersion/g"  ${appListFile}
                fi
                formattedOutput+="$name $appNewVersion, "
            else
                writeMailMessageFile "✅ No Update for $name -> $appNewVersion"
            fi
        else
            writeMailMessageFile "🤔 $name has no version info"
        fi
    fi
    unset appNewVersion
    unset name
    unset previousVersion
done

writeMailMessageFile "**** text for report"
writeMailMessageFile ""
writeMailMessageFile $formattedOutput
writeMailMessageFile ""
writeMailMessageFile "****"

# clean up Installomator Functions 
rm "$functionsPath"

## Email the report

## Update this array with extra email addresses as needed
SMTP_TO=("persone.one@example.com" "persone.two@example.com")

SMTP_SERVER="smtp.myorg.com"
SMTP_RC="set smtp=${SMTP_SERVER}"
MAIL_RC_FILE="mail.rc"
if [[ $(id -u) == 0 ]]; then
    MAIL_RC_ROOT="/etc"
else
    MAIL_RC_ROOT="/Users/${USER}"
fi
MAIL_RC="${MAIL_RC_ROOT}/${MAIL_RC_FILE}"


SMTP_FROM="installomator_noreply@example.com"

SUBJECT="Installomator update report"

TEXT_FILENAME="update.log"
MESSAGE_FILE="mail_msg.txt"

RELAY="set smtp=${SMTP_SERVER}"

# check to see if global mailer settings are set
grep -s "${SMTP_RC}" "${MAIL_RC}"
if [[ ! $? == 0 ]]; then
    echo "${SMTP_RC}" | tee -a "${MAIL_RC}"
fi

export REPLYTO=$SMTP_FROM


# Send the email using the 'mail' command
cat "${mailMessageFile%,*}" | mail -s "$SUBJECT" -u installomator_noreply $SMTP_TO

