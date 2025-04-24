#!/bin/bash

# Script to renice processes.

# Author: Bart Reardon
# Date: 2025-04-24
# Version: 1.0

## Description:
# This sets the priority of processes to the specified value.
# It will check for the process every 60 seconds and renice it if found.
# If the process is not found, it will retry for a maximum of 10 times.
# If the process is not found after 10 retries, it will exit with an error.
# Log output is written to /var/log/renice-<process_name>.log

# Usage: ./renice-process.sh <process_name> [nice_value]
# Example: ./renice-process.sh 'MyProcess' +10

# Process name will match any process name that contains the string.
# For example, if the process name is 'MyProcess', it will match 'MyProcess', 'MyProcess2', 'MyProcess3', etc.


PROCESS_NAME="$1"
NICE_VALUE="${2:-+10}" # Default to +20 if not provided
# If using in a jamf script:
# PROCESS_NAME="$4"
# NICE_VALUE="${5:-+10}" # Default to +20 if not provided

# Constants
RETRY_INTERVAL=60 # seconds
MAX_RETRIES=10 # maximum number of retries
TOTAL_RUNTIME=600 # seconds (10 minutes)
START_TIME=$(date +%s)

print_usage() {
    echo "Usage: $0 <process_name> [nice_value]"
    echo "Example: $0 'MyProcess' +10"
}

# check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please run with sudo."
    exit 1
fi
# check PROCESS_NAME is not empty
if [ -z "$PROCESS_NAME" ]; then
    echo "Process name is required."
    print_usage
    exit 1
fi

# NICE_VALUE needs to be in the range -20 to +20
if ! [[ "$NICE_VALUE" =~ ^[-+]?[0-9]+$ ]] || [ "$NICE_VALUE" -lt -20 ] || [ "$NICE_VALUE" -gt 20 ]; then
    echo "NICE_VALUE must be an integer between -20 and +20."
    print_usage
    exit 1
fi

# log file
LOG_FILE="/var/log/renice-${PROCESS_NAME}.log"
# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

write_log() {
  local message="$1"
  # echo to stdout
  echo "$message"
  # echo to log file
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Function to renice  processes
renice_process() {
    pids=$(pgrep -f "$PROCESS_NAME")

    if [ -n "$pids" ]; then
        # echo to stderr to avoid confusion with stdout
        write_log "Found one or more processes for ${PROCESS_NAME}:"
        for pid in $pids; do
            write_log "Evaluating $(get_process_name "$pid") with PID $pid"
            # Check if the process is already reniced to the desired value
            if [[ $(get_nice_value "$pid") -eq "$NICE_VALUE" ]]; then
                write_log "Process $pid already has nice value of ${NICE_VALUE}. Skipping..."
                continue
            fi
            /usr/bin/renice ${NICE_VALUE} -p "$pid"
            /usr/sbin/taskpolicy -b -p "$pid"
            write_log "Reniced process $pid to ${NICE_VALUE} priority and limit to E cores only"
        done
        return 0
    else
        return 1
    fi
}

# Return the current nice value of a given PID
get_nice_value() {
    ps -o ni= -p "$1"
}

# Return process name of a given PID
get_process_name() {
    ps -o comm= -p "$1"
}

# Main loop
retry_count=0
write_log "Starting renice script..."
while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))

    if [ "$ELAPSED_TIME" -ge "$TOTAL_RUNTIME" ]; then
        echo "Maximum runtime (10 minutes) exceeded.  Exiting."
        exit 1
    fi

    renice_process
    return_code=$?

    if [[ $return_code == 0 ]]; then
        echo "${PROCESS_NAME} process reniced successfully."
        break
    else
        echo "${PROCESS_NAME} process not found. Retrying in $RETRY_INTERVAL seconds..."
        sleep "$RETRY_INTERVAL"
        retry_count=$((retry_count + 1))

        if [ "$retry_count" -ge "$MAX_RETRIES" ]; then
            echo "Maximum retries reached. Exiting."
            exit 1
        fi
    fi
done
