#!/bin/bash

# First configure bash to correctly handle missing variables and errors
set -eEuo pipefail

_print_help() {
cat << EOF

Overview
 - this script is intended to run as cron on multiple machines at the same time
 - the only way the machines can communicate is via is via shared filesystem
   where a specific directory is located - used by machines to coordinate
 - script automatically checks if lock directory is located on mounted storage
 - the extra information about the machine that is running command is stored
   inside lock directory in the file called pid
 - script should be able to work on samba/cifs (isilon), nfs and lustre (tested)
 - the time is gathered from the cifs server's time, so it does not matter
   how different the datetime settings are on the client side
 - for testing you can provide a --hostname as an argument, which will be then
   set as a hostname in the lock directory (so that you can test and develop on
   local machine - note that this will prevent checking if lock directory is
   located on a mounted storage
 - running script too many times, will trigger restart limit, which will kill
   the process if it is running locally / remove the pid and lock folder if it
   is running on remote host
 - when command is executed, the timeout is running and waiting for limit to
   expire, if that happens, command is killed
 - command's output goes into stdout, parallax output goes into log file or logger

Arguments
   --command=<string>     command to be executed - it can be also multiple commands separated by semicolon ;
   --lock-dir=<path>      location of main lock directory, where it will store hostname directories and pid locks inside,
                          must also be on shared filesystem, one that other host systems have access to
   --logger-tag=<string>  for the 'logger' command - all logs are redirected to system logs - alternative of argument '-f'
                          you can parse the log data by using 'journalctl -t <tag>' (if journal is/still stored)
   --log-file=<path>      alternative of logger, store output into a file on this location - will fail if used together with --logger-tag
   --hostname=<string>    for testing - it 'fakes' a remote hostname when run on the same host
                          this will prevent checking if lock directory is located on mounted storage
 Runtime limits
   --tdelay=<integer>   (d)elay time after lock directory is created, before command is executed (in seconds, default 10)
   --truntime=<integer>  max run(t)time (in seconds) for command (in seconds, default 28800 = 8h)
   --tremote=<integer>   how much extra time does a remote host get before this host removes pid file? (in seconds, default 21600 = 6h)
                         note that pid file of remote host gets removed when: ( tdelay + truntime + tremote ) > now
 Restart limit
   --restarts=<integer>  how many times can a script run (default 20), before
                          - local pid will get killed
                          - for processes that are running on remote the lock folder and pid file will be removed
                         Note that has nothing to do with time limits - this is simply counter of script restarts.
                         If many hosts are often running this script, then it should be set to higher number.
Examples
  1. Run one command, output logs to a system logs, leave default run limits
     ${0} --command="ls" --lock-dir=/groups/umcg-atd/tmp01/testing --logger-tag=myrun
  2. Run two commands, output logs to a log file on a system, leave default run limits, fake hostname
     ${0} --command=\"id; sleep 10; who\" --lock-dir=/groups/umcg-atd/tmp01/testing --log-file=/tmp/myrun.log --hostname=wh-chaperone
  3. Run one command, output logs to a log file on a system, set runtime limits
     ${0} --command=\"uptime\" --lock-dir=/groups/umcg-atd/tmp01/testing --log-file=/tmp/myrun.log --tdelay=3 --truntime=600 --tremote=100
     - make a lock file and wait for 4 seconds before executing a command,
     - then it will run an 'uptime' command and limit its runtime to a 600s=10 min, when it will be automatically killed,
     - if another script is executed on the same host, but command is still running, and if lock folder is 10 min old, then it will kill process
     - if another script is executed but on the remote host, but lock folder is 600s+100s old, it will remote lock folder and pid file inside
  4. Run one command, output logs to a log file on a system, leave default time limits, but set restart limit to max 5
     ${0} --command=\"uptime\" --lock-dir=/groups/umcg-atd/tmp01/testing --log-file=/tmp/myrun.log --restarts=5
     this script can be called up to 5 times, after when it will be killed regardless of runtime limits

EOF
   exit 1
}

_exec_dir=$(pwd)

# default settings
_script_path_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
_logger_tag=""
_log_file=""
_testing=false               # normally we don't test things, but setting a hostname changes that, and then
                             # we also don't check if remote storage is actually a mount point
_hostname="$(/bin/hostname)" # for developing and testing - first argument overwrites hostname
_small_delay="10"            # in seconds: how long should script wait (after the lock directory is created)
                             # to actually start the command
_max_runtime=28800           # [= 6h] in seconds: how long can command run before is being killed?
_extra_remote_time=21600     # [= 4h] in seconds: how much extra should local job ignore the remote host's job
                             # Script removes lock folder and files after
                             #         elapsed > delay + _max_runtime + _extra_remote_time
_restarts="20"               # how many times can script be restarted and remain ignored, after then a local
                             # processes will be killed, where remote processes will have lock directory and
                             # pid file removed

while [[ "${#}" -gt 0 ]]; do
   _arg=${1//\~/${HOME}}
   case "${_arg//=*}" in
      "--command")       _command="${_arg#--*=}" ;;
      "--lock-dir")      _main_lock_dir="${_arg#--*=}" ;;
      "--logger-tag")    _logger_tag="${_arg#--*=}" ;;
      "--log-file")      _log_file="${_arg#--*=}" ;;
      "--hostname")      _hostname="${_arg#--*=}"; _testing=true ;;
      "--tdelay")        _small_delay="${_arg#--*=}" ;;
      "--truntime")      _max_runtime="${_arg#--*=}" ;;
      "--tremote")       _extra_remote_time="${_arg#--*=}" ;;
      "--restarts")      _restarts="${_arg#--*=}" ;;
      *)                 _print_help ;;
   esac
   shift
