# Parallax - Parallel (execution) across (multiple hosts)

Overview

 - for more information see script's header and help function
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

