#!/bin/bash
#
# Copyright (c) 2017 Stephan Linz <linz@li-pro.net>
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of tool chain https://github.com/lipro-armbian/build
#

# Variables:
# CUSTOMIZE_SERVICES (global indexed array)
# DOCKER (global associative array)

# Hold all services that have to process for image customization.
declare -g -a CUSTOMIZE_SERVICES

# Hold all Docker related setup and configuration options.
declare -g -A DOCKER

# Functions:
# foreach
# __extend_service_list (internal used lambda function)
# create_service_list
# __extend_docker_options (internal used lambda function)
# create_service_options
# create_apt_source_list
# install_apt_get

# foreach <array> <function>
#
# Helper function to itterate over the given <array> and execute on each
# element the lambda <function> with the call syntax:
#
#   <function> <array_key> <array_value>
#
foreach(){
	arr="$(declare -p $1)" ; eval "declare -A f="${arr#*=};
	for i in ${!f[@]}; do $2 "$i" "${f[$i]}"; done
}

# __extend_service_list <index> <service>
#
# Extend the list of service (CUSTOMIZE_SERVICES) and its options.
# NOTE: This is an internal lambda function used by create_service_list().
#
# Parameters:
#  <index>     The index of given service option string.
#  <service>   The service option string with following syntax:
#
#              <service> := <name>,<opt0>,<opt1>, ... <optN>
#
#              Upper and lowercase of the option string has no matter.
#              All characters will converted into lowercase.
#
# Results:
#  CUSTOMIZE_SERVICES   The indexed array variable in the global environment
#                       with a list of services that have to process will be
#                       extended with the new service name.
#  <SERVICE>_OPTIONS    The indexed array variable in the global environment
#                       with a list of service options will be created.
#                       <SERVICE> is substitute with a single service name
#                       in uppercase from CUSTOMIZE_SERVICES -- so for each
#                       element in the list of services a <SERVICE>_OPTIONS
#                       variable will exist, either without or with content
#                       of given options in the origin customization string.
#
__extend_service_list()
{
	local srv=$2

	if [[ -n $srv ]]; then

		# name : opt(N) : opt(N+1)
		local options=($(tr ',' ' ' <<< "$srv"))

		local name=${options[0]}
		unset options[0] # remove the name, the 1st element
		CUSTOMIZE_SERVICES+=(${name,,})

		eval "declare -g -a ${name^^}_OPTIONS"
		eval "${name^^}_OPTIONS=(${options[@],,})"

	fi
}

# create_service_list <customize_with_name>
#
# Create a list of services that have to process and additional
# lists of options, one list for each service.
#
# Parameters:
#  <customize_with_name>   The name of an environment variable that have to
#                          hold the customization string with following syntax:
#
#                          <customize_with> := <srv0>:<srv1>: ... <srvN>
#                                    <srvX> := <name>,<opt0>,<opt1>, ... <optN>
#
#                          Upper and lowercase of the customization string
#                          has no matter. All characters will converted into
#                          lowercase.
#
# Results:
#  CUSTOMIZE_SERVICES   The indexed array variable in the global environment
#                       with a list of services that have to process will be
#                       created. Each element holds a single service name.
#  <SERVICE>_OPTIONS    The indexed array variable in the global environment
#                       with a list of service options will be created.
#                       See __extend_service_list() for more details.
#
create_service_list ()
{
	local arg1; arg1=$(declare -p $1) || \
		display_alert "${FUNCNAME[0]}: EINVAL" "$1" "err"
	eval "local c_str=${arg1#*=}"

	if [[ -n $c_str ]]; then

		# srv(N) , srv(N+1)
		local services=($(tr ':' ' ' <<< "$c_str"))
		foreach services __extend_service_list

	fi
}

# __extend_docker_options <index> <option>
#
# Extend the list of Docker options (DOCKER).
# NOTE: This is an internal lambda function used by create_service_options().
#
# Parameters:
#  <index>    The index of given option string.
#  <option>   The option string with syntax as defined for <docker_options>
#             in the calling function create_service_options(), see there.
#
# Results:
#   DOCKER[ogpgpub]   The OpenPGP public key of the remote APT repository.
#   DOCKER[repourl]   The URL of the remote APT repository.
#   DOCKER[release]   The release string for the APT repository definition.
#   DOCKER[srcfile]   The Debian APT source list file name.
#
# See:
#   https://docs.docker.com/engine/installation/linux/debian/
#   https://docs.docker.com/engine/installation/linux/ubuntu/
#   https://docs.docker.com/cs-engine/install/#/install-on-ubuntu-1404-lts
#
__extend_docker_options()
{
	local opt=$2

	case $opt in
		wheezy|jessie|stretch)
			# The Debian release of the Docker Engine.
			DOCKER[release]=debian-$opt
			;;
		trusty|xenial)
			# The Ubuntu release of the Docker Engine.
			DOCKER[release]=ubuntu-$opt
			;;
		commercial*)
			# The commercially supported version of the Docker Engine.
			DOCKER[ogpgpub]=0xA178AC6C6238F52E
			DOCKER[srcfile]=dockerproject.list
			# commercial - major_minor --> repository version (default 1.12)
			local rv=($(tr '-' ' ' <<< "$opt"))
			DOCKER[repourl]=https://packages.docker.com/${rv[1]:-1.12}/apt/repo
			;;
		community*)
			# The community supported version of the Docker Engine.
			DOCKER[ogpgpub]=0xF76221572C52609D
			DOCKER[srcfile]=dockerproject.list
			DOCKER[repourl]=https://apt.dockerproject.org/repo/
			;;
	esac
}

