# Surf archiving

## Quickstart

### Adding arcXX to a group

vi group_vars/hyperchicken_cluster/vars.yml

define variable `archive_groups`:

```yml
archive_groups:
  - name: arc01
    groups:
      - 'umcg-atd'
      - 'solve-rd'
    archive_system: 'archive.surfsara.nl'
    archive_user: 'umcg-atd-dm'
    archive_system_fingerprints:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJNpdWNkupmMeY2hjod0Nyu5Eu2W7bnpwXSXnkcQqOap
      - ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDORQo/SUxIROOa/dHVEMUTDH9CatGFkQBHvYv0nOUUfeHTYtksNFfjKOHg6HY0X0Fz83bMPMYx+YWFY1THrGwY=
archive_ssh_key_location: '/root/.ssh/id_ed25519_archive'
archive_ssh_key_type: 'ed25519'
```

this defines for the groups `solve-rd` and `umcg-atd` an archive folders of `arc01`. They will be prepared to be automounted (when accessed) in the folders `/group/[solve-rd,umcg-atd]/arc01/`. The archive are stored on remote systems 'archive.surfsara.nl', which is accessed main user `umcg-atd-dm`. Keys for access are stored on each system inside the `/root/.ssh/id_ed25519_archive{,.pub}`.


### Removing arcXX from a group

Leave the `archive_groups` variables defined, except the `archive_groups.groups` should be emptied (see empty list below) and then rerun the playbook. This will unmount the mountpoints, disable the systemd `.automount` services and removed their systemd unit files (.mount and .automount). After this you can (if you need) remove the entire `archive_groups` variable.

```yml
archive_groups:
  - name: arc01
    groups: []  # define an empty group
#    groups:
#      - 'umcg-atd'
#      - 'umcg-gsad'
    archive_system: 'archive.surfsara.nl'
    archive_user: 'umcg-atd-dm'
    archive_system_fingerprints:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJNpdWNkupmMeY2hjod0Nyu5Eu2W7bnpwXSXnkcQqOap
      - ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDORQo/SUxIROOa/dHVEMUTDH9CatGFkQBHvYv0nOUUfeHTYtksNFfjKOHg6HY0X0Fz83bMPMYx+YWFY1THrGwY=
```

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

## How the role works

## systemd automounts

It creates for each group's archive:
 - two systemd unit files
    - `.mount` and `.automount`
    - they contain a tag marker which can be later found
    - they are placed in the /etc/systemd/system/ and activated
    - they file names are structured in a systemd manner
      - the dashes `-` are replaced with `\x2d` and
      - the slashes `/` are replaced with dashes `-`
 - a mountpoint directory is created at the `/groups/[groupname]/[archive name]`

The service enables and starts the `.automount`, which checkes if the `mountpoints` are created.
Is so, thene every time a user access the directory a mount is called.

### fuse.sshfs

The `.mount` file declares mounting from remote system, by using `fuse.sshfs`.
In the back it uses a regular `ssh` connection. The conneciton is defined in the
`/root/.ssh/conf.d/remote_archive`.
Connection is multiplexed for all groups and persistent (2h).

# Debug

## Check if services are running

For both .automount and .mount services.

You can either look for the available services in the `systemctl` (and look for .automount and .mount).
Or browse for those file extensions in the `/etc/systemd/systemd/`.

    [root@talos system]# systemctl status 'groups-umcg\x2datd-arc01.automount'
    [root@talos system]# systemctl status 'groups-umcg\x2datd-arc01.mount'

## Changes in the service files

Will not be automatically reflected in the systemd. You must first run the

    [root@talos system]# systemctl daemon-reload

and then either of the

    [root@talos system]# systemctl status 'groups-umcg\x2datd-arc01.automount'
    [root@talos system]# systemctl restart 'groups-umcg\x2datd-arc01.automount'


## Check the connection to the remote system

    [root@talos system]# ssh umcg-atd-dm@archive.surfsara.nl

## Check if multiplexing is working

    [root@talos system]# netstat -tpn | grep 145
    tcp        0      0 10.10.1.195:52316       145.100.5.8:22          ESTABLISHED 194899/ssh
