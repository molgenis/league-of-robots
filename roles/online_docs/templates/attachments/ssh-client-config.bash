#jinja2: trim_blocks:False
#!/bin/bash
#
# Bash sanity.
#
set -e # Exit on error.
set -u # Error on unbound variables.
#
# Set umask to ensure the file and folders for SSH are private.
#
umask 0077
#
# Make sure to use UTF and not some funky wonky charset.
#
LANG='en_US.UTF-8'
LC_NUMERIC="${LANG}"

SCRIPT_NAME="$(basename "${0}")"
SCRIPT_NAME="${SCRIPT_NAME%.*sh}"

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
==================================================================================================
Script to configure your OpenSSH client for logins to {{ slurm_cluster_name | capitalize }}.

Usage:

	$(basename "${0}") OPTIONS

OPTIONS:

	-h         Show this help.
	-u user    Your account name, which should be used as default for logins to {{ slurm_cluster_name | capitalize }}.
	-l level   Log level. Must be TRACE, DEBUG, INFO (default), WARN, ERROR or FATAL.
==================================================================================================
EOH
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
# Use a global variable "resolved_log_level_prio" with a lookup function
# to determine the priority of a log level.
# This is a silly workaround for the lack of hashes / assiciative arrays in Bash 3.x from 2007,
# which we still need to support as even the most recent version of macOS does not support Bash 4 or newer :(
#
declare resolved_log_level_prio
function getLogLevelPrio() {
	case "${1}" in
		'TRACE') resolved_log_level_prio='0';;
		'DEBUG') resolved_log_level_prio='1';;
		'INFO') resolved_log_level_prio='2';;
		'WARN') resolved_log_level_prio='3';;
		'ERROR') resolved_log_level_prio='4';;
		'FATAL') resolved_log_level_prio='5';;
		*)
			printf '%s\n' "FATAL: Unsupprted log level ${1:-}. Must be TRACE, DEBUG, INFO (default), WARN, ERROR or FATAL. "
			trap - EXIT
			exit 1
			;;
	esac
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
	if [[ ! {% raw %}"${#}"{% endraw %} -eq 5 ]]; then
		printf '%s\n' "WARN: should have passed 5 arguments to ${FUNCNAME[0]}: log_level, LINENO, FUNCNAME, (Exit) STATUS and log_message."
	fi
	#
	# Determine prio.
	#
	_log_level="${1}"
	getLogLevelPrio "${_log_level}"
	_log_level_prio="${resolved_log_level_prio}"
	#
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
		if [[ "${_log_level_prio}" -ge '4' || "${_status}" -ne 0 ]]; then
			printf '%s\n' "${_log_line}" 1>&2
		else
			printf '%s\n' "${_log_line}"
		fi
	fi
	#
	# Exit if this was a FATAL error.
	#
	if [[ "${_log_level_prio}" -ge '5' ]]; then
		trap - EXIT
		if [[ "${_status}" -ne 0 ]]; then
			exit "${_status}"
		else
			exit 1
		fi
	fi
}

#
# Lock function using flock and a file descriptor (FD).
# This uses FD 200 as per flock manpage example.
#
function thereShallBeOnlyOne() {
	local _lock_file
	local _lock_dir
	_lock_file="${1}"
	_lock_dir="$(dirname "${_lock_file}")"
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Checking if flock utility is installed ..."
	if command -v flock >/dev/null 2>&1; then
		#
		# The flock file locking utility is installed.
		#
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Will use flock utility for locking."
		mkdir -p "${_lock_dir}"  || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}" "Failed to create dir for lock file @ ${_lock_dir}."
		exec 200>"${_lock_file}" || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}" "Failed to create FD 200>${_lock_file} for locking."
		if ! flock -n 200; then
			log4Bash 'ERROR' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Lockfile ${_lock_file} already claimed by another instance of $(basename "${0}")."
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' 'Another instance is already running and there shall be only one.'
			# No need for explicit exit here: log4Bash with log level FATAL will make sure we exit.
		else
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Successfully got exclusive access to lock file ${_lock_file}."
		fi
	else
		#
		# The flock file locking utility is missing.
		# Use a simple, but not atomic so less reliable fallback.
		# Note: this is always the case on macOS that has no flock installed by default :(
		#
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "The flock utility is missing; will fallback to less reliable pgrep ..."
		if [[ $(pgrep "${SCRIPT_NAME}") -gt 1 ]]; then
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' 'Another instance is already running and there shall be only one.'
		fi
	fi
}

