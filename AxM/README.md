## AxM API Authentication

zsh version of Implementing OAuth for the Apple School and Business Manager API

https://developer.apple.com/documentation/apple-school-and-business-manager-api/implementing-oauth-for-the-apple-school-and-business-manager-api

### Requirements:
 - Private key downloaded from Apple Business Manager or Apple School Manager
 - Client ID - Found in the "Manage" info pane for the API key in ABM/ASM
 - Key ID    - Found in the "Manage" info pane for the API key in ABM/ASM

### Usage:
`./create_client_assertion.sh <path_to_key.pem> <client_id> <key_id>`

### Example:
`./create_client_assertion.sh "private-key.pem" "BUSINESSAPI.9703f56c-10ce-4876-8f59-e78e5e23a152" "d136aa66-0c3b-4bd4-9892-c20e8db024ab"`


The JWT generated is valid for 180 days and does not need to be re-generated every time you want to use it
Create the JWT once, then use that when requesting a bearer token from the ABM/ASM API.