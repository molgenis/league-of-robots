#!/bin/bash
# First configure bash to correctly handle missing variables and errors
set -eEuo pipefail

_print_help() {
cat << EOF

Overview
 - this script is intended to run as cron on multiple machines at the same time
 - the machines use a specific directory on a shared filesystem to communicate to coordinate their actions
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
 - output from commands are redirected into stdout, parallax's output goes into
   log file or logger

Mandatory arguments
 --command=<string>
     command to be executed - it can be also multiple commands separated by
     semicolon ; character
 --lock-dir=<path>
     location of main lock directory, where it will store hostname directories
     and pid locks inside, must also be on shared filesystem, one that other
     host systems have access to
 --logger-tag=<string>
     for the 'logger' command - all logs are redirected to system logs.
     This is alternative of the argument '-f'. Elevated users can parse the log
     data by using 'journalctl -t <tag>' (if journal is/still stored).
 --log-file=<path>
     alternative of logger, store output to a file on this location - fails when
     used together with --logger-tag

Extra arguments - time limits
 --randomdelay=<integer>
     maximum (d)elay time after lock dir is created and before command is
     executed (in seconds, default 10). Actual delay is a random number between
     5 seconds (minimum) and this number (maximim).
 --runtime=<integer>
     max run(t)time (in seconds) for command (in seconds, default 28800 = 8h)
 --remoteextratime=<integer>
     how much extra time does a remote host get before this host removes remotes
     hosts pid file? (in seconds, default 21600 = 6h)
     Note: that pid file of remote host gets removed only when:
       now > ( randomdelay + runtime + remoteextratime )
Other arguments
 --restarts=<integer>
     how many times can a script run (default 20), before
       - process running on local system: pid gets killed
       - process running on remote system: delete pid file and lock folder
     Note that has nothing to do with time limits - this is simply counter of
     script restarts.
     If many hosts are often running this script, it must be set to high number.
 --hostname=<string>
     for testing - it 'fakes' a remote hostname when run on the same host
     It will also not check if lock directory is located on mounted storage
 --debug
     Prints in stdout an extra debugging information

Examples
  1. Run one command, output logs to a system logs, leave default run limits
     ${0} --command="ls" --lock-dir=/groups/umcg-atd/tmp01/testing --logger-tag=myrun
  2. Run two commands, output logs to a log file on a system, leave default run limits, fake hostname
     ${0} --command=\"id; sleep 10; who\" --lock-dir=/groups/umcg-atd/tmp01/testing --log-file=/tmp/myrun.log --hostname=wh-chaperone
  3. Run one command, output logs to a log file on a system, set runtime limits
     ${0} --command=\"uptime\" --lock-dir=/groups/umcg-atd/tmp01/testing --log-file=/tmp/myrun.log --randomdelay=3 --runtime=600 --remoteextratime=100
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

_exec_dir=${PWD}

# default settings
_script_path_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
_logger_tag=""
_log_file=""
_debug=false
_testing=false               # normally we don't test things, but setting a hostname changes that, and then
                             # we also don't check if remote storage is actually a mount point
_hostname="$(/bin/hostname)" # for developing and testing - first argument overwrites hostname
_random_delay_default="10"   # in seconds: how long should script wait (after the lock directory is created)
                             # to actually start the command. Delay is a random number between 5 seconds and
                             # this number. It changes at every run. It prevents misconfigured cron timings
                             # for when all nodes are set up to start at the same time.
_max_runtime=28800           # [= 6h] in seconds: how long can command run before is being killed?
_extra_remote_time=21600     # [= 4h] in seconds: how much extra should local job ignore the remote host's job
                             # Script removes lock folder and files after
                             #         elapsed > delay + _max_runtime + _extra_remote_time
_restarts="20"               # how many times can script be restarted and remain ignored, after then a local
                             # processes will be killed, where remote processes will have lock directory and
                             # pid file removed
_try_again=2                 # if we wait in line, let's try again

_small_random_delay_argument="${_random_delay_default}"
while [[ "${#}" -gt 0 ]]; do
   _arg=${1//\~/${HOME}}
   case "${_arg//=*}" in
      "--command")          _command="${_arg#--*=}" ;;
      "--lock-dir")         _main_lock_dir="${_arg#--*=}" ;;
      "--logger-tag")       _logger_tag="${_arg#--*=}" ;;
      "--log-file")         _log_file="${_arg#--*=}" ;;
      "--hostname")         _hostname="${_arg#--*=}"; _testing=true ;;
      "--randomdelay")      _small_random_delay_arg="${_arg#--*=}" ;;
      "--runtime")          _max_runtime="${_arg#--*=}" ;;
      "--remoteextratime")  _extra_remote_time="${_arg#--*=}" ;;
      "--debug")            _debug=true ;;
      "--restarts")         _restarts="${_arg#--*=}" ;;
      *)                    _print_help ;;
   esac
   shift