function manageConfig() {
	local _user="${1}"
	local _private_key_file="${2}"
	local _result
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' 'Will configure SSH logins to {{ slurm_cluster_name | capitalize }} for'
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "    for user: ${_user}"
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "    using private key file: ${_private_key_file}"
	#
	# Create directory for SSH config if it did not already exist.
	#
	_result=$(mkdir -p -m 700 "${HOME}/.ssh/tmp" 2>&1) \
		|| log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Failed to create ${HOME}/.ssh/tmp. Result was: ${_result}"
	_result=$(mkdir -p -m 700 "${HOME}/.ssh/conf.d" 2>&1) \
		|| log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Failed to create ${HOME}/.ssh/conf.d. Result was: ${_result}"
	#
	# Fix permissions recursively in case directories already existed,
	# but permissions were to open: make the SSH client config private.
	#
	_result=$(chmod -R go-rwx "${HOME}/.ssh" 2>&1) \
		|| log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Failed to fix permissions recursively for ${HOME}/.ssh/. Result was: ${_result}"
	#
	# Create new known_hosts file and append the public key of the Certificate Authority (CA) for {{ slurm_cluster_name | capitalize }}.
	#
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Appending the public key of the Certificate Authority (CA) to ${HOME}/.ssh/known_hosts ..."
	printf '%s\n' \
		"@cert-authority {% for jumphost in groups['jumphost'] %}{{ jumphost | regex_replace('^' + ai_jumphost + '\\+','')}}*,{% if public_ip_addresses is defined and public_ip_addresses[jumphost] | length %}{{ public_ip_addresses[jumphost] }},{% endif %}{% endfor %}{% for adminhost in groups['administration'] %}*{{ adminhost | regex_replace('^' + ai_jumphost + '\\+','')}},{% endfor %}*{{ stack_prefix }}-* {{ lookup('file', ssh_host_signer_ca_private_key+'.pub') }} for {{ slurm_cluster_name }}" \
		> "${HOME}/.ssh/known_hosts.new"
	if [[ -e "${HOME}/.ssh/known_hosts" ]]; then
		#
		# When user already had a known_hosts file, then 
		# remove a potentially outdated CA public key for the same machines based on the slurm_cluster_name: {{ slurm_cluster_name }}
		# and append all other lines to the new known_hosts file. 
		#
		sed '/^\@cert-authority .* for {{ slurm_cluster_name }}$/d' \
			"${HOME}/.ssh/known_hosts" \
			| sort \
			>> "${HOME}/.ssh/known_hosts.new"
	fi
	#
	# Make new known_hosts file the default.
	#
	log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Replacing ${HOME}/.ssh/known_hosts with ${HOME}/.ssh/known_hosts.new ..."
	mv "${HOME}/.ssh/known_hosts.new" "${HOME}/.ssh/known_hosts"
	#
	# Create main config file if it did not already exist.
	#
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Creating or updating ${HOME}/.ssh/config ..."
	touch "${HOME}/.ssh/config"
	#
	# Instruct main config file to include additional config files from the conf.d subdir.
	# This is the only change we make to the main config file;
	# all {{ slurm_cluster_name | capitalize }} specific stuff will go into a separate config file,
	# so we can easily update that by replacing the {{ slurm_cluster_name | capitalize }} config file
	# without affecting any other SSH configs.
	#
	if grep -cqi '^Include conf.d/\*$' "${HOME}/.ssh/config"; then
		#
		# Check the order: the Include directive must be placed before any Host or Match directives,
		# otherwise the Include will only apply to a specific set of hosts.
		#
		if grep -cqi '^Host\|^Match' "${HOME}/.ssh/config"; then
			local _first_line_include="$(grep -in '^Include conf.d/\*$' "${HOME}/.ssh/config" | head -n 1 | awk -F ':' '{print $1}')"
			local _first_line_host_or_match="$(grep -in '^Host\|^Match'  "${HOME}/.ssh/config" | head -n 1 | awk -F ':' '{print $1}')"
			if [[ "${_first_line_include}" -lt "${_first_line_host_or_match}" ]]; then
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Include directive for conf.d subdir already present in main ${HOME}/.ssh/config file"
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "    and located in correct order: before Host or Match directives."
			else
				log4Bash 'ERROR' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Include directive for conf.d subdir already present in main ${HOME}/.ssh/config file on the wrong line."
				log4Bash 'ERROR' "${LINENO}" "${FUNCNAME[0]:-main}" '0' 'The order is important: the line "Include conf.d/*" must be present before any "Host ..." or "Match ..." directives.'
				log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Fix the order of lines in your ${HOME}/.ssh/config file manually and run this script again."
			fi
		else
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Include directive for conf.d subdir already present in main ${HOME}/.ssh/config file."
		fi
	else
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Adding Include directive for conf.d subdir to config ${HOME}/.ssh/config."
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Prepending Include directive for conf.d subdir to new config ${HOME}/.ssh/config.new ..."
		printf '%s\n\n' 'Include conf.d/*' > "${HOME}/.ssh/config.new"
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Appending existing ${HOME}/.ssh/config to new config ${HOME}/.ssh/config.new ..."
		cat "${HOME}/.ssh/config" >> "${HOME}/.ssh/config.new"
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Replacing existing ${HOME}/.ssh/config with ${HOME}/.ssh/config.new ..."
		mv "${HOME}/.ssh/config.new" "${HOME}/.ssh/config"
	fi
	#
	# Create cluster specific config file
	#
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Creating or updating ${HOME}/.ssh/conf.d/{{ slurm_cluster_name }} ..."
	cat <<EOF > "${HOME}/.ssh/conf.d/{{ slurm_cluster_name }}"
#
# Special comment lines parsed by our mount-cluster-drives script to create sshfs mounts.
# (Will be ignored by OpenSSH.)
# {% set sshfs_jumphost = groups['jumphost'] | first | regex_replace('^' + ai_jumphost + '\\+','') %}
# {% set sshfs_ui = groups['user_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') %}
#SSHFS {{ sshfs_ui }}_groups={{ sshfs_jumphost }}+{{ sshfs_ui }}:/groups/
#SSHFS {{ sshfs_ui }}_home={{ sshfs_jumphost }}+{{ sshfs_ui }}:/home/${_user}/
#

#
# Generic stuff: only for macOS clients.
#
IgnoreUnknown UseKeychain
    UseKeychain yes
IgnoreUnknown AddKeysToAgent
    AddKeysToAgent yes
#
# Host settings.
#
Host{% for jumphost in groups['jumphost'] %} {{ jumphost | regex_replace('^' + ai_jumphost + '\\+','') }}*{% endfor %}
    #
    # Default account name when not specified explicitly.
    #
    User ${_user}
    #
    # Prevent timeouts
    #
    ServerAliveInterval 60
    ServerAliveCountMax 5
    #
    # We use public-private key pairs for authentication.
    # Do not use password based authentication as fallback,
    # which may be confusing and won't work anyway.
    #
    IdentityFile "${_private_key_file}"
    PasswordAuthentication No
    #
    # Multiplex connections to
    #   * reduce lag when logging in to the same host in a second terminal
    #   * reduce the amount of connections that are made to prevent excessive DNS lookups
    #     and to prevent getting blocked by a firewall, because it thinks we are executing a DoS attack.
    #
    # Name/location of sockets for connection multiplexing are configured using the ControlPath directive.
    # In the ControlPath directive %C expands to a hashed value of %l_%h_%p_%r, where:
    #    %l = local hostname
    #    %h = remote hostname
    #    %p = remote port
    #    %r = remote username
    # This makes sure that the ControlPath is
    #   * a unique socket that is local to machine on which the sessions are created,
    #     which means it works with home dirs from a shared network file system.
    #     (as sockets cannot be shared by servers.)
    #   * not getting to long as the hash has a fixed size not matter how long %l_%h_%p_%r was.
    #
    ControlMaster auto
    ControlPath ~/.ssh/tmp/%C
    ControlPersist 1m
#
# Expand short jumphost names to FQDN or IP address.
#{% if public_ip_addresses is defined and public_ip_addresses | length %}{% for jumphost in groups['jumphost'] %}
Host {{ jumphost | regex_replace('^' + ai_jumphost + '\\+','') }}
    HostName {{ public_ip_addresses[jumphost | regex_replace('^' + ai_jumphost + '\\+','')] }}{% endfor %}{% else %}
Host {% for jumphost in groups['jumphost'] %}{{ jumphost | regex_replace('^' + ai_jumphost + '\\+','') }} {% endfor %}{% if slurm_cluster_domain | length %}!*.{{ slurm_cluster_domain }}{% endif %}
    HostName %h{% if slurm_cluster_domain | length %}.{{ slurm_cluster_domain }}{% endif %}{% endif %}
#
# Universal jumphost settings for triple-hop SSH.
#
Host *+*+*
    ProxyCommand ssh -x -q \$(echo %h | sed 's/+[^+]*$//') -W \$(echo %h | sed 's/^[^+]*+[^+]*+//'):%p
#
# Double-hop SSH settings to connect via specific jumphosts.
#
Host {% for jumphost in groups['jumphost'] %}{{ jumphost | regex_replace('^' + ai_jumphost + '\\+','')}}+* {% endfor %}{% raw %}{% endraw %}
    ProxyCommand ssh -x -q \$(echo "\${JUMPHOST_USER:-%r}")@\$(echo %h | sed 's/+[^+]*$//'){% if slurm_cluster_domain | length %}.{{ slurm_cluster_domain }}{% endif %} -W \$(echo %h | sed 's/^[^+]*+//'):%p
#
# Sometimes port 22 for the SSH protocol is blocked by firewalls; in that case you can try to use SSH on port 443 as fall-back.
# Do not use port 443 by default for SSH as it is officially assigned to HTTPS traffic
# and some firewalls will cause problems with SSH traffic over port 443.
#
Host {% for jumphost in groups['jumphost'] %}{{ jumphost | regex_replace('^' + ai_jumphost + '\\+','')}}443+* {% endfor %}{% raw %}{% endraw %}
    ProxyCommand ssh -x -q \$(echo "\${JUMPHOST_USER:-%r}")@\$(echo %h | sed 's/443+[^+]*$//'){% if slurm_cluster_domain | length %}.{{ slurm_cluster_domain }}{% endif %} -W \$(echo %h | sed 's/^[^+]*+//'):%p -p 443

EOF
}

