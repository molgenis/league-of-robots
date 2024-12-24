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
# Quota settings for groups:
# For Lustre file systems we prefer "project quota" for group folders,
# but we'll use "group quota" when project quota are not supported (yet).
#
declare -A ldap_quota_limits=()
declare -A quota_types=(
	{% for lfs_item in lfs_mounts | selectattr('lfs', 'search', '(home|((tmp)|(rsc)|(prm)|(dat))[0-9]+)$') %}
		{% if lfs_item['quota_type'] is defined %}
	['{{ lfs_item['lfs'] }}']='{{ lfs_item['quota_type']}}'
		{% endif %}
	{% endfor %}
)
declare -A quota_pid_increments=(
	{% for lfs_item in lfs_mounts | selectattr('lfs', 'search', '(home|((tmp)|(rsc)|(prm)|(dat))[0-9]+)$') %}
		{% if lfs_item['quota_pid_increment'] is defined %}
	['{{ lfs_item['lfs'] }}']='{{ lfs_item['quota_pid_increment']}}'
		{% endif %}
	{% endfor %}
)
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
declare ldif_dir="${TMPDIR}/ldifs"
declare ldap_config_file='/etc/openldap/readonly-ldapsearch-credentials.bash'

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
Script to fetch quota values from an LDAP server and apply them to a shared File System for a cluster.

Usage:

	$(basename "${0}") OPTIONS

OPTIONS:

	-h   Show this help.
	-a   Apply (new) settings to the File System(s).
	     By default this script will only do a "dry run" and fetch + list the settings as stored in the LDAP.
	 r   Recursively (re)apply p and P attributes on Lustre project quota dirs.
	     WARNING: this will take a long time when there is a lot of data on the file system.
	     Under normal conditions this should not be necessary, but it can be used to add these attributes in
	     case they were lost or in case Lustre project quota is turned on later for existing data.
	-l   Log level.
	     Must be one of TRACE, DEBUG, INFO (default), WARN, ERROR or FATAL.

