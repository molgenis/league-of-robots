#!/bin/zsh

set -e
set -u

#
# Global variables.
#
declare pfs_base_path='/ifs/rekencluster'
declare pfs_name_prefix='umcgst'
declare TMPDIR="${TMPDIR:-/tmp}" # Default to /tmp if ${TMPDIR} was not defined.
declare SCRIPT_NAME
SCRIPT_NAME="$(basename "${0}" '.zsh')"
export TMPDIR
export SCRIPT_NAME
declare mixed_stdouterr='' # global variable to capture output from commands for reporting in custom log messages.

#
# Initialise Log4Zsh logging with defaults.
#
l4z_log_level="${log_level:-INFO}"
declare -A l4z_log_levels
l4z_log_levels=(
	'TRACE' '0'
	'DEBUG' '1'
	'INFO'  '2'
	'WARN'  '3'
	'ERROR' '4'
	'FATAL' '5'
)
l4z_log_level_prio="${l4z_log_levels[${l4z_log_level}]}"

#
# Make sure dots are used as decimal separator.
#
LANG='en_US.UTF-8'
LC_NUMERIC="${LANG}"

#
##
### functions
##
#
function showHelp() {
	#
	# Display commandline help on STDOUT.
	#
	cat <<EOH
===============================================================================================================
Script to apply quota settings to shares served by an Isilon OneFS cluster.
Quota settings are parsed from *.quotaconfig files stored on the shares.

Usage:

	${SCRIPT_NAME} OPTIONS

OPTIONS:

	-h   Show this help.
	-a   Apply (new) settings to the File System(s).
	     By default this script will only do a "dry run" and fetch + list the settings.
	-l   Log level.
	     Must be one of TRACE, DEBUG, INFO (default), WARN, ERROR or FATAL.

Details:

	Values are always reported with a dot as the decimal seperator (LC_NUMERIC="en_US.UTF-8").
===============================================================================================================

EOH
	#
	# Reset trap and exit.
	#
	trap 'trap - EXIT' EXIT
	exit 0
}

#
# Catch all function for logging using log levels like in Log4j.
# ARGS: LOG_LEVEL, LINENO, FUNCNAME, EXIT_STATUS and LOG_MESSAGE.
#
function log4Zsh() {
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
	local _log_level_prio="${l4z_log_levels[$_log_level]}"
	local _status="${4:-$?}"
	#
	# Log message if prio exceeds threshold.
	#
	if [[ "${_log_level_prio}" -ge "${l4z_log_level_prio}" ]]; then
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
		if [[ "${_log_level_prio}" -ge "${l4z_log_levels[ERROR]}" || "${_status}" -ne 0 ]]; then
			printf '%s\n' "${_log_line}" > '/dev/stderr'
		else
			printf '%s\n' "${_log_line}"
		fi
	fi	
	#
	# Exit if this was a FATAL error.
	#
	if [[ "${_log_level_prio}" -ge "${l4z_log_levels[FATAL]}" ]]; then
		#
		# Reset trap and exit.
		#
		trap 'trap - EXIT' EXIT
		if [[ "${_status}" -ne 0 ]]; then
			exit "${_status}"
		else
			exit 1
		fi
	fi
}

#
# Custom signal trapping functions (one for each signal) required to format log lines depending on signal.
#
function trapHandler() {
	local _signal="${1}"
	local _line="${2}"
	local _function="${3}"
	local _status="${4}"
	log4Zsh 'FATAL' "${_line}" "${_function}" "${_status}" "Trapped ${_signal} signal."
}

#
# Trap all exit signals: HUP(1), INT(2), QUIT(3), TERM(15), ERR.
#
TRAPHUP() {
	trapHandler 'HUP' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}"
}
TRAPINT() {
	trapHandler 'INT' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}"
}
TRAPQUIT() {
	trapHandler 'QUIT' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}"
}
TRAPTERM() {
	trapHandler 'TERM' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}"
}
TRAPEXIT() {
	local _exit_signal="${?}"
	if [[ "${_exit_signal}" -ne 0 ]]; then
		trapHandler 'EXIT' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}"
	fi
}
TRAPZERR() {
	trapHandler 'ERR' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}"
}

#
# Apply quota using "isi" commands.
#
function setIisilonDirectoryQuota () {
	local _path="${1}"
	local _soft_limit="${2}"
	local _hard_limit="${3}"
	local _grace_period="${4}"
	local _enforce="${5:-false}"
	local _quota_stats
	local _quota_cmd
	#
	# Check if dir already has quota limits
	# and hence if we need to create new or modify existing limits.
	#
	_quota_stats="$(isi quota quotas list --no-header --no-footer --format table --path "${_path}")"
	if [[ -z "${_quota_stats:-}" ]]; then
		_quota_cmd='create'
	else
		_quota_cmd='modify'
	fi
	if [[ "${_enforce}" == 'true' ]]; then
		if [[ "${apply_settings}" -eq 1 ]]; then
			log4Zsh 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Running 'isi quota quotas ${_quota_cmd}' for ${_path} with limits soft=${_soft_limit}, hard=${_hard_limit}, grace=${_grace_period} and enforced=${_enforce} ..."
			isi quota quotas "${_quota_cmd}" "${_path}" directory --enforced="${_enforce}" --container=true \
				--soft-threshold="${_soft_limit}" \
				--hard-threshold="${_hard_limit}" \
				--soft-grace="${_grace_period}"
			isi quota quotas modify "${_path}" directory --clear-advisory-threshold
		else
			log4Zsh 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Dry run: compiled 'isi quota quotas ${_quota_cmd}' command for ${_path} with limits soft=${_soft_limit}, hard=${_hard_limit}, grace=${_grace_period} and enforced=${_enforce}."
		fi
	else
		if [[ "${apply_settings}" -eq 1 ]]; then
			log4Zsh 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Running 'isi quota quotas ${_quota_cmd}' for ${_path} with advisory limit=${_soft_limit} and enforced=${_enforce} ..."
			isi quota quotas "${_quota_cmd}" "${_path}" directory --enforced="${_enforce}" --container=false \
				--advisory-threshold="${_soft_limit}"
			isi quota quotas modify "${_path}" directory --clear-soft-threshold --clear-hard-threshold
		else
			log4Zsh 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Dry run: compiled 'isi quota quotas ${_quota_cmd}' command for ${_path} with limits soft=${_soft_limit}, hard=${_hard_limit}, grace=${_grace_period} and enforced=${_enforce}."
		fi
	fi
}