#
##
### Main.
##
#

#
# Trap all exit signals: HUP(1), INT(2), QUIT(3), TERM(15), ERR.
#
trapSig HUP INT QUIT TERM EXIT ERR

#
# Initialise Log4Bash logging with defaults.
#
l4b_log_level='INFO'
getLogLevelPrio "${l4b_log_level}"
l4b_log_level_prio="${resolved_log_level_prio}"
mixed_stdouterr='' # global variable to capture output from commands for reporting in custom log messages.

#
# Get commandline arguments.
#
declare user
while getopts ":l:u:h" opt; do
	case "${opt}" in
		l)
			l4b_log_level="${OPTARG}"
			getLogLevelPrio "${l4b_log_level}"
			l4b_log_level_prio="${resolved_log_level_prio}"
			;;
		u)
			user="${OPTARG}"
			;;
		h)
			showHelp
			trap - EXIT
			exit 0
			;;
		\?)
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Invalid option -${OPTARG}. Try $(basename "${0}") -h for help."
			;;
		:)
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Option -${OPTARG} requires an argument. Try $(basename "${0}") -h for help."
			;;
		esac
done

#
# Make sure only one copy of this script runs simultaneously to prevent messing up config files.
#
thereShallBeOnlyOne "${TMPDIR:-/tmp}/${SCRIPT_NAME}.lock"

