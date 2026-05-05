The [BluePine Bluetooth Scanning Suite](https://github.com/cncartistsec/BluePine-WiFi-Pineapple-Pager) includes all of the Bluetooth Scanners + Tools in one payload and will receive more frequent updates.


# Bluetooth Jammer Detector / Locator (bt-jammer-detect)
![Bluetooth Jammer Detector Poster](../images/jam-detect-poster.jpg)

![Bluetooth Jammer Detector](../images/BT-jam-detect.jpg)

Detects & Locates Bluetooth Jammers/Interference Devices within close range.  Required to have a USB Bluetooth Adapter to utilize the connection between internal and external Bluetooth.  The stronger the jammer/interference, the more easily it will be found.  Even a weak jammer can cause signal outages in devices, but it takes a very strong interference or being very close (at most 4-6 ft away from source) to interrupt the connection between the internal Bluetooth and external USB Bluetooth. 

"Jam" counter resets every 25 "nojams" to clean out errors, and the "Found" counter will only count true confirmed jams in the area.  Confirmed jams are calculated at 5 jams per 25 scans.  A sequential jam is accounted for and more severe, meaning you are closer to the jammer/interference device.  This method may not work with certain Bluetooth dongles or setups and has only been confirmed to work with a USB CSR8510 / CSR v4.0 Bluetooth Adapter on the Pager.  Includes GPS coordinate logging if GPS device enabled.
