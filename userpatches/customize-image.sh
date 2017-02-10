#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script
#
# NOTE: It is copied to /tmp/overlay directory inside the image
# and executed there inside chroot environment so don't reference
# any files that are not already installed.
#
# Copyright (c) 2017 Stephan Linz <linz@li-pro.net>
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of tool chain https://github.com/lipro-armbian/build
#

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

SRC=/tmp/overlay
DEST=$SRC/output

# Include variables and functions as exported from host
# by the script: customize-image-host.sh
source $SRC/input/variables.sh
source $SRC/input/functions.sh

# Include here to make generic installation functions available.
source $SRC/lib/general.sh

# Prepare service list that have to process.
create_service_list CUSTOMIZE_WITH

display_alert "Starting release specific customization process" \
	"$BOARD $RELEASE" "ext"
case $RELEASE in
	wheezy)
		# your code here
		;;
	jessie)
		# your code here
		;;
	stretch)
		# your code here
		;;
	trusty)
		# your code here
		;;
	xenial)
		# your code here
		;;
esac

display_alert "Starting common customization process" \
	"$(eval 'echo ${CUSTOMIZE_SERVICES[@]}')" "ext"
for SRV in ${CUSTOMIZE_SERVICES[@]}; do
	case $SRV in
		docker)
			DOCKER_OPTIONS+=(${RELEASE,,})
			display_alert "Run installation" \
				"$SRV $(eval 'echo ${DOCKER_OPTIONS[@]}')"
			create_service_options SRV DOCKER_OPTIONS
			display_alert "With options" "$(eval 'echo ${DOCKER[@]}')"
			create_apt_source_list DOCKER
			install_apt_get DOCKER
			;;
		vagrant)
			# your code here
			;;
	esac
done
