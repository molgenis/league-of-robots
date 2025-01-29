#!/bin/bash
set -euo pipefail

_tmp_basename="$(basename $(mktemp -u))"
_tag="surf_archive"
_main_dir="/var/cache/arcq/"
_queue_dir="${_main_dir}/queue"
_stdout_dir="${_main_dir}/output"
_delay=0.5

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
    --sha256sum  <path>      compute the sha256sum of the file
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

echo "${_arg} ${_path}" >> "${_queue_dir}/${_third}/${_tmp_basename}"

echo "Submitted to remote host, waiting for reply ..."
echo "(  You can press CTRL+C and check later for the output in ${_stdout_dir}/${_tmp_basename}  )"
sleep ${_delay} && sync
while ! test -s "${_stdout_dir}/${_tmp_basename}.done"; do
   sleep ${_delay}
done

sync
cat "${_stdout_dir}/${_tmp_basename}"
