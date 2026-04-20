#!/bin/bash
# Title: USB Enable Storage Devices / Mass Media
# Author: cncartist
# Description: Tool will create hotplug file that enables mass media/USB storage devices for Pager, or allow it to be removed.  Devices will be mounted to /usb/ by default and no reboot is required.  Thanks to dark_pyrro for research and documentation on the fix.
# Category: general
# 
# Acknowledgements: 
# dark_pyrro - Research and fix for USB storage devices for Pager
# WFP_pager_HotPlug-USB - https://codeberg.org/dark_pyrro/WFP_pager_HotPlug-USB
# 

# ---- CONFIG ----
usbhotplug_file="/etc/hotplug.d/block/20-usb"

# check if file is not empty this time around
if [[ -s "$usbhotplug_file" ]]; then
	LOG " "
	LOG "Hotplug file for USB already exists:"
	LOG green "$usbhotplug_file"
	LOG "Press OK to continue..."
	LOG " "
	WAIT_FOR_BUTTON_PRESS A
	sleep 0.5
	resp=$(CONFIRMATION_DIALOG "Do you want to Remove the Hotplug file from your Pager?

	Disabling USB Storage Device Auto-Mount?")
	if [[ "$resp" == "$DUCKYSCRIPT_USER_CONFIRMED" ]] ; then
		LOG "Removing Hotplug file..."
		rm "$usbhotplug_file"
		LOG "Hotplug file removed!"
		LOG green "Completed!"
	else
		LOG "Keeping Hotplug file..."
	fi
else
	LOG " "
	resp=$(CONFIRMATION_DIALOG "Do you want to Enable USB Storage Device Auto-Mount for your Pager?")
	if [[ "$resp" == "$DUCKYSCRIPT_USER_CONFIRMED" ]] ; then
		LOG "Creating Hotplug file for USB Auto-Mount..."
cat <<EOF > "$usbhotplug_file"
#!/bin/bash

[[ "\$ACTION" == "add" ]] || [[ "\$ACTION" == "remove" ]] || exit
[[ "\$DEVTYPE" == "partition" ]] || [[ "\$DEVTYPE" == "disk" ]] || exit

[[ "\$ACTION" == "add" ]] && {
        [[ \$(echo \$DEVPATH | grep usb) ]] && {
                umount /usb
                mount /dev/\$DEVNAME /usb
        }
}
EOF
		LOG "Hotplug file created!"
		LOG "Setting permissions..."
		chmod +x "$usbhotplug_file"
		LOG green "Completed!"
		LOG " "
		LOG "Now you can use USB Storage with the Pager."
		LOG " "
		LOG "USB Storage Devices will mount to '/usb/'"
	else
		LOG "Hotplug file creation skipped..."
	fi
fi

exit 0
