#!/bin/bash

set -e # Exit if any subcommand or pipeline returns a non-zero exit status.
set -u # Raise exception if variable is unbound. Combined with set -e will halt execution when an unbound variable is encountered.
set -o pipefail # Fail when any command in series of piped commands failed as opposed to only when the last command failed.

#
# Global vars.
#
slurm_cluster_name='{{ slurm_cluster_name | capitalize }}'
slurm_notification_slack_webhook='{{ slurm_notification_slack_webhook[stack_dtap_state] }}'
{% raw %}
slurm_event_type='unspecified'
SCRIPT_NAME="$(basename "${0}")"
node_state_dir='/tmp/slurm/'
node_state_file_old="${node_state_dir}/sinfo_report_old"
node_state_file_old_short="${node_state_file_old}-${$}.short"
node_state_file_new="${node_state_dir}/sinfo_report_new-${$}"
node_state_file_new_short="${node_state_file_new}.short"
send_notification='false'

#
##
### Functions
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

function trapHandler() {
	local _signal="${1}"
	local _line="${2}"
	local _function="${3}"
	local _status="${4}"
	log4Bash 'FATAL' "${_line}" "${_function}" "${_status}" "Trapped ${_signal} signal."
}

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
#    log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' 'We cannot continue because of ... .'
#
# Example of executing a command and logging failure with the EXIT_STATUS of that command (= ${?}):
#    someCommand || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}" 'Failed to execute someCommand.'
#
function log4Bash() {
	local _log_level
	local _log_level_prio
	local _status
	local _problematic_line
	local _problematic_function
	local _log_message
	local _log_line_prefix
	local _log_line
	#
	# Validate params.
	#
	if [[ ! "${#}" -eq 5 ]]
	then
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
	if [[ "${_log_level_prio}" -ge "${l4b_log_level_prio}" ]]
	then
		_problematic_line="${2:-'?'}"
		_problematic_function="${3:-'main'}"
		_log_message="${5:-'No custom message.'}"
		#
		# Some signals erroneously report $LINENO = 1,
		# but that line contains the shebang and cannot be the one causing problems.
		#
		if [[ "${_problematic_line}" -eq 1 ]]
		then
			_problematic_line='?'
		fi
		#
		# Format message.
		#
		_log_line_prefix=$(printf "%-s %-5s @ L%-s(%-s)>" "${SCRIPT_NAME}" "${_log_level}" "${_problematic_line}" "${_problematic_function}")
		_log_line="${_log_line_prefix} ${_log_message}"
		if [[ -n "${mixed_stdouterr:-}" ]]
		then
			_log_line="${_log_line} STD[OUT+ERR]: ${mixed_stdouterr}"
		fi
		if [[ "${_status}" -ne 0 ]]
		then
			_log_line="${_log_line} (Exit status = ${_status})"
		fi
		#
		# Log to STDOUT and syslog
		#
		logger --id="${$}" -s "${_log_line}"
	fi
	#
	# Exit if this was a FATAL error.
	#
	if [[ "${_log_level_prio}" -ge "${l4b_log_levels['FATAL']}" ]]
	then
		#
		# Compile JSON error message and send it to Slack channel.
		#
		local _pattern='"'
		local _replacement="'"
		read -r -d '\0' message <<- EOM
			{
				"type": "mrkdwn",
				"text": "*Failed to report node state for _${slurm_cluster_name}_*:  
				${_log_line//${_pattern}/${_replacement}}"
			}\0
		EOM
		sendMessage
		#
		# Cleanup.
		#
		rm -f "${node_state_file_new}" "${node_state_file_new_short}" "${node_state_file_old_short}"
		#
		# Reset trap and exit.
		#
		trap - EXIT
		if [[ "${_status}" -ne 0 ]]
		then
			exit "${_status}"
		else
			exit 1
		fi
	fi
}

function thereShallBeOnlyOne() {
	local _lock_file
	local _lock_dir
	_lock_file="${1}"
	_lock_dir="$(dirname "${_lock_file}")"
	mkdir -p -m 750 "${_lock_dir}"  || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}" "Failed to create dir for lock file at ${_lock_dir}."
	exec 200>"${_lock_file}" || log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Failed to create FD 200>${_lock_file} for locking."
	while ! flock -n 200; do
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}" "Lockfile ${_lock_file} already claimed by another instance of $(basename "${0}"); waiting 60 secs ..."
		sleep 60
		exec 200>"${_lock_file}" || log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Failed to create FD 200>${_lock_file} for locking."
	done
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Created FD 200 on lock file ${_lock_file} to unsure no other instance is executed in parallel."
}

function sendMessage() {
	curl -X POST "${slurm_notification_slack_webhook}" \
		 -H 'Content-Type: application/json' \
		 -d "${message}"
}

