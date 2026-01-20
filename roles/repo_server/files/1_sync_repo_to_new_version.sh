#!/bin/bash

set -ueo pipefail

_main="/mnt/repos"
! test -d "${_main}/0cache" && mkdir "${_main}/0cache"

print_all_repos() {
   echo ""
   echo "All available repositories are"
   cd ${_main}/dnf.repos.d/
   find . -name "*.repo" -type f -printf '    %P\n'
}

if [[ -z "${1:-}" ]]; then
      echo "Error, you did not provide repo!"
      print_all_repos
      echo ""
      echo "Correct syntax is"
      echo "  ${0} os_distribution/repository"
      exit
fi

_os_distribution=${1%%/*}

_repo_file=${1##*/}
_repo=${_repo_file//.repo}


echo _os_distribution=$_os_distribution
echo _repo_file=$_repo_file
echo _repo=$_repo

_time="$(date +%Y%m%d-%H%M%S)"
dnf reposync --conf ${_main}/dnf.repos.d/${_os_distribution}.conf --repo ${_repo} --downloaddir=${_main}/0cache/${_os_distribution}/ && \
mkdir -p "${_main}/1versions/${_os_distribution}/${_repo}/" && \
cp -a --reflink=always ${_main}/0cache/${_os_distribution}/${_repo}/ "${_main}/1versions/${_os_distribution}/${_repo}/${_time}/" || exit
echo ""
echo ""
echo "New version created:   ${_main}/1versions/${_os_distribution}/${_repo}/${_time}"
