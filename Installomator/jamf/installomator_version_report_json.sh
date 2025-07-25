#!/bin/zsh

#
# Process the list of labels, download directly from the Installomator git repo
# process the labels and report the version number
# Will also record the last run in a file and compare against the last known version
# If there is a new version, a report is generated with the updated labels and what version is the latest
# 

# Fetch all policies that use Installomator and output the labels

JAMFUSER=""
JAMFPASS=""
JSSURL="myorg.jamfcloud.com"

RAWInstallomatorURL="https://raw.githubusercontent.com/Installomator/Installomator/main"

# properties we're going to fill up
policyIDList=()
labels=()
installomatorLabelList=()
# this is a list of jamf pro script ID's that represent the various versions of Installomator that might be in use
installomatorScriptIDs=()

# Initial json data for storing policy information
jsonData=$(jq -n '{"policies": []}')


# this script needs jq so check for that
if ! which jq >/dev/null; then
    echo "jq not installed - exiting"
    exit 1
fi


getAPIToken() {
    ### Get Bearer Token - https://derflounder.wordpress.com/2021/12/10/obtaining-checking-and-renewing-bearer-tokens-for-the-jamf-pro-api/ 
    JAMFUSER="$1"
    JAMFPASS="$2"
    # Get username and password encoded in base64 format and stored as a variable in a script:
    ENCODED_CREDENTIALS=$(printf ${JAMFUSER}:${JAMFPASS} | /usr/bin/iconv -t ISO-8859-1 | /usr/bin/base64 -i -)
    # Use encoded username and password to request a token with an API call and store the output as a variable in a script:
    AUTH_TOKEN=$(/usr/bin/curl "https://${JSSURL}/api/v1/auth/token" --silent --request POST --header "Authorization: Basic ${ENCODED_CREDENTIALS}")
    # Read the output, extract the token information and store the token information as a variable in a script:
    API_TOKEN=$(/usr/bin/plutil -extract token raw -o - - <<< "${AUTH_TOKEN}")
    # Verify that the token is valid and unexpired by making a separate API call, checking the HTTP status code and storing status code information as a variable in a script:
    API_AUTH_CHECK=$(/usr/bin/curl --write-out %{http_code} --silent --output /dev/null "https://${JSSURL}/api/v1/auth" --request GET --header "Authorization: Bearer ${API_TOKEN}")

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
    curl -sX "GET" \
        "https://${JSSURL}/JSSResource/${api}" \
        -H "accept: application/json" \
        -H "Authorization: Bearer ${token}"
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

labelFromInstallomator() {
    echo "${RAWInstallomatorURL}/fragments/labels/$1.sh"
}

appendJSONData() {
    echo "Appending $1"
    newData=$(jq --argjson newdata "$1" '.policies += [$newdata]' <<< "${jsonData}")
    if [[ $? -eq 0 ]]; then
        jsonData=$newData
    else
        echo "Error appending data"
    fi
}


loadInstallomator() {
    # load functions from Installomator
    functionsPath="/private/tmp/functions.sh"
    curl -sL ${RAWInstallomatorURL}/fragments/functions.sh -o "${functionsPath}"
    source "${functionsPath}"
}

cleanup() {
    # clean up Installomator Functions
    functionsPath="/private/tmp/functions.sh"
    rm "$functionsPath"
}

getVersionForLabel() {
    label=$1
    local appNewVersion=""
    local name=""

    # Installomator settings (helps avoid warnings with some labels)
    LOGGING=INFO
    log_priority=INFO
    declare -A levels=(DEBUG 0 INFO 1 WARN 2 ERROR 3 REQ 4)

    # get label fragment from Installomator repo
    fragment=$(curl -sL $(labelFromInstallomator $label))
    if [[ "$fragment" == *"404"* ]]; then
        echo "no fragment"
        continue
    fi
    
    # Process the fragment in a case block which should match the label
    caseStatement="
    case $label in
        $fragment
        *)
            echo \"$label didn't match anything in the case block - weird.\"
        ;;
    esac
    "
    eval $caseStatement

    if [[ ! $? == 0 ]]; then
        # something went wrong
        echo "Error fetching version info"
        continue
    fi
    
    if [[ -n $name ]]; then
        if [[ -n "$appNewVersion" ]]; then
            echo "$appNewVersion"
        else
            echo "no version info"
        fi
    fi
}

API_TOKEN=$(getAPIToken "$JAMFUSER" "$JAMFPASS")

# get a list of all scripts that start with "Installomator"
scriptsJSON=$(getJSONFromJSSResourceAPI "api/v1/scripts?page=0&page-size=100&sort=id%3Aasc&filter=name%3D%3D%22Installomator%2A%22" "${API_TOKEN}")
installomatorScriptIDs=($(jq -r '.results[] | .id' <<< "${scriptsJSON}"))

# fetch all policies from Jamf
policyJSON=$(getJSONFromJSSResourceAPI "JSSResource/policies" "${API_TOKEN}")

# read in all the policy ID's that have "Installomator"
policyIDList=($(echo $policyJSON | jq '.policies[] | select(.name | startswith("Installomator")) | .id'))


# load functions from Installomator
loadInstallomator

count=0
# pull the ID record and extract the installomator label
for id in $policyIDList; do
    policyDetailForID=$(getJSONFromJSSResourceAPI "JSSResource/policies/id/${id}" "${API_TOKEN}")
    name=$(jq -r '.policy.general.name' <<< "${policyDetailForID}")
    # split name on " - " and take the last part, trimming any leading whitespace
    appName=$(echo $name | awk -F' - ' '{print $NF}' | xargs)

    enabled=$(jq -r '.policy.general.enabled' <<< "${policyDetailForID}")
    echo "Processing ID $id - $name"
    if [[ "$enabled" == "true" ]]; then
        installomatorLabel=$(jq -r '.policy.scripts[] | select(.id == ('${(j:, :)installomatorScriptIDs}')) | .parameter4' <<< "${policyDetailForID}")
        labelVersion=$(getVersionForLabel $installomatorLabel)
        # create new json item
        jsonItem="{\"id\": $id, \"policyName\": \"$name\", \"name\": \"$appName\", \"label\": \"$installomatorLabel\", \"version\": \"$labelVersion\"}"
        appendJSONData "${jsonItem}"
    else
        echo "   Disabled"
    fi
    # if count is greater than 5 them break
    #if [[ $count -gt 5 ]]; then
    #    break
    #fi
    count=$((count+1))
done

# print out the json data
echo "Processed $count policies"
echo "Json Data:"
echo $jsonData

# clean up Installomator Functions
cleanup


