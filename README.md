
## OpenDDS-Based SmartLock demo

### About

The sources in this folder showcase OpenDDS P2P features using ICE/Stun and the RTPS Relay with a demo SmartLock application.

Currently there is an Android tablet app which communicates and controls two Raspberry Pis (mock smart-locks). The Raspberry Pis use a [Pi Traffic Light](http://lowvoltagelabs.com/products/pi-traffic/) to simulate the locked/unlocked states simply by lighting up red for unlocked and green for locked.

Some notes on the directory structure:

* _android_: Android Studio project files and Idl for SmartLock app.
* _certs_: Certificates for one tablet and two Raspberry Pis (the tablet files are also copied under android SmartLock/app/src/main/assets).
* _deploy_:  Deployment scripts for RTPS Relay on GCP.
* _dockerfiles_: Build environments for Android and Raspberry Pi.
* _src_: Source files for SmartLock application on Raspberry Pi and the core IDL files used by Android as well.

### Plugging in the pins

On the Raspberry Pi, the smart lock app uses the below (highlighted in yellow) traffic light pin assignments. Simply plug in the light so that the first pin is the 19th pin and the lights are facing outside of the case (away from the circuit board). The yellow box below shows which ones. Additionally, on the traffic light board it shows which lights are expected in GPIO pin 10, 9, 11, GND (actual pins 19, 21, 23, 25) in the order to match them up if needed.

![Raspberry Pi Pin assignments](docs/pi-traffic-light-pins.png)
