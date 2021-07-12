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
if [[ "${BASH_VERSINFO}" -lt 4 || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
	echo "Sorry, you need at least bash 4.x to use ${0}." >&2
	exit 1
fi

set -e # Exit if any subcommand or pipeline returns a non-zero exit status.
set -u # Raise exception if variable is unbound. Combined with set -e will halt execution when an unbound variable is encountered.
set -o pipefail # Fail when any command in series of piped commands failed as opposed to only when the last command failed.

umask 0077

export TMPDIR="${TMPDIR:-/tmp}" # Default to /tmp if $TMPDIR was not defined.

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
Script to fetch data from the LDAP server and apply them to a shared File System for a cluster. This includes:
 * Applying quota to (large, shared) Physical File Systems (PFSs).
 * Caching meta-data for groups and their members on PFSs.

Usage:

	$(basename $0) OPTIONS

OPTIONS:

	-h   Show this help.
	-f   Logical File System (LFS) for which to retrieve settings from the LDAP 
	     and apply them to the corresponding Physical File System (PFS).
	     Must be either:
	      * a specific LFS as specified in the config file (see below).
	      * ALL for all known LFSs as specified in the config file (see below).
	     LFS(s) must have a mapping to a Physical File System (PFS) in the associated config file (see below).
	-a   Apply (new) settings to the File System(s).
	     By default this script will only do a "dry run" and fetch + list the settings as stored in the LDAP.
	-b   Backup directory. Will create a full backup of both the user and group info from the LDAP in the specified dir.
	-l   Log level.
	     Must be one of TRACE, DEBUG, INFO (default), WARN, ERROR or FATAL.

Details:

	Values are always reported with a dot as the decimal seperator (LC_NUMERIC="en_US.UTF-8").

	Values for some variables are imported by sourcing a config.
	The config file must contain LDAP credentials and file systems in bash syntax.
	Example given:
		#
		# Credentials:
		#
		LDAP_USER='some_account' 
		LDAP_PASS='some_passwd'
		LDAP_SEARCH_BASE='ou=umcg,o=rs'
		#
		# Prefixes of IDVault entitlements for which group data must be processed.
		#
		declare -a entitlement_prefixes=('umcg' 'll')
		#
		# Mappings of Logical File Systems (LFSs) to Physical File Systems (PFSs).
		#  * for groups to apply group quota.
		#  * for users to apply 'private group' quota.
		#    Private groups contain only a single user and have the same name + ID as that user.
		# In case an LFS is available from multiple PFSs, multiple PFSs may be listed separated by a comma.
		# 
		declare -A lfs_to_pfs_for_groups=(
			['tmp03']='umcgst08'
			['tmp04']='umcgst06'
			['prm02']='umcgst07'
			['prm03']='umcgst09'
		)
		declare -A lfs_to_pfs_for_users=(
			['home']='umcgst07,umcgst09'
		)
		declare -a pfs_with_apps=(
			'umcgst07'
			'umcgst09'
		)
		#
		# Only allow groups to store data here and set quota for individual users to the lowest possible value (1k).
		#
		declare -a pfs_without_users=(
			'umcgst06'
			'umcgst08'
		)
	
	The config file must be located in same location as this script and have the same basename, 
	but suffixed with *.cfg instead of *.bash.
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
	local _trap_function="${1}"
	local _line="${2}"
	local _function="${3}"
	local _status="${4}"
	shift 4
	for _sig; do
		trap "${_trap_function} ${_sig} ${_line} ${_function} ${_status}" "${_sig}"
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
trapSig 'trapHandler' '${LINENO}' '${FUNCNAME:-main}' '$?' HUP INT QUIT TERM EXIT ERR

#
# Catch all function for logging using log levels like in Log4j.
# ARGS: LOG_LEVEL, LINENO, FUNCNAME, EXIT_STATUS and LOG_MESSAGE.
#
function log4Bash() {
	#
	# Validate params.
	#
	if [ ! ${#} -eq 5 ] ;then
		echo "WARN: should have passed 5 arguments to ${FUNCNAME}: log_level, LINENO, FUNCNAME, (Exit) STATUS and log_message."
	fi
	
	#
	# Determine prio.
	#
	local _log_level="${1}"
	local _log_level_prio=${l4b_log_levels[$_log_level]}
	local _status="${4:-$?}"
	
	#
	# Log message if prio exceeds threshold.
	#
	if [ ${_log_level_prio} -ge ${l4b_log_level_prio} ]; then
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
		local _log_timestamp=$(date "+%Y-%m-%dT%H:%M:%S") # Creates ISO 8601 compatible timestamp.
		local _log_line_prefix=$(printf "%-s %-s %-5s @ L%-s(%-s)>" "${SCRIPT_NAME}" "${_log_timestamp}" "${_log_level}" "${_problematic_line}" "${_problematic_function}")
		local _log_line="${_log_line_prefix} ${_log_message}"
		if [ ! -z "${mixed_stdouterr:-}" ]; then
			_log_line="${_log_line} STD[OUT+ERR]: ${mixed_stdouterr}"
		fi
		if [ ${_status} -ne 0 ]; then
			_log_line="${_log_line} (Exit status = ${_status})"
		fi
		
		#
		# Log to STDOUT (low prio <= 'WARN') or STDERR (high prio >= 'ERROR').
		#
		if [[ ${_log_level_prio} -ge ${l4b_log_levels['ERROR']} || ${_status} -ne 0 ]]; then
			printf '%s\n' "${_log_line}" > /dev/stderr
		else
			printf '%s\n' "${_log_line}"
		fi
	fi
	
	#
	# Exit if this was a FATAL error.
	#
	if [ ${_log_level_prio} -ge ${l4b_log_levels['FATAL']} ]; then
		#
		# Reset trap and exit.
		#
		trap - EXIT
		if [ ${_status} -ne 0 ]; then
			exit ${_status}
		else
			exit 1
		fi
	fi
}

#
# Parse LDIF records and apply quota to Physical File Systems (PFSs).
#
function parseLdif () {
	local    _ldif_file="${1}"
	local    _ldap_quota_attr_key_prefix="${2,,}" # Convert to lowercase.
	shift 2
	local -a _lfs_to_pfs_fake_hash=("${@}")
	#
	local    _ldap_attr_regex='([^: ]{1,}): ([^:]{1,})'
	local    _fake_hash_regex='([^: ]{1,})::([^:]{1,})'
	local    _pos_int_regex='^[0-9]+$'
	#
	# Restore lfs-to-pfs mapping from "fake" hash into a real one.
	#
	local -A _lfs_to_pfs=()
	for _mapping in ${_lfs_to_pfs_fake_hash[@]:-}; do
		if [[ ${_mapping} =~ ${_fake_hash_regex} ]]; then
			local _lfs_key="${BASH_REMATCH[1]}"
			local _pfs_val="${BASH_REMATCH[2]}"
			_lfs_to_pfs[${_lfs_key}]="${_pfs_val}"
			log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "Added mapping for ${_lfs_key} -> ${_pfs_val} to _lfs_to_pfs hash."
		else
			log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipped malformed mapping entry ${_mapping} from _lfs_to_pfs_fake_hash array."
		fi
	done
	#
	# Append the NULL character to the LDIF file, so we can detect that as EOF instead of a newline.
	#
	printf '\0' >> "${_ldif_file}"
	#
	# Substitute the blank line record separator with a # character and read records into an array.
	#
	IFS='#' read -r -d '' -a _ldif_records < <(sed 's/^$/#/' "${_ldif_file}") || log4Bash 'FATAL' ${LINENO} "${FUNCNAME:-main}" $? "Parsing LDIF file (${_ldif_file}) into records failed."
	#
	# Loop over records in the array and create a faked-multi-dimensional hash.
	#
	local _ldif_record
	for _ldif_record in "${_ldif_records[@]}"; do
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
			if [[ ${_ldif_line} =~ ${_ldap_attr_regex} ]]; then
				local _key=${BASH_REMATCH[1],,} # Convert key on-the-fly to lowercase.
				local _value=${BASH_REMATCH[2]}
				#
				# This may be a multi-valued attribute and therefore check if key already exists;
				# When key already exists make sure we append instead of overwriting the existing value(s)!
				#
				if [[ ! -z "${_directory_record_attributes[${_key}]+isset}" ]]; then
					_directory_record_attributes["${_key}"]="${_directory_record_attributes[${_key}]} ${_value}"
				else
					_directory_record_attributes["${_key}"]="${_value}"
				fi
				log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "     key   contains: ${_key}."
				log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "     value contains: ${_value}."
			else
				log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Failed to parse LDIF key:value pair (${_ldif_line})."
			fi
		done < <(printf '%s\n' "${_ldif_record}") || log4Bash 'FATAL' ${LINENO} "${FUNCNAME:-main}" $? "Parsing LDIF record failed."
		#
		# Use processed LDIF record to:
		#  1. Apply quota to PFS.
		#  2. Store cached meta-data in apps LFS.
		#
		if [[ ! -z "${_directory_record_attributes['dn']+isset}" ]]; then
			#
			# Parse cn from dn.
			#
			local _group=$(dn2cnWithEntitlementPrefix "${_directory_record_attributes['dn']}")
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Processing group: ${_group}..."
			#
			# Check if group exists on this machine: 
			# May be absent in case it is a private group of a user that is not entitled for this machine.
			#
			if [ $(getent group "${_group}") ]; then
				log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "   Group exists on this machine."
			else
				log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "   Skipping group ${_group}, because it does not exist on this machine. (Most likely private group for user that is not entitled.)"
				continue
			fi
			#
			# Check if group name starts with prefix of an entitlement for which we want to process group data.
			#
			local _process_group='no'
			local _entitlement_prefix
			for _entitlement_prefix in ${entitlement_prefixes[@]}; do
			local _prefix_regex="^${_entitlement_prefix}-"
				if [[ ${_group} =~ ${_prefix_regex} ]]; then
					_process_group='yes'
					break
				fi
			done
			if [[ ${_process_group} == 'yes' ]]; then
				local _list="${entitlement_prefixes[*]}"
				log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "   Group's entitlement prefix exists in list of entitlements to process: ${_list// /, }."
			else
				log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "   Skipping group ${_group}, because it does not exist in an entitlement, which we want to process."
				continue
			fi
			#
			# Loop over Logical File Systems (LFSs),
			# find the corresponding quota values,
			# find the corresponding Physical File System (PFS) and
			# apply quota settings to PFS.
			#
			for (( _offset = 0 ; _offset < ${#logical_file_systems[@]:-0} ; _offset++ )); do
				local _lfs="${logical_file_systems[${_offset}]}"
				if [[ -z ${_lfs_to_pfs[${_lfs}]+isset} ]]; then
					log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "   Skipping LFS ${_lfs} without mapping to a PFS."
					continue
				else
					log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "   Processing quota settings for LFS ${_lfs}..."
				fi
				local    _soft_quota_limit=''
				local    _hard_quota_limit=''
				if [[ ! -z "${_directory_record_attributes[${_ldap_quota_attr_key_prefix}${_lfs}]+isset}" && ! -z "${_directory_record_attributes[${_ldap_quota_attr_key_prefix}${_lfs}soft]+isset}" ]]; then
					_soft_quota_limit="${_directory_record_attributes[${_ldap_quota_attr_key_prefix}${_lfs}'soft']}"
					_hard_quota_limit="${_directory_record_attributes[${_ldap_quota_attr_key_prefix}${_lfs}]}"
				else
					log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "   Quota values missing for group ${_group} on LFS ${_lfs}."
					log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      Search key was ${_ldap_quota_attr_key_prefix}${_lfs}."
					continue
				fi
				log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      soft_quota_limit contains: ${_soft_quota_limit}."
				log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      hard_quota_limit contains: ${_hard_quota_limit}."
				#
				# Check for negative numbers and non-integers.
				#
				if [[ ! ${_soft_quota_limit} =~ ${_pos_int_regex} || ! ${_hard_quota_limit} =~ ${_pos_int_regex} ]]; then
					log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "   Quota values malformed for group ${_group} on LFS ${_lfs}. Must be integers >= 0."
					continue
				fi
				#
				# Check if soft limit is smaller than or equal to the hard limit:
				# lfs setquota will fail when the soft limit is larger than the hard limit.
				#
				if [[ ${_soft_quota_limit} -gt ${_hard_quota_limit} ]]; then
					log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "   Quota values malformed for group ${_group} on LFS ${_lfs}. Soft limit cannot be larger than hard limit."
					continue
				fi
				#
				# Check for 0 (zero).
				# When quota values are set to zero it means unlimited: not what we want.
				# When zero was specified we'll interpret this as "do not allow this group to consume any space".
				# Due to the technical limitations of how quota work we'll configure the lowest possible value instead:
				# This is 2 * the block/stripe size on Lustre File Systems.
				#
				if [[ ${_soft_quota_limit} -eq 0 ]]; then
					_soft_quota_limit='2M'
					log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "   Converted soft quota limit of 0 (zero) for group ${_group} on LFS ${_lfs} to lowest possible value of ${_soft_quota_limit}."
				else
					# Just append unit: all quota values from the IDVault are in GB.
					_soft_quota_limit="${_soft_quota_limit}G"
				fi
				if [[ ${_hard_quota_limit} -eq 0 ]]; then
					_hard_quota_limit='2M'
					log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "   Converted hard quota limit of 0 (zero) for group ${_group} on LFS ${_lfs} to lowest possible value of ${_hard_quota_limit}."
				else
					# Just append unit: all quota values from the IDVault are in GB.
					_hard_quota_limit="${_hard_quota_limit}G"
				fi
				
				#
				# Compile and apply Lustre quota command to PFS(s).
				#
				local -a _pfss=($(printf '%s' "${_lfs_to_pfs[${_lfs}]}" | tr ',' ' '))
				local    _pfs
				for _pfs in ${_pfss[@]}; do
					log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "   Compiling quota command for LFS ${_lfs} on PFS ${_pfs}."
					local _lfs_cmd="lfs setquota -g ${_group} --block-softlimit ${_soft_quota_limit} --block-hardlimit ${_hard_quota_limit} /mnt/${_pfs}"
					if [ "${apply_settings}" -eq 1 ]; then
						log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" 0 "   Applying quota cmd: ${_lfs_cmd}"
						mixed_stdouterr="$(${_lfs_cmd})" || log4Bash 'FATAL' ${LINENO} "${FUNCNAME:-main}" $? "lfs setquota failed."
					else
						log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" 0 "   Dry run quota cmd: ${_lfs_cmd}"
					fi
				done
				#
				# In case we are processing 'private groups' for individual users:
				# Set quota to the smallest possible value for file systems where private groups are banned.
				#
				if [[ ${_ldap_quota_attr_key_prefix} =~ 'person' ]]; then
					for _pfs in ${pfs_without_users[@]}; do
						log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "   Compiling quota command for private group on PFS ${_pfs}."
						local _lfs_cmd="lfs setquota -g ${_group} --block-softlimit 2M --block-hardlimit 2M /mnt/${_pfs}"
						if [ "${apply_settings}" -eq 1 ]; then
							log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" 0 "   Applying quota cmd: ${_lfs_cmd}"
							mixed_stdouterr="$(${_lfs_cmd})" || log4Bash 'FATAL' ${LINENO} "${FUNCNAME:-main}" $? "lfs setquota failed."
						else
							log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" 0 "   Dry run quota cmd: ${_lfs_cmd}"
						fi
					done
				fi
			done
			#
			# Store cached meta-data.
			#
			if [[ ${_ldap_quota_attr_key_prefix} =~ 'group' ]]; then
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" 0 'Processing group meta-data...'
				declare -a _meta_data_keys=('ruggroupownervalue' 'ruggroupdatamanagervalue')
			elif [[ ${_ldap_quota_attr_key_prefix} =~ 'person' ]]; then
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" 0 'Processing private group (=user) meta-data...'
				declare -a _meta_data_keys=('loginexpirationtime' 'logindisabled')
			else
				log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" 0 "Found unsupported ldap_quota_attr_key_prefix ${_ldap_quota_attr_key_prefix}: skipping meta-data caching."
				return
			fi
			declare -a _meta_data=()
			local      _meta_data_key
			for _meta_data_key in "${_meta_data_keys[@]}"; do
				local _meta_data_item="${_directory_record_attributes[${_meta_data_key}]:-NA}"
				_meta_data_key="${_meta_data_key#ruggroup}" # Remove meaningless characters from key.
				_meta_data_key="${_meta_data_key%value}"    # Remove meaningless characters from key.
				if [[ ${_meta_data_item} == 'NA' ]]; then
					log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "   SOP violation: ${_group} lacks ${_meta_data_key}."
				else
					log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "   Found meta-data for ${_group}: ${_meta_data_key}=${_meta_data_item}."
				fi
				if [[ "${#_meta_data[@]:-0}" -eq 0 ]]; then
					_meta_data=("${_meta_data_key}=${_meta_data_item}")
				else
					_meta_data=("${_meta_data[@]}" "${_meta_data_key}=${_meta_data_item}")
				fi
			done
			if [[ "${apply_settings}" -eq 1 && "${#meta_data_cache_dirs[@]:-0}" -ge 1 ]]; then
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "   Storing ${_group} meta-data..."
				local _cache_dir
				for _cache_dir in "${meta_data_cache_dirs[@]}"; do
					saveMetaDataCache "${_cache_dir}" "${_group}" "${_meta_data[@]}"
				done
			fi
		else
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "dn attribute missing for ${_ldif_record}"
		fi
	done
}

#
# Store meta-data in cache file.
#
function saveMetaDataCache () {
	local    _cache_dir="${1}"
	local    _object="${2}" # Either a group or a private group a.k.a. a user.
	shift 2
	local -a _meta_data_items=("${@}")
	local    _meta_data_item
	local    _cache_file="${_cache_dir}/${_object}"
	log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      Writing cached meta-data to ${_cache_file}."
	#
	# Create cache dir if not already present and initialize cache file deleting any old content.
	# Also update timestamps on cache dir and cache files.
	#
	if [ ! -d "${_cache_dir}" ]; then
		(umask 0022; mkdir -p -m '755' "${_cache_dir}")
	else
		touch "${_cache_dir}"
	fi
	(umask 0033; touch "${_cache_file}")
	printf '' > "${_cache_file}"
	for _meta_data_item in "${_meta_data_items[@]:-}"; do
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "      Writing to cache _meta_data_item: ${_meta_data_item}"
		printf '%s\n' "${_meta_data_item}" >> "${_cache_file}"
	done
}

#
# Extract a CN from a DN LDAP attribute.
#
function dn2cnWithEntitlementPrefix () {
	# cn=umcg-someuser,ou=users,ou=umcg,o=rs
	local _dn="$1"
	local _cn='MIA'
	local _regex='cn=([^, ]+)'
	if [[ ${_dn} =~ ${_regex} ]]; then
		_cn="${BASH_REMATCH[1]}"
	fi
	printf '%s' "${_cn}"
}

#
##
### Variables.
##
#

groups_ldif=${TMPDIR}/groups.ldif
users_ldif=${TMPDIR}/users.ldif
SCRIPT_NAME="$(basename $0 .bash)"
mixed_stdouterr='' # global variable to capture output from commands for reporting in custom log messages.

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

#
##
### Main.
##
#

#
# Get commandline arguments.
#
declare -a logical_file_systems=()
declare    apply_settings=0
while getopts "f:l:b:ah" opt; do
	case $opt in
		h)
			showHelp
			;;
		f)
			logical_file_systems="${OPTARG}"
			;;
		b)
			backup_dir="${OPTARG}"
			;;
		a)
			apply_settings=1
			;;
		l)
			l4b_log_level=${OPTARG^^}
			l4b_log_level_prio=${l4b_log_levels[${l4b_log_level}]}
			;;
		\?)
			log4Bash "${LINENO}" "${FUNCNAME:-main}" '1' "Invalid option -${OPTARG}. Try $(basename $0) -h for help."
			;;
		:)
			log4Bash "${LINENO}" "${FUNCNAME:-main}" '1' "Option -${OPTARG} requires an argument. Try $(basename $0) -h for help."
			;;
		esac
