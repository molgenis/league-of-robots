#!/bin/bash

# shellcheck disable=SC2004

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

umask 0027

# Env vars.
export TMPDIR="${TMPDIR:-/tmp}" # Default to /tmp if $TMPDIR was not defined.
SCRIPT_NAME="$(basename "${0}")"
SCRIPT_NAME="${SCRIPT_NAME%.*sh}"
LOG_DIR="/var/log/${SCRIPT_NAME}/"
ROLE_USER="$(whoami)"
REAL_USER="$(logname 2>/dev/null || echo 'no login name')"

#
##
### Generic BASH functions for error handling and logging.
##
#

#
# Custom signal trapping functions (one for each signal) required to format log lines depending on signal.
#
function trapSig() {
	for _sig; do
		trap 'trapHandler '"${_sig}"' ${LINENO} ${FUNCNAME[0]:-main} ${?}' "${_sig}"
	done
}

# shellcheck disable=SC2329
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
#
# Requires 5 ARGS:
#  1. log_level        Defined explicitly by programmer.
#  2. ${LINENO}        Bash env var indicating the active line number in the executing script.
#  3. ${FUNCNAME[0]}   Bash env var indicating the active function in the executing script.
#  4. (Exit) STATUS    Either defined explicitly by programmer or use Bash env var ${?} for the exit status of the last command.
#  5  log_message      Defined explicitly by programmer.
#
# When log_level == FATAL the script will be terminated.
#
# Example of debug log line (should use EXIT_STATUS = 0 = 'OK'):
#    log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' 'We managed to get this far.'
#
# Example of FATAL error with explicit exit status 1 defined by the script: 
#    log4Bash 'FATAL' ${LINENO} "${FUNCNAME[0]:-main}" '1' 'We cannot continue because of ... .'
#
# Example of executing a command and logging failure with the EXIT_STATUS of that command (= ${?}):
#    someCommand || log4Bash 'FATAL' ${LINENO} "${FUNCNAME[0]:-main}" ${?} 'Failed to execute someCommand.'
#
function log4Bash() {
	local _log_level
	local _log_level_prio
	local _status
	local _problematic_line
	local _problematic_function
	local _log_message
	local _log_timestamp
	local _log_line_prefix
	local _log_line
	#
	# Validate params.
	#
	if [[ "${#}" -ne 5 ]]; then
		echo "WARN: should have passed 5 arguments to ${FUNCNAME[0]}: log_level, LINENO, FUNCNAME, (Exit) STATUS and log_message."
	fi
	#
	# Determine prio.
	#
	_log_level="${1}"
	_log_level_prio="${l4b_log_levels["${_log_level}"]}"
	_status="${4:-$?}"
	#
	# Log message if prio exceeds threshold.
	#
	if [[ "${_log_level_prio}" -ge "${l4b_log_level_prio}" ]]; then
		_problematic_line="${2:-'?'}"
		_problematic_function="${3:-'main'}"
		_log_message="${5:-'No custom message.'}"
		#
		# Some signals erroneously report $LINENO = 1,
		# but that line contains the shebang and cannot be the one causing problems.
		#
		if [[ "${_problematic_line}" -eq 1 ]]; then
			_problematic_line='?'
		fi
		#
		# Format message.
		#
		_log_timestamp=$(date "+%Y-%m-%dT%H:%M:%S") # Creates ISO 8601 compatible timestamp.
		_log_line_prefix=$(printf "%-s %-s %-5s @ L%-s(%-s)>" "${SCRIPT_NAME}" "${_log_timestamp}" "${_log_level}" "${_problematic_line}" "${_problematic_function}")
		_log_line="${_log_line_prefix} ${_log_message}"
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
			printf '%s\n' "${_log_line}" 1>&2
		else
			printf '%s\n' "${_log_line}"
		fi
	fi
	#
	# Exit if this was a FATAL error.
	#
	if [[ "${_log_level_prio}" -ge "${l4b_log_levels['FATAL']}" ]]; then
		#
		# Cleanup
		#
		rm -Rf "${BACKUP_TMP_DIR:-missing}"
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
l4b_log_level_prio="${l4b_log_levels[${l4b_log_level}]}"
mixed_stdouterr='' # global variable to capture output from commands for reporting in custom log messages.

#
# Lock function using flock and a file descriptor (FD).
# This uses FD 200 as per flock manpage example.
#
function thereShallBeOnlyOne() {
	local _lock_file
	local _lock_dir
	_lock_file="${1}"
	_lock_dir="$(dirname "${_lock_file}")"
	mkdir -p "${_lock_dir}"  || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}" "Failed to create dir for lock file @ ${_lock_dir}."
	exec 200>"${_lock_file}" || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}" "Failed to create FD 200>${_lock_file} for locking."
	if ! flock -n 200; then
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Lockfile ${_lock_file} already claimed by another instance of $(basename "${0}")."
		log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' 'Another instance is already running and there shall be only one.'
		# No need for explicit exit here: log4Bash with log level FATAL will make sure we exit.
	fi
}

