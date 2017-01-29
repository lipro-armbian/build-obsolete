#!/bin/bash
#
# Copyright (c) 2016 Stephan Linz, linz@li-pro.net
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of tool chain https://github.com/lipro-armbian/build
#
#--------------------------------------------------------------------------------------------------------------------------------
export LANG=""
exec ./compile.sh local \
	BOARD=cubietruck \
	BRANCH=dev \
	RELEASE=xenial \
	KERNEL_ONLY=no \
	BUILD_DESKTOP=no \
	ROOTFS_TYPE=ext4 \
	COMPRESS_OUTPUTIMAGE=yes \
	PROGRESS_DISPLAY=plain \
	PROGRESS_LOG_TO_FILE=yes
