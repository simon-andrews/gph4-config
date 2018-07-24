gph4-config
===========
gph4-config is a script for applying settings across a set of GoPro Hero 4 cameras. Both the Black and Silver models are supported. gph4-config works by connecting to the wireless network of the camera, then sending commands over HTTP.

Set up
------
 1. Power on your GoPro.
 2. Hold down the gear button on the left side for a few seconds until a light on the front flashes blue. This enables wireless.
 3. Pair the GoPro with a phone running the GoPro app. Set the SSID and password to something convenient.

Usage
-----
`./gph4-config.sh [ARGUMENTS]`. See the help menu with `./gph4-config.sh -h` for more information.

At the very least, you'll need to specify the SSIDs of the cameras you want to configure with the `-c` flag. For example, `./gph4-config.sh -c "my_gopro1 my_gopro2"`.

You'll probably also need to specify a password with the `-p` flag, especially if you're connecting to a new device for the first time.

Other neat stuff
----------------
 * [GoPro Hero 4 WiFi Commands](https://github.com/KonradIT/goprowifihack/blob/master/HERO4/WifiCommands.md)
 * The [wireless](https://github.com/joshvillbrandt/wireless) library.