# create_service_options <service_name> <service_options_name>
#
# Parse environment variable DOCKER_OPTIONS or the given arguments
# and create all further required environment variable to configure
# the installation and setup process.
#
# Parameters:
#   <service_name>           The name of a variable in the global environment
#                            that have to hold the service name whose options
#                            have to create (a string).
#   <service_options_name>   The name of an indexed array variable in the
#                            global environment that have to hold the
#                            configure and installation options string for
#                            the service with following syntax.
#
# Option string syntax (indexed array):
#   <service_options> := <docker_options> | <vagrant_options>
#    <docker_options>    The Docker service option string.
#   <vagrant_options>    The Vagrant service option string.
#
# Docker option string syntax (indexed array):
#    <docker_options> := (<release> <version>)
#           <release> := wheezy | jessie | trusty | xenial
#           <version> := community | commercial[-<major_minor>]
#                       <major_minor> := 1.12 | 1.11 | 1.10 | 1.9
#
# Vagrant option string syntax (indexed array):
#   <vagrant_options> := ( t.b.d. )
#
# Results:
#   DOCKER[ogpgpub]   The OpenPGP public key of the remote APT repository.
#   DOCKER[repourl]   The URL of the remote APT repository.
#   DOCKER[release]   The release string for the APT repository definition.
#   DOCKER[srcfile]   The Debian APT source list file name.
#   DOCKER[pkglist]   The list of Debian package names.
#
create_service_options ()
{
	local arg1; arg1=$(declare -p $1) || \
		display_alert "${FUNCNAME[0]}: EINVAL" "$1" "err"
	eval "declare service=${arg1#*=}"

	local arg2; arg2=$(declare -p $2) || \
		display_alert "${FUNCNAME[0]}: EINVAL" "$2" "err"
	eval "declare -a options=${arg2#*=}"

	case $service in
		docker)
			# Prefer the community version as default. Will be
			# overridden by the commercial option in the rest of
			# the origin option list.
			options=(community ${options[@]})
			foreach options __extend_docker_options
			DOCKER[pkglist]="docker-engine"
			;;
		vagrant)
			# your code here
			;;
	esac
}

# create_apt_source_list <option_array_name>
#
# Create a new Debian APT source list entry as specified by the given
# option array.
#
# Parameters:
#   <option_array_name>   The name of an environment variable that have to
#                         hold all needed values. It must be an associative
#                         array with following keys:
#
#                         ogpgpub   OpenPGP publik key, the last 64-bit from
#                                   the fingerprint beginning with 0x
#                         repourl   Debian package repository URL
#                         release   Debian OS release name
#                         srcfile   Debian APT source list file name
#
create_apt_source_list()
{
	local arg1; arg1=$(declare -p $1) || \
		display_alert "${FUNCNAME[0]}: EINVAL" "$1" "err"
	eval "declare -A options=${arg1#*=}"

	for i in ogpgpub repourl release srcfile; do
		[[ -z ${options[$i]} ]] && \
			display_alert "${FUNCNAME[0]}: EINVAL" "$1[$i]" "err"
	done

	display_alert "Download and install OpenPGP publik key" "${options[ogpgpub]}"
	eval 'apt-key adv --keyserver keys.gnupg.net --recv-keys ${options[ogpgpub]}' \
		${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/output.log'} \
		${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

	if [ ! -f /etc/apt/sources.list.d/${options[srcfile]} ]; then
		display_alert "Create APT source list" \
			"${options[srcfile]} ${options[repourl]} ${options[release]}"
		echo "deb ${options[repourl]} ${options[release]} main" > \
			/etc/apt/sources.list.d/${options[srcfile]}
	fi

	display_alert "Updating package list. Please wait"
	eval 'apt-get update' \
		${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/output.log'} \
		${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}
}

# install_apt_get <option_array_name>
#
# Install packages with Debian APT as specified by the given option array.
#
# Parameters:
#   <option_array_name>   The name of an environment variable that have to
#                         hold all needed values. It must be an associative
#                         array with following keys:
#
#                         pkglist   Space separated List of Debian package
#                                   names that have to install.
#
install_apt_get ()
{
	local arg1; arg1=$(declare -p $1) || \
		display_alert "${FUNCNAME[0]}: EINVAL" "$1" "err"
	eval "declare -A options=${arg1#*=}"

	for i in pkglist; do
		[[ -z ${options[$i]} ]] && \
			display_alert "${FUNCNAME[0]}: EINVAL" "$1[$i]" "err"
	done

	# fancy progress bars
	[[ -z $OUTPUT_DIALOG ]] && local apt_extra_progress="--show-progress -o DPKG::Progress-Fancy=1"

	display_alert "Install packages. Please wait" "${options[pkglist]}"
	eval 'DEBIAN_FRONTEND=noninteractive apt-get -q -y \
		$apt_extra_progress install ${options[pkglist]}' \
		${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/output.log'} \
		${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}
}