function showHelp() {
	#
	# Display commandline help on STDOUT.
	#
	cat <<EOH
===============================================================================================================
Script to send notifications triggered by Slurm events.

Usage:

	$(basename "${0}") OPTIONS

Options:

	-h	Show this help.
	-e	Slurm event type that triggered this script.
	-l	[level]
		Log level.
		Must be one of TRACE, DEBUG, INFO (default), WARN, ERROR or FATAL.
===============================================================================================================
EOH
	trap - EXIT
	exit 0
}

#
##
### Main
##
#

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
# Trap all exit signals: HUP(1), INT(2), QUIT(3), TERM(15), ERR.
#
trapSig HUP INT QUIT TERM EXIT ERR

#
# Get commandline arguments.
#
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Parsing commandline arguments ..."
while getopts "e:l:h" opt
do
	case "${opt}" in
		e)
			slurm_event_type="${OPTARG^^}"
			;;
		l)
			l4b_log_level="${OPTARG^^}"
			l4b_log_level_prio="${l4b_log_levels["${l4b_log_level}"]}"
			;;
		h)
			showHelp
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
# Make sure only one instance of this script at a time is processing events.
# Otherwise we may overwrite state files while processing
# or sending notifications may fail due to message rate limiting.
#
thereShallBeOnlyOne "${node_state_dir}/nodes.lock"

#
# Get current node state after we got executed by strigger.
# Example output:
#
# PARTITION|AVAIL|NODES|STATE|NODELIST|REASON
# regular*|up|1|drained*|gs-vcompute05|NHC: check_ps_loadavg:  1-minute load average too high:  85 >= 48
# regular*|up|9|mixed|gs-vcompute[01-04,06-10]|none
# user_interface|up|1|idle|gearshift|none
#
log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Slurm's strigger detected one or more compute node event of type: ${slurm_event_type}."
sinfo -o "%P|%a|%D|%T|%N|%E" > "${node_state_file_new}"
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "New node state stored in ${node_state_file_new}."

#
# Compile JSON node state message payload.
#
read -r -d '\0' message <<- EOM
	{
		"type": "mrkdwn",
		"text": "*Node state on _${slurm_cluster_name}_ changed due to node ${slurm_event_type} event*:  
		\`\`\`
		$(tr \" \' < "${node_state_file_new}" | column -t -s '|')
		\`\`\`"
	}\0
EOM

#
# Delete old node state after one day to send a new notification
# if the problem was not yet resolved.
#
if [[ -e "${node_state_file_old}" ]]; then
	mixed_stdouterr="$(find "${node_state_file_old}" -mtime +1 -delete 2>&1)"
	mixed_stdouterr='' # Reset this variable to prevent logging wrong message in wrong place.
fi

#
# Compile new notification.
#
if [[ -e "${node_state_file_old}" ]]; then
	if [[ -r "${node_state_file_old}" ]]; then
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "${node_state_file_old} exists and is readable."
		#
		# Drop some resolution from the "REASON" field to prevent sending redundant notifications
		# when the state has not changed significantly.
		# E.g. load was too high and changed slightly, but is still is too high.
		#
		sed 's/:  [^:]*$//' "${node_state_file_old}" \
			| grep -i 'drain\|down\|fail\|maint\|respond' \
			| sort > "${node_state_file_old_short}"
		sed 's/:  [^:]*$//' "${node_state_file_new}" \
			| grep -i 'drain\|down\|fail\|maint\|respond' \
			| sort > "${node_state_file_new_short}"
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Created ${node_state_file_old_short} and ${node_state_file_new_short}."
		if cmp -s "${node_state_file_old_short}" "${node_state_file_new_short}"; then
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "No differences found in ${node_state_file_old_short} compared to ${node_state_file_new_short}."
		else
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Differences were found in ${node_state_file_old_short} compared to ${node_state_file_new_short}."
			mixed_stdouterr="$(cp "${node_state_file_new}" "${node_state_file_old}" 2>&1)" || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}" "Failed to copy ${node_state_file_new} to ${node_state_file_old}."
			mixed_stdouterr='' # Reset this variable to prevent logging wrong message in wrong place.
			send_notification='true'
			log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0'  "send_notification = ${send_notification}."
		fi
	else
		log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "${node_state_file_old} exists but is not readable."
	fi
else
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "${node_state_file_old} does not exist: therefore node state must have changed."
	mixed_stdouterr="$(cp "${node_state_file_new}" "${node_state_file_old}" 2>&1)" || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}" "Failed to copy ${node_state_file_new} to ${node_state_file_old}."
	mixed_stdouterr='' # Reset this variable to prevent logging wrong message in wrong place.
	send_notification='true'
	log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0'  "send_notification = ${send_notification}."
fi

#
# Post message to Slack channel.
#
if [[ "${send_notification}" == 'true' ]]; then
	sendMessage
else
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' 'Node state has not changed: not sending message.'
fi

#
# Cleanup
#
rm -f "${node_state_file_new}" "${node_state_file_new_short}" "${node_state_file_old_short}"
log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' 'Finished.'
trap - EXIT
exit 0
{% endraw %}