Details:

	Values are always reported with a dot as the decimal seperator (LC_NUMERIC="en_US.UTF-8").
	LDAP connection details are fetched from ${ldap_config_file}.
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
# Parse LDIF records and apply quota to Physical File Systems (PFSs) containing group dirs.
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
		# Reset hash and then query for quota values for this group on this LFS.
		#
		ldap_quota_limits=()
		local _soft_quota_limit
		local _hard_quota_limit
		getQuotaFromLDAP "${_lfs_from_lfs_path}" "${_group_from_lfs_path}"
		if [[ -n "${ldap_quota_limits['soft']+isset}" && \
			  -n "${ldap_quota_limits['hard']+isset}" ]]; then
			_soft_quota_limit="${ldap_quota_limits['soft']}"
			_hard_quota_limit="${ldap_quota_limits['hard']}"
		else
			log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "   Quota values missing for group ${_group_from_lfs_path} on LFS ${_lfs_from_lfs_path}."
			continue
		fi
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      _soft_quota_limit contains: ${_soft_quota_limit}."
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      _hard_quota_limit contains: ${_hard_quota_limit}."
		#
		# Check for negative numbers and non-integers.
		#
		if [[ ! "${_soft_quota_limit}" =~ ${_pos_int_regex} || ! "${_hard_quota_limit}" =~ ${_pos_int_regex} ]]; then
			log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "   Quota values malformed for group ${_group_from_lfs_path} on LFS ${_lfs_from_lfs_path}. Must be integers >= 0."
			continue
		fi
		#
		# Check if soft limit is larger than the hard limit as that will quota commands to fail.
		#
		if [[ "${_soft_quota_limit}" -gt "${_hard_quota_limit}" ]]; then
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
		if [[ "${_soft_quota_limit}" -eq 0 ]]; then
			_soft_quota_limit='2M'
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "   Converted soft quota limit of 0 (zero) for group ${_group_from_lfs_path} on LFS ${_lfs_from_lfs_path} to lowest possible value of ${_soft_quota_limit}."
		else
			# Just append unit: all quota values from the IDVault are in GB.
			_soft_quota_limit="${_soft_quota_limit}G"
		fi
		if [[ "${_hard_quota_limit}" -eq 0 ]]; then
			_hard_quota_limit='4M'
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "   Converted hard quota limit of 0 (zero) for group ${_group_from_lfs_path} on LFS ${_lfs_from_lfs_path} to lowest possible value of ${_hard_quota_limit}."
		else
			# Just append unit: all quota values from the IDVault are in GB.
			_hard_quota_limit="${_hard_quota_limit}G"
		fi
		if [[ "${_fs_type}" == 'lustre' ]]; then
			#
			# Get the GID for this group, which will be used as the ID for quota accounting.
			#
			local _gid
			_gid="$(getent group "${_group_from_lfs_path}" | awk -F ':' '{printf $3}')"
			if [[ "${quota_types[${_lfs_from_lfs_path}]:-group}" == 'project' ]]; then
				local _pid
				_pid=$((${_gid} + ${quota_pid_increments[${_lfs_from_lfs_path}]:-0}))
				applyLustreQuota "${_lfs_path}" 'project' "${_pid}" "${_soft_quota_limit}" "${_hard_quota_limit}"
			else
				applyLustreQuota "${_lfs_path}" 'group' "${_gid}" "${_soft_quota_limit}" "${_hard_quota_limit}"
			fi
		elif [[ "${_fs_type}" == 'nfs4' ]]; then
			saveQuotaCache "${_lfs_path}" "${_soft_quota_limit}" "${_hard_quota_limit}"
		else
			log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "   Cannot configure quota due to unsupported file system type: ${_fs_type}."
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
			# Get the primary GID for this user, which will be used as the ID for quota accounting.
			#
			local _uid
			_uid="$(id -u "${_user_from_lfs_path}")"
			if [[ "${quota_types[${_lfs_from_lfs_path}]:-group}" == 'project' ]]; then
				local _pid
				_pid=$((${_uid} + ${quota_pid_increments[${_lfs_from_lfs_path}]:-0}))
				applyLustreQuota "${_lfs_path}" 'project' "${_pid}" "${_soft_quota_limit}" "${_hard_quota_limit}"
			else
				applyLustreQuota "${_lfs_path}" 'group' "${_gid}" "${_soft_quota_limit}" "${_hard_quota_limit}"
			fi
		else
			log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "   Cannot configure quota due to unsupported file system type: ${_fs_type}."
		fi
	done
}

#
# Prefer Lustre project a.k.a. file set a.k.a folder quota limits:
#  * Set project attribute on LFS path using GID as project ID.
#  * Use lfs setquota to configure quota limit for project.
# Fallback to group quota if project quota is not supported.
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
# Store quota limits in a cache file.
# This can then be used by the storage system itself to read the values and apply quota limits.
# Needed for example for our Isilon systems which do not support the normal NFS quota tools on NFS clients.
#
function saveQuotaCache () {
	local    _lfs_path="${1}"
	local    _soft_quota_limit="${2}"
	local    _hard_quota_limit="${3}"
	local    _cmd
	local -a _cmds
	if [[ "${apply_settings}" -eq 1 ]]; then
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "   Updating quota cache ..."
	else
		log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "   Dry run: the following commands to update the cache would have been executed with the '-a' switch ..."
	fi
	_cmds=(
		"umask 0027; touch ${_lfs_path}.quotacache.new"
		"printf 'soft=%s\n' ${_soft_quota_limit} >  ${_lfs_path}.quotacache.new"
		"printf 'hard=%s\n' ${_hard_quota_limit} >> ${_lfs_path}.quotacache.new"
		"mv -f ${_lfs_path}.quotacache.new ${_lfs_path}.quotacache"
	)
	for _cmd in "${_cmds[@]}"; do
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "   Applying cmd: ${_cmd}"
		if [[ "${apply_settings}" -eq 1 ]]; then
			eval "${_cmd}" || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" "${?}" "Failed to execute: ${_cmd}"
		fi
	done
}