done

_small_random_delay="${_small_random_delay_arg:-${_random_delay_default}}"

# Prepare random delay in seconds: 5 seconds <= delay <= [ random delay number ]
if [[ "${_small_random_delay}" -gt "5" ]]; then
  # make a number between 5 and argument number and with two decimal numbers
  _tmp_size="$(( _small_random_delay - 5))"
  _tmp_num="$(( RANDOM % _tmp_size ))"
  _small_random_delay="$(( _tmp_num + 5)).$(( RANDOM % 99 ))"
  unset _tmp_rand1 _tmp_rand2
else _small_random_delay=5
fi

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
_local_lock_dir="${_main_lock_dir}/${_hostname}"
_pidfile="${_local_lock_dir}/pid"

function clean_stale_pidfiles(){
   local _stale_local_pidfile
   _stale_local_pidfile="${_local_lock_dir}/pid"
   if test -e "${_stale_local_pidfile}"; then
      local _pid
      # clear all the pids that are not running
      for _pid in $(cat "${_stale_local_pidfile}"); do
         if ! pgrep -u ${UID} "timeout" | grep -q "${_pid}"; then
            sed -i "/${_pid}/d" "${_stale_local_pidfile}"
            _logme "($$ ${FUNCNAME}) Removed ${_pid} from pid file"
         fi
      done
      # if file is now empty, clean directory
      if ! test -s "${_stale_local_pidfile}"; then
         rm -f "${_local_lock_dir}/pid"
         rm -f "${_local_lock_dir}/remote"
         [ -z "$(ls -A ${_local_lock_dir})" ] && rmdir "${_local_lock_dir}" && sync
         _logme "(${$} ${FUNCNAME}) Removed local local files and directory [${_local_lock_dir}/{pid,remote}]!"
      fi
   fi
}

function check_time(){
   #### Parameters explained
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
   # does NOT include _small_random_delay, tail, as last one is the most important
   sync && _time_created=$(stat -c %Z ${_main_lock_dir}/${_tmphost})
   local _time_delay_start
   _time_delay_start="$(bc -l <<< "${_time_created} + ${_small_random_delay}")"    # add delay to the time of when the lock folder has been created
   if test -z "${_time_delay_start}"; then # the time is missing
      _logme "(${$} ${FUNCNAME}) Error _time_delay_start is empty"
      exit 200
   fi
   local _time_max_runtime
   _time_max_runtime=$(bc -l <<< "${_time_delay_start} + ${_max_runtime}")
   local _time_max_remotetime
   _time_max_remotetime=$(bc -l <<< "${_time_delay_start} + ${_max_runtime} + ${_extra_remote_time}")

   # Collect time from server
   _timedir="${_main_lock_dir}/${_tmphost}/.testtimedir.$(date +%s.%N)"
   # clean old directory
   sync && test -d "${_timedir}" && rmdir "${_timedir}" && sync
   mkdir "${_timedir}" && sync
   # collect time on the server side
   _time_now="$(stat -c %Z ${_timedir})"
   rmdir "${_timedir}" && sync
   _logme "(${$} ${FUNCNAME})    collected _time_now epoch seconds from server [${_time_now}]"
   ${_debug} && _logme "(${$} ${FUNCNAME})      _time_now=$_time_now"
   ${_debug} && _logme "(${$} ${FUNCNAME})      _time_max_runtime=$_time_max_runtime"
   ${_debug} && _logme "(${$} ${FUNCNAME})      _time_max_remotetime=$_time_max_remotetime"
   if (( $(bc -l <<< "${_time_now} > ${_time_max_remotetime}") )); then
      _logme "(${$} ${FUNCNAME})    remote host runs for too long! (returning 14)"
      return 14   # clean remote host lock directory and files
   elif (( $(bc -l <<< "${_time_now} > ${_time_max_runtime}") )); then
      _logme "(${$} ${FUNCNAME})    should kill! (returning 13)"
      return 13   # kill
   elif (( $(bc -l <<< "${_time_now} < ${_time_delay_start}") )); then
      _logme "(${$} ${FUNCNAME})    should wait (returning 1)"
      return 1    # wait
   elif (( $(bc -l <<< "${_time_now} >= ${_time_delay_start}") )); then
      _logme "(${$} ${FUNCNAME})    can run (returning ok 0)"
      return 0    # run
   else
      _logme "(${$} ${FUNCNAME})    unexpected result (exit 201)"
      exit 201
   fi
}

