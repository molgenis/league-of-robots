#!/bin/bash
set -euo pipefail
_tag="surf_archive"

function _print_help(){
   cat << EOF
   Provide one of the following arguments
    --dmfind-reg <path>      print regular files / files that reside only on disk
    --dmfind-mig <path>      print files that are being copied from disk to tape
    --dmfind-dul <path>      print files that reside both online and offline
    --dmfind-ofl <path>      print data that is no longer on disk (is on tape)
    --dmfind-unm <path>      print files which are being copied from tape to disk
    --dmget      <path>      recall / stage online FROM TAPE
    --dmls       <path>      list state
    --dmput      <path>      send to offline / stage TO TAPE
EOF
}

if [[ "${#}" -lt 2 ]] || [[ "${1}" == "-h" ]] || [[ "${1}" == "--help" ]]; then
   _print_help
fi

_arg="${1:-default}"
_path="${2:-/error_path}"
if ! test -e "${_path}"; then
   echo "Error, path must exist!"
   exit 1
fi

_first="$(echo "${_path}" | cut -s -d'/' -f2)"
if [[ "${_first}" != "groups" ]]; then
   echo "Failed: directory must be from the /groups!"
   exit 1
fi
_second="$(echo "${_path}" | cut -s -d'/' -f3)"
_third="$(echo "${_path}" | cut -s -d'/' -f4)"
if [[ ! "${_third}" =~ ^"arc"[0-9][0-9]$ ]]; then
   echo "Failed: directory must be in the arc filesystem!"
   exit 1
fi

_users_queue="$(mktemp -u -p /var/cache/arcq/queue/${_third}/)"
echo "${_arg} ${_path}" >> "${_users_queue}"
