#!/bin/bash

_main="/mnt/repos"
! test -d "${_main}/0cache" && mkdir "${_main}/0cache"

print_all_repos() {
      cd ${_main}/0cache/
      _allrepos=$(ls -d */ 2>/dev/null)
      for _thisrepo in ${_allrepos}; do echo "   ${_thisrepo//\/}"; done
}

if [[ -z "${1}" ]]; then
      echo "you did not provide repo"
      print_all_repos
      exit
fi

if ! test -d ${_main}/0cache/${1}; then
      echo "this repo does not yet exist in the:"
      print_all_repos
      read -n1 -p "> do you want to add this repository as a NEW one? [Y/n]: " _confirm
      if [[ "${_confirm}" == "" ]] || [[ "${_confirm}" == "Y" ]]; then
      unset _confirm
      mkdir "${_main}/0cache/${1}"
      else
      exit
      fi
fi

_repo=${1}
_time="$(date +%Y%m%d-%H%M%S)"
dnf reposync --arch=x86_64 --repo ${_repo} --downloaddir=${_main}/0cache/ && \
mkdir -p "${_main}/1versions/${_repo}/" && \
cp -a --reflink=always ${_main}/0cache/${_repo} "${_main}/1versions/${_repo}/${_time}" || exit
echo ""
echo ""
echo "New version created:   ${_main}/1versions/${_repo}/${_time}"
