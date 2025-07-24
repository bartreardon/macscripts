#!/bin/zsh

# set -x

json() {
    local json_command=$1 # first argument
    local json_data=${@[$#]} # last argument

    # Process optional arguments if present
    case "$#" in
        2) ;;
        3) path=$2;;
        4) path=$2; value=$3 ;;
    esac

    # process json command
    case "$json_command" in
        "validate")
            result=$(/usr/bin/sqlite3 /dev/null "SELECT json_valid('${json_data}');")
            if [[ "$result" == "1" ]]; then
                return 0
            else
                return 1
            fi
            ;;
        "extract")
            result=$(/usr/bin/sqlite3 /dev/null "SELECT json_extract('${json_data}', '$.$path');")
            echo $result
            ;;
        "array_length")
            result=$(/usr/bin/sqlite3 /dev/null "SELECT json_array_length('${json_data}', '$.$path');")
            echo $result
            ;;
        "type")
            result=$(/usr/bin/sqlite3 /dev/null "SELECT json_type('${json_data}', '$.$path');")
            echo $result
            ;;
        "set")
            result=$(/usr/bin/sqlite3 /dev/null "SELECT json_set('${json_data}', '$.$path', '$value');")
            echo $result
            ;;
        "remove")
            result=$(/usr/bin/sqlite3 /dev/null "SELECT json_remove('${json_data}', '$.$path');")
            echo $result
            ;;
        "array")
            result=$(/usr/bin/sqlite3 /dev/null "SELECT json_array($json_data);")
            echo $result
            ;;
        *)
            echo "Unknown command"
            exit 1
            ;;
    esac
}


jsondata=$(
    cat <<EOF
{
    "name": "Google Chrome",
    "path": "/Applications/Google Chrome.app",
    "nested": {
        "anotherpath": "/Applications/Google Chrome.app"
    },
    "arraytest": [
        "one",
        "two",
        "three"
    ],
    "typetest": true
}
EOF
)

## Examples

# Usage: json <command> [path] [value] <json>
#    Commands:
#        validate
#        extract
#        array_length
#        type
#        set
#        remove
#        array

# validate json
if json validate "$jsondata"; then
    echo "Valid JSON"
    echo $jsondata
    echo "\n--\n"
else
    echo "Invalid JSON"
    exit 1
fi

# extract a value
echo "Extracting name value:"
json extract "name" "$jsondata"
echo "\n--\n"

# extract a nested value
echo "Extract nested value: 'nested.anotherpath'"
json extract  "nested.anotherpath" "$jsondata"
echo "\n--\n"

# get an array length
echo "Array length of 'arraytest': " 
json array_length "arraytest" "$jsondata"
echo "\n--\n"

# get a value type
echo "Type of 'typetest': "
json type "typetest" "$jsondata"
echo "Type of 'arraytest': "
json type "arraytest" "$jsondata"
echo "\n--\n"

# set a value (create if it doesn't exist)
echo "set a value:  adding 'foo' 'bar'"
json set "foo" "bar" "$jsondata"
# overwrite a value
echo "overwrite a value: changing 'foo' 'bar' to 'foo' 'baz'"
json set "foo" "baz" "$jsondata"
# set a nested value
echo "set a nested value: adding 'nested.foo' 'bar'"
json set "nested.foo" "bar" "$jsondata"
echo "\n--\n"


# remove a value
echo "remove a value: removing 'arraytest'"
json remove "arraytest" "$jsondata"
echo "\n--\n"

# remove a nested value
echo "remove a nested value: removing 'nested.anotherpath'"
json remove "nested.anotherpath" "$jsondata"
echo "\n--\n"


# return a json array from values
echo "return a json array from values: "
json array "'foo','bar','baz'"
echo "\n--\n"

# set a value to a json array
echo "set a value to a json array: "
json set "foo" "$(json array "'foo','bar','baz'")" "$jsondata"




