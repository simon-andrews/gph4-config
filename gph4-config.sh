#!/bin/bash

# Some global variables
camera_ssids=""
networkmanager="unset"
nm_candidates=( "nmcli" )
verbose=0

# Performs a GET request with curl, only shows output if there are errors (HTTP
# errors don't count as "errors" here.
function quiet_get {
	curl --silent --show-error --output /dev/null $1
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
		if [ verbose != 0 ]; then
			echo "Using $networkmanager as network manager"
		fi
	fi
}

OPTIND=1 # Reset getopt, if it's been used in the shell previously
while getopts "h?vc:" opt; do
	case "$opt" in
		h) show_help; exit 0;;
		c) camera_ssids=$OPTARG;;
		v) verbose=1;;
	esac
done

echo $camera_ssids