done

#
# Initialise vars from config file.
#
declare -A lfs_to_pfs_for_groups=()
declare -A lfs_to_pfs_for_users=()
declare -a pfs_with_apps=()
declare -a pfs_without_users=()

#
# Source config file.
#
# Config file must contain in bash syntax:
#	# 
#	# Credentials:
#	# 
#	LDAP_USER='some_account'
#	LDAP_PASS='some_passwd'
#	LDAP_SEARCH_BASE='ou=groups,ou=umcg,o=rs'
#	#
#	# Prefixes of IDVault entitlements for which group data must be processed.
#	#
#	declare -a entitlement_prefixes=('umcg' 'll')
#	# 
#	# Mappings of Logical File Systems (LFSs) to Physical File Systems (PFSs).
#	#  * for groups to apply group quota.
#	#  * for users to apply 'private group' quota.
#	#    Private groups contain only a single user and have the same name + ID as that user.
#	# In case an LFS is available from multiple PFSs, multiple PFSs may be listed separated by a comma.
#	# 
#	declare -A lfs_to_pfs_for_groups=(
#		['prm02']='umcgst07'
#		['prm03']='umcgst09'
#		['tmp03']='umcgst08'
#		['tmp04']='umcgst06'
#	)
#	declare -A lfs_to_pfs_for_users=(
#		['home']='umcgst07,umcgst09'
#	)
#	declare -a pfs_with_apps=(
#		'umcgst07'
#		'umcgst09'
#	)
#	#
#	# Only allow groups to store data here and set quota for individual users to the lowest possible value (1k).
#	#
#	declare -a pfs_without_users=(
#		'umcgst06'
#		'umcgst08'
#	)
# Config file must be located in same location as this script.
#
config_file="$(cd -P "$( dirname "$0" )" && pwd)/${SCRIPT_NAME}.cfg"
if [[ -r "${config_file}" && -f "${config_file}" ]]; then
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Sourcing config file ${config_file}..."
	source "${config_file}" || log4Bash 'FATAL' ${LINENO} "${FUNCNAME:-main}" $? "Cannot source ${config_file}."
