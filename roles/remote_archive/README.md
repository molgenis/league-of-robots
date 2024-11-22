# Surf archiving

## Important

 - note that this role does not do anything with pfs/lfs
 - this is due to how
   - the mount points are automatically detected, based on simple archive list of groups
   - how the mountpoints (folders) are automatically created AND removed when not needed!
   - the fuse.sshfs needs extra parameters, that are shared across mount points, so they
     do not need to be provided separately (as for example in the lfs)
   - and most importantly due to the fact that `/etc/fstab` is not used, but labeled
     systemd unit files are

## About

When mount point is accessed
 - system establishes an ssh connection to each the remote archive system
 - it mounts the remote folder via sshfs onto the subfolder of the associated group
 - permissions of the `-dm` user is applied on the system
 - on remote system all the data is stored under the user of the established ssh connection
 - after the user(s) stop using the mountpoint folder (no files are open, and user is not
   accessing the folder anymore) the mountpoint is disconnected from remote server
 - all groups that use the same archive system are sharin the same ssh connection which implies
   - connections to the remote archive system are well managed
   - bandwidth to the remote archive is shared between the groups
   - (TODO) bandwidth could be throttled
 - permissions
   - even though that the files are owned in the backed by the remote archive user
   - local user can access only the files from the group that he is a member of

## Prerequisites

 - this role will be deployed on the user interface machines only
 - the groups that have access to the archive, are defined in the `archive_groups`
   of the `group_vars/[stack]_cluster/vars.yml`
 - (if missing on stack user interface machine) role creates ssh key-pair for user root
 - (if ^ public key is missing on remote archive server's `.ssh/authorized_keys`, then
   this role will fail > administrator must login to remote archive machine and copy
   content of `/root/.ssh/id_ed25519_archive.pub` into `.ssh/authorized_keys` file on
   the remote archive server. To establish connection
    - (either) via ssh from another stack that has already connected archive, or
    - via ssh from any machine, using password (see `group_vars/all/secrets.yml`)
 - rerun the role