function getQuotaFromLDAP () {
	local    _lfs="${1}"
	local    _group="${2}"
	local    _ldap_attr_regex='([^: ]{1,})(:{1,2}) ([^:]{1,})'
	local    _ldif_file="${ldif_dir}/${_group}.ldif"
	local _ldap
	#
	# Query LDAP
	#
	for _ldap in "${domain_names[@]}"; do
		local _uri="${domain_configs[${_ldap}_uri]}"
		local _search_base="${domain_configs[${_ldap}_search_base]}"
		local _bind_dn="${domain_configs[${_ldap}_bind_dn]}"
		local _bind_pw="${domain_configs[${_ldap}_bind_pw]}"
		local _group_object_class="${domain_configs[${_ldap}_group_object_class]}"
		local _group_quota_soft_limit_template="${domain_configs[${_ldap}_group_quota_soft_limit_template]}"
		local _group_quota_hard_limit_template="${domain_configs[${_ldap}_group_quota_hard_limit_template]}"
		local _group_quota_soft_limit_key="${_group_quota_soft_limit_template/LFS/${_lfs}}"
		local _group_quota_hard_limit_key="${_group_quota_hard_limit_template/LFS/${_lfs}}"
		ldapsearch -LLL -o ldif-wrap=no \
				-H "${_uri}" \
				-D "${_bind_dn}" \
				-w "${_bind_pw}" \
				-b "${_search_base}" \
				"(&(ObjectClass=${_group_object_class})(cn:dn:=${_group}))" \
				"${_group_quota_soft_limit_key}" \
				"${_group_quota_hard_limit_key}" \
				>"${_ldif_file}" 2>&1 \
			|| log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" "${?}" "ldapsearch for user ${_bind_dn} on server ${_uri} failed."
		#
		# Parse query results.
		#
		local    _ldif_record
		local -a _ldif_records
		while IFS= read -r -d '' _ldif_record; do
			_ldif_records+=("${_ldif_record}")
		done < <(sed 's/^$/\x0/' "${_ldif_file}") \
			|| log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" "${?}" "Parsing LDIF file (${_ldif_file}) into records failed."
		#
		# Loop over records in the array and create a faked-multi-dimensional hash.
		#
		for _ldif_record in "${_ldif_records[@]:-}"; do
			#
			# Remove trailing white space like the new line character.
			# And skip blank lines.
			#
			_ldif_record="${_ldif_record%%[[:space:]]}"
			[[ "${_ldif_record}" == '' ]] && continue
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "LDIF record contains: ${_ldif_record}"
			#
			# Parse record's key:value pairs.
			#
			local -A _directory_record_attributes=()
			local    _ldif_line
			while IFS=$'\n' read -r _ldif_line; do
				[[ "${_ldif_line}" == '' ]] && continue # Skip blank lines.
				log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "LDIF key:value pair contains: ${_ldif_line}."
				if [[ "${_ldif_line}" =~ ${_ldap_attr_regex} ]]; then
					local _key="${BASH_REMATCH[1],,}" # Convert key on-the-fly to lowercase.
					local _sep="${BASH_REMATCH[2]}"
					local _value="${BASH_REMATCH[3]}"
					#
					# Check if value was base64 encoded (double colon as separator)
					# or plain text (single colon as separator) and decode if necessary.
					#
					if [[ "${_sep}" == '::' ]]; then
						log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "     decoding base64 encoded value..."
						_value="$(printf '%s' "${_value}" | base64 -di)"
					fi
					#
					# This may be a multi-valued attribute and therefore check if key already exists;
					# When key already exists make sure we append instead of overwriting the existing value(s)!
					#
					if [[ -n "${_directory_record_attributes[${_key}]+isset}" ]]; then
						_directory_record_attributes["${_key}"]="${_directory_record_attributes["${_key}"]} ${_value}"
					else
						_directory_record_attributes["${_key}"]="${_value}"
					fi
					log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "     key   contains: ${_key}."
					log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "     value contains: ${_value}."
				else
					log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Failed to parse LDIF key:value pair (${_ldif_line})."
				fi
			done < <(printf '%s\n' "${_ldif_record}") || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" "${?}" "Parsing LDIF record failed."
			#
			# Get Quota from processed LDIF record if this the right group.
			#
			local _ldap_group
			if [[ -n "${_directory_record_attributes['dn']+isset}" ]]; then
				#
				# Parse cn from dn.
				#
				_ldap_group=$(dn2cn "${_directory_record_attributes['dn']}")
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Found group ${_ldap_group} in dn attribute."
			else
				log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "dn attribute missing for ${_ldif_record}"
			fi
			if [[ "${_ldap_group}" == "${_group}" ]]; then
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Group from ldap record matches the group we were looking for: ${_ldap_group}."
			else
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipping LDAP group ${_ldap_group} that does not match the LFS group ${_group} we were looking for."
				continue
			fi
			#
			# Get quota values for this group on this LFS.
			#
			if [[ -n "${_directory_record_attributes["${_group_quota_soft_limit_key}"]+isset}" && \
				  -n "${_directory_record_attributes["${_group_quota_hard_limit_key}"]+isset}" ]]; then
				ldap_quota_limits['soft']="${_directory_record_attributes["${_group_quota_soft_limit_key}"]}"
				ldap_quota_limits['hard']="${_directory_record_attributes["${_group_quota_hard_limit_key}"]}"
				return
			else
				log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "   Quota values missing for group ${_ldap_group} on LFS ${_lfs}."
				log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      Search keys were ${_group_quota_soft_limit_key} and ${_group_quota_hard_limit_key}."
				continue
			fi
		done
	done
}