#
# Get account name and path to private key.
#
if [[ -z "${user:-}" ]]; then
	read -e -p "Type the account name you received from the helpdesk for logins to {{ slurm_cluster_name | capitalize }} and press [ENTER]: " user
fi
if [[ -z "${user:-}" ]]; then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' 'Your account name cannot be empty.'
fi
read -e -p "Specify the path to the private key file you want to use (or accept the default: ~/.ssh/id_ed25519) and press [ENTER]: " private_key_file
private_key_file="${private_key_file:-~/.ssh/id_ed25519}"
if [[ -e "${private_key_file/#\~/${HOME}}" ]]; then
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "The specified private key file ${private_key_file} exists."
else
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "The specified private key file ${private_key_file} does not exist."
fi

#
# Check if client has a compatible OpenSSH version.
# We need OpenSSH >= 7.3 to support the Include directive in the main ~/.ssh/config file.
#
ssh_version_string="$(ssh -V 2>&1)"
ssh_version_regex='OpenSSH_([0-9][0-9]*).([0-9][0-9]*)'
if [[ "${ssh_version_string}" =~ ${ssh_version_regex} ]]; then
	ssh_version_major="${BASH_REMATCH[1]}"
	ssh_version_minor="${BASH_REMATCH[2]}"
	compatible_ssh='no'
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Detected OpenSSH version ${ssh_version_major}.${ssh_version_minor}."
	if [[ "${ssh_version_major}" -gt '7' ]]; then
		compatible_ssh='yes'
	elif [[ "${ssh_version_major}" -eq '7' ]]; then
		if [[ "${ssh_version_minor}" -ge '3' ]]; then
			compatible_ssh='yes'
		fi
	fi
	if [[ "${compatible_ssh}" == 'yes' ]]; then
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "OpenSSH version ${ssh_version_major}.${ssh_version_minor} is compatible."
	else
		log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Your OpenSSH client version ${ssh_version_major}.${ssh_version_minor} is too old and incompatible."
	fi
