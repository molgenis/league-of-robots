#jinja2: trim_blocks:True, lstrip_blocks: True
#!/bin/bash

#
# Code Conventions:
# 	Indentation:           TABs only
# 	Functions:             camelCase
# 	Global Variables:      lower_case_with_underscores
# 	Local Variables:       _lower_case_with_underscores_and_prefixed_with_underscore
# 	Environment Variables: UPPER_CASE_WITH_UNDERSCORES
#

#
##
### Environment and Bash sanity.
##
#
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
	echo "Sorry, you need at least bash 4.x to use ${0}." >&2
	exit 1
fi

set -e # Exit if any subcommand or pipeline returns a non-zero exit status.
set -u # Raise exception if variable is unbound. Combined with set -e will halt execution when an unbound variable is encountered.
set -o pipefail # Fail when any command in series of piped commands failed as opposed to only when the last command failed.

umask 0077

#
# No more Ansible variables below this point!
#
{% raw %}
#
# Global variables.
#
declare TMPDIR="${TMPDIR:-/tmp}" # Default to /tmp if ${TMPDIR} was not defined.
declare SCRIPT_NAME
SCRIPT_NAME="$(basename "${0}" '.bash')"
export TMPDIR
export SCRIPT_NAME
declare mixed_stdouterr='' # global variable to capture output from commands for reporting in custom log messages.

#
# Initialise Log4Bash logging with defaults.
#
l4b_log_level="${log_level:-INFO}"
declare -A l4b_log_levels=(
	['TRACE']='0'
	['DEBUG']='1'
	['INFO']='2'
	['WARN']='3'
	['ERROR']='4'
	['FATAL']='5'
)
l4b_log_level_prio="${l4b_log_levels["${l4b_log_level}"]}"

#
# Make sure dots are used as decimal separator.
#
LANG='en_US.UTF-8'
LC_NUMERIC="${LANG}"

#
##
### Functions.
##
#
function showHelp() {
	#
	# Display commandline help on STDOUT.
	#
	cat <<EOH
===============================================================================================================
Script to apply quota to Lustre file systems used on HPC clusters from the League of Robots.
 * For home dirs this script will configure user quota with a small hard coded limit.
 * For group folders this will be project / file set quota
   based on values stored in *.quotaconfig files on that file system.

E.g. when a group folder located at

	/mnt/umcgst04_slice5/groups/umcg-sysops/tmp08/
	
has a corresponding *.quotaconfig at

	/mnt/umcgst04_slice5/groups/umcg-sysops/tmp08.quotaconfig

With content

	project_id=63700187
	size_soft_limit=128
	size_hard_limit=1152

this script will set project quota with project ID 63700187 and the listed values in GB.

Usage:

	$(basename "${0}") OPTIONS

OPTIONS:

	-h   Show this help.
	-a   Apply (new) settings to the File System(s).
	     By default this script will only do a "dry run" and list the settings used.
	 r   Recursively (re)apply p and P attributes on Lustre project quota dirs.
	     WARNING: this will take a long time when there is a lot of data on the file system.
	     Under normal conditions this should not be necessary, but it can be used to add these attributes in
	     case they were lost or in case Lustre project quota is turned on later for existing data.
	-l   Log level.
	     Must be one of TRACE, DEBUG, INFO (default), WARN, ERROR or FATAL.

Details:

	Values are always reported with a dot as the decimal seperator (LC_NUMERIC="en_US.UTF-8").
===============================================================================================================

EOH
	#
	# Reset trap and exit.
	#
	trap - EXIT
	exit 0
}

#
# Custom signal trapping functions (one for each signal) required to format log lines depending on signal.
#
function trapSig() {
	for _sig; do
		trap 'trapHandler '"${_sig}"' ${LINENO} ${FUNCNAME[0]:-main} ${?}' "${_sig}"
	done
}

