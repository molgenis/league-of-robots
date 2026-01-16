#!/bin/bash

_main="/mnt/repos"

echo "  Checking which deployments are not linked correctly ..."
for _link in $(find ${_main} -type l ! -exec test -e {} \; -print); do
   read -p "> ${_link} is dead - (r)emove is or re(L)ink [r/L]? " _confirm
   if [[ "${_confirm}" == "L" ]] || [[ "${_confirm}" == "" ]]; then
      read -p "> write path to relink: " _path
      ln -s -f "${_path}" "${_link}" && echo "  done"
   elif [[ "${_confirm}" == "r" ]]; then
      if [[ "${remove}" == "" ]]; then
         read -p "> removing ${_link}, confirm [enter]" _remove
         rm "${_link}" && echo "  removed"
      fi
   fi
done
