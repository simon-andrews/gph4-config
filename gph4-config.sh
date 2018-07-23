#!/bin/bash

# Some global variables
camera_ssids=""
networkmanager=""
nm_candidates=( "nmcli" )
password=""
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
	echo " -h            Show this help information"
	echo " -p [PASS]     Set the WiFi password for the cameras"
	echo " -v            Enable verbose logging"
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
	case $networkmanager in
		"nmcli") connect_nmcli $1 $2 $3; return;;
	esac
	echo "Done connecting!"
}

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

function set_orientation {
	argument=-1
	case $1 in
		up)   argument=1;;
		down) argument=2;;
		gyro) argument=0;;
	esac
	if [ $argument -eq -1 ]; then
		echo "Invalid orientation $1!"
		exit 1
	fi
	quiet_get "http://10.5.5.9/gp/gpControl/setting/52/$argument"
}

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
		*)        echo "Invalid resolution $1!"; exit 1;;
	esac
	quiet_get "http://10.5.5.9/gp/gpControl/setting/2/$argument"
}

OPTIND=1 # Reset getopt, if it's been used in the shell previously
while getopts "hvc:o:r:p:" opt; do
	case $opt in
		h) show_help; exit 0;;
		v) verbose=1;;
		c) camera_ssids=$OPTARG;;
		o) target_orientation=$OPTARG;;
		r) target_resolution=$OPTARG;;
		p) password=$OPTARG;;
	esac
done
if [ $OPTIND -eq 1 ]; then
	show_help
	exit 1
fi

detect_network_manager
for ssid in $camera_ssids; do
	connect $ssid $password $interface
	if [ "$target_orientation" != "" ]; then
		set_orientation $target_orientation
	fi
	if [ "$target_resolution" != "" ]; then
		set_video_resolution $target_resolution
	fi
done