function trapHandler() {
	local _signal="${1}"
	local _line="${2}"
	local _function="${3}"
	local _status="${4}"
	log4Bash 'FATAL' "${_line}" "${_function}" "${_status}" "Trapped ${_signal} signal."
}

#
# Trap all exit signals: HUP(1), INT(2), QUIT(3), TERM(15), ERR.
#
trapSig HUP INT QUIT TERM EXIT ERR

#
# Catch all function for logging using log levels like in Log4j.
# ARGS: LOG_LEVEL, LINENO, FUNCNAME, EXIT_STATUS and LOG_MESSAGE.
#
function log4Bash() {
	#	
	# Validate params.
	#
	if [ ! "${#}" -eq 5 ] ;then
		echo "WARN: should have passed 5 arguments to ${FUNCNAME[0]}: log_level, LINENO, FUNCNAME, (Exit) STATUS and log_message."
	fi
	#
	# Determine prio.
	#
	local _log_level="${1}"
	local _log_level_prio="${l4b_log_levels["${_log_level}"]}"
	local _status="${4:-$?}"
	#
	# Log message if prio exceeds threshold.
	#
	if [[ "${_log_level_prio}" -ge "${l4b_log_level_prio}" ]]; then
		local _problematic_line="${2:-'?'}"
		local _problematic_function="${3:-'main'}"
		local _log_message="${5:-'No custom message.'}"
		#
		# Some signals erroneously report $LINENO = 1,
		# but that line contains the shebang and cannot be the one causing problems.
		#
		if [ "${_problematic_line}" -eq 1 ]; then
			_problematic_line='?'
		fi
		#
		# Format message.
		#
		local _log_timestamp
		local _log_line_prefix
		_log_timestamp=$(date "+%Y-%m-%dT%H:%M:%S") # Creates ISO 8601 compatible timestamp.
		_log_line_prefix=$(printf "%-s %-s %-5s @ L%-s(%-s)>" "${SCRIPT_NAME}" "${_log_timestamp}" "${_log_level}" "${_problematic_line}" "${_problematic_function}")
		local _log_line="${_log_line_prefix} ${_log_message}"
		if [[ -n "${mixed_stdouterr:-}" ]]; then
			_log_line="${_log_line} STD[OUT+ERR]: ${mixed_stdouterr}"
		fi
		if [[ "${_status}" -ne 0 ]]; then
			_log_line="${_log_line} (Exit status = ${_status})"
		fi
		#
		# Log to STDOUT (low prio <= 'WARN') or STDERR (high prio >= 'ERROR').
		#
		if [[ "${_log_level_prio}" -ge "${l4b_log_levels['ERROR']}" || "${_status}" -ne 0 ]]; then
			printf '%s\n' "${_log_line}" > '/dev/stderr'
		else
			printf '%s\n' "${_log_line}"
		fi
	fi	
	#
	# Exit if this was a FATAL error.
	#
	if [[ "${_log_level_prio}" -ge "${l4b_log_levels['FATAL']}" ]]; then
		#
		# Reset trap and exit.
		#
		trap - EXIT
		if [[ "${_status}" -ne 0 ]]; then
			exit "${_status}"
		else
			exit 1
		fi
	fi
}

