#!/bin/bash

# Some global variables
camera_ssids=""
networkmanager=""
nm_candidates=( "nmcli" )
old_connection=""
password=""
should_update_date_time=0
target_fps=""
target_orientation=""
target_resolution=""
wifi_interface=""
verbose=0

# Performs a GET request with curl, only shows output if there are errors (HTTP
# errors don't count as "errors" here.
function quiet_get {
	echo_verbose "GET $1"
	curl --silent --show-error --output /dev/null $1
}

function echo_verbose {
	if [ $verbose -eq 1 ]; then
		echo $1
	fi
}

# Shows help information
function show_help {
	echo "gph4-config"
	echo "==========="
	echo " -c [SSIDs]    SSIDs for the GoPro cameras you want to configure"
	echo " -f [FPS]      Set frames/second. Options are 100, 60, 50, 48, 30, 24"
	echo " -h            Show this help information"
	echo " -o [SETTING]  How should the GoPro orient itself (up/down/gyro)"
	echo " -p [PASS]     Set the WiFi password for the cameras"
	echo " -r [RES]      Set resolution. Only resolutions that work on Hero 4"
	echo "               Black AND Silver are supported. Those are: 4k, 2.7k,"
	echo "               1080p_sv (superview), 1080p, 960p, 720p_sv, 720p, wvga"
	echo " -t            Synchronize the camera clock with your computer"
	echo " -v            Enable verbose messages"
}

# Detect what network manager software is being used. On Ubuntu (and most other
# Linux distros) this will be NetworkManager (nmcli). On Mac, this will be
# networksetup.
function detect_network_manager {
	for candidate in "${nm_candidates[@]}"; do
		which $candidate > /dev/null
		if [ $? -eq 0 ]; then # check which exit code was 0 (command was found)
			networkmanager=$candidate
			break
		fi
	done
	if [ "$networkmanager" = "" ]; then
		echo "No supported network managers detected!"
		echo "Supported network managers are:"
		echo $nm_candidates
		exit 1
	else
		echo_verbose "Using $networkmanager as network manager"
	fi
}

# Echos whatever network nmcli is currently connected to
function get_current_connection_nmcli {
	connections=$(nmcli connection | grep 802)
	IFS=' ' read -ra data <<< "$connections"
	# active connections float to the top, so we're _probably_ connected to the
	# first thing in the list
	for word in "${data[@]}"; do
		if [ "${#word}" -eq 36 ]; then
			echo "${word}"
			return
		fi
	done
}

# Echo whatever we're currently connected to.
function get_current_connection {
	case "$networkmanager" in
		"nmcli") echo $(get_current_connection_nmcli);;
		*)       echo "Unrecognized network manager $networkmanager!"; exit 1;;
	esac
}

# Find the current connection and make note of it so we can reconnect to it
# later
function save_old_connection {
	old_connection=$(get_current_connection)
	echo_verbose "Made a note that the current connection is $old_connection"
}

# Reconnect to whatever network we used to be connected to.
function restore_old_connection {
	echo_verbose "Re-connecting to $old_connection"
	connect $old_connection
}

# Connects to a network with nmcli. First argument is the SSID, second argument
# is the password, third argument is the interface.
function connect_nmcli {
	nmcli connection up "$1" &> /dev/null
	if [ $? -eq 10 ]; then
		echo_verbose "No existing NetworkManager profile for this GoPro found"
		echo_verbose "Making a new one..."
		nmcli device wifi connect "$1" password "$2"
	fi
}

# Connect to a network. First argument is the SSID, second argument is the
# password, third argument is the interface.
function connect {
	echo "Connecting to $1..."
	case "$networkmanager" in
		"nmcli") echo "yeet";; #connect_nmcli $1 $2 $3; return;;
		*)       echo "Unrecognized network manager $networkmanager!"; exit 1;;
	esac
	echo "Done connecting!"
}

# Tell the GoPro to enter video mode
function enter_video_mode {
	echo_verbose "Entering video mode..."
	quiet_get "http://10.5.5.9/gp/gpControl/command/mode?p=0"
}

# Enters video mode and triggers the shutter, instructing the GoPro to start
# recording video
function start_recording {
	enter_video_mode
	echo "Starting to record at $(date +%H:%M:%S)"
	quiet_get "http://10.5.5.9/gp/gpControl/command/shutter?p=1"
}

# Instructs the GoPro to stop recording video
function stop_recording {
	echo "Stopping recording at $(date +%H:%M:%S)"
	quiet_get "http://10.5.5.9/gp/gpControl/command/shutter?p=0"
}

# Set the orientation of the GoPro UI (rightside-up, upside-down, gyro based)
function set_orientation {
	argument=-1
	case $1 in
		up)   argument=1;;
		down) argument=2;;
		gyro) argument=0;;
		*)    echo "Invalid orientation $1!"; return;;
	esac
	quiet_get "http://10.5.5.9/gp/gpControl/setting/52/$argument"
}

# Set video resolution. "sv" = SuperView
function set_video_resolution {
	argument=-1
	# sv = superview
	case $1 in
		4k)       argument=1;;
		2.7k)     argument=4;;
		1440p)    argument=7;;
		1080p_sv) argument=8;;
		1080p)    argument=9;;
		960p)     argument=10;;
		720p_sv)  argument=11;;
		720p)     argument=12;;
		wvga)     argument=13;;
		*)        echo "Invalid resolution $1!"; return;;
	esac
	quiet_get "http://10.5.5.9/gp/gpControl/setting/2/$argument"
}

# Set video FPS
function set_fps {
	argument=-1
	case $1 in
		100) argument=2;;
		60)  argument=5;;
		50)  argument=6;;
		48)  argument=7;;
		30)  argument=8;;
		#25)  argument=9;; # Seems to just fall through to 10=24FPS on the camera
		24)  argument=10;; # Works fine, even though wiki says it shouldn't
		*)   echo "Invalid FPS $1!"; return;;
	esac
	quiet_get "http://10.5.5.9/gp/gpControl/setting/3/$argument"
}

# Synchronize the GoPro's time with the computer's current time.
function update_date_time {
	x=$(printf "%%%02x%%%02x%%%02x%%%02x%%%02x%%%02x" $(date "+%y %m %d %H %M %S"))
	quiet_get "http://10.5.5.9/gp/gpControl/command/setup/date_time?p=${x}"
}

OPTIND=1 # Reset getopt, if it's been used in the shell previously
while getopts "hvdc:f:o:p:r:" opt; do
	case $opt in
		h) show_help; exit 0;;
		v) verbose=1;;
		c) camera_ssids=$OPTARG;;
		d) should_update_date_time=1;;
		f) target_fps=$OPTARG;;
		o) target_orientation=$OPTARG;;
		p) password=$OPTARG;;
		r) target_resolution=$OPTARG;;
	esac
done
if [ $OPTIND -eq 1 ]; then
	show_help
	exit 1
fi

detect_network_manager
save_old_connection
for ssid in $camera_ssids; do
	connect $ssid $password $interface
	echo "Applying configuration..."
	if [ "$target_orientation" != "" ]; then
		set_orientation $target_orientation
	fi
	if [ "$target_resolution" != "" ]; then
		set_video_resolution $target_resolution
	fi
	if [ "$target_fps" != "" ]; then
		set_fps $target_fps
	fi
	if [ "$should_update_date_time" -eq 1 ]; then
		update_date_time
	fi
done
restore_old_connection