else
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Config file ${config_file} missing or not accessible."
fi

if [ "${apply_settings}" -eq 1 ]; then
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' 'Found option -a: will fetch, list and apply settings.'
else
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' 'Option -a not specified: will only perform a "dry run" to fetch + list settings. Use -a to apply settings.'
fi

#
# Compile list of folders where meta-data will be cached.
#
declare -a meta_data_cache_dirs=()
if [[ -d '/apps' ]]; then
	meta_data_cache_dirs=('/apps/.tmp/ldap_cache/')
fi
for (( offset = 0 ; offset < ${#pfs_with_apps[@]:-0} ; offset++ )); do
	if [[ -d "/mnt/${pfs_with_apps[${offset}]}/apps/" ]]; then
		meta_data_cache_dir="/mnt/${pfs_with_apps[${offset}]}/apps/.tmp/ldap_cache/"
		meta_data_cache_dirs=(${meta_data_cache_dirs[@]:-} "${meta_data_cache_dir}")
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Found meta-data cache dir: ${meta_data_cache_dir}."
	else
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "No apps dir found on PFS: ${pfs_with_apps[${offset}]}."
	fi
done
if [[ "${#meta_data_cache_dirs[@]:-0}" -ge 1 ]]; then
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "List of meta_data_cache_dirs contains: $(printf "%s " "${meta_data_cache_dirs[@]}")."
else
	log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "List of meta_data_cache_dirs is empty: will not update/store the meta-data cache on any FS."
fi

#
# Compile list of LDAP quota fields to retrieve.
#
ldap_group_quota_fields='cn ruggroupOwnerValue ruggroupDataManagerValue'
if [ ${#logical_file_systems[@]:-0} -ge 1 ]; then
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Logical File Systems (LFSs) specified: ${logical_file_systems[@]}."
	if [ "${logical_file_systems[0]}" == 'ALL' ]; then
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "List of logical_file_systems contains ALL -> will fetch all known LFSs from config file ${config_file}..."
		logical_file_systems=(${!lfs_to_pfs_for_groups[@]} ${!lfs_to_pfs_for_users[@]})
	fi
else
	log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "Not a single Logical File System (LFS) specified with -f: will not apply quota settings to corresponding Physical File Systems (PFSs)."
fi
for (( offset = 0 ; offset < ${#logical_file_systems[@]:-0} ; offset++ )); do
	lfs="${logical_file_systems[${offset}]}"
	#
	# Check if we know on which PFS each LFS is located.
	#
	if [ ! -z "${lfs_to_pfs_for_groups[${lfs}]+isset}" ]; then
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "List of lfs_to_pfs_for_groups contains mapping ${lfs} -> ${lfs_to_pfs_for_groups[${lfs}]}."
		ldap_group_quota_fields="${ldap_group_quota_fields} ruggroupUMCGQuota${lfs} ruggroupUMCGQuota${lfs}Soft"
	elif [ ! -z "${lfs_to_pfs_for_users[${lfs}]+isset}" ]; then
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "List of lfs_to_pfs_for_users contains ${lfs} -> ${lfs_to_pfs_for_users[${lfs}]}."
	else
		log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Mapping to Physical File Sytem (PFS) missing for Logical File System (LFS) '${lfs}' in config file ${config_file}."
	fi
done

#
# Query LDAP.
#
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Retrieving data from LDAP..."
log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "ldap_group_quota_fields to retrieve = ${ldap_group_quota_fields}."
mixed_stdouterr=$(ldapsearch -LLL -o ldif-wrap=no -D "${LDAP_USER}" -w "${LDAP_PASS}" -b "${LDAP_SEARCH_BASE}" \
					"(ObjectClass=GroupofNames)" ${ldap_group_quota_fields} 2>&1 >"${groups_ldif}") \
					|| log4Bash 'FATAL' ${LINENO} "${FUNCNAME:-main}" $? "ldapsearch failed."

ldap_user_quota_fields='cn rugpersonUMCGQuotaHome rugpersonUMCGQuotaHomeSoft loginExpirationTime loginDisabled'
log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "ldap_user_quota_fields to retrieve = ${ldap_user_quota_fields}."
mixed_stdouterr=$(ldapsearch -LLL -o ldif-wrap=no -D "${LDAP_USER}" -w "${LDAP_PASS}" -b "${LDAP_SEARCH_BASE}" \
					"(ObjectClass=person)" ${ldap_user_quota_fields} 2>&1 > "${users_ldif}") \
					|| log4Bash 'FATAL' ${LINENO} "${FUNCNAME:-main}" $? "ldapsearch failed."
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "ldapsearch results were saved to ${groups_ldif} and ${users_ldif}."

#
# Emulate "fake" associative array a.k.a. hash using a normal array as we cannot pass hashes in Bash without ugly hacks. 
# Then parse LDIF records.
#
declare -a lfs_to_pfs_fake_hash=()
declare    key_value_combi

for lfs_key in ${!lfs_to_pfs_for_groups[@]}; do
	key_value_combi="${lfs_key}::${lfs_to_pfs_for_groups[${lfs_key}]}"
	lfs_to_pfs_fake_hash=(${lfs_to_pfs_fake_hash[@]:-} ${key_value_combi})
	log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "Added ${key_value_combi} from lfs_to_pfs_for_groups to lfs_to_pfs_fake_hash."
done
parseLdif "${groups_ldif}" 'ruggroupUMCGQuota'  "${lfs_to_pfs_fake_hash[@]:-}"

lfs_to_pfs_fake_hash=()
for lfs_key in ${!lfs_to_pfs_for_users[@]}; do
	key_value_combi="${lfs_key}::${lfs_to_pfs_for_users[${lfs_key}]}"
	lfs_to_pfs_fake_hash=(${lfs_to_pfs_fake_hash[@]:-} ${key_value_combi})
	log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "Added ${key_value_combi} from lfs_to_pfs_for_users to lfs_to_pfs_fake_hash."
done
parseLdif "${users_ldif}"  'rugpersonUMCGQuota' "${lfs_to_pfs_fake_hash[@]:-}"

#
# Cleanup tmp files.
#
if [ ${l4b_log_level_prio} -lt ${l4b_log_levels['INFO']} ]; then
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" 0 "Debug mode: temporary files ${groups_ldif} and ${users_ldif} won't be removed."
else
	rm "${groups_ldif}"
	rm "${users_ldif}"
fi

#
# Optional: Make backup of (complete) list of users and group
#           Perform new LDAP search to list all fields accessible to user who performs the query.
#
if [ ! -z "${backup_dir:-}" ]; then
	#
	# Create directory for backups.
	#
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Retrieving data from LDAP for backup..."
	mixed_stdouterr=$(mkdir -m 0700 -p "${backup_dir}" 2>&1) \
					|| log4Bash 'FATAL' ${LINENO} "${FUNCNAME:-main}" $? "Failed to create backup dir ${backup_dir}."
	if [[ -d ${backup_dir} && -w ${backup_dir} ]]; then
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Backup dir ${backup_dir} is Ok."
	else
		log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '0' "Backup dir ${backup_dir} cannot be used. Check path and permissions."
	fi
	#
	# Create timestamp.
	#
	BACKUP_TS=`date "+%Y-%m-%d-T%H%M"`
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Retrieving data from LDAP for backup..."
	mixed_stdouterr=$(ldapsearch -o ldif-wrap=no -LLL -D "${LDAP_USER}" -w "${LDAP_PASS}" -b "${LDAP_SEARCH_BASE}" \
					"(ObjectClass=GroupofNames)" 2>&1 >"${backup_dir}/groups-${BACKUP_TS}.ldif") \
						|| log4Bash 'FATAL' ${LINENO} "${FUNCNAME:-main}" $? "ldapsearch failed."
	
	mixed_stdouterr=$(ldapsearch -o ldif-wrap=no -LLL -D "${LDAP_USER}" -w "${LDAP_PASS}" -b "${LDAP_SEARCH_BASE}" \
					"(ObjectClass=person)" 2>&1 > "${backup_dir}/users-${BACKUP_TS}.ldif") \
						|| log4Bash 'FATAL' ${LINENO} "${FUNCNAME:-main}" $? "ldapsearch failed."
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "ldapsearch results for backup were saved to ${groups_ldif} and ${users_ldif}."
fi

#
# Reset trap and exit.
#
log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" 0 "Finished!"
trap - EXIT
exit 0