#
# Parse *.quotaconfig files and apply quota to Physical File Systems (PFSs) containing group dirs.
#
function processGroupDirs () {
	local    _lfs_path_regex='/mnt/([^/]+)/groups/([^/]+)/([^/]+)'
	local    _pos_int_regex='^[0-9]+$'
	local    _lfs_path
	local -a _lfs_paths=("${@}")
	#
	# Loop over Logical File System (LFS) paths,
	# find the corresponding quota values,
	# and apply quota settings.
	#
	for _lfs_path in "${_lfs_paths[@]}"; do
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Processing LFS path ${_lfs_path} ..."
		local _pfs_from_lfs_path
		local _group_from_lfs_path
		local _lfs_from_lfs_path
		local _fs_type
		if [[ "${_lfs_path}" =~ ${_lfs_path_regex} ]]; then
			_pfs_from_lfs_path="${BASH_REMATCH[1]}"
			_group_from_lfs_path="${BASH_REMATCH[2]}"
			_lfs_from_lfs_path="${BASH_REMATCH[3]}"
			log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      found _pfs_from_lfs_path:   ${_pfs_from_lfs_path}."
			log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      found _group_from_lfs_path: ${_group_from_lfs_path}."
			log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      found _lfs_from_lfs_path:   ${_lfs_from_lfs_path}."
			_fs_type="$(awk -v _mount_point="/mnt/${_pfs_from_lfs_path}" '{if ($2 == _mount_point) print $3}' /proc/mounts)"
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "      found _fs_type:             ${_fs_type}."
		else
			log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipping malformed LFS path ${_lfs_path}."
			continue
		fi
		#
		# Get values from *.quotaconfig file.
		#
		unset project_id
		unset size_soft_limit
		unset size_hard_limit
		if [[ -e  "${_lfs_path}.quotaconfig" && -r "${_lfs_path}.quotaconfig" ]]; then
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "   Fetching quota settings from ${_lfs_path}.quotaconfig ..."
			# shellcheck source=/dev/null
			source "${_lfs_path}.quotaconfig"
		else
			log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "   Config file ${_lfs_path}.quotaconfig missing or not readable."
			continue
		fi
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      project_id      = ${project_id:-}"
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      size_soft_limit = ${size_soft_limit:-}"
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      size_hard_limit = ${size_hard_limit:-}"
		if [[ -z "${project_id:-}" || \
			  -z "${size_soft_limit:-}" || \
			  -z "${size_hard_limit:-}" ]]; then
			log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "   Quota values missing for group ${_group_from_lfs_path} on LFS ${_lfs_from_lfs_path}."
			continue
		fi
		#
		# Check for negative numbers and non-integers.
		#
		if [[ ! "${project_id}" =~ ${_pos_int_regex} || ! "${size_soft_limit}" =~ ${_pos_int_regex} || ! "${size_hard_limit}" =~ ${_pos_int_regex} ]]; then
			log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "   Quota values malformed for group ${_group_from_lfs_path} on LFS ${_lfs_from_lfs_path}. Must be integers >= 0."
			continue
		fi
		#
		# Check if soft limit is larger than the hard limit as that will quota commands to fail.
		#
		if [[ "${size_soft_limit}" -gt "${size_hard_limit}" ]]; then
			log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "   Quota values malformed for group ${_group_from_lfs_path} on LFS ${_lfs_from_lfs_path}. Soft limit cannot be larger than hard limit."
			continue
		fi
		#
		# Check for 0 (zero).
		# When quota values are set to zero it means unlimited: not what we want.
		# When zero was specified we'll interpret this as "do not allow this group to consume any space".
		#
		# Due to the technical limitations of how quota work we'll configure the lowest possible value instead:
		# This is 2 * the block/stripe size on Lustre File Systems.
		# With the current block size of 1 MB this means a 2 MB minimal soft quota limit.
		#
		# On Isilon systems the hard limit must be larger than the soft limit,
		# so therefore we use 4 * the block/stripe size for the hard limit.
		#
		if [[ "${size_soft_limit}" -eq 0 ]]; then
			size_soft_limit='2M'
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "   Converted soft quota limit of 0 (zero) for group ${_group_from_lfs_path} on LFS ${_lfs_from_lfs_path} to lowest possible value of ${size_soft_limit}."
		else
			# Just append unit: all quota values from the IDVault are in GB.
			size_soft_limit="${size_soft_limit}G"
		fi
		if [[ "${size_hard_limit}" -eq 0 ]]; then
			size_hard_limit='4M'
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "   Converted hard quota limit of 0 (zero) for group ${_group_from_lfs_path} on LFS ${_lfs_from_lfs_path} to lowest possible value of ${size_hard_limit}."
		else
			# Just append unit: all quota values from the IDVault are in GB.
			size_hard_limit="${size_hard_limit}G"
		fi
		if [[ "${_fs_type}" == 'lustre' ]]; then
				applyLustreQuota "${_lfs_path}" 'project' "${project_id}" "${size_soft_limit}" "${size_hard_limit}"
		else
			log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "   Cannot configure quota due to unsupported file system type: ${_fs_type}."
		fi
		#
		# Create .quotcache file in place that is accessible for users on all systems,
		# because *.quotaconfig file is not part of the mount and hence only available
		# on a SAI and not accessible on other systems.
		# This will allow users to check the quota status of their folders using the quota
		# command from the cluster-utils module.
		#
		if [[ "${apply_settings}" -eq 1 ]]; then
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "   Creating ${_lfs_path}/.quotacache file ..."
			{
				cp "${_lfs_path}.quotaconfig" "${_lfs_path}/.quotacache.new"
				mv "${_lfs_path}/.quotacache.new" "${_lfs_path}/.quotacache"
			} || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" "${?}" "   Failed to create ${_lfs_path}/.quotacache."
		fi
	done
}

