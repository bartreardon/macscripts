#!/bin/zsh

# compress a script into a bzip2 compressed base64 encoded blob

inputFile="$1"
outputFile="$2"
if [ -z "$inputFile" ]; then
    echo "Usage: $0 <input-file> [<output-file>]"
    exit 1
fi
if [ -z $outputFile ]; then
    outputFile="${inputFile%.*}.bz2.sh"
fi
filedata=$(/usr/bin/bzcat -zk9 "$inputFile" | /usr/bin/base64 -w120)

scriptData=$( cat <<-EOF
#!/bin/zsh

# This is a bzip2 compressed base64 encoded script of ${inputFile}
# that will be decoded and executed in a subshell.

data="${filedata}"

/usr/bin/base64 -d -o - <<< "\$data" | /usr/bin/bzcat | /bin/zsh -s "\$@"
EOF
)

# write the script to the output file
echo "$scriptData" > "$outputFile"
chmod +x "$outputFile"
echo "Created compressed script: $outputFile"
