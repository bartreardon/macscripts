#!/bin/zsh

# Generates a random word from the system dictionary
# Assuming the dictionary doesn't change, this will generate the same word
# every time if given the same device serial number and optional salt
# Useful for generating predictable device hostnames.

SERIAL_NUMBER=$(/usr/sbin/system_profiler SPHardwareDataType | awk '/Serial/ {print $NF}')
SALT=$1

# generate random word
randomWord() {
    logger "[func ${funcstack[1]}]: Generating random word using $1 as the seed value"
    # use serial number as the seedval for the random number generator if no seedval is passed in
    local seedval=${1:-$(/usr/sbin/system_profiler SPHardwareDataType | awk '/Serial/ {print $NF}')}
     # convert seedval to a numeric value
    local seed_numeric=$(echo -n $seedval | md5 | tr -d 'a-f' | tr -d '\n' | tr -d '[:space:]')
    
    # generate a list of words between 5 and 10 characters long
    local wordlist=$(awk 'length($0) >= 5 && length($0) <= 10' /usr/share/dict/words)
    # count the number of words in the list
    local wordCount=$(echo $wordlist | wc -w | tr -d " ")

    # generate a pseudo random number based off the seed_numeric value
    local random_number=$((${seed_numeric:0:15} % $((wordCount + 1))))

    # get the word from the list
    echo ${(U)wordlist} | awk -v random_number=$random_number 'BEGIN{ RS = "" ; FS = "\n" }{print $random_number}'
}

getWordFromSerial() {
    local serial=$1
    local SALT="$2"

    deviceWord="$(randomWord "$serial${SALT}")"
       
    echo "${(U)deviceWord}"
}

getWordFromSerial "${SERIAL_NUMBER}" "${SALT}"