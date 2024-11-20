# Surf archiving

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

 - role uses a pre-created ssh key-pair for each cluster stack. Key must be stored
   at `/root/.ssh/id_ed25519_archive{.pub}` with permission `0600`. Role will crash
   otherwise. Administrator must copy content of `/root/.ssh/id_ed25519_archive.pub`
   into remote archive server's `.ssh/authorized_keys` file and then rerun the role.
 - this role will be deployed on the user interface machines only
 - the groups that have access to the archive, are defined in the `archive_groups`
   of the `group_vars/[stack]_cluster/vars.yml`