done

# Check that --command and --lock-dir are configured
if test -z "${_main_lock_dir:-}" || test -z "${_command:-}"; then
   echo -e "Error: missing --lock-dir/--command arguments!\nRun\n\t$0 --help\n"; exit 1
fi

# Check that --logger-tag or --log-file are configured
if test -z "${_logger_tag:-}" && test -z "${_log_file:-}"; then
   echo -e "Error: missing either --logger-tag or --log-file arguments!\nRun\n\t$0 --help\n"; exit 1
fi

[[ -n "${_logger_tag}" && -n "${_log_file}" ]] && { echo "Error: logger tag and log file should not be defined at the same time!"; exit 1; }

function _logme() {
   if [[ -n "${1:-}" ]]; then # $1 exists
      if [[ -n "${_logger_tag:-}" ]]; then
         logger -t "${_logger_tag:-}" "${1}"
      else
         echo "${1}" >> "${_log_file}"
      fi
   else # $1 does not exist, we redirect stream into command
      if [[ -n "${_logger_tag}" ]]; then
         logger -t "${_logger_tag}"
      else cat - >> "${_log_file}"
      fi
   fi
}
trap '_logme "${$} Command (${BASH_COMMAND}) failed on line number (${LINENO})"' ERR

# Check that we have actually use shared storage
function _ismounted {
   _mounted=false; _subpath="";
   for _slice in ${1//\// }; do
      _subpath=${_subpath}/${_slice}
      mountpoint -q ${_subpath} && _mounted=true
   done
   if $_mounted; then return 0; else return 1; fi
}
if ! ${_testing} && ! _ismounted "${_main_lock_dir}"; then
   echo "Main folder where locks are created is not mounted - other hosts cannot access!"
   exit 255
fi

if ! test -d "${_main_lock_dir}"; then
    mkdir -p "${_main_lock_dir}"
    _logme "Created ${_main_lock_dir}"
fi
_lock_dir="${_main_lock_dir}/${_hostname}"
_pidfile="${_lock_dir}/pid"

function clean_stale_pidfiles(){
   local _stale_pidfile
   _stale_pidfile="${_lock_dir}/pid"
   if test -e "${_stale_pidfile}"; then
      local _pid
      # first clear all the pids that are not running
      for _pid in $(cat "${_stale_pidfile}"); do
         if ! pgrep -u ${UID} "timeout" | grep -q "${_pid}"; then
            sed -i "/${_pid}/d" "${_stale_pidfile}"
            _logme "($$ ${FUNCNAME}) Removed ${_pid} from pid file"
         fi
      done
      # if file is now empty, remove it whole file
      if test -z "$(cat "${_stale_pidfile}")"; then
         rm -f "${_stale_pidfile}" && _logme "(${$} ${FUNCNAME}) Removed stale pid file [${_lock_dir}/pid]"
      fi
   fi
}

function check_time(){
   # $1 must hostname (or else is assigned to this hostname)
   # 1. check's if time file exist, and
   # 2. check time
   #                                            return   further action
   #     now > _time_delay_start                   0        can start
   #     if _start_time is unassigned              1        need to wait
   #     now < _time_delay_start                   1        need to wait
   #     now > _time_delay_start + _max_runtime    13       should kill process
   #     now >                                     14       should kill process
   #      _time_delay_start + _max_runtime + _extra_remote_time
   #     file `time` is missing or wrong perms              log
   [[ -n "${1:-}" ]] && _tmphost="${1}" || _tmphost="${_hostname}"
   local _time_created
   _time_created=$(stat -c %Z ${_main_lock_dir}/${_tmphost})    # does NOT include _small_delay, tail, as last one is the most important
   local _time_delay_start
   _time_delay_start="$((_time_created + _small_delay))"    # add delay to the time of when the lock folder has been created
   if test -z "${_time_delay_start}"; then # the time is missing
      _logme "(${$} ${FUNCNAME}) Error _time_delay_start is empty"
      exit 200
   fi
   local _time_max_runtime
   _time_max_runtime=$((_time_delay_start + _max_runtime))
   local _time_max_remotetime
   _time_max_remotetime=$(( _time_delay_start + _max_runtime + _extra_remote_time))

   # Collect time from server
   _timedir="${_main_lock_dir}/${_tmphost}/.testtimedir"
   test -d "${_timedir}" && rmdir "${_timedir}" # clean old directory
   mkdir "${_timedir}"
   _time_now="$(stat -c %Z ${_timedir})"        # get server's time
   rmdir "${_timedir}"

   _logme "(${$} ${FUNCNAME})    collected _time_now epoch seconds from server [${_time_now}]"
   _logme "(${$} ${FUNCNAME})      _time_now=$_time_now"
   _logme "(${$} ${FUNCNAME})      _time_max_runtime=$_time_max_runtime"
   _logme "(${$} ${FUNCNAME})      _time_max_remotetime=$_time_max_remotetime"
   if [[ "${_time_now}" -gt "${_time_max_remotetime}" ]]; then
      _logme "(${$} ${FUNCNAME})    remote host runs for too long! (now returning 14 ... )"
      return 14   # clean remote host lock directory and files
   elif [[ "${_time_now}" -gt "${_time_max_runtime}" ]]; then
      _logme "(${$} ${FUNCNAME})    should kill! (now returning 13 ...)"
      return 13   # kill
   elif [[ "${_time_now}" -lt "${_time_delay_start}" ]]; then
      _logme "(${$} ${FUNCNAME})    should wait (now returning 1 ...)"
      return 1    # wait
   elif [[ "${_time_now}" -ge "${_time_delay_start}" ]]; then
      _logme "(${$} ${FUNCNAME})    can run (now returning ok 0 ...)"
      return 0    # run
   else
      _logme "(${$} ${FUNCNAME})    unexpected result (exit 201)"
      exit 201
   fi
}

function remove_locks(){
   # Cleaning up after run
   if test -d "${_main_lock_dir}" && test -d "${_lock_dir}"; then
      if test -z "$(cat "${_lock_dir}/pid")"; then   # check if pidfile contains our process or is empty
         rm -f "${_lock_dir}/pid" # simply remove it
         rmdir "${_lock_dir}" && _logme "(${$} ${FUNCNAME})   lock directory removed [$(pwd)/${_hostname}]"
      fi
   fi
}

function killing_pid(){
   if test -e "${_lock_dir}/pid"; then
      _pids="$(sort -u < "${_lock_dir}/pid")"
   else
      _logme "(${$} ${FUNCNAME}) Error, no pid provided to kill and pid file is missing. Exit 255!"
      exit 255
   fi
   for _each_pid in ${_pids}; do
      if pgrep -u "${UID}" "timeout" 2>&1 | grep -q "${_each_pid}"; then # killing timeout processes
         _logme "(${$} ${FUNCNAME}) Killing process ${_each_pid}"
         kill -9 "${_each_pid}" && \
           _logme "(${$} ${FUNCNAME})  ${_each_pid} killed!"
      fi
   done
}

function start_flow(){
   _logme "($$ ${FUNCNAME}) Entering main loop]"
   sync
   if ! test -w "${_lock_dir}/"; then
      _logme "($$ ${FUNCNAME})    top level locking directory is missing [${_lock_dir}]"
   fi
   _all_host_count="$(ls -1 ${_main_lock_dir}| wc -l)"
   _my_hostname_count="$(find "${_main_lock_dir}" -name "${_hostname}" | wc -l)"
   if [[ "${_all_host_count}" -eq "0" ]]; then
      _logme "($$ ${FUNCNAME})    no other host if running anything right now"
      _logme "($$ ${FUNCNAME})    making lock directory ${_lock_dir}"
      mkdir "${_lock_dir}" || { _logme "($$ ${FUNCNAME})      cannot create lock dir ${_lock_dir}" ; exit 255; }
      sync
      sleep ${_small_delay} # don't rush things
      start_flow
   else # hosts are running things
      _logme "($$ ${FUNCNAME})    lock dirs exist"
      if [[ "${_my_hostname_count}" -gt "0" ]]; then # my hostname is running script
         _logme "($$ ${FUNCNAME})    this machine can run this script"
         if [[ "${_my_hostname_count}" -eq "${_all_host_count}" ]]; then # it's ONLY my hostname
            _logme "($$ ${FUNCNAME})    ONLY this machine can run this this script"
            # Is pid file inside and it contains pid?
            _time_result=$(check_time)
            if [[ "${_time_result}" -eq "0" ]]; then
               touch "${_lock_dir}/pid"
               if test -e "${_pidfile}"; then
                  if test -z "$(cat ${_pidfile})" ; then # pidfile exists and is empty
                     _logme "($$ ${FUNCNAME})    we already delayed the start so we can now proceed"
                     # the main command we would like to run inside cron
                     # _command="{ HOSTALIASES=/etc/hosts-LoR ${_command}; }"
                     # _command_logger="_logme \"($$ ${FUNCNAME})    main command SUCCESSFULLY finished!\""
                     _logme "($$ ${FUNCNAME})    RUNNING MAIN COMMAND"
                     timeout "${_max_runtime}" bash -c "cd ${_exec_dir} && ${_command%;}" & _child="${!}"
                     echo "${_child}" >> "${_pidfile}" # storing process ID inside the pid file
                     # Next line ensures that process is killed if lock pid file disappears
                     {  (  while test -e ${_pidfile} && grep -q "${_child}" "${_pidfile}"; do sleep ${_small_delay}; done; \
                           if pgrep -u ${UID} timeout 2>&1 | grep -q ${_child}; then
                              _logme "($$ ${FUNCNAME}) Killing PID ${_child} because the lock pid file disappeared!"; \
                              kill -9 "${_child}"; \
                              test -d "${_lock_dir}" && echo -n "" > "${_pidfile}"; \
                           fi \
                        ) & \
                     } 1>/dev/null 2>&1
                     _logme "($$ ${FUNCNAME}) Waiting for child response ..."
                     wait ${_child} 2>/dev/null || true   #  true ensures that the cleanup is done
                     sync
                     echo -n "" > "${_pidfile}" && sync   # empty pidfile if it is still exist by the end of process
                     _logme "($$ ${FUNCNAME}) Child process ended, syncing files finished"
                  else # the pid file is not empty
                     _running_pid="$(head -n1 < "${_pidfile}")"
                     echo "${_running_pid}" >> "${_pidfile}" # duplicating process ID inside pid file
                     _pidfile_nr_lines="$(wc -l < "${_pidfile}")"
                     if [[ "${_pidfile_nr_lines}" -gt "${_restarts}" ]]; then # this script was run more than restarts limit, time to kill it
                        killing_pid
                        exit 255
                     else # it exist and has a pid
                        _logme "($$ ${FUNCNAME})  x script already running > logging & exiting"
                        exit 255
                     fi
                  fi
               fi
            else
               case "${_time_result}" in
                  1)
                     _logme "($$ ${FUNCNAME})      too early, let's wait ... "
                     sleep ${_small_delay} && start_flow         # go to start
                     ;;
                  13|14)
                     _logme "($$ ${FUNCNAME})      we should kill: this process is running for too long"
                     killing_pid
                     exit 255
                     ;;
                  255)
                     _logme "($$ ${FUNCNAME}) Cannot get time of lock directory!"
                     exit 200
                     ;;
                  *)
                     _logme "($$ ${FUNCNAME}) Unknown error: _time_result=${_time_result}"
                     ;;
               esac
            fi
         fi
      else # other hosts are running this script
         _logme "($$ ${FUNCNAME})   there are other hosts running this script"
         for _each_host in */; do # loop through the hosts directories
            _remote_pidfile="${_main_lock_dir}/${_each_host}/pid"
            _remote_running_pid="$(head -n1 < "${_remote_pidfile}")"
            _remote_pidfile_nr_lines="$(wc -l < "${_remote_pidfile}")"
            echo "${_remote_running_pid}" >> "${_remote_pidfile}" # duplicating process ID inside pid file
            _remote_time_result=$(check_time "${_each_host}")
            # remove lock and pid, if time expired or script was restarted for too many times
            if [[ "${_remote_time_result}" -eq "14" ]] || \
               [[ "${_remote_pidfile_nr_lines}" -gt "${_restarts}" ]]; then
               _logme "($$ ${FUNCNAME}) '${_each_host//\/}' runs script for too long. Removing the lock directory and files inside. Host will clean this processes on its own side!"
               rm -f "${_each_host}/"*               # remove all files, the selection of just 'time' and 'pid' could make issues
                                                     # if some other files would appear - like .nfsXXX .tmp or similar
               rmdir "${_each_host}/"
            fi
         done
         _logme "($$ ${FUNCNAME})   removing our host from the race and exit ... "
         test -d ${_hostname} && rmdir ${_hostname}
         exit 250
      fi
   fi
}

_logme "($$ main) _______ Starting _______"
cd "${_main_lock_dir}"
clean_stale_pidfiles # first just clean old pids
_return_code="0"
start_flow 2>&1 || _return_code=${?:-0}
if [[  "${_return_code}" -ne "0" ]]; then
   _logme "($$ main) exited with an error [ \$?=${_return_code} ] ..."
   case "${_return_code}" in
      250)
         _logme "($$ main) Parallel host execution, exiting the main scipt (exit 255) ..."
         ;;
      255)
         _logme "($$ main) Parallel script execution, exiting the main scipt (exit 255) ..."
         ;;
      *)
   esac
   exit 1
fi

# Cleanning up
remove_locks

_logme "($$ main) _______ Finished _______"

