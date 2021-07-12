#!/bin/bash

#
# Custom ssh-ldap-wrapper script.
#  * Fetches public keys
#     * For regular users from the LDAP: from LDAP using default ssh-ldap-helper or
#     * For local admin users: from a local ~/.ssh/authorized_keys file.
#  * Filters the public keys by dropping unsupported key types or short key sizes considered weak.
#  * Can prepend an SSH forced command for regular users in specific groups to provide restricted access.
#
declare user="${1}"
declare regex='^([0-9][0-9]*) .* \((.*)\)$'
declare ssh_ldap_helper='/usr/libexec/openssh/ssh-ldap-helper'
declare ssh_keygen='/usr/bin/ssh-keygen'
declare minimal_rsa_key_size='4096'
declare admin_gid='{{ auth_groups['admin'].gid }}'
declare ssh_forced_command='restrict,command="/bin/rsync --server --daemon --config=/etc/rsyncd.conf ." '
declare -a authorized_keys=()

function filterKeys() {
  local _public_key="${1}"
  local _fingerprint
  test -z "${_public_key:-}" && return
  _fingerprint="$("${ssh_keygen}" -l -f /dev/stdin <<< "${_public_key}")"
  if [[ "${_fingerprint}" =~ ${regex} ]]; then
    local _key_size="${BASH_REMATCH[1]}"
    local _key_type="${BASH_REMATCH[2]}"
    if [[ "${_key_type}" == 'ED25519' ]]; then
      authorized_keys=("${authorized_keys[@]}" "${_public_key}")
    elif [[ "${_key_type}" == 'RSA' ]] && [[ "${_key_size}" -ge "${minimal_rsa_key_size}" ]]; then
      authorized_keys=("${authorized_keys[@]}" "${_public_key}")
    else
      echo "WARN: Skipping unsupported ${_key_size} bit ${_key_type} key." 1>&2
    fi
  else
    echo "ERROR: Failed to parse key fingerprint ${fingerprint:-}." 1>&2
  fi
}

#
# Check if specified user exists.
#
if id "${user:-missing}" >/dev/null 2>&1; then
  if [[ "$(id -g "${user}")" == "${admin_gid}" ]]; then
    #
    # Use ~/.ssh/authorized_keys file from a local home dir for members of the admin group,
    # so admins can still login in case of an LDAP (connection) failure.
    #
    key_file="$(getent passwd "${user}" | cut -d: -f6)/.ssh/authorized_keys"
    while read -r public_key; do
      filterKeys "${public_key}"
    done < "${key_file}"
  else
    #
    # Fetch public keys from LDAP server for non-admin users and
    # prepend an SSH forced command to restrict users to rsync-only access
    # unless they do not match certain groups.
    #
    declare groups
    groups="$(id -Gn "${user}")"
    if [[ "${user}" != *guest* && "${groups}" != *sftp-only* && "${groups}" != *rsync-only* ]]; then
      ssh_forced_command=''  # Disables the forced command resulting in full shell access.
    fi
    while read -r public_key; do
      test -z "${public_key:-}" && continue
      filterKeys "${ssh_forced_command}${public_key}"
    done < <("${ssh_ldap_helper}" -s "${user}")
  fi
else
  echo "ERROR: user ${user:-} does not exist." 1>&2
  exit
fi

for authorized_key in "${authorized_keys[@]}"; do
  printf '%s\n' "${authorized_key}"
done