function end_remove_local_locks(){
   # cleaning up after run
   if test -d "${_main_lock_dir}" && test -d "${_local_lock_dir}"; then
      # check that pidfile is not empty
      if test -e "${_local_lock_dir}/pid"; then
         # simply remove it
         rm -f "${_local_lock_dir}/pid"
         rm -f "${_local_lock_dir}/remote"
         [ -z "$(ls -A ${_local_lock_dir})" ] && rmdir "${_local_lock_dir}/" && sync
         _logme "(${$} ${FUNCNAME})   lock directory removed [$(pwd)/${_hostname}]"
      fi
   fi
}

function killing_pid(){
   if test -e "${_local_lock_dir}/pid"; then
      _pids="$(sort -u < "${_local_lock_dir}/pid")"
   else
      _logme "(${$} ${FUNCNAME}) Error, no pid provided to kill and pid file is missing. Exit 255!"
      exit 255
   fi
   for _each_pid in ${_pids}; do
      # killing timeout processes
      if pgrep -u "${UID}" "timeout" 2>&1 | grep -q "${_each_pid}"; then
         _logme "(${$} ${FUNCNAME}) Killing process ${_each_pid}"
         kill -9 "${_each_pid}" && \
           _logme "(${$} ${FUNCNAME})  ${_each_pid} killed!"
      fi
   done
}

function other_hosts_are_running(){
   _try_again=$(( _try_again - 1 ))
   _logme "($$ ${FUNCNAME})   there are other hosts running this script"
   test -d "${_main_lock_dir}" && cd "${_main_lock_dir}"
   for _each_host in */; do # loop through the hosts directories
      _each_host="${_each_host%\/}"
      {
         [[ "${_each_host}" == "${_hostname}" ]] && continue
         ${_debug} && _logme "(${$} ${FUNCNAME})      _each_host=$_each_host"
         ${_debug} && _logme "(${$} ${FUNCNAME})      _hostname=$_hostname"
         _remote_file="${_main_lock_dir}/${_each_host}/remote"
	 _remote_file_lines=0
	 test -e ${_remote_file} && _remote_file_lines="$(wc -l < "${_remote_file}")"
         # first check time
         _remote_time_result=$(check_time "${_each_host}")
         # then update the remotepidfile inside, and not updating change time of ^ hosts directory
         ${_debug} && _logme "(${$} ${FUNCNAME})      Appending hostname into ${_remote_file}"
         echo "${_hostname}" >> "${_remote_file}" # log attempt
         _logme "($$ ${FUNCNAME}) 'file \'${_each_host//\/}/remote\' has \'${_remote_file_lines}\' lines inside!'"
         # remove lock and pid, if time expired or script was restarted for too many times
         if [[ "${_remote_time_result}" -eq "14" ]] || \
            [[ "${_remote_file_lines}" -ge "${_restarts}" ]]; then
            _logme "($$ ${FUNCNAME}) '${_each_host//\/}' runs for too long. Removig pid file and lock dir. Host will stop script on own side!"
            # remove all files, also files like .nfsXXX .tmp or similar
            rm -f "${_each_host}/"*
            [ -z "$(ls -A ${_each_host})" ] &&  rmdir "${_each_host}/" && sync
         fi
       } 2>/dev/null || continue
   done
   _logme "($$ ${FUNCNAME})   removing our host from the race and exit ... "
   test -d "${_hostname}" && [ -z "$(ls -A ${_hostname})" ] && rmdir "${_hostname}" && sync
   exit 250
}


