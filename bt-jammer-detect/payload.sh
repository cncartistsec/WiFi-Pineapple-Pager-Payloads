#!/bin/bash
# Title: Bluetooth Jammer Detector & Locator
# Author: cncartist
# Description: Detects & Locates Bluetooth Jammers/Interference Devices within close range.  Required to have a USB Bluetooth Adapter to utilize the connection between internal and external Bluetooth.  The stronger the jammer/interference, the more easily it will be found.  Even a weak jammer can cause signal outages in devices, but it takes a very strong interference or being very close (at most 4-6 ft away from source) to interrupt the connection between the internal Bluetooth and external USB Bluetooth.  
# Category: reconnaissance
#
# ============================================
# Notes:
# ============================================
# "Jam" counter resets every 25 "nojams" to clean out errors, and the "Found" counter will only count true confirmed jams in the area.  Confirmed jams are calculated at 5 jams per 25 scans.  A sequential jam is accounted for and more severe, meaning you are closer to the jammer/interference device.  This method may not work with certain Bluetooth dongles or setups and has only been confirmed to work with a USB CSR8510 / CSR v4.0 Bluetooth Adapter on the Pager.  Includes GPS coordinate logging if GPS device enabled.
# 

# ---- CONFIG ----
LOOT_BASE="/root/loot/csec/"; LOOT_DIR="${LOOT_BASE}bt-jammer-detect"
mkdir -p "$LOOT_DIR"
TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
REPORT_DETJAM_FILE="$LOOT_DIR/Report_Jam_${TIMESTAMP}.txt"
KEYCKTMP_FILE="$LOOT_DIR/JamKeyCkTmp.txt"
# temp_devname="Apple Apple Test Long Name Apple"

total_scans=0
total_detected=0
scan_mute="false"
scan_stealth=0
# set on each total run
cancel_app=0
gpspos_last=""

