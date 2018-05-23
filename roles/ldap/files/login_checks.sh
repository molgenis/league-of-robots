#!/bin/bash

VARDIR=/var/lib/pam_script
VARLOG=$VARDIR/$PAM_USER

MOUNTPOINT1=/home
USERDIR1=$MOUNTPOINT1/$PAM_USER

SACCTMGR=/usr/bin/sacctmgr
LFS=/usr/bin/lfs
AWK=/bin/awk
GREP=/bin/grep

LOGFILE=/tmp/log.$PAM_USER
GROUP=$( /usr/bin/id -g $PAM_USER )
SLURMACCOUNT=users

SSHDIR=$( eval /bin/echo ~$PAM_USER )/.ssh

# Usage: run_with_timeout N cmd args...
#    or: run_with_timeout cmd args...
# In the second case, cmd cannot be a number and the timeout will be 10 seconds.
run_with_timeout () {
    local time=10
    if [[ $1 =~ ^[0-9]+$ ]]; then time=$1; shift; fi
    # Run in a subshell to avoid job control messages
    ( "$@" &
      child=$!
      # Avoid default notification in non-interactive shell for SIGTERM
      trap -- "" SIGTERM
      ( sleep $time
        kill $child 2> /dev/null ) &
      wait $child
    )
}

create_dir () {

   if [ $# -ne 2 ]; then
      echo "ERROR: create_dir expects both mountpoint and directory as arguments"
      exit -1
   fi

   echo "Checking for $2"

   # check if directory exists in MOUNTPOINT
   if [ -d "$2" ]; then
      echo Directory exists, skipping create
   else
      echo "Creating directory"
      mkdir $2
      chown $PAM_USER:$GROUP $2
      chmod 700 $2
   fi

   # check if directory exists now
   if [ -d "$2" ]; then
      echo Directory exists, OK
   else
      echo "ERROR: Directory $2 should exist but doesn't"
      exit -1
   fi
}

create_ssh_key() {
   echo "Checking for .ssh in $SSHDIR"
   if [ ! -e $SSHDIR ]; then
      echo "Creating $SSHDIR"
      mkdir $SSHDIR
      chmod 700 $SSHDIR
      chown $PAM_USER:$GROUP $SSHDIR
   else
      echo ".ssh directory exists already, continuing"
   fi
   if [ ! -e $SSHDIR/id_rsa ]; then
      echo "Creating key pair"
      ssh-keygen -t rsa -N "" -f $SSHDIR/id_rsa
      chmod 600 $SSHDIR/id_rsa
      chown $PAM_USER:$GROUP $SSHDIR/id_rsa
      chown $PAM_USER:$GROUP $SSHDIR/id_rsa.pub
      echo "Adding key pair to authorized_keys"
      if [ ! -e $SSHDIR/authorized_keys ]; then
         cp $SSHDIR/id_rsa.pub $SSHDIR/authorized_keys
         chmod 600 $SSHDIR/authorized_keys
         chown $PAM_USER:$GROUP $SSHDIR/authorized_keys
      else
         cat $SSHDIR/id_rsa.pub >> $SSHDIR/authorized_keys
      fi
   else
      echo "Key exists, checking for authorized_keys"
      if [ ! -e $SSHDIR/authorized_keys ]; then
         cp $SSHDIR/id_rsa.pub $SSHDIR/authorized_keys
         chmod 600 $SSHDIR/authorized_keys
         chown $PAM_USER:$GROUP $SSHDIR/authorized_keys
      else
         echo "authorized_keys exists, doing nothing"
      fi
   fi
   echo "Final check for authorized_keys, to see if we are OK"
   if [ ! -e $SSHDIR/authorized_keys ]; then
      echo "ERROR: authorized_keys has not been generated"
      exit -1
   fi
}

create_ssh_dir() {
   # Check for and crate $SSHDIR
   # make authorized_keys immutable (as we use ldap for pubkey auth)
   echo "Checking for .ssh in $SSHDIR"
   if [ ! -e $SSHDIR ]; then
      echo "Creating $SSHDIR"
      mkdir $SSHDIR
      chmod 700 $SSHDIR
      chown $PAM_USER:$GROUP $SSHDIR
   else
      echo ".ssh directory exists already, continuing"
   fi

   if [ ! -e $SSHDIR/authorized_keys ]; then
      touch $SSHDIR/authorized_keys
      chown root:root $SSHDIR/authorized_keys
      chmod 444 $SSHDIR/authorized_keys
   else
      echo "authorized_keys exists, doing nothing"
   fi
   echo "Making sure authorized_keys is immutable"
   chattr +i $SSHDIR/authorized_key
}

set_quota () {
   if [ $# -ne 5 ]; then
      echo "ERROR: set_quota expects 4 values for quota and a file system name"
      exit -1
   fi
   if [ "$PAM_USER" == "root" ]; then
      return 0
   fi
   echo "Checking for existing quota in $5"
   quota_user=$( $LFS quota -u $PAM_USER $5 | $GREP $5 | $AWK '{print $3}' )
   quota_group=$( $LFS quota -g $GROUP $5 | $GREP $5 | $AWK '{print $3}' )
# Check if quota obtained are real numbers
   if ! [[ $quota_user =~ ^-?[0-9]+$ && $quota_group =~ ^-?[0-9]+$ ]]; then
      echo "ERROR: Strange quota"
      exit -1
   fi
# Add the quota for user and group, to check if either is set
   quota=$(($quota_user + $quota_group))
   # regexp for checking if quota are a number
   echo Quota: $quota
   if [ $quota -eq "0" ]; then
      echo "Setting quota for $5"
      $LFS setquota -g $GROUP --block-softlimit $1 --block-hardlimit $2 --inode-softlimit $3 --inode-hardlimit $4 $5
      if [ $? -ne 0 ]; then
         echo "ERROR: Problem setting quota"
         exit -1
      fi
   else
      echo "FD: Quota already set, doing nothing"
   fi
}

add_user_to_slurm() {

   echo "Adding account to SLURM db"
   user_exists=$( $SACCTMGR show user $PAM_USER | grep $PAM_USER )
   if [ -z "$user_exists" ]; then
      $SACCTMGR -i create user name=$PAM_USER account=$SLURMACCOUNT fairshare=1
      if [ $? -ne 0 ]; then
         echo "ERROR: Problem creating user in accounting database"
         exit -1
      fi
   else
      echo User already exists in slurm. OK.
   fi
}

login_actions () {

   echo "Checking if $PAM_USER has been handled already"
   if [ -f "$VARLOG" ]; then
      echo "User already known, exiting"
      exit 0
   fi

   create_dir $MOUNTPOINT1 $USERDIR1

   # create ssh_dir with empty immutable authorized_keys
   create_ssh_dir

   # Create account in SLURM accounting db
   add_user_to_slurm

   # set homedir-quota:
   set_quota 1G 2G 200k 220k /home

   # Final action: create file with username in /var directory
   echo $( /usr/bin/getent passwd $PAM_USER | /bin/awk -F ':' '{print $5}' ) > $VARLOG
   echo "Finished actions successfully"
}

# Log start of script
echo "Script starting" > $LOGFILE

# Run the desired actions with a timeout of 10 seconds
run_with_timeout 10 login_actions >> $LOGFILE

echo "Script finished" >> $LOGFILE

exit 0