#
# Apply quota to Physical File Systems (PFSs) containing home dirs.
#
function processHomeDirs () {
	local    _lfs_path_regex='/mnt/([^/]+)/(home)/([^/]+)'
	local    _lfs_path
	local -a _lfs_paths=("${@}")
	local    _soft_quota_limit='1G'
	local    _hard_quota_limit='2G'
	for _lfs_path in "${_lfs_paths[@]}"; do
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Processing LFS path ${_lfs_path} ..."
		local _pfs_from_lfs_path
		local _lfs_from_lfs_path
		local _user_from_lfs_path
		local _fs_type
		if [[ "${_lfs_path}" =~ ${_lfs_path_regex} ]]; then
			_pfs_from_lfs_path="${BASH_REMATCH[1]}"
			_lfs_from_lfs_path="${BASH_REMATCH[2]}"
			_user_from_lfs_path="${BASH_REMATCH[3]}"
			log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      found _pfs_from_lfs_path:  ${_pfs_from_lfs_path}."
			log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      found _lfs_from_lfs_path:  ${_lfs_from_lfs_path}."
			log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      found _user_from_lfs_path: ${_user_from_lfs_path}."
			_fs_type="$(awk -v _mount_point="/mnt/${_pfs_from_lfs_path}" '{if ($2 == _mount_point) print $3}' /proc/mounts)"
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "      found _fs_type:             ${_fs_type}."
		else
			log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipping malformed LFS path ${_lfs_path}."
			continue
		fi
		if [[ "${_fs_type}" == 'lustre' ]]; then
			#
			# Get the UID for this user and use it as a unique quota project ID.
			#
			local _uid
			_uid="$(id -u "${_user_from_lfs_path}")"
			applyLustreQuota "${_lfs_path}" 'project' "${_uid}" "${_soft_quota_limit}" "${_hard_quota_limit}"
		else
			log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "   Cannot configure quota due to unsupported file system type: ${_fs_type}."
		fi
	done
}

