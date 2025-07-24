#!/bin/sh

# Add file path and extensions to scan
# echo "<result>$PATH</result>"

findFile=("*.docm" "*.dotm" "*.xlsm" "*.xltm" "*.sh")
filesFound=""


for filetype in ${findFile[@]}; do 
    myFile=$(/usr/bin/locate "$filetype")
    if [[ -n $myFile ]]; then
        IFS=$'\n'
        for file in ${myFile[@]}; do 
            filesFound+="\n${file}"
        done
    fi
done

if [[ -n "${filesFound}" ]]; then
    echo "<result>Found"
    echo "${filesFound}"
    echo "</result>"
    exit 99
fi
exit 0