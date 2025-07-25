#!/bin/bash
 
# Cleanup script that uses swiftdialog for input prompts
  
report_file="$(mktemp).tsv"
 
jamfpro_url="https://myorg.jamfcloud.com"      
 
jamfpro_user=""
 
jamfpro_password=""

listToDelete="
"

# Parse JSON via osascript and JavaScript
function get_json_value() {
    JSON="$1" osascript -l 'JavaScript' \
        -e 'const env = $.NSProcessInfo.processInfo.environment.objectForKey("JSON").js' \
        -e "JSON.parse(env).$2"
}
# --message "Enter list of serial numbers to process as well as jamf pro username and password" \
serialdata=$(/usr/local/bin/dialog --title "Jamf Pro Cleanup" \
                    --message "Enter list of serial numbers to process as well as jamf pro username and password  <br><br>Leave _Delete_ box unchecked to do a trial run" \
                    --textfield "Serial",editor \
                    --textfield "Username" \
                    --textfield "Password",secure \
                    --checkbox "Delete" \
                    --height 600 \
                    --moveable \
                    --icon SF=trash.circle,colour=red \
                    -2 \
                    --json)
returncode=$?

if [[ $returncode -ne 0 ]]; then
    exit
fi

echo $serialdata

listToDelete=$(get_json_value "${serialdata}" "Serial")
jamfpro_user=$(get_json_value "${serialdata}" "Username")
jamfpro_password=$(get_json_value "${serialdata}" "Password")
will_delete=$(get_json_value "${serialdata}" "Delete")


## Auth Token Stuff

# Get username and password encoded in base64 format and stored as a variable in a script:
encodedCredentials=$(printf ${jamfpro_user}:${jamfpro_password} | /usr/bin/iconv -t ISO-8859-1 | /usr/bin/base64 -i -)
# Use encoded username and password to request a token with an API call and store the output as a variable in a script:
authToken=$(/usr/bin/curl "${jamfpro_url}/api/v1/auth/token" --silent --request POST --header "Authorization: Basic ${encodedCredentials}")
# Read the output, extract the token information and store the token information as a variable in a script:
api_token=$(/usr/bin/plutil -extract token raw -o - - <<< "${authToken}")
# Verify that the token is valid and unexpired by making a separate API call, checking the HTTP status code and storing status code information as a variable in a script:
api_authentication_check=$(/usr/bin/curl --write-out %{http_code} --silent --output /dev/null "${jamfpro_url}/api/v1/auth" --request GET --header "Authorization: Bearer ${api_token}")

if [[ ${api_authentication_check} != "200" ]]; then
    echo "Creation of bearer token failed. Error code ${api_authentication_check}"
    echo "TOKEN = ${authToken}"
    echo "jamfpro_user = ${jamfpro_user}"
    echo "JSSURL = ${jamfpro_url}"
    exit
fi

## END Auth Token Stuff

# If the Jamf Pro URL, the account username or the account password aren't available
# otherwise, you will be prompted to enter the requested URL or account credentials.
 
if [[ -z "$jamfpro_url" ]]; then
     read -p "Please enter your Jamf Pro server URL : " jamfpro_url
fi
 
if [[ -z "$jamfpro_user" ]]; then
     read -p "Please enter your Jamf Pro user account : " jamfpro_user
fi
 
if [[ -z "$jamfpro_password" ]]; then
     read -p "Please enter the password for the $jamfpro_user account: " -s jamfpro_password
fi


echo
 
# Remove the trailing slash from the Jamf Pro URL if needed.
jamfpro_url=${jamfpro_url%%/}
 
IFS=$'\n'

echo "Downloading list of computer information..."
ComputerXML=$(curl -sf --header "Authorization: Bearer $api_token" "${jamfpro_url}/JSSResource/computers/subset/basic" -H "Accept: application/xml" 2>/dev/null)
 
# loop through the ids again and delete all computers
 
for serial in ${listToDelete}; do
 
    if [[ ! -f "$report_file" ]]; then
       touch "$report_file"
       printf "Jamf Pro ID Number\tMake\tModel\tSerial Number\tUDID\n" > "$report_file"
    fi
     
    matchingIDs=$(echo "$ComputerXML" | xmllint --xpath "//computers/computer[serial_number='$serial']/id" - 2>/dev/null | grep -Eo "<id[^<]*" | grep -Eo "[0-9]+")
     
    if [[ -z $matchingIDs ]]; then
        echo "Computer record with serial $serial not found. Skipping"
    else
 
        ComputerRecord=$(curl -sf --header "Authorization: Bearer $api_token" "${jamfpro_url}/JSSResource/computers/id/$matchingIDs" -H "Accept: application/xml" 2>/dev/null)
        MachineModel=$(echo "$ComputerRecord" | xmllint --xpath "//computer/hardware/model_identifier/text()" - 2>/dev/null)
 
 
        Make=$(echo "$ComputerRecord" | xmllint --xpath '//computer/hardware/make/text()' - 2>/dev/null)
        SerialNumber=$(echo "$ComputerRecord" | xmllint --xpath '//computer/general/serial_number/text()' - 2>/dev/null)
        UDIDIdentifier=$(echo "$ComputerRecord" | xmllint --xpath '//computer/general/udid/text()' - 2>/dev/null)               
        if [[ $will_delete == "true" ]]; then
            # update ea value
            # Generate the JSON payload
            # Submit unmanage payload to the Jamf Pro Server
            curl -k -s --header "Authorization: Bearer $api_token" -X "PUT" "$jamfpro_url/JSSResource/computers/udid/$UDIDIdentifier/subset/extension_attributes" \
                -H "Content-Type: application/xml" \
                -H "Accept: application/xml" \
                -d "<computer><extension_attributes><extension_attribute><type>String</type><name>Decommissioned</name><value>true</value></extension_attribute></extension_attributes></computer>"

            if [[ $? -eq 0 ]]; then
                echo "Marked computer record with id $matchingIDs as decommissioned"
                printf "$matchingIDs\t$Make\t$MachineModel\t$SerialNumber\t$UDIDIdentifier\n" >> "$report_file"
            else
                echo "ERROR! Failed to update computer record with id $matchingIDs"
            fi
        else
            echo "Will mark computer record with id $matchingIDs for decommission"
            printf "$matchingIDs\t$Make\t$MachineModel\t$SerialNumber\t$UDIDIdentifier\n" >> "$report_file"
        fi
    fi
 
done
 
if [[ -f "$report_file" ]]; then
 echo "Report on deleted Macs available here: $report_file"
fi
             
         
 
exit 0