# Check for required tools
check_dependencies() {
	local evtestCheck=0; local count=0; local limit=3
	# check evtest
	if command -v evtest &> /dev/null; then
		evtestCheck=1
	fi
	if [[ "$evtestCheck" -eq 0 ]]; then
		local dependText=""
		# ask if they want to install now
		if [[ "$evtestCheck" -eq 0 ]]; then
			dependText="evtest"
		fi
		resp=$(CONFIRMATION_DIALOG "Dependency not met!
		
		Required: $dependText
		
		Install automatically now?")
		if [[ "$resp" == "$DUCKYSCRIPT_USER_CONFIRMED" ]] ; then
			LOG blue  "================================================="
			LOG "Starting package install..."
			sleep 1
			count=0
			while [[ -f "/var/lock/opkg.lock" ]] && [[ "$count" -lt 3 ]] ; do
				LOG red "Opkg currently locked by a process. Waiting..."
				sleep 5
				count=$((count + 1))
			done
			# Check WiFi Client Mode enabled
			count=1 # Number of packets to send
			timeout=3 # Seconds to wait for a response
			if ping -c $count -w $timeout "8.8.8.8" > /dev/null 2>&1; then
				LOG "Network connection is active..."
				LOG "Running 'opkg update'"
				LOG "Please wait..."
				# opkg update && opkg install evtest
				if opkg update; then
					LOG green "'opkg update' successful."
					if [[ "$evtestCheck" -eq 0 ]]; then
						LOG "Installing evtest..."
						LOG "Please wait..."
						opkg install evtest
					fi
					LOG green "Package installed!"
				else
					LOG red "'opkg update' failed. Check network..."
				fi
			else
				LOG red "Network connection is down..."
			fi
			LOG blue  "================================================="
		else
			ERROR_DIALOG "Dependency not met:
			
			Required: $dependText not installed!"
			LOG red   "===================================== CRITICAL =="
			LOG red   "== Dependency not met: $dependText"
			LOG red   "===================================== CRITICAL =="
			LOG cyan "== Install with ->"
			LOG "opkg update"
			LOG "opkg install evtest"
			LOG blue  "================================================="
			LOG cyan "== Or all in one command ->"
			LOG "opkg update && opkg install evtest"
			LOG blue  "================================================="
			sleep 1
			exit 1
		fi
	fi
}

# start key check collection
start_evtest() {
	# (evtest /dev/input/event0 | grep "^Event:" &> "$KEYCKTMP_FILE") &
	# wrap the command in a second subshell and redirect its output to hide job ID and PID
	((evtest /dev/input/event0 | grep "^Event:" &> "$KEYCKTMP_FILE") &) > /dev/null 2>&1
}


detect_jammers() {
	/etc/init.d/gpsd reload 2>/dev/null
	/etc/init.d/gpsd restart 2>/dev/null
	
	# possible cleanup from last run
	rm "$KEYCKTMP_FILE" 2>/dev/null
	killall evtest 2>/dev/null	
	
	# name to be used for device to be pinged
	local temp_devname="Apple"
	# adapter_base decides which adapter is the one doing the pinging
	# the other adapter will receive the request and reply back
	local adapter_base="hci0"

	local maxJams=5
	local maxNoJams=25
	local showruntimeNS=0

	local jams=0
	local nojamcount=0
	local nojamstreak=0
	local seqJams=0
	local jamLast=0
	local jammerDet=0
	local jamConf=0
	local nojamstreak_hold=0
	local jamLast_hold=0
	local totalruntime=0
	local runnum=0
	local running=0
	local cancelJamRun=0
	local checkStrict=0

	local adapterdown=0
	local hci0_status=""
	local hci0_MAC=""
	local hci0_NAME=""
	local hci0_NAMEold=""
	local hci1_status=""
	local hci1_MAC=""
	local hci1_NAME=""
	local hci1_NAMEold=""
	local pinged_device=""
	
	local status_display=""
	local jams_display=""
	local jammerDet_display=""
	local nojamstreak_display=""
	local totalruntime_display=""

	# check pause/cancel
	check_cancel_jam() {
		# LOG "checking pause/cancel"
		# load content of file into string, then check string vs match
		# local FILE_CONTENT=$(<"$KEYCKTMP_FILE")
		
		# confirm cancel is pressed
		# if grep -Eq "\\(BTN_EAST\\), value 1" "$KEYCKTMP_FILE"; then
		if grep -q "(BTN_EAST), value 1" "$KEYCKTMP_FILE"; then
			# LOG "found"
			killall evtest 2>/dev/null
			# empty file
			:> "$KEYCKTMP_FILE"
			cancel_app=1
			# if cancel_press=1 then prompt asking if they actually want to cancel.
			LOG blue "--------------------------------------------------"
			LOG "Stopping..."
			LOG "Stopping..."
			LOG "Stopping..."
			LOG blue "--------------------------------------------------"
			sleep 0.5
		else
			# LOG "not found, empty file"
			# empty file
			:> "$KEYCKTMP_FILE"
		fi
	}

	updatebtdevname() {
		hci0_MAC=$(hciconfig hci0 | grep 'BD Address' | awk '{print $3}' 2>/dev/null)
		hci1_MAC=$(hciconfig hci1 | grep 'BD Address' | awk '{print $3}' 2>/dev/null)

		# change name for discoverable mac
		if [[ "$adapter_base" == "hci1" ]] ; then
			# LOG "hci0_MAC: $hci0_MAC"
			# LOG "hci0_NAME: $hci0_NAME"
			hci0_NAMEold="$hci0_NAME"
			# LOG "old hci0_NAMEold: $hci0_NAMEold"
			LOG cyan "--------- Updating Bluetooth device name --------"
			LOG "From: '$hci0_NAMEold'"
			LOG "To: '$temp_devname'"
			LOG "--- name will be returned back after scanning ---"
			bluetoothctl <<-EOF >/dev/null 2>&1
			select $hci0_MAC
			system-alias "$temp_devname"
			quit
			EOF
			sleep 0.5
			rm ".bluetoothctl_history" 2>/dev/null
			hci0_NAME=$(hciconfig -a hci0 | grep "Name:" | awk -F"'" '{print $2}')
			# LOG "new hci0_NAME: $hci0_NAME"
		else
			# LOG "hci1_MAC: $hci1_MAC"
			# LOG "hci1_NAME: $hci1_NAME"
			hci1_NAMEold="$hci1_NAME"
			# LOG "old hci1_NAMEold: $hci1_NAMEold"
			LOG cyan "--------- Updating Bluetooth device name --------"
			LOG "From: '$hci1_NAMEold'"
			LOG "To: '$temp_devname'"
			LOG "--- name will be returned back after scanning ---"
			bluetoothctl <<-EOF >/dev/null 2>&1
			select $hci1_MAC
			system-alias "$temp_devname"
			quit
			EOF
			sleep 0.5
			rm ".bluetoothctl_history" 2>/dev/null
			hci1_NAME=$(hciconfig -a hci1 | grep "Name:" | awk -F"'" '{print $2}')
			# LOG "new hci1_NAME: $hci1_NAME"
		fi
	}


	hci_check_status() {
		adapterdown=0
		local discov="OFF"
		
		if [[ "$adapter_base" == "hci1" ]] ; then
			hci0_output=$(hciconfig -a hci0 2>&1)
			sleep 1
			hci1_output=$(hciconfig -a hci1 2>&1)
		else
			hci1_output=$(hciconfig -a hci1 2>&1)
			sleep 1
			hci0_output=$(hciconfig -a hci0 2>&1)
		fi
		# hci0_status=$(hciconfig hci0 |& awk 'NR==3 {print $1}')
		hci0_status=$(echo "$hci0_output" | awk 'NR==3 {print $1}')
		# grab next line if possible failure
		if [[ "$hci0_status" != "UP" ]] ; then
			hci0_status=$(echo "$hci0_output" | awk 'NR==4 {print $1}')
		fi
		hci0_NAME=$(echo "$hci0_output" | grep "Name:" | awk -F"'" '{print $2}' 2>/dev/null)
		
		# hci1_status=$(hciconfig hci1 |& awk 'NR==3 {print $1}')
		hci1_status=$(echo "$hci1_output" | awk 'NR==3 {print $1}')
		# grab next line if possible failure
		if [[ "$hci1_status" != "UP" ]] ; then
			hci1_status=$(echo "$hci1_output" | awk 'NR==4 {print $1}')
		fi
		hci1_NAME=$(echo "$hci1_output" | grep "Name:" | awk -F"'" '{print $2}' 2>/dev/null)
		
		if [[ "$adapter_base" == "hci1" ]] ; then
			if echo "$hci0_output" | grep -q "PSCAN ISCAN"; then discov="ON"; fi
		else
			if echo "$hci1_output" | grep -q "PSCAN ISCAN"; then discov="ON"; fi
		fi
		if [[ "$discov" != "ON" || "$hci1_status" != "UP" || "$hci0_status" != "UP" ]] ; then
			# LOG "Working magic, adapter not discoverable or up..."
			adapterdown=1
			# printf "  hci0_output: %s\n\n" "${hci0_output}" >> "$REPORT_DETJAM_FILE"
			# printf "  hci1_output: %s\n\n" "${hci1_output}" >> "$REPORT_DETJAM_FILE"
		else
			if [[ "$running" -eq 0 || "$checkStrict" -eq 1 ]] ; then
				if echo "$hci1_output" |& grep -q "read local name on hci1: I/O error"; then
					# LOG "hci1 down"
					adapterdown=1
				fi
				if echo "$hci0_output" |& grep -q "read local name on hci0: I/O error"; then
					# LOG "hci0 down"
					adapterdown=1
				fi
			fi
		fi
	}

	bring_adapters_up() {
		if [[ "$scan_stealth" -eq 0 ]] ; then LED WHITE; fi
		LOG blue "--------------------------------------------------"
		if [[ "$running" -eq 0 ]] ; then
			LOG "Preparing Bluetooth Adapters"
			# LOG "Trying to Bring down Adapters"
			hciconfig hci0 down 2>/dev/null
			sleep 1.5
			hciconfig hci1 down 2>/dev/null
			sleep 1.5
			LOG "Please wait..."
			service bluetoothd restart 2>/dev/null
			sleep 2
			# LOG "Trying to Bring up Adapters"
		else
			LOG "Resetting Bluetooth status"
		fi
		if [[ "$adapter_base" == "hci1" ]] ; then
			hciconfig hci0 up piscan 2>/dev/null
			sleep 1.5
			hciconfig hci1 up noscan 2>/dev/null
			sleep 1.5
		else
			hciconfig hci0 up noscan 2>/dev/null
			sleep 1.5
			hciconfig hci1 up piscan 2>/dev/null
			sleep 1.5
		fi
		LOG "Verifying Adapters status"

		loop=0
		while true; do
			# LOG red "in loop"
			loop=$((loop + 1))
			# check both adapters are up and online
			hci_check_status
			if [[ "$adapterdown" -eq 1 ]]; then
				if [[ "$loop" -gt 1 ]] ; then
					LOG red "RESET FAILED! Trying to reset again."
				fi
				LOG "Trying to Stop Blueooth"
				service bluetoothd stop 2>/dev/null
				sleep 2
				LOG "Trying to Remove Bluetooth"
				rmmod btusb 2>/dev/null
				sleep 2
				LOG "Trying to Enable Bluetooth"
				modprobe btusb 2>/dev/null
				sleep 2
				LOG "Trying to Start Blueooth"
				service bluetoothd start 2>/dev/null
				sleep 2
				LOG "Trying to Bring up Adapters"
				if [[ "$adapter_base" == "hci1" ]] ; then
					hciconfig hci0 up piscan 2>/dev/null
					sleep 1.5
					hciconfig hci1 up noscan 2>/dev/null
					sleep 1.5
				else
					hciconfig hci0 up noscan 2>/dev/null
					sleep 1.5
					hciconfig hci1 up piscan 2>/dev/null
					sleep 1.5
				fi
				if [[ "$running" -eq 1 ]] ; then
					totalruntime=$((totalruntime+11))			
				fi		
				if [[ "$loop" -eq 5 ]] ; then
					LOG red "BLUETOOTH ADAPTER ERROR!"
					LOG "Adapter(s) could not be brought back up with software!"
					LOG " "
					LOG "Hardware Reset Required! Unplug and replug USB!"
					LOG " "
					LOG red "USB BT Adapter could also be missing?"
					LOG " "
					# exit 1
					cancel_app=1
					cancelJamRun=1
					break
				fi
			else
				LOG green "Bluetooth Adapters are ready!"
				break
			fi
		done
		LOG blue "--------------------------------------------------"
		# hide line on table
		jamConf=1
		if [[ "$scan_stealth" -eq 0 ]] ; then LED BLUE SLOW; fi
	}
	
	length_display() {
		local length=0
		local max_value=0
		local mins=0
		local secs=0
		length=${#nojamstreak}
		nojamstreak_display="$nojamstreak"
		if [[ "$length" -lt 11 ]] ; then
			max_value=$((11-length))
			nojamstreak_display+=" "
			for (( i = 0; i < max_value; i++ ))
			do
				nojamstreak_display+="¨"
			done
		fi
		length=${#jammerDet}
		jammerDet_display="$jammerDet"
		if [[ "$length" -lt 6 ]] ; then
			max_value=$((6-length))
			jammerDet_display+=" "
			for (( i = 0; i < max_value; i++ ))
			do
				jammerDet_display+="¨"
			done
		fi
		if [[ "$totalruntime" -gt 60 ]] ; then
			mins=$((totalruntime/60)); secs=$((totalruntime%60))
			if [[ "$mins" -gt 9 ]] ; then
				totalruntime_display="${mins}min"
			else
				totalruntime_display="${mins}min ${secs}s"
			fi
		else
			totalruntime_display="${totalruntime}s"
		fi
		jams_display=" $jams ¨¨¨"
	}
	
	resp=$(CONFIRMATION_DIALOG "Confirm Jammer Detection?")
	if [[ "$resp" == "$DUCKYSCRIPT_USER_CONFIRMED" ]] ; then
		if [[ "$scan_stealth" -eq 0 ]] ; then LED WHITE; fi
	
		TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
		REPORT_DETJAM_FILE="$LOOT_DIR/Report_Jam_${TIMESTAMP}.txt"
		printf "═════════════════════════════════════════════════\n" >> "$REPORT_DETJAM_FILE"
		printf "  Bluetooth Jammer Detector Scan\n" >> "$REPORT_DETJAM_FILE"
		printf "  Date: %s\n" "${TIMESTAMP}" >> "$REPORT_DETJAM_FILE"
		printf "═════════════════════════════════════════════════\n" >> "$REPORT_DETJAM_FILE"
		printf "%s - EVENT: Prepare BT Adapters\n" $(date +"%Y-%m-%d_%H%M%S") >> "$REPORT_DETJAM_FILE"
		
		LOG "Loading Jammer Detector..."

		# check both adapters are up and online
		hci_check_status
		if [[ "$adapterdown" -eq 0 ]] ; then
			# prepare adapters
			LOG "Preparing Bluetooth Adapters"
			hciconfig hci0 down 2>/dev/null
			sleep 1.5
			hciconfig hci1 down 2>/dev/null
			sleep 1.5
			LOG "Please wait..."
			if [[ "$adapter_base" == "hci1" ]] ; then
				hciconfig hci0 up piscan 2>/dev/null
				sleep 1.5
				hciconfig hci1 up noscan 2>/dev/null
				sleep 1.5
			else
				hciconfig hci0 up noscan 2>/dev/null
				sleep 1.5
				hciconfig hci1 up piscan 2>/dev/null
				sleep 1.5
			fi
			LOG "Verifying Adapters status"
			hci_check_status
			if [[ "$adapterdown" -eq 0 ]] ; then
				updatebtdevname
				LOG blue "--------------------------------------------------"
				LOG green "----------------- Ready to Rock! -----------------"
			else
				# Adapters down, try to bring back up
				bring_adapters_up
				updatebtdevname
				LOG blue "--------------------------------------------------"
				LOG green "----------------- Ready to Rock! -----------------"
			fi
		else
			sleep 1
			if ! hciconfig hci1 >/dev/null 2>&1; then
				resp=$(CONFIRMATION_DIALOG "USB Bluetooth / hci1 NOT FOUND!
				
				Are you sure you have a USB Bluetooth Adapter plugged in and want to continue having the system reset it?")
				if [[ "$resp" != "$DUCKYSCRIPT_USER_CONFIRMED" ]] ; then
					cancelJamRun=1
				fi
			fi
			sleep 0.5
			if [[ "$cancelJamRun" -eq 0 ]] ; then
				# adapters down, try to bring back up
				bring_adapters_up
				if [[ "$cancelJamRun" -eq 0 ]] ; then
					updatebtdevname
					LOG blue "--------------------------------------------------"
					LOG green "----------------- Ready to Rock! -----------------"
				fi
			fi
		fi
		
		# check if cancelled
		if [[ "$cancelJamRun" -eq 0 ]] ; then
			if [[ "$scan_stealth" -eq 0 ]] ; then LED BLUE SLOW; fi
			if [[ "$adapter_base" == "hci1" ]] ; then
				pinged_device="$hci0_MAC"
			else
				pinged_device="$hci1_MAC"
			fi
			
			printf "════════════════════════════════════════════\n" >> "$REPORT_DETJAM_FILE"
			printf "%s - EVENT: Start scan\n" $(date +"%Y-%m-%d_%H%M%S") >> "$REPORT_DETJAM_FILE"
			# gps check
			gpspos_cur=$(GPS_GET)
			if [[ "$gpspos_cur" != "0 0 0 0" ]] ; then
				gpspos_last="$gpspos_cur" # GPS is valid
				printf "GPS Pos.: %s\n" "${gpspos_last}" >> "$REPORT_DETJAM_FILE"
			else
				if [[ -n "$gpspos_last" ]] ; then # gps lost, last known coordinates: gpspos_last
					printf "GPS LOST! %s (Last Known Pos.)\n" "${gpspos_last}" >> "$REPORT_DETJAM_FILE"
				fi
			fi
			printf "════════════════════════════════════════════\n" >> "$REPORT_DETJAM_FILE"


			LOG green "------------- Begin Jammer Detection -------------"
			:> "$KEYCKTMP_FILE"
			start_evtest
			LOG blue "--------------------------------------------------"
			LOG cyan "-------- Long Press or Tap OK to stop... ---------"
			LOG blue "--------------------------------------------------"
			
			# start detection loop
			while true; do
				running=1
				# check cancel on each run
				check_cancel_jam; if [[ "$cancel_app" -eq 1 ]]; then break; fi
				if (( runnum % 50 == 0 )) && (( runnum != 0 )); then
					if [[ "$jamConf" -eq 0 ]] ; then
						LOG blue "--------------------------------------------------"
					fi
					LOG cyan "-------- Long Press or Tap OK to stop... ---------"
					LOG cyan "------- It may take a second to process... -------"
					if (( runnum % 12 != 0 )); then
						LOG blue "--------------------------------------------------"
					fi
				fi
				if (( runnum % 12 == 0 )); then
					# LOG "$number is divisible by XX and can be 0."
					if [[ "$jamConf" -eq 0 ]] ; then
						LOG blue "--------------------------------------------------"
					fi
					LOG cyan "Status | Jams | Found # | Clean Streak | Uptime --"
					LOG blue "--------------------------------------------------"
				fi
				start=$SECONDS; startms=$EPOCHREALTIME; startms=${startms/./}; runnum=$((runnum+1))
				jamConf=0; nojamstreak_hold=0; jamLast_hold=0; checkStrict=0
				
				# run info ping
				if timeout --signal=SIGINT "8s" hcitool -i "$adapter_base" info "$pinged_device" &>/dev/null; then
					# got result from info
					runtime=$((SECONDS-start))
					totalruntime=$((totalruntime+runtime))
					endms=$EPOCHREALTIME; endms=${endms/./}; runtimens=$((endms - startms))
					# check runtime of result
					if [[ "$runtimens" -gt 3050000 && "$runnum" -gt 1 ]] ; then
						nojamstreak_hold="$nojamstreak"; jamLast_hold="$jamLast"
						jams=$((jams+1))
						jamLast=1
						jamConf=1
						nojamcount=0
						nojamstreak=0
						length_display
						runtime_display=""
						if [[ "$showruntimeNS" -eq 1 ]] ; then
							runtime_display="${runtime}s ($runtimens ns)"
						fi
						status_display="JAM! ¨ "
						LOG red "${status_display}|${jams_display}| $jammerDet_display | $nojamstreak_display | ${totalruntime_display} ${runtime_display}"
						LOG blue "--------------------------------------------------"
						if [[ "$nojamstreak_hold" -gt 100 ]] ; then
							LOG magenta "--- JAM! ---- Possible Jam DETECTED! ---- JAM! ---"
							LOG magenta "--- Likely a device hiccup! ex. CPU/Memory Lag ---"
						else
							if [[ "$jamLast_hold" -eq 1 ]] ; then
								# LOG "Sequential JAM!"
								LOG red "-- JAM! - Jam CONFIRMED! - Getting Warm! - JAM! --"
								seqJams=$((seqJams+1))
							else
								LOG magenta "--- JAM! ---- Possible Jam DETECTED! ---- JAM! ---"
							fi
						fi
						LOG blue "--------------------------------------------------"
						printf "%s - EVENT: Jam!\n" $(date +"%Y-%m-%d_%H%M%S") >> "$REPORT_DETJAM_FILE"
						printf "Jams: %s | Found: %s | Clean Streak: %s | Uptime: %s\n" "$jams" "$jammerDet" "$nojamstreak_hold" "$totalruntime_display" >> "$REPORT_DETJAM_FILE"
					else
						# runtime good, no jam
						nojamcount=$((nojamcount+1))
						nojamstreak=$((nojamstreak+1))
						jamLast=0
						length_display
						runtime_display=""
						if [[ "$showruntimeNS" -eq 1 ]] ; then
							runtime_display="${runtime}s ($runtimens ns)"
						fi
						if [[ "$runnum" -gt 1 ]] ; then
							# status_display="Safe ¨ "
							status_display="No Jam "
						else
							status_display="Start -"
						fi
						if [[ "$nojamcount" -ge "$maxNoJams" ]] ; then
							jams_display=" RESET"
							LOG blue "${status_display}|${jams_display}| $jammerDet_display | $nojamstreak_display | ${totalruntime_display} ${runtime_display}"
						else
							LOG "${status_display}|${jams_display}| $jammerDet_display | $nojamstreak_display | ${totalruntime_display} ${runtime_display}"
						fi
					fi
					if [[ "$nojamcount" -ge "$maxNoJams" ]] ; then
						# LOG " ------------- Resetting Jams"
						nojamcount=0
						jams=0
						seqJams=0
					fi
					sleep 1
					totalruntime=$((totalruntime+1))
				else
					# got NO result from info or TIMED OUT
					runtime=$((SECONDS-start))
					totalruntime=$((totalruntime+runtime))
					endms=$EPOCHREALTIME; endms=${endms/./}; runtimens=$((endms - startms))
					sleep 1
					# check hciconfig status for both hci0 and hci1
					checkStrict=1
					hci_check_status
					# reset strict check
					checkStrict=0
					if [[ "$adapterdown" -eq 0 ]] ; then
						# LOG "Possible Jam DETECTED!"
						# LOG "Jammer Interference or Serious CPU/Memory Lag!"
						nojamstreak_hold="$nojamstreak"; jamLast_hold="$jamLast"
						jams=$((jams+1))
						jamLast=1
						jamConf=1
						nojamcount=0
						nojamstreak=0
						length_display
						runtime_display=""
						if [[ "$showruntimeNS" -eq 1 ]] ; then
							runtime_display="${runtime}s ($runtimens ns)"
						fi
						status_display="FULLJAM"
						LOG red "${status_display}|${jams_display}| $jammerDet_display | $nojamstreak_display | ${totalruntime_display} ${runtime_display}"
						LOG blue "--------------------------------------------------"
						if [[ "$nojamstreak_hold" -gt 100 ]] ; then
							LOG red "- FULLJAM! -- Possible Jam DETECTED! -- FULLJAM! -"
							LOG magenta "--- Likely a device hiccup! ex. CPU/Memory Lag ---"
						else
							if [[ "$jamLast_hold" -eq 1 ]] ; then
								# LOG "Sequential JAM!"
								LOG red "- FULLJAM! -- Jam CONFIRMED! --- Getting Warm! ---"
								seqJams=$((seqJams+1))
							else
								LOG red "- FULLJAM! -- Possible Jam DETECTED! -- FULLJAM! -"
							fi
						fi
						LOG blue "--------------------------------------------------"
						printf "%s - EVENT: Full Jam!\n" $(date +"%Y-%m-%d_%H%M%S") >> "$REPORT_DETJAM_FILE"
						printf "Jams: %s | Found: %s | Clean Streak: %s | Uptime: %s\n" "$jams" "$jammerDet" "$nojamstreak_hold" "$totalruntime_display" >> "$REPORT_DETJAM_FILE"
						sleep 3
						totalruntime=$((totalruntime+5))
					else
						# LOG "Adapter(s) DOWN, false positive!"
						# LOG "hcitool FAIL - HOW IS THIS POSSIBLE?"
						length_display
						runtime_display=""
						if [[ "$showruntimeNS" -eq 1 ]] ; then
							runtime_display="${runtime}s ($runtimens ns)"
						fi
						status_display="DOWN --"
						LOG magenta "${status_display}|${jams_display}| $jammerDet_display | $nojamstreak_display | ${totalruntime_display} ${runtime_display}"
						LOG blue "--------------------------------------------------"
						LOG magenta "-------- Adapter DOWN/ERROR, Resetting... --------"
						bring_adapters_up
						totalruntime=$((totalruntime+5))
					fi
				fi
				if [[ "$jams" -ge "$maxJams" ]] ; then
					# jammer detected
					LOG blue "--------------------------------------------------"
					if [[ "$seqJams" -gt 0 ]] ; then
						LOG red     "-- JAMMED! ---- Jammer CONFIRMED! ----- JAMMED! --"
						LOG red     "--------- Jammer very Close or Powerful! ---------"
					else
						LOG red     "-- JAMMED! ---- Jammer CONFIRMED! ----- JAMMED! --"
					fi
					LOG blue "--------------------------------------------------"
					# gps check
					gpspos_cur=$(GPS_GET)
					if [[ "$gpspos_cur" != "0 0 0 0" ]] ; then
						gpspos_last="$gpspos_cur" # GPS is valid
						printf "GPS Pos.: %s\n" "${gpspos_last}" >> "$REPORT_DETJAM_FILE"
					else
						if [[ -n "$gpspos_last" ]] ; then # gps lost, last known coordinates: gpspos_last
							printf "GPS LOST! %s (Last Known Pos.)\n" "${gpspos_last}" >> "$REPORT_DETJAM_FILE"
						fi
					fi
					printf "%s - EVENT: Jammer Detected!\n" $(date +"%Y-%m-%d_%H%M%S") >> "$REPORT_DETJAM_FILE"
					jammerDet=$((jammerDet+1))
					total_detected=$((total_detected + 1))
					jamConf=1
					# LOG "Resetting Jams"
					nojamcount=0
					jams=0
					seqJams=0
					
					# silent alert/vibrate?
					if [[ "$scan_mute" == "false" ]] ; then
						RINGTONE "warning"
					fi
				fi
			done
			
			
			
			
			length_display
			printf "Total Runtime: %s\n" "$totalruntime_display" >> "$REPORT_DETJAM_FILE"
			printf "════════════════════════════════════════════\n" >> "$REPORT_DETJAM_FILE"
			printf "%s - EVENT: Finish scan\n" $(date +"%Y-%m-%d_%H%M%S") >> "$REPORT_DETJAM_FILE"
			printf "════════════════════════════════════════════\n" >> "$REPORT_DETJAM_FILE"
			
			total_scans=$((total_scans + 1))
			if [[ "$jammerDet" -gt 0 ]] ; then
				if [[ "$scan_stealth" -eq 0 ]] ; then LED RED SLOW; fi
				if [[ "$scan_mute" == "false" ]] ; then
					RINGTONE "warning"
				fi
				LOG red "Jammer(s) detected: $jammerDet"
				printf "%s Bluetooth Jammer(s) found\n" "${jammerDet}" >> "$REPORT_DETJAM_FILE"
			else
				if [[ "$scan_stealth" -eq 0 ]] ; then LED MAGENTA; fi
				LOG green "No Jammers detected, all clear!"
				printf "No Jammers found, all clear!\n" >> "$REPORT_DETJAM_FILE"
			fi
		
			LOG "Cleaning up..."
			rm "$KEYCKTMP_FILE" 2>/dev/null
			killall evtest 2>/dev/null
			
			# return adapters to noscan
			hciconfig hci0 up noscan 2>/dev/null
			sleep 1
			hciconfig hci1 up noscan 2>/dev/null
			sleep 1

			# change name back for discoverable mac
			if [[ "$adapter_base" == "hci1" ]] ; then
				bluetoothctl <<-EOF >/dev/null 2>&1
				select $hci0_MAC
				system-alias "$hci0_NAMEold"
				quit
				EOF
				sleep 0.5
				rm ".bluetoothctl_history" 2>/dev/null
			else
				bluetoothctl <<-EOF >/dev/null 2>&1
				select $hci1_MAC
				system-alias "$hci1_NAMEold"
				quit
				EOF
				sleep 0.5
				rm ".bluetoothctl_history" 2>/dev/null
			fi
		fi
		LOG "Completed Jammer Detection..."
		LOG green "Press OK to continue..."
		WAIT_FOR_BUTTON_PRESS A
	else
		LOG "Skipped Jammer Detection..."
	fi
	if [[ "$scan_stealth" -eq 0 ]] ; then LED MAGENTA; fi
	LOG " "
}

check_dependencies

LOG blue "--------------------------------------------------"
LOG cyan "------ Bluetooth Jammer Detector / Locator -------"
LOG cyan "------------------ by cncartist ------------------"
LOG blue "--------------------------------------------------"

detect_jammers

LOG "Exiting..."
exit 0
