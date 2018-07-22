#!/bin/bash

# Performs a GET request with curl, only shows output if there are errors (HTTP
# errors don't count as "errors" here.
function quiet_get {
	curl --silent --show-error --output /dev/null $1
}

# Detect what network manager software is being used On Ubuntu (and most other
# Linux distros) this will be NetworkManager (nmcli). On Mac, this will be
# networksetup.

networkmanager="unset"
nm_candidates=( "nmcli" )

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
	echo "Using $networkmanager as network manager"
fi
