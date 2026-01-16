

#!/bin/bash

_main="/mnt/repos"
for _dir in ${_main} ${_main}/1versions ${_main}/2deploy; do
      test -d ${_dir} || { echo "error no ${_main}"; exit; }
done

print_all_stacks() {
      cd ${_main}/2deploy/
      echo " available stacks are:"
      _allstacks=$(ls -d */ 2>/dev/null | grep -v versions)
      for _thisstack in ${_allstacks}; do echo "   ${_thisstack//\/}"; done
}

if [[ -z "${1}" ]]; then
      echo "you did not provide stack"
      print_all_stacks
      exit
fi

if ! test -d ${_main}/2deploy/${1}; then
      echo "this stack not part of the"
      print_all_stacks
      read -n1 -p "> do you want to add this stack as NEW stack? [Y/n]: " _confirm
      if [[ "${_confirm}" == "" ]] || [[ "${_confirm}" == "Y" ]]; then
      unset _confirm
      mkdir "${_main}/2deploy/${1}"
      else
      exit
      fi
fi

_stack=${1}

echo " ________ repositories available __________"
allrepos=()
i=0
cd ${_main}/1versions/
for _repo in *; do
      allrepos+=("${_repo}")
      echo "  ${i}    ${_repo}"
      i=$((i+1))
done
read -p "> select: " reposelect
echo "  You picked:   ${allrepos[$reposelect]}"
echo ""

echo " ________ versions available inside ${allrepos[$reposelect]} ____________"
allversions=()
j=0
cd "${_main}/1versions/${allrepos[${reposelect}]}"

for _version in *; do
      allversions+=("${_version}")
      echo "  ${j}    ${_version}"
      j=$((j+1))
done
read -p "> select: " versionselect
echo "  You picked:   ${allrepos[$reposelect]}/${allversions[${versionselect}]}"

echo " ---------- Confirm ---------"
echo " The link will be created between"
echo "   2deploy/${_stack}/${allrepos[$reposelect]}  ->  1versions/${allrepos[$reposelect]}/${allversions[versionselect]}"
read -p "> press [enter] to confirm"
ln -f -s "${_main}/1versions/${allrepos[$reposelect]}/${allversions[versionselect]}" "${_main}/2deploy/${_stack}/${allrepos[$reposelect]}" && echo done
echo ""
