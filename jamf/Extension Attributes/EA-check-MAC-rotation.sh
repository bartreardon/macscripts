#!/bin/bash

SSID_TO_COMPARE=""

# 1. Find your Wi-Fi interface (en0/en1/etc)
WIFI_IF=$(networksetup -listallhardwareports \
  | awk '/Wi-Fi|AirPort/{getline; print $2; exit}')
 
# 2. Get current SSID (if not associated, networksetup prints an error)
SSID=$(/usr/sbin/ipconfig getsummary "$WIFI_IF" | awk '/ SSID/ {print $NF}' 2>/dev/null)
 
# If not on the compariston ssid, it’s not “attempting”/connected → result No
if [[ "$SSID" != "$SSID_TO_COMPARE" ]]; then
  echo "<result>No</result>"
  exit 0
fi
 
# 3. Grab the interface’s MAC address
MAC=$(/usr/sbin/networksetup -getmacaddress "$WIFI_IF" \
  | awk '{print $3}')
 
# 4. Inspect the first octet’s “local” bit (0x02)
first_octet=${MAC%%:*}
dec=$((0x$first_octet))
 
if (( dec & 2 )); then
  # local bit set → randomisation still on
  echo "<result>Yes</result>"
else
  echo "<result>No</result>"
fi
 
exit 0