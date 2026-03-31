#!/bin/bash
# Title: Disable All Alerts
# Author: cncartist
# Description: Lists and Turns All Enabled Alerts Off.  Asks before turning off and shows count/names.
# Category: csec/general

# ---- CONFIG ----
ALERT_DIR="/root/payloads/alerts/"
declare -A ALERTS_FOUND

output=$(find "$ALERT_DIR" -type d ! -path '*/DISABLED*' -print)
output2=""
PREFIX="DISABLED."

LOG blue "================================================="
LOG      "========== List Active/Enabled Alerts ==========="
LOG blue "================================================="
LOG      "===== Allows Turning All Alerts Off at Once ====="
LOG blue "================================================="
LOG "Press OK to continue..."
LOG " "
WAIT_FOR_BUTTON_PRESS A
sleep 0.25
LOG "Checking for Enabled Alerts...."
LOG " "

while IFS= read -r line; do
	if [ -n "$(find "$line" -maxdepth 1 -type f -print)" ]; then
		output2+="$line
" # echo "$line has files."
		ALERTS_FOUND["$line"]="y"
	fi
done <<< "$output"

if [[ -n "$output2" ]] ; then
	LOG green "Found ${#ALERTS_FOUND[@]} Enabled Alert(s)!"
	LOG " "
	for alertcur in "${!ALERTS_FOUND[@]}"; do
		# only shows dir name (example too many times)
		# LOG cyan "$(basename "$alertcur")"
		# show 2 dirs for clarity
		LOG cyan " - ${alertcur#${alertcur%/*/*}/}"
	done
	LOG " "
	LOG "Press OK to continue..."
	LOG " "
	WAIT_FOR_BUTTON_PRESS A
	sleep 0.25
	
	resp=$(CONFIRMATION_DIALOG "${#ALERTS_FOUND[@]} Alert(s) Enabled, do you want to Disable them ALL?")
	sleep 0.25
	if [[ "$resp" == "$DUCKYSCRIPT_USER_CONFIRMED" ]] ; then
		# echo -e "$output2"
		LOG green "Turning Off Enabled Alert(s)..."
		while IFS= read -r line; do
			if [[ -n "$line" ]] ; then
				dir_name="$line"
				parent_dir="$(dirname "$dir_name")"
				base_name="$(basename "$dir_name")"
				new_name="$PREFIX"
				new_name+="$base_name"

				# Move the directory to its new name. The command is run from the parent directory
				# echo "Moving: ${parent_dir}/${base_name} To: ${parent_dir}/${new_name}"
				LOG "Turning Off: ${line#${line%/*/*}/}"
				mv "${parent_dir}/${base_name}" "${parent_dir}/${new_name}"
			fi
		done <<< "$output2"
		LOG " "
		LOG green "Completed Turning Off ${#ALERTS_FOUND[@]} Alert(s)!"
		LOG " "
	else
		LOG "Skipped disabling alerts..."
	fi
else
	LOG red "No Enabled Alerts Found!"
fi
LOG "Exiting..."
LOG " "

exit 0
