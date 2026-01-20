#!/bin/bash

set -ueo pipefail

_main="/mnt/repos"
for _dir in ${_main} ${_main}/1versions ${_main}/2deploy; do
   test -d ${_dir} || { echo "creating ${_dir}" && mkdir "${_dir}"; }
done

print_all_stacks() {
   cd ${_main}/2deploy/
   echo "Available stacks are: "
   find . -mindepth 1 -maxdepth 1 -type d -printf ' %P\n'
}

if [[ -z "${1:-}" ]]; then
   echo "Error, at least [stack_prefix] is missing. Use either"
   echo "   ${0} [stack]"
   echo "or"
   echo "   ${0} [stack] [OS_distribution] [repository] [version]"
   print_all_stacks
   exit
fi

if ! test -d ${_main}/2deploy/${1}; then
   echo "Error: this stack not part of the"
   print_all_stacks
   read -n1 -p "> you want to ADD this stack as NEW stack? [Y/n]: " _confirm
   if [[ "${_confirm}" == "" ]] || [[ "${_confirm}" == "Y" ]] || [[ "${_confirm}" == "y" ]]; then
      unset _confirm
      mkdir "${_main}/2deploy/${1}"
   else
      exit
   fi
fi

_stack=${1}

if [[ "${#}" -eq "4" ]]; then   # if all four variables were provided from command line
   _distroselect="${2}"
   _reposelect="${3}"
   _versionselect="${4}"
else                            # if not, then prompt for them
   echo "________ OS distributions available __________"
   _distroselect="error"
   while true; do
      test -d "${_main}/1versions/${_distroselect}" 2>/dev/null && break
      find "${_main}/1versions/" -mindepth 1 -maxdepth 1 -type d -printf '    %P\n'
      read -p "> select: " _distroselect
      echo ""
      echo "  You picked:   ${_distroselect}"
      test -d "${_main}/1versions/${_distroselect}" || echo "Wrong distribution, try again!"
   done

   echo "________ Select repository from the ${_distroselect} __________"
   _reposelect="error"
   while true ; do
      test -d "${_main}/1versions/${_distroselect}/${_reposelect}" 2>/dev/null && break
      find "${_main}/1versions/${_distroselect}" -mindepth 1 -maxdepth 1 -type d -printf '    %P\n'
      read -p "> select: " _reposelect
      echo "  You picked:   ${_reposelect}"
      test -d "${_main}/1versions/${_distroselect}/${_reposelect}" || echo "Wrong repository, try again!"
      echo ""
   done

   echo "________ Select versions from the ${_distroselect}/${_reposelect} ____________"
   _versionselect="error"
   while true; do
      test -d "${_main}/1versions/${_distroselect}/${_reposelect}/${_versionselect}" 2>/dev/null && break
      find "${_main}/1versions/${_distroselect}/${_reposelect}" -mindepth 1 -maxdepth 1 -type d -printf '    %P\n'
      read -p "> select: " _versionselect
      echo "  You picked:   ${_versionselect}"
      test -d "${_main}/1versions/${_distroselect}/${_reposelect}/${_versionselect}" || echo "Wrong version, try again!"
      echo ""
   done
fi

cd "${_main}"
if ! test -d "1versions/${_distroselect}/${_reposelect}/${_versionselect}"; then
   echo "Error, 1versions/${_distroselect}/${_reposelect}/${_versionselect} does not exist!"
   exit
else
   echo "---------- Confirm ---------"
   echo " The link will be created between"
   echo "   2deploy/${_stack}/${_reposelect}  ->  1versions/${_distroselect}/${_reposelect}/${_versionselect}"
   read -p "> press [enter] to confirm"
   ln -f -s "1versions/${_distroselect}/${_reposelect}/${_versionselect}" "2deploy/${_stack}/${_reposelect}"
   echo ""
fi