function showHelp() {
	#
	# Display commandline help on STDOUT.
	#
	cat <<EOH
===============================================================================================================
Creates backups using rsync with support for "link-dest" to save storage space.

Usage:

	$(basename "${0}") OPTIONS

Options:

	-h	Show this help.
	-l	[level]
		Log level.
		Must be one of TRACE, DEBUG, INFO (default), WARN, ERROR or FATAL.
	-s	[source]
		Source data to be backupped.
		May be local data or data from a remote machine.
		E.g.:
			/path/to/source/data
			hostname:/path/to/source/data
			fully.qualified.domain.name:/path/to/source/data
	-d	[destination]
		Destination on local storage of the backup server where the baskup will be stored.
	-k	Minimum number of successful backups to keep.
	-r	Minimal retention time for backups.
	-u	User: the account used to create the backups.
		This user must have read access to the source and read + write access to the destination.

Backups older than the retention time specified with -r will be deleted automatically only
when there are more successful backups than specified with -k.

===============================================================================================================
EOH
	trap - EXIT
	exit 0
}

#
##
### Main.
##
#

#
# Get commandline arguments.
#
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Parsing commandline arguments ..."
declare destination=''
declare source=''
declare keep=''
declare retention_time=''
declare user=''
while getopts ":d:s:k:r:u:l:h" opt; do
	case "${opt}" in
		h)
			showHelp
			;;
		d)
			destination="${OPTARG}"
			;;
		s)
			source="${OPTARG}"
			;;
		k)
			keep="${OPTARG}"
			;;
		r)
			retention_time="${OPTARG}"
			;;
		u)
			user="${OPTARG}"
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
# Check commandline options.
#
if [[ -z "${destination:-}" ]]; then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Must specify destination where to store the backup with -d. Try $(basename "${0}") -h for help."
elif [[ ! "${destination}" =~ ^[a-zA-Z0-9_/.-]+$ ]]; then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Destination where to store the backup contains invalid characters. Try $(basename "${0}") -h for help."
fi
if [[ -z "${source:-}" ]]; then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Must specify source data to backup with -s. Try $(basename "${0}") -h for help."
elif [[ ! "${source}" =~ ^[a-zA-Z0-9_/.:@-]+$ ]]; then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Source data to backup contains invalid characters. Try $(basename "${0}") -h for help."
fi
if [[ -z "${keep:-}" ]]; then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Must specify the minimal number of successful backups to keep with -k. Try $(basename "${0}") -h for help."
elif [[ ! "${keep}" =~ ^[0-9]+$ ]]; then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Number of backups to keep must be an integer. Try $(basename "${0}") -h for help."
fi
if [[ -z "${retention_time:-}" ]]; then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '0' "Must specify the minimal retention time with -r. Try $(basename "${0}") -h for help."
elif [[ ! "${retention_time}" =~ ^[0-9]+$ ]]; then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Retention time in days must be an integer. Try $(basename "${0}") -h for help."
fi
if [[ -z "${user:-}" ]]; then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '0' "Must specify the username for the account that will create the backups with -u. Try $(basename "${0}") -h for help."
else
	if [[ "${ROLE_USER}" != "${user}" ]]; then
		log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "This script must be executed by user ${user}, but you are ${ROLE_USER} (${REAL_USER})."
	fi
fi

#
# Create log dir
#
# shellcheck disable=SC2174
mkdir -m 700 -p "${LOG_DIR}/" || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" "$?" "Cannot create ${LOG_DIR}."
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Log files will be written to ${LOG_DIR} ..."

#
# Make sure only one copy of this script runs simultaneously per source to backup.
#
# As servernames and folders may contain various characters that would require escaping in (lock) file names,
# we compute a hash of ${source} to append to the ${SCRIPT_NAME} for creating unique lock file.
# We write the ${source} down in the lock file to make it easier to detect which ${source} the lock file is for.
#
hashed_source="$(printf '%s' "${source}" | md5sum | awk '{print $1}')"
lock_file="${LOG_DIR}/${SCRIPT_NAME}-${hashed_source}.lock"
thereShallBeOnlyOne "${lock_file}"
printf 'This lock file is used for making backups of %s.\n' "${source}" > "${lock_file}"

#
# Ensure destination dir exists.
#
# shellcheck disable=SC2174
mkdir -p -m 700 "${destination}/"  || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" "$?" "Cannot create ${destination}."