#
# Extract a CN from a DN LDAP attribute.
#
function dn2cn () {
	# cn=umcg-someuser,ou=users,ou=umcg,o=rs
	local _dn="$1"
	local _cn='MIA'
	local _regex='cn=([^, ]+)'
	if [[ "${_dn}" =~ ${_regex} ]]; then
		_cn="${BASH_REMATCH[1]}"
	fi
	printf '%s' "${_cn}"
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
# Parse LDAP config file.
#
if [[ -e  "${ldap_config_file}" && -r "${ldap_config_file}" ]]; then
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Fetching ldapsearch credentials from config file ${ldap_config_file} ..."
	# shellcheck source=/dev/null
	source "${ldap_config_file}"
else
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Config file ${ldap_config_file} missing or not readable."
fi

if [ "${apply_settings}" -eq 1 ]; then
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' 'Found option -a: will fetch, list and apply settings.'
else
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' 'Option -a not specified: will only perform a "dry run" to fetch + list settings. Use -a to apply settings.'
fi

#
# Get a list of LFS paths: folders for groups, which we want to apply project quota to.
# On a SAI always in format/location:
#	/mnt/${pfs}/groups/${group}/${lfs}/
# E.g.:
#	/mnt/umcgst02/groups/umcg-atd/prm08/
#
readarray -t lfs_paths < <(find /mnt/*/groups/*/ -maxdepth 1 -mindepth 1 -type d -name "[a-z][a-z]*[0-9][0-9]*")

#
# Create tmp dir for LDIFs with results from LDAP queries.
#
mkdir -p "${ldif_dir}"

#
# Get quota values from LDAP and apply quota limits to file systems.
#
processGroupDirs "${lfs_paths[@]:-}"

#
# Apply hard coded limits to home dirs for all regular users.
#
readarray -t lfs_paths < <(find /mnt/*/home/ -maxdepth 1 -mindepth 1 -type d)
processHomeDirs "${lfs_paths[@]:-}"

#
# Cleanup tmp files.
#
if [[ "${l4b_log_level_prio}" -lt "${l4b_log_levels['INFO']}" ]]; then
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Debug mode: temporary dir ${ldif_dir} won't be removed."
else
	rm -Rf "${ldif_dir}"
fi

#
# Reset trap and exit.
#
log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" 0 "Finished!"
trap - EXIT

{% endraw %}
