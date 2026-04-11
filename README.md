# WiFi-Pineapple-Pager-Payloads
Hak5 WiFi Pineapple Pager Payloads by cncartist

The [BluePine Bluetooth Scanning Suite](https://github.com/cncartistsec/BluePine-WiFi-Pineapple-Pager) includes all of these Bluetooth tools in one payload and will receive more frequent updates.


# Bluetooth Device Hunter (bt-device-hunter)
![Bluetooth Device Hunter](images/BT-device-hunter.jpg)

Bluetooth Device Hunter (Classic + LE combined or separate).  Data builds over time in case name or manufacturer is missed on first scans.  Custom configuration allowed.  Verbose logging / debugging / mute / privacy mode available.



# Bluetooth Config MAC USB (bt-cfg-tool-mac)
Bluetooth MAC Address Changer for USB CSR8510 / CSR v4.0 Bluetooth Adapter.  Tool will act on hci1 by default and has been tested to work on various CSR8510 Bluetooth Adapters (range from $5-10).  Can also permanently change Alias/Name for specific MAC as an option, or restore the old name before change.  Boot the pager first before plugging in USB BT Adapter to ensure it gets hci1 instead of hci0.



# Bluetooth Config Discov/Name (bt-cfg-tool)
Bluetooth Discoverable Setting Changer + Bluetooth Hardware Name Changer.  Can change both USB + Internal Settings.



# Bluetooth PineFlipKill - WiFi Pineapple, Flipper, and USB Kill Scanner (bt-pineflipkill-scan)
WiFi Pineapple BT / Flipper Zero / USB Kill BT Scanner.  Use Pagers USB A port for bluetooth, not USB C.



# USB Ducky / Flipper Scanner & Data Stream Capture (usb-ducky-flipper)
![USB Ducky / Flipper Scanner & Data Stream Capture](images/USB-ducky-scan.jpg)

Hak5 USB Rubber Ducky / Bad USB / Flipper Zero USB Scanner & Data Stream Capture.  Use Pagers USB A port for testing, not USB C.  This tool will capture and decode the key inputs for a keyboard like device and save the output of what was being sent in a data stream text file.

Outputs (ascii art + powershell):

![Output 1](images/USB%20ducky%20mr%20bean%20output.PNG)

![Output 2](images/USB%20ducky%20powershell%20output.PNG)



# Disable All Alerts (sys-cfg-alerts-off)
![Disable All Alerts](images/ALERTS-off.jpg)

Lists and Turns All Enabled Alerts Off.  Asks before turning off and shows count/names.



# Handshake Cleaner (handshake-cleaner)
Clears/Deletes Handshakes matching SSID, helpful to clean out unwanted SSIDs.