else
	log4Bash 'WARN' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Failed to determine OpenSSH client version; you may be using an incompatible version."
fi

#
# Create/update SSH config.
#
manageConfig "${user}" "${private_key_file}"

#
# Notify user.
#
log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' 'Finished configuring your SSH client for logins to {{ slurm_cluster_name | capitalize }}.'
log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' 'You can log in to User Interface {{ groups['user_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}'
log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' '    via jumphost {{ groups['jumphost'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}{% if slurm_cluster_domain | length %}.{{ slurm_cluster_domain }}{% endif %}'
log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' '    in a terminal with the following SSH command:'
log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' '        ssh {{ groups['jumphost'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}+{{ groups['user_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}'
log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' 'We will now test your connection by executing the above SSH command to login and logout.'
log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' 'If this is the first time your private key will be used for an SSH session,'
log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' '    you will receive a prompt to supply the password for your private key,'
log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' '    which can be stored in your login KeyChain,'
log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "    so you won't have to retype the password again for a subsequent SSH session."
read -e -p "Press [ENTER] to test your connection."
if ssh {{ groups['jumphost'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}+{{ groups['user_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }} exit; then
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' 'Login was succesful.'
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' 'Consult the online documentation for additional examples '
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' '    and how to transfer data with rsync over SSH.'
else
	log4Bash 'ERROR' "${LINENO}" "${FUNCNAME[0]:-main}" '0' 'Failed to login; check if your network either wired or using WiFi is up.'
	log4Bash 'WARN' "${LINENO}" "${FUNCNAME[0]:-main}" '0' 'Consult the online documentation for debugging options.'
fi
read -e -p "Press [ENTER] to exit."

trap - EXIT
exit 0
