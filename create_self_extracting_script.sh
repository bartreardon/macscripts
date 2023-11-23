#!/bin/zsh

# Author: Bart Reardon
# Date: 2023-11-23

# Script for creating self extracting base64 encoded files.

# usage: file_to_self_extracting_script <file_path> [target_path]

SCRIPT_NAME=$(basename "$0")
FILE_TO_ENCODE=""
TARGET_PATH=""

file_to_self_extracting_script() {
    base64_string=$(base64 -i "$1")
    filename=$(basename "$1")
    target_path=${2}
    if [[ -n "$target_path" ]]; then
        # check to see if the path ends with a slash
        if [[ ! "$target_path" =~ /$ ]]; then
            target_path="${target_path}/"
        fi
    fi

    cat <<EOF > "${filename}_extract.sh"
#!/bin/bash
base64_string='$base64_string'
echo "\$base64_string" | base64 -d > "${target_path}$filename"
echo "File '${target_path}$filename' has been recreated."
EOF

    chmod +x "${filename}_extract.sh"

    echo "Self-extracting script '${filename}_extract.sh' created."
}

printUsage() {
    echo "OVERVIEW: ${SCRIPT_NAME} is a utility that creates self extracting base64 encoded scripts."
    echo ""
    echo "USAGE: ${SCRIPT_NAME} --file <filename> [--target <directory>]"
    echo ""
    echo "OPTIONS:"
    echo "    -f, --file <filename>     Encode the selected file"
    echo "    -t, --target <directory>  Target directory to extract the file to. Defaults to the current directory."
    echo "    -h, --help                Print this message"
    echo ""
}

# if no arguments passed, print help and exit
if [[ "$#" -eq 0 ]]; then
    printUsage
    exit 0
fi

# Loop through named arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --file|-f) FILE_TO_ENCODE="$2"; shift ;;
        --target|-t) TARGET_PATH="$2"; shift ;;
        --help|-h|help) printUsage; exit 0 ;;
        *) echo "Unknown argument: $1"; printUsage; exit 1 ;;
    esac
    shift
done

if [[ -z "$FILE_TO_ENCODE" ]]; then
    echo "Error: No file specified."
    printUsage
    exit 1
fi

file_to_self_extracting_script "${FILE_TO_ENCODE}" "${TARGET_PATH}"
