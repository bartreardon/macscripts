#!/bin/zsh

# Set the device to a random shard in the following ratios:
#   Shard 1 5%
#   Shard 2 25%
#   Shard 3 Remainder


# Path to store the preference
PREF_PATH="/Library/Preferences/com.org.shardpref.plist"
# Key to store the shard
# update as required to suit the EA name
PREF_KEY="my-deployment-EA-shard"

checkShard() {
    local myshard=$(/usr/bin/defaults read $PREF_PATH $PREF_KEY 2>/dev/null)
    # if the shard is already set, then we just exit
    if [[ -n $myshard ]]; then
        echo "$myshard"
    fi
}   

# Function to get the current shard from preferences, or generate a new one if none exists
getShard() {
    # Generate a random number between 1 and 100
    local rand=$((RANDOM % 100 + 1))
    
    if (( rand <= 5 )); then
        echo "Shard 1"
    elif (( rand <= 25 )); then
        echo "Shard 2"
    else
        echo "Shard 3"
    fi
}

# Check if the shard is already set
SHARD=$(checkShard)

# If the shard is not set, then we generate a new one
if [[ -z $SHARD ]]; then
    SHARD=$(getShard)
    /usr/bin/defaults write $PREF_PATH $PREF_KEY $SHARD
fi

# Output the result
echo "<result>$SHARD</result>"

exit 0