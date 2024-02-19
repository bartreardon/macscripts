#!/bin/zsh

# (C) 2024 Bart Reardon
#
# This script presents a list of jamf computer prestages and prompts you to select the ID of a source prestage and destination prestage
# will move all devices in the source prestage into the destination one.
#
### This script comes with no warranty or guarantee that it is fit for purpose and definitely could be improved. ###

# account for updading the prestage
JSSURL=""
API_USERNAME=""
API_PASSWORD=""

declare -A prestageList

prestageList=()
serialList=()

selectedOriginPrestageID=""
selectedDestinationPrestageID=""

# this function was sourced from https://stackoverflow.com/a/26809278
function json_array() {
  echo -n '['
  while [ $# -gt 0 ]; do
    x=${1//\\/\\\\}
    echo -n \"${x//\"/\\\"}\"
    [ $# -gt 1 ] && echo -n ', '
    shift
  done
  echo ']'
}

json() {
    # Usage: json <command> [path] [value] <json>
    # sources from https://github.com/bartreardon/macscripts/blob/master/json_via_sqlite.sh

    local json_command=$1 # first argument
    local json_data=${@[$#]} # last argument

    # Process optional arguments if present
    case "$#" in
        2) ;;
        3) path=$2;;
        4) path=$2; value=$3 ;;
    esac

    # process json command
    case "$json_command" in
        "extract")
            result=$(/usr/bin/sqlite3 /dev/null "SELECT json_extract('${json_data}', '$.$path');")
            echo $result
            ;;
        "array_length")
            result=$(/usr/bin/sqlite3 /dev/null "SELECT json_array_length('${json_data}', '$.$path');")
            echo $result
            ;;
        *)
            logger "Unknown command $json_command"
            exitScript 1
            ;;
    esac
}

### Get Bearer Token - https://derflounder.wordpress.com/2021/12/10/obtaining-checking-and-renewing-bearer-tokens-for-the-jamf-pro-api/ 
encodedCredentials=$(printf ${API_USERNAME}:${API_PASSWORD} | /usr/bin/iconv -t ISO-8859-1 | /usr/bin/base64 -i -)

# Use encoded username and password to request a token with an API call and store the output as a variable in a script:
authToken=$(/usr/bin/curl "https://${JSSURL}/api/v1/auth/token" --silent --request POST --header "Authorization: Basic ${encodedCredentials}")
# Read the output, extract the token information and store the token information as a variable in a script:
api_token=$(/usr/bin/plutil -extract token raw -o - - <<< "${authToken}")
# Verify that the token is valid and unexpired by making a separate API call, checking the HTTP status code and storing status code information as a variable in a script:
api_authentication_check=$(/usr/bin/curl --write-out %{http_code} --silent --output /dev/null "https://${JSSURL}/api/v1/auth" --request GET --header "Authorization: Bearer ${api_token}")

if [[ ${api_authentication_check} != "200" ]]; then
    echo "Creation of bearer token failed. Error code ${api_authentication_check}"
    echo "TOKEN = ${authToken}"
    echo "API_USERNAME = ${API_USERNAME}"
    echo "JSSURL = ${JSSURL}"
    exit
fi

### END Bearer token section

# get a list of all PreStage Enrollments
preStageJSON=$( /usr/bin/curl -s "https://${JSSURL}/api/v3/computer-prestages?page=0&page-size=100" \
    --header "Authorization: Bearer $api_token" \
    --header "Accept: application/json" )

totalCount=$(json extract "totalCount" "$preStageJSON")

# build the prestage list 
for i in {0..$(( $totalCount - 1 ))}; do
    prestageID=$(json extract "results[$i].id" "$preStageJSON")
    prestageName=$(json extract "results[$i].displayName" "$preStageJSON")
    echo "ID: $prestageID - $prestageName"
    prestageList[$prestageID]="$prestageName"
done

# print and select an origin prestage
echo "Select the origin PreStage Enrollment"
read "?Enter the PreStage ID: " selectedOriginPrestageID
# check selected prestage is in the list
if [[ -z ${prestageList[$selectedOriginPrestageID]} ]]; then
    echo "Invalid PreStage ID"
    exit 1
fi
echo "Selected origin PreStage Enrollment: $selectedOriginPrestageID - ${prestageList[$selectedOriginPrestageID]}"

# print and select a destination prestage
echo "Select the destination PreStage Enrollment"
read "?Enter the PreStage ID: " selectedDestinationPrestageID
# check selected prestage is in the list
if [[ -z ${prestageList[$selectedDestinationPrestageID]} ]]; then
    echo "Invalid PreStage ID"
    exit 1
fi
echo "Selected destination PreStage Enrollment: $selectedDestinationPrestageID - ${prestageList[$selectedDestinationPrestageID]}"

# get the serial numbers of the devices to be moved from the origin prestage
sourcePrestageJSON=$( /usr/bin/curl -s "https://${JSSURL}/api/v2/computer-prestages/${selectedOriginPrestageID}/scope" \
    --header "Authorization: Bearer $api_token" \
    --header "Accept: application/json" )

sourceCount=$(json array_length "assignments" "$sourcePrestageJSON")
sourceVersionLock=$(json extract "versionLock" "$sourcePrestageJSON")