#
##
### Main
##
#

#
# Get commandline arguments.
#
declare apply_settings=0
while getopts ":l:ah" opt; do
	case "${opt}" in
		h)
			showHelp
			;;
		a)
			apply_settings=1
			;;
		l)
			l4z_log_level="${OPTARG:u}"
			l4z_log_level_prio="${l4z_log_levels[${l4z_log_level}]}"
			;;
		\?)
			log4Zsh 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Invalid option -${OPTARG}. Try ${SCRIPT_NAME} -h for help."
			;;
		:)
			log4Zsh 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Option -${OPTARG} requires an argument. Try ${SCRIPT_NAME} -h for help."
			;;
		esac
done

log4Zsh 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Configuring quota ..."
#
# Find Physical File Systems/Shares (PFS-ses)
#
if [[ -e "${pfs_base_path}" ]]; then
	log4Zsh 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "${pfs_base_path} exists."
else
	log4Zsh 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "${pfs_base_path} does not exist."
fi
log4Zsh 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Search for PFS-ses with prefix ${pfs_name_prefix} in ${pfs_base_path} ..."
declare -a pfss
pfss=("${(f)$(find "${pfs_base_path}" -mindepth 1 -maxdepth 1 -type d -name "${pfs_name_prefix}*")}")
log4Zsh 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Search for PFS-ses in ${pfs_base_path} done!"
if [[ "${#pfss[@]}" -eq 0 ]]; then
	log4Zsh 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "No PFS-ses starting with prefix ${pfs_name_prefix} found in ${pfs_base_path}."
else
	log4Zsh 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Found ${#pfss[@]} PFS-ses starting with prefix ${pfs_name_prefix} found in ${pfs_base_path}:"
	log4Zsh 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "      ${pfss[*]}"
fi
#
# Search for Logical File Systems/Shares (LFS-ses) on each of the PFS-ses.
#
for pfs in "${pfss[@]}"; do
	if [[ -e "${pfs}/home" ]]; then
		log4Zsh 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Processing LFS home on PFS ${pfs} ..."
		declare -a home_dirs
		home_dirs=($(find "${pfs}/home/" -mindepth 1 -maxdepth 1 -type d | sort))
		if [[ "${#home_dirs[@]:-0}" -eq 0 ]]; then
			log4Zsh 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "No home dirs found in ${pfs}/home/."
		else
			for home_dir in "${home_dirs[@]}"; do
				setIisilonDirectoryQuota "${home_dir}" '1G' '2G' '7D' 'true'
			done
		fi
	fi
	if [[ -e "${pfs}/groups" ]]; then
		log4Zsh 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Processing groups on PFS ${pfs} ..."
		declare -a groups
		group_dirs=($(find "${pfs}/groups/" -mindepth 2 -maxdepth 2 -type d | sort))
		if [[ "${#group_dirs[@]:-0}" -eq 0 ]]; then
			log4Zsh 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "No group dirs found in ${pfs}/groups/."
		else
			for group_dir in "${group_dirs[@]}"; do
				quota_config_file="${group_dir}.quotaconfig"
				unset size_soft_limit
				unset size_hard_limit
				if [[ -f "${quota_config_file}" && -r "${quota_config_file}" ]]; then
					source "${quota_config_file}" 2>&1 || {
						log4Zsh 'ERROR' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}" "Cannot source ${quota_config_file}."
						continue
					}
					#
					# Create .quotacache file for use by clients.
					#
					if [[ "${apply_settings}" -eq 1 ]]; then
						cp "${quota_config_file}" "${group_dir}/.quotacache" \
							|| log4Zsh 'ERROR' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}" "Cannot create ${group_dir}/.quotacache"
					fi
				else
					log4Zsh 'ERROR' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "${quota_config_file} missing or not readable."
					continue
				fi
				if [[ -z "${size_soft_limit:-}" || -z "${size_hard_limit:-}" ]]; then
					log4Zsh 'ERROR' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Skipping setting quota limits for ${group_dir}, because ${quota_config_file} was malformed."
					continue
				fi
				if [[ "${size_soft_limit}" -eq 0 ]]; then
					size_soft_limit='2M'
					log4Zsh 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "   Converted soft quota limit of 0 (zero) to lowest possible value of ${size_soft_limit}."
				else
					# Just append unit: all quota values from the IDVault are in GB.
					size_soft_limit="${size_soft_limit}G"
				fi
				if [[ "${size_hard_limit}" -eq 0 ]]; then
					size_hard_limit='4M'
					log4Zsh 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "   Converted hard quota limit of 0 (zero) to lowest possible value of ${size_hard_limit}."
				else
					# Just append unit: all quota values from the IDVault are in GB.
					size_hard_limit="${size_hard_limit}G"
				fi
				setIisilonDirectoryQuota "${group_dir}" "${size_soft_limit}" "${size_hard_limit}" '14D' 'true'
			done
		fi
	fi
done

#
# Reset trap and exit.
#
log4Zsh 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" 0 'Finished!'
trap 'trap - EXIT' EXIT
exit 0