#
# Create backup with rsync
#
# -r recursive
# -l preserve symlinks
# -p preserve permissions
# -t preserve modification times
# -g preserve group
# -o preserver owner
# -A preserve ACLs
# -H preserve hard links
# -X preserve extended attributes
# -c Use checksum, not modification time & size, to determine if files have changed.
# -s No space-splitting for source or destination paths. (Wildcard chars can be used.)
# -S handle sparse files efficiently
# -q quiet; suppress non-error messages.
#
backup_start_ts="$(date "+%Y-%m-%d-T%H%M")"
if [[ -e "${destination}/${backup_start_ts}" ]]; then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Backup ${destination}/${backup_start_ts} already exists."
fi
printf 'Working on backup of %s to %s ... ' "${source}" "${destination}/${backup_start_ts}" >> "${lock_file}"
rsync_log="${LOG_DIR}/${SCRIPT_NAME}-${hashed_source}-rsync-${backup_start_ts}.log"
log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "Using rsync log file ${rsync_log}."
set +e
if [[ -L "${destination}/latest_rsync" ]]; then
	#
	# Use Rsync's --link-dest feature to create multiple hard links to the same files 
	# if they have not changed since the previous backup.
	# This prevents redundancy and hence saves precious backup disk space.
	#
	rsync -rlptgoAHXcsSq --link-dest="${destination}/latest" \
	"${source}" \
	"${destination}/${backup_start_ts}_in_flux" \
	>> "${rsync_log}" 2>&1
	return_value="${?}"
else
	#
	# This is the first backup.
	#
	rsync -rlptgoAHXcsSq \
	"${source}" \
	"${destination}/${backup_start_ts}_in_flux" \
	>> "${rsync_log}" 2>&1
	return_value="${?}"
fi
set -e
if [[ "${return_value}" -ne 0 && "${return_value}" -ne 24 ]]; then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Backup failed for ${source} -> ${destination}/${backup_start_ts}_in_flux."
fi

#
# Sanity check: rsync log should exist and should be empty.
#
if [[ ! -f "${rsync_log}" ]]; then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Backup failed for ${source} -> ${destination}/${backup_start_ts}: log file ${rsync_log} missing."
elif [[ -s "${rsync_log}" ]]; then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Backup failed for ${source} -> ${destination}/${backup_start_ts}: log file ${rsync_log} not empty!"
else
	#
	# Cleanup and signal success.
	#
	rm "${rsync_log}"
	touch "${destination}/${backup_start_ts}_in_flux/backup.finished"
	mv "${destination}/${backup_start_ts}"{_in_flux,}
	cd "${destination}"
	current_dir="$(pwd)"
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Creating symlink in ${current_dir} latest -> ${backup_start_ts}."
	ln -s -f -n "${backup_start_ts}" latest
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Backup of ${source} completed successfully!"
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "${destination}/${backup_start_ts} is now marked as 'latest' backup."
	printf 'done.\n' >> "${lock_file}"
fi

#
# Remove old backups that exceed retention time limit.
#
# We need to check not only modification time, but also if there is a minimal amount of good backups.
# If the backup jobs failed for some time, the last remaining *good* backups may be older than the specified retention time.
#
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" "${?}" "Deleting outdated ${source} backups from ${destination} ..."
declare -a good_backups
readarray -t good_backups < <(find "${destination}/" -mindepth 1 -maxdepth 2 -type f -name backup.finished | sort -n -r)
if [[ "${#good_backups[@]}" -gt "${keep}" ]]; then
	log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "Number of good backups (${#good_backups[@]}) exceeds number of backups to keep (${keep})."
	now_in_seconds="$(date '+%s')"
	mod_in_seconds="$(date -r "${good_backups[${keep}]}" '+%s')"
	delta_in_seconds="$((${now_in_seconds}-${mod_in_seconds}))"
	age_in_days="$((${delta_in_seconds}/86400))"
	if [[ "${age_in_days}" -gt "${retention_time}" ]]; then
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "Age in days of the last good backup that must by kept (${age_in_days}) is more than the retention time in days (${retention_time})."
		retention_time="${age_in_days}"
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Using updated retention time: ${retention_time}."
	else
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "Age in days of the last good backup that must by kept (${age_in_days}) is less than the retention time in days (${retention_time})."
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Using retention time: ${retention_time}."
	fi
	outdated_backups_count="$(find "${destination}/" -mindepth 1 -maxdepth 1 -mtime "+${retention_time}" -type d | wc -l)"
	if [[ "${outdated_backups_count}" -ge 1 ]]; then
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Removing ${outdated_backups_count} outdated backup(s) ..."
		find "${destination}/" -mindepth 1 -maxdepth 1 -mtime "+${retention_time}" -type d -exec rm -Rf '{}' \;
		find "${LOG_DIR}/" -mtime "+${retention_time}" -name '*.log' -exec rm -f'{}' \;
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "    done."
	else
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "There are no outdated backups to remove."
	fi
else
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Number of successful backups (${#good_backups[@]}) does not exceed the minimal amount of successful backups to keep(${keep}); No outdated backups will be removed."
fi

#
# Reset trap and exit.
#
trap - EXIT
exit 0
