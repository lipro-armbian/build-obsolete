#!/bin/bash
#
# This file will be sourced in context of image customization
# to prepare files at host.
#
# Copyright (c) 2017 Stephan Linz <linz@li-pro.net>
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of tool chain https://github.com/lipro-armbian/build
#

display_alert "Calling image customization script at host" "customize-image-host.sh" "info"

# script configuration
OVERLAY=$SRC/userpatches/overlay
OUTPUT=$OVERLAY/output
INPUT=$OVERLAY/input

# variables and functions that have to export from host into image
EXPORTED_VARIABLES=" \
	CUSTOMIZE_WITH \
	PROGRESS_DISPLAY \
	PROGRESS_LOG_TO_FILE \
"
EXPORTED_FUNCTIONS=" \
	display_alert \
"

display_alert "Compress and remove old logs"
mkdir -p $OUTPUT/debug
(cd $OUTPUT/debug && tar -czf logs-$(<timestamp).tgz *.log) > /dev/null 2>&1
rm -f $OUTPUT/debug/*.log > /dev/null 2>&1
date +"%d_%m_%Y-%H_%M_%S" > $OUTPUT/debug/timestamp

display_alert "Delete compressed logs older than 7 days"
(cd $OUTPUT/debug && find . -name '*.tgz' -atime +7 -delete) > /dev/null

display_alert "Export host variables to image"
mkdir -p $INPUT
cat << :EOF > $INPUT/variables.sh
#!/bin/bash
#
# Copyright (c) 2017 Stephan Linz <linz@li-pro.net>
#
# !!! DO NOT EDIT !!!
# This file was automatically generated.
#

# Variables (should be exported):
:EOF
(
	for v in $EXPORTED_VARIABLES; do
		echo "# $v"
	done
	echo
	for v in $EXPORTED_VARIABLES; do
		eval 'set | sed -n "/^$v=.*$/p"'
	done
) >> $INPUT/variables.sh

display_alert "Export host functions to image"
mkdir -p $INPUT
cat << :EOF > $INPUT/functions.sh
#!/bin/bash
#
# Copyright (c) 2017 Stephan Linz <linz@li-pro.net>
#
# !!! DO NOT EDIT !!!
# This file was automatically generated.
#

# Functions (should be exported):
:EOF
(
	for f in $EXPORTED_FUNCTIONS; do
		echo "# $f"
	done
	echo
	for f in $EXPORTED_FUNCTIONS; do
		eval 'set | sed -n "/^$f ()/,/^}/p"'
	done
) >> $INPUT/functions.sh

# for debug purpose (should be uncommented for production)
mkdir -p $INPUT
set > $INPUT/set.env
