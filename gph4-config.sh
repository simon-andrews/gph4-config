#!/bin/bash

# Some global variables
camera_ssids=""
networkmanager="unset"
nm_candidates=( "nmcli" )
password=""
wifi_interface=""
verbose=0

# Performs a GET request with curl, only shows output if there are errors (HTTP
# errors don't count as "errors" here.
function quiet_get {
	curl --silent --show-error --output /dev/null $1
}

function echo_verbose {
	if [ $verbose == 1 ]; then
		echo $1
	fi
}

# Shows help information
function show_help {
	echo "gph4-config"
	echo "==========="
	echo " -c [SSIDs]    SSIDs for the GoPro cameras you want to configure"
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

	if [ $networkmanager = "unset" ]; then
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
	echo "Connecting to $1..."
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
	case $networkmanager in
		"nmcli") connect_nmcli $1 $2 $3; return;;
	esac
}


OPTIND=1 # Reset getopt, if it's been used in the shell previously
while getopts "hvc:p:" opt; do
	case $opt in
		h) show_help; exit 0;;
		v) verbose=1;;
		c) camera_ssids=$OPTARG;;
		p) password=$OPTARG;;
	esac
done

detect_network_manager

for ssid in $camera_ssids; do
	connect $ssid $password $interface
done
