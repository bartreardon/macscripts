#!/bin/zsh

# Fetch all policies that use Installomator and output the labels
# This assumes two things:
#  1 - That you have one or more Installomator scripts in your jamf pro instance 
#      and that the name starts with "Installomator"
#  2 - Any policies that use said scripts also start with "Installomator"
#      A more robust method would be to query every policy and check if it uses any of the
#      scripts identified in step 1 but that would take some time. 

ENCODED_CREDENTIALS="<creds>"
JSSURL="myorg.jamfcloud.com"

# properties we're going to fill up
policyIDList=()
installomatorLabelList=()

# this is a list of jamf pro script ID's that represent the various versions of Installomator that might be in use
installomatorScriptIDs=()

# this script needs jq so check for that
if ! which jq >/dev/null; then
    echo "jq not installed - exiting"
    exit 1
fi

getAPIToken() {
    ### Get Bearer Token - https://derflounder.wordpress.com/2021/12/10/obtaining-checking-and-renewing-bearer-tokens-for-the-jamf-pro-api/ 
    # Get username and password encoded in base64 format and stored as a variable in a script:
    local JSSURL=$1
    local ENCODED_CREDENTIALS=$2
    # Use encoded username and password to request a token with an API call and store the output as a variable in a script:
    local AUTH_TOKEN=$(/usr/bin/curl "https://${JSSURL}/api/v1/auth/token" --silent --request POST --header "Authorization: Basic ${ENCODED_CREDENTIALS}")
    # Read the output, extract the token information and store the token information as a variable in a script:
    local API_TOKEN=$(/usr/bin/plutil -extract token raw -o - - <<< "${AUTH_TOKEN}")
    # Verify that the token is valid and unexpired by making a separate API call, checking the HTTP status code and storing status code information as a variable in a script:
    local API_AUTH_CHECK=$(/usr/bin/curl --write-out %{http_code} --silent --output /dev/null "https://${JSSURL}/api/v1/auth" --request GET --header "Authorization: Bearer ${API_TOKEN}")

    if [[ ${API_AUTH_CHECK} != "200" ]]; then
        echo "Creation of bearer token failed. Error code ${API_AUTH_CHECK}"
        echo "TOKEN = ${AUTH_TOKEN}"
        echo "JAMFUSER = ${JAMFUSER}"
        echo "JSSURL = ${JSSURL}"
        exit
    fi
    echo "${API_TOKEN}"
    ### END Bearer token section
}

getJSONFromJSSResourceAPI() {
    api=$1
    token=$2
    curl_args=(--write-out "\n%{http_code}" --fail --silent --request GET --header "accept: application/json" --header "Authorization: Bearer ${token}")
    if ! output=$(curl "${curl_args[@]}" "https://${JSSURL}/${api}"); then
        echo "Failure: code=$output"
        exit 1
    else
        sed '$ d' <<<"$output"
    fi    
}

API_TOKEN=$(getAPIToken "$JSSURL" "$ENCODED_CREDENTIALS")

# get a list of all scripts that start with "Installomator"
scriptsJSON=$(getJSONFromJSSResourceAPI "api/v1/scripts?page=0&page-size=100&sort=id%3Aasc&filter=name%3D%3D%22Installomator%2A%22" "${API_TOKEN}")
installomatorScriptIDs=($(jq -r '.results[] | .id' <<< "${scriptsJSON}"))

# fetch all policies from Jamf
policyJSON=$(getJSONFromJSSResourceAPI "JSSResource/policies" "${API_TOKEN}")

# read in all the policy ID's that have "Installomator"
policyIDList=($(echo $policyJSON | jq '.policies[] | select(.name | startswith("Installomator")) | .id'))

# pull the ID record and extract the installomator label
for id in $policyIDList; do
    policyDetailForID=$(getJSONFromJSSResourceAPI "JSSResource/policies/id/${id}" "${API_TOKEN}")
    name=$(jq -r '.policy.general.name' <<< "${policyDetailForID}")
    enabled=$(jq -r '.policy.general.enabled' <<< "${policyDetailForID}")
    echo "Processing ID $id - $name"
    if [[ "$enabled" == "true" ]]; then
        installomatorLabelList+=$(jq -r '.policy.scripts[] | select(.id == ('${(j:, :)installomatorScriptIDs}')) | .parameter4' <<< "${policyDetailForID}")
    else
        echo "   Disabled"
    fi
done

echo "\n-------"
echo "Installimator labels in use:"
echo $installomatorLabelList[@]