function start_flow(){
   sleep ${_small_random_delay}
   _logme "($$ ${FUNCNAME}) Entering main loop on on host ${_hostname}"
   sync
   if ! test -w "${_main_lock_dir}/"; then
      _logme "($$ ${FUNCNAME})    top level locking directory is missing [${_main_lock_dir}]"
   fi

   _all_hosts_count="$(find "${_main_lock_dir}/" -mindepth 1 -maxdepth 1 -type d | wc -l)"
   _all_hosts="$(find "${_main_lock_dir}/" -mindepth 1 -maxdepth 1 -type d)"
   ${_debug} && _logme "($$ ${FUNCNAME})    content of _main_lock_dir [$(echo ${_all_hosts})]"
   ${_debug} && _logme "($$ ${FUNCNAME})    _all_hosts_count=${_all_hosts_count}"
   _this_hostname_count="$(sync && find "${_main_lock_dir}" -name "${_hostname}" | wc -l)"
   ${_debug} && _logme "(${$} ${FUNCNAME})    _small_random_delay=${_small_random_delay}"
   if [[ "${_all_hosts_count}" -eq "0" ]]; then
      _logme "($$ ${FUNCNAME})    no other host if running anything right now"
      _logme "($$ ${FUNCNAME})    making local lock directory ${_local_lock_dir}"
      mkdir "${_local_lock_dir}" 2>/dev/null || { _logme "($$ ${FUNCNAME})      cannot create lock dir ${_local_lock_dir}" ; exit 255; }
      sync
      _logme "($$ ${FUNCNAME})    now sleeping for ${_small_random_delay}"
      sleep ${_small_random_delay} # don't rush things
      start_flow
   else # hosts are running things
      _logme "($$ ${FUNCNAME})    lock dirs exist"
      # this hostname is ALSO locking next to others
      if [[ "${_this_hostname_count}" -gt "0" ]]; then
         _logme "($$ ${FUNCNAME})    this machine can run a script"
         # only our host is locking
         if [[ "${_this_hostname_count}" -eq "${_all_hosts_count}" ]]; then
            _logme "($$ ${FUNCNAME})    this hostname is ONLY one that can run this script"
            # Is pid file inside and it contains pid?
            _time_result=$(check_time)
            if [[ "${_time_result}" -eq "0" ]]; then
               touch "${_local_lock_dir}/pid"
               if test -e "${_pidfile}"; then
                  if test -z "$(cat ${_pidfile})" ; then # pidfile exists and is empty
                     _logme "($$ ${FUNCNAME})    we already delayed the start so we can now proceed"
                     # the main command we would like to run inside cron
                     # _command="{ HOSTALIASES=/etc/hosts-LoR ${_command}; }"
                     # first remove remote file
                     test -e "${_main_lock_dir}/${_hostname}/remote" && rm -f "${_main_lock_dir}/${_hostname}/remote" && sync
                     _logme "($$ ${FUNCNAME})    Submitting commands ..."
                     # Sleep at the end is important! It keeps the proccess with
                     # registered PID number opened, and prevents other proccess
                     # to run at the same time!
                     timeout "${_max_runtime}" bash -c "cd ${_exec_dir} && ${_command%;}; sleep ${_small_random_delay}" & _child="${!}"
                     echo "${_child}" >> "${_pidfile}"
                     # Next line ensures that process is killed if lock pid file disappears
                     {  (  while test -e ${_pidfile} && grep -q "${_child}" "${_pidfile}"; do sleep ${_small_random_delay}; done; \
                           if pgrep -u ${UID} timeout 2>&1 | grep -q ${_child}; then
                              _logme "($$ ${FUNCNAME}) Killing PID ${_child} because the lock pid file disappeared!"; \
                              kill -9 "${_child}"; \
                              test -d "${_local_lock_dir}" && echo -n "" > "${_pidfile}"; \
                           fi \
                        ) & \
                     } 1>/dev/null 2>&1
                     _logme "($$ ${FUNCNAME}) Waiting for child response ..."
                     if wait ${_child} 2>/dev/null; then
                        _logme "($$ ${FUNCNAME})    succeeded!"
                     else _logme "($$ ${FUNCNAME})    FAILED!"; fi
                     sync
                     # empty pidfile if it is still exist by the end of process
                     test -s "${_pidfile}" && echo -n "" > "${_pidfile}" && sync
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
                     sleep ${_small_random_delay} && start_flow         # go to start
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
         # other hosts are locking as well as our host
         else
            _logme "($$ ${FUNCNAME})    other hosts can run as well"
            other_hosts_are_running
         fi
      # our host is not locking, only others
      else
         _logme "($$ ${FUNCNAME})    other hosts can run as well"
         other_hosts_are_running
      fi
   fi
}

_logme "($$ main) _______ Starting _______"
cd "${_main_lock_dir}"
# first just clean old pids
clean_stale_pidfiles
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

# make sure you sleep for small random delay at the end, before cleaning the lock directores
# so that they are not cleaned and another parallel process starts accidentaly
sleep "${_small_random_delay_argument}"

# Cleanning up
end_remove_local_locks

_logme "($$ main) _______ Finished _______"