destinationPrestageJSON=$( /usr/bin/curl -s "https://${JSSURL}/api/v2/computer-prestages/${selectedDestinationPrestageID}/scope" \
    --header "Authorization: Bearer $api_token" \
    --header "Accept: application/json" )

destinationVersionLock=$(json extract "versionLock" "$destinationPrestageJSON")
echo "Destination version lock: $destinationVersionLock"

if [[ -z $destinationVersionLock ]]; then
    echo "Destination prestage has no version lock"
    exit 1
fi

# build the serial list from source prestage

echo "Source count: $sourceCount"
echo -n "Processing source prestage"
for i in {0..$(( $sourceCount - 1 ))}; do
    serialNumber=$(json extract "assignments[$i].serialNumber" "$sourcePrestageJSON")
    serialList+="$serialNumber"
    echo -n "."
done
echo "Done processing source prestage."

#### Process

# format serial number list for json
formattedSerialNumberList=$( json_array "${serialList[@]}" )

# create json data from source prestage
sourceJSONData="{
  \"serialNumbers\": $formattedSerialNumberList,
  \"versionLock\": $sourceVersionLock
}"

# create json data for destination prestage
destinationJSONData="{
  \"serialNumbers\": $formattedSerialNumberList,
  \"versionLock\": $destinationVersionLock
}"

# echo "Source JSON: $sourceJSONData"

# echo "Destination JSON: $destinationJSONData"
# current date in yyymmdd format
currentDate=$(date "+%Y%m%d")
tempFile="/tmp/moved_devices_${currentDate}.txt"

# prompt to continue
echo ""
echo "This will move ${sourceCount} devices from the origin PreStage Enrollment to the destination PreStage Enrollment"
echo "Origin PreStage Enrollment      : $selectedOriginPrestageID - ${prestageList[$selectedOriginPrestageID]}"
echo "Destination PreStage Enrollment : $selectedDestinationPrestageID - ${prestageList[$selectedDestinationPrestageID]}"
echo ""
echo "'y' to continue, any key to exit and print serial numbers"
echo ""
read "?Continue? (y/n): " continue

if [[ $continue != "y" ]]; then
    echo "Exiting"
    echo $formattedSerialNumberList > "$tempFile"
    echo "Device list saved to $tempFile"
    exit 0
fi

# remove devices from source prestage
removeDevicesResultJSON=$(/usr/bin/curl "https://${JSSURL}/api/v2/computer-prestages/$selectedOriginPrestageID/scope/delete-multiple" \
--silent \
--request POST \
--header "Authorization: Bearer $api_token" \
--header "Accept: application/json" \
--header "Content-Type: application/json" \
--data ''"$sourceJSONData"'')
exitcode=$?
if [[ $exitcode -ne 0 ]]; then
    echo "Failed to remove devices from origin prestage"
    echo "ERROR:"
    echo $removeDevicesResultJSON
    echo "JSON Data:"
    echo $sourceJSONData
    exit 1
fi

# check result
removeHTTPStatus=$(json extract "httpStatus" "$removeDevicesResultJSON")
if  [[ -n $removeHTTPStatus ]]; then
    echo "Failed to remove devices from origin prestage"
    echo "ERROR:"
    echo $removeDevicesResultJSON
    exit 1
else
    echo "Devices removed from origin prestage"
    echo $removeDevicesResultJSON > /tmp/removeDevicesResultJSON_${currentDate}.txt
    echo "Results saved to /tmp/removeDevicesResultJSON_${currentDate}.txt"
fi

# submit new scope for destination prestage
putDevicesResultsJSON=$(/usr/bin/curl "https://${JSSURL}/api/v2/computer-prestages/$selectedDestinationPrestageID/scope" \
--silent \
--request PUT \
--header "Authorization: Bearer $api_token" \
--header "Accept: application/json" \
--header "Content-Type: application/json" \
--data ''"$destinationJSONData"'')
exitcode=$?
if [[ $exitcode -ne 0 ]]; then
    echo "Failed to add devices to destination prestage"
    echo "ERROR:"
    echo $putDevicesResultsJSON
    echo "JSON Data:"
    echo $destinationJSONData
    exit 1
fi
# check result
putHTTPStatus=$(json extract "httpStatus" "$putDevicesResultsJSON")
if  [[ -n $putHTTPStatus ]]; then
    echo "Failed to add devices to destination prestage"
    echo "ERROR:"
    echo $putDevicesResultsJSON
    exit 1
else
    echo "Devices added to destination prestage"
    echo $putDevicesResultsJSON > /tmp/putDevicesResultsJSON_${currentDate}.txt
    echo "Results saved to /tmp/putDevicesResultsJSON_${currentDate}.txt"
fi

echo "Devices moved from :"
echo "    origin ${prestageList[$selectedOriginPrestageID]}"
echo "  to:"
echo "    destination ${prestageList[$selectedDestinationPrestageID]}"
# save device list to file
echo $formattedSerialNumberList > "$tempFile"
echo "Device list saved to $tempFile"

# expire the auth token
/usr/bin/curl "$URL/uapi/auth/invalidateToken" \
--silent \
--request POST \
--header "Authorization: Bearer $api_token"

exit 0
