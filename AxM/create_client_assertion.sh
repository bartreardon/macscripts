#!/bin/zsh

# zsh version of Implementing OAuth for the Apple School and Business Manager API
#   https://developer.apple.com/documentation/apple-school-and-business-manager-api/implementing-oauth-for-the-apple-school-and-business-manager-api
#
# Created by Bart Reardon, June 11, 2025 

# Requirements:
#   Private key downloaded from Apple Business Manager or Apple School Manager
#   Client ID - Found in the "Manage" info pane for the API key in ABM/ASM
#   Key ID    - Found in the "Manage" info pane for the API key in ABM/ASM

# Usage:
# ./create_client_assertion.sh <path_to_key.pem> <client_id> <key_id>
# Example:
# ./create_client_assertion.sh "private-key.pem" "BUSINESSAPI.9703f56c-10ce-4876-8f59-e78e5e23a152" "d136aa66-0c3b-4bd4-9892-c20e8db024ab"

# The JWT generated is valid for 180 days and does not need to be re-generated every time you want to use it
# Create the JWT once, then use that when requesting a bearer token from the ABM/ASM API.
# re-create once it has expired.

private_key_file="${1:-private-key.pem}"
client_id="$2"
team_id="$client_id"
key_id="$3"
audience="https://account.apple.com/auth/oauth2/v2/token"
alg="ES256"

iat=$(date -u +%s)
exp=$((iat + 86400 * 180))
jti=$(uuidgen)

# Check to see if we have all our stuff
if [[ ! -e $private_key_file ]]; then
  echo "Private key $private_key_file can't be found"
  exit 1
fi
if [[ -z $client_id ]] || [[ -z $key_id ]]; then
  echo "Client ID or Key ID are missing"
  echo "Client ID: $client_id"
  echo " Key ID: $key_id"
  exit 1
fi

# base64url encode
b64url() {
  # Encode base64 to url safe format
  echo -n "$1" | openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

pad64() {
  # Pad ECDSA signature on the left with 0s until it is exactly 64 characters long (i.e., 32 bytes = 64 hex digits)
  local hex=$1
  printf "%064s" "$hex" | tr ' ' 0
}

# JWT sections
header=$(jq -nc --arg alg "$alg" --arg kid "$key_id" '{alg: $alg, kid: $kid, typ: "JWT"}')
payload=$(jq -nc \
  --arg sub "$client_id" \
  --arg aud "$audience" \
  --argjson iat "$iat" \
  --argjson exp "$exp" \
  --arg jti "$jti" \
  --arg iss "$team_id" \
  '{sub: $sub, aud: $aud, iat: $iat, exp: $exp, jti: $jti, iss: $iss}')

header_b64=$(b64url "$header")
payload_b64=$(b64url "$payload")
signing_input="${header_b64}.${payload_b64}"

# Create temporary file
sigfile=$(mktemp /tmp/sig.der.XXXXXX)

# Sign using EC private key, output raw DER binary to file
echo -n "$signing_input" | openssl dgst -sha256 -sign ${private_key_file} > "$sigfile"

# Extract R and S integers using ASN1 parse
r_hex=""
s_hex=""
i=0

while read -r line; do
  hex=$(echo "$line" | awk -F: '/INTEGER/ {print $NF}')
  if [[ -n "$hex" ]]; then
    if [[ $i -eq 0 ]]; then
      r_hex="$hex"
    elif [[ $i -eq 1 ]]; then
      s_hex="$hex"
    fi
    ((i++))
  fi
done < <(openssl asn1parse -in "$sigfile" -inform DER 2>/dev/null)

# Clean up the sig file as we no longer need it
rm $sigfile

# create R and S values
r=$(pad64 "$r_hex")
s=$(pad64 "$s_hex")

# Convert signature to base64  
rs_b64url=$(echo "$r$s" | xxd -r -p | openssl base64 -A | tr '+/' '-_' | tr -d '=')

# form the completed JWT
jwt="${signing_input}.${rs_b64url}"

echo "$jwt" > client_assertion.txt
echo "✅ JWT written to client_assertion.txt"
echo "JWT valid until $(date -r $exp)"

###### Requesting a bearer token #######
## Put this in a seperate script and pass in the path to your client_assertion.txt 

## Client Assertion generated with the create_client_assertion.sh script (the actual content of the file, not the file itself)
# client_assert="$1"
## or if you want to use the file
# client_assert=$(cat $1)

## Client ID from ABM/ASM
# client_id="$2"

# request_json=$(curl -s -X POST \
# -H 'Host: account.apple.com' \
# -H 'Content-Type: application/x-www-form-urlencoded' \
# "https://account.apple.com/auth/oauth2/token?grant_type=client_credentials&client_id=${client_id}&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer&client_assertion=${client_assert}&scope=business.api")

# ACCESS_TOKEN=$(echo $request_json | jq -r '.access_token')

## Access token is valid for 1 hour

## Fetch all organisational devices:
# curl "https://api-business.apple.com/v1/orgDevices" -H "Authorization: Bearer ${ACCESS_TOKEN}"

## https://developer.apple.com/documentation/applebusinessmanagerapi