#
# Prefer Lustre project a.k.a. file set a.k.a folder quota limits:
#  * Set project attribute on LFS path using project ID.
#  * Use "lfs setquota" to configure quota limit for project.
#
function applyLustreQuota () {
	local    _lfs_path="${1}"
	local    _quota_type="${2}"
	local    _id="${3}"
	local    _soft_quota_limit="${4}"
	local    _hard_quota_limit="${5}"
	local    _cmd
	local -a _cmds
	if [[ "${apply_settings}" -eq 1 ]]; then
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "   Executing quota commands ..."
	else
		log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "   Dry run: the following quota commands would have been executed with the '-a' switch ..."
	fi
	if [[ "${_quota_type}" == 'project' ]]; then
		if [[ "${recursive}" -eq 1 ]]; then
			#
			# Disabling set -e for recursive chattr is required,
			# because chattr returns exit 1 when it encounters data that is not a file nor directory.
			# E.g. it will return exit 1 when it encounters a symlink and
			# there is no simple commandline argument to skip/ignore symlinks.
			# Moreover using
			#	"set +e && chattr -R -f +P ${_lfs_path}"
			#	"set +e && chattr -R -f -p ${_id} ${_lfs_path}"
			# in "${_cmds[@]" and looping over those command lines in a sub shell with
			#	mixed_stdouterr="$(${_cmd} 2>&1)" || ....
			# does not work either: it will not generate an error, but will not apply the attributes recursively either.
			#
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" "${?}" '   Applying project quota attributes recursively with chattr; This may take a long time ...'
			{ set +e
			  chattr -R -f +P "${_lfs_path}"
			  chattr -R -f -p ${_id} "${_lfs_path}"
			  set -e
			} || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" "${?}" '   Failed to apply chattr recursively.'
			_cmds=(
				"lfs setquota -p ${_id} --block-softlimit ${_soft_quota_limit} --block-hardlimit ${_hard_quota_limit} ${_lfs_path}"
			)
		else
			_cmds=(
				"chattr +P ${_lfs_path}"
				"chattr -p ${_id} ${_lfs_path}"
				"lfs setquota -p ${_id} --block-softlimit ${_soft_quota_limit} --block-hardlimit ${_hard_quota_limit} ${_lfs_path}"
			)
		fi
	elif [[ "${_quota_type}" == 'group' ]]; then
		_cmds=(
			"lfs setquota -g ${_id} --block-softlimit ${_soft_quota_limit} --block-hardlimit ${_hard_quota_limit} ${_lfs_path}"
		)
	else
		log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "   Unsupported Lustre quota type: ${_quota_type}."
	fi
	for _cmd in "${_cmds[@]}"; do
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "   Command: ${_cmd}"
		if [[ "${apply_settings}" -eq 1 ]]; then
			mixed_stdouterr="$(${_cmd} 2>&1)" || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" "${?}" "Failed to execute: ${_cmd}"
		else
			log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' '     Dry run: nothing changed.'
		fi
	done
}

#
##
### Main.
##
#

#
# Get commandline arguments.
#
declare apply_settings=0
declare recursive=0
while getopts ":l:ahr" opt; do
	case "${opt}" in
		h)
			showHelp
			;;
		a)
			apply_settings=1
			;;
		r)
			recursive=1
			;;
		l)
			l4b_log_level="${OPTARG^^}"
			l4b_log_level_prio="${l4b_log_levels["${l4b_log_level}"]}"
			;;
		\?)
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Invalid option -${OPTARG}. Try $(basename "${0}") -h for help."
			;;
		:)
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Option -${OPTARG} requires an argument. Try $(basename "${0}") -h for help."
			;;
		*)
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Unhandled option. Try $(basename "${0}") -h for help."
			;;
		esac
done

#
# Get a list of LFS paths: folders for groups, which we want to apply project quota to.
# On a SAI always in format/location:
#	/mnt/${pfs}/groups/${group}/${lfs}/
# E.g.:
#	/mnt/umcgst02/groups/umcg-atd/prm08/
#
readarray -t lfs_paths < <(find /mnt/*/groups/*/ -maxdepth 1 -mindepth 1 -type d -name "[a-z][a-z]*[0-9][0-9]*")
processGroupDirs "${lfs_paths[@]:-}"

#
# Apply hard coded limits to home dirs for all regular users.
#
readarray -t lfs_paths < <(find /mnt/*/home/ -maxdepth 1 -mindepth 1 -type d)
processHomeDirs "${lfs_paths[@]:-}"

#
# Reset trap and exit.
#
log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" 0 "Finished!"
trap - EXIT

{% endraw %}
