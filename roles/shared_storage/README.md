# Ansible Role: shared_storage

This role mounts parts of shared storage systems (shares a.k.a. exports) on various machines of an HPC cluster depending on their purpose.

## Terminology

 * **PFS**: **P**hysical **F**ile **S**ystem. Could also be actually virtualised nowadays, but always something only sys admins should worry about.
   We never bother end users on an HPC cluster with _PFS-ses_.
 * **LFS**: **L**ogical **F**ile **S**ystem. A piece of a (shared/local) storage system for a specific purpose and a specific group of users.
   This is how end users see and work with storage systems: _PFS_ naming is consistent and remains constant no matter on which _PFS_ the _LFS_ is located. 
   When a _PFS_ is End of Life and phased out, the data can be migrated to a different _PFS_ keeping the _LFS_ and hence the path to the data for end users exactly the same.
 * **home**: An _LFS_ for user's home directories.
 * **dat[0-9]{2}**: An _LFS_ for exchanging data with diagnostics lab LIMS.
   * On a file system maintained by the hospital IT staff.
   * By design only mounted on the _Chaperone_ servers.
 * **tmp[0-9]{2}**: An _LFS_ for **t**e**mp**orary data.
   * On a file system optimized for High Performance (HP) where possible.
   * Without backups.
   * with automagic cleanup of old data.
   * By design mounted on both _User Interface (UI)_ and _compute nodes_ of an HPC cluster.
 * **rsc[0-9]{2}**: An _LFS_ for **r**ead-only **s**torage **c**ache:
   * On a file system optimized for High Performance (HP) where possible.
   * Without backups.
   * Without automagic cleanup of old data.
   * By design mounted
     * read-write on the _User Interface (UI)_ servers of an HPC cluster with write permissions limited to data managers.
     * read-only on compute nodes.
 * **prm[0-9]{2}**: An _LFS_ for **p**e**rm**anent data:
   * On a file system optimized for High Availability (HA) where possible.
   * With backups.
   * Without automagic cleanup of old data.
   * By design only mounted on the _User Interface (UI)_ servers of an HPC cluster.
     In order to crunch data from a _prm_ _LFS_ it must be staged to a _tmp_ or _rsc_ _LFS_ first.
 * **apps**: An _LFS_ for the original of the shared environment (software, modules, reference data).
   * By design mounted read-write and only on the _Deploy Admin Interface (DAI)_ in **/apps**.
   * Preferably on a local file system and not on shared storage as the latter is known to be horribly slow 
     for many ```module load/unload``` commands, which are used during dependency management, and for building software from sources.
 * **env[0-9]{2}**: An _LFS_ for a copy of the shared environment (software, modules, reference data).
   * By design mounted read-only on both _User Interface (UI)_ and _compute nodes_ of an HPC cluster in **/apps**
   * By design mounted read-write on the _Deploy Admin Interface (DAI)_ of an HPC cluster in **/mnt/env[0-9]{2}**
     The _DAI_ also contains the read-write primary copy / original of the shared environment from a local storage device and mounted in **/apps**
     An rsync-based tool is used to synchronise **/apps** to all copies in **/mnt/env[0-9]{2}**,
     which is read-only mounted in **/apps** on the _UI_ and _compute nodes_.

An HPC cluster can have
 * Only one **home** and one **apps** _LFS_
 * Multiple **dat[0-9]{2}**, **rsc[0-9]{2}**, **tmp[0-9]**, **prm[0-9]** and **env[0-9]** _LFS-ses_. We keep the numbers unique over all clusters.
   Hence there is only one _prm03_. If multiple machines optionally from multiple clusters have an _prm03_ _LFS_ mount,
   it must contain the same data with the same permissions.

## group_vars

The _LFS-ses_ and _PFS-ses_ they are located on must be specified for each HPC cluster in the corresponding _group\_vars_ located at ```groups_vars/{{stack_name}}/vars.yml```
An example snippet (see below for explanation of what get's mounted where based on this example):
```
---
#
# Other group_vars
#
###################################################################################################
#
# Physical File Systems (PFS-ses).
#
pfs_mounts:
  - pfs: 'isilon11'
    source: 'some-storage001.stor.local:/ifs'
    type: 'nfs4'
    rw_options: 'defaults,_netdev,vers=4.0,noatime,nodiratime'
    ro_options: 'defaults,_netdev,vers=4.0,noatime,nodiratime,ro'
  - pfs: 'lusty2'
    source: '10.0.0.203@tcp12:10.0.0.204@tcp12:/lusty2'
    type: 'lustre'
    rw_options: 'defaults,_netdev,flock'
    ro_options: 'defaults,_netdev,ro'
  - pfs: local_raid
    #
    # Example of a complete PFS that is not mounted via the shared_storage role, but with the local_storage role instead.
    # Normally the source, type and rw_options are used to mount both the complete PFS
    # as well as LFS-ses from that PFS, but in this case we must use separate pfs_* arguments
    # to mount the complete PFS and these must match what was specified for this local file system.
    # The file system should have already been mounted by the local_storage role,
    # so the pfs_* arguments are de facto only used to validate that the file system was mounted correctly
    # and to ensure the play stops when this is not the case to prevent making sub directories
    # for the LFS-ses in the mount point from the small OS disk as opposed to on the PFS.
    #
    pfs_source: LABEL=local_raid
    pfs_type: xfs
    pfs_options: rw,relatime,nofail,x-systemd.device-timeout=10
    #
    # File system source, type and mount options only used for LFS-ses from this PFS.
    #
    source: '/mnt'
    type: 'none'
    rw_options: 'bind,nofail'
    ro_options: 'bind,ro,nofail'
    machines: "{{ groups['sys_admin_interface'] }}"
#
# Logical File Systems (LFS-ses) with:
#  * specification of what needs to get mounted where or for which groups.
#  * on which PFS an LFS is located.
#
lfs_mounts:
  - lfs: home
    pfs: local_raid
    rw_machines: "{{ groups['user_interface'] }}"
  - lfs: env08
    pfs: isilon11
    ro_machines: "{{ groups['compute_node'] + groups['user_interface'] }}"
    rw_machines: "{{ groups['deploy_admin_interface'] }}"
  - lfs: tmp08
    pfs: isilon11
    type: bind
    groups:
      - ateam
      - colla
      - production
      - cool-project
    rw_machines: "{{ groups['user_interface'] + groups['deploy_admin_interface'] }}"
  - lfs: prm05
    pfs: isilon11
    type: bind
    groups:
      - ateam
      - production
    rw_machines: "{{ groups['user_interface'] + groups['deploy_admin_interface'] }}"
  - lfs: prm03
    pfs: lusty2
    type: bind
    groups:
      - ateam
      - colla
      - production
    rw_machines: "{{ groups['user_interface'] }}"
###################################################################################################
#
# Other group_vars
#
...
```

#### pfs_mounts

The **pfs_mounts** variable lists all Physical File Systems and their technical specs required by the ```mount``` command. Per _PFS_:

 * **pfs**: a label for this _PFS_.
   * Preferably only lowercase characters a-z.
   * Used as the mountpoint in **/mnt/** on the _Sys Admin Interface (SAI)_.
   * Usually the same as a (sub)folder from the file system.
     Can be either the root folder if the entire file system is used only as this _PFS_ 
     or a subfolder when the same storage system is used by other systems / clients too.
   * Optionally the label may be suffixed by a slash forward and the subfolder.
     This can be used when the parent dir of the subfolder contains other subfolders 
     with data from other other systems / clients
     that should **not** be mounted / available on the _SAI_.
 * **source**: device or URL for the file system as used by the ```mount``` command.  
   Will always get suffixed with the ***pfs** value.  
   Used for mounting both _PFS-ses_ and _LFS-ses_ unless **pfs_source** is defined (see below).
 * **type**: file system type as used by the ```mount``` command.  
   Used for mounting both _PFS-ses_ and _LFS-ses_ unless **pfs_type** is defined (see below).
 * **pfs_source**: optional attribute to override **source** when mounting the complete _PFS_.
 * **pfs_type**: optional attribute to override **type** when mounting the complete _PFS_.
 * **rw_options**: mount options when mounting this _PFS_ **read-write** using the ```mount``` command.
 * **ro_options**: mount options when mounting this _PFS_ **read-only** using the ```mount``` command.
 * **machines**:
   * Lists the machines that should mount this _LFS_ `read-write`.

The example above would result in the following _PFS_ entries in ```/etc/fstab``` only on the _SAI_:
```
some-storage001.stor.local:/ifs/isilon11     /mnt/isilon11    nfs4      defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
10.0.0.203@tcp12:10.0.0.204@tcp12:/lusty2    /mnt/lusty2      lustre    defaults,_netdev,flock                          0 0
```

#### lfs_mounts

The **lfs_mounts** variable lists all Logical File Systems, which provide the user's perspective of the data. Per _LFS_:

 * **lfs**: a label for this _LFS_
   * **env[0-9]{2}** _LFS-ses_:
      * Label is used as the mountpoint in **/mnt/** on the _Deploy Admin Interface (DAI)_.
      * On all other machines the mountpoint is always **/apps** and therefore:
      * A specific machine can only mount one instance of this _LFS_ type.
   * **home** _LFS-ses_:
      * Mountpoint is always **/home**.
      * A specific machine can only mount one instance of this _LFS_ type.
   * **dat[0-9]{2}**, **rsc[0-9]{2}**, **tmp[0-9]{2}** and **prm[0-9]{2}** _LFS-ses_:
      * Mountpoint per group is always **/groups/{{ group }}/{{ lfs }}**.
      * Groups may have access to multiple **dat[0-9]{2}**, **rsc[0-9]{2}**, **tmp[0-9]{2}** or **prm[0-9]{2}** _LFS-ses_.
 * **pfs**: a label for the _PFS_ that holds this _LFS_.
   * Used to lookup the technical specs required by the ```mount``` command in the ```pfs_mounts``` variable.
   * Hence for every label mentioned here there must be an entry in the list of ```pfs_mounts```.
 * **type**:
   * Optional attribute only for **dat[0-9]{2}**, **rsc[0-9]{2}**, **tmp[0-9]{2}** and **prm[0-9]{2}** _LFS-ses_.
   * Only possible value is `bind`.
   * When this is specified the complete PFS will be mount first and
   * Next this role will create `bind` mounts per group.
   * This is a workaround to create less _normal_ mounts and required when using `lustre` file systems to prevent running out of Lustre IDs.
 * **ro_machines**:
   * Lists the machines that should mount this _LFS_ `read-only`.
   * A cluster may use multiple _LFS-ses_ of the same type for different machines to distribute the IO load.
 * **rw_machines**:
   * Lists the machines that should mount this _LFS_ `read-write`.
   * A cluster may use multiple _LFS-ses_ of the same type for different machines to distribute the IO load.
 * **groups**: Only for **dat[0-9]{2}**, **rsc[0-9]{2}**, **tmp[0-9]{2}** and **prm[0-9]{2}** _LFS-ses_.
   * Lists the groups that can use this _LFS_.
   * Subfolders with correct permissions will be created automagically for the specified groups.
 
The example above would result in the following _LFS_ entries in ```/etc/fstab```:
 * on the _SAI_:
   ```
   some-storage001.stor.local:/ifs/cluster/isilon11/home    /home nfs4 defaults,_netdev,vers=4.0,noatime,nodiratime 0 0
   ```
 * on the _DAI_:
   ```
   some-storage001.stor.local:/ifs/isilon11/home                         /home                         nfs4    defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   some-storage001.stor.local:/ifs/isilon11/env08                        /mnt/env08                    nfs4    defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   some-storage001.stor.local:/ifs/isilon11/groups/ateam/tmp08           /groups/ateam/tmp08           nfs4    defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   some-storage001.stor.local:/ifs/isilon11/groups/colla/tmp08           /groups/colla/tmp08           nfs4    defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   some-storage001.stor.local:/ifs/isilon11/groups/production/tmp08      /groups/production/tmp08      nfs4    defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   some-storage001.stor.local:/ifs/isilon11/groups/cool-project/tmp08    /groups/cool-project/tmp08    nfs4    defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   ```
 * on the _UI_:
   ```
   some-storage001.stor.local:/ifs/isilon11/home                          /home                         nfs4      defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   some-storage001.stor.local:/ifs/isilon11/env08                         /apps                         nfs4      defaults,_netdev,vers=4.0,noatime,nodiratime,ro 0 0
   some-storage001.stor.local:/ifs/isilon11/groups/ateam/tmp08            /groups/ateam/tmp08           nfs4      defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   some-storage001.stor.local:/ifs/isilon11/groups/colla/tmp08            /groups/colla/tmp08           nfs4      defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   some-storage001.stor.local:/ifs/isilon11/groups/production/tmp08       /groups/production/tmp08      nfs4      defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   some-storage001.stor.local:/ifs/isilon11/groups/cool-project/tmp08     /groups/cool-project/tmp08    nfs4      defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   some-storage001.stor.local:/ifs/isilon11/groups/ateam/prm05            /groups/ateam/prm05           nfs4      defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   some-storage001.stor.local:/ifs/isilon11/groups/production/prm05       /groups/production/prm05      nfs4      defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   10.0.0.203@tcp12:10.0.0.204@tcp12:/lusty2/groups/colla/prm03           /groups/colla/prm03           lustre    defaults,_netdev,flock                          0 0
   10.0.0.203@tcp12:10.0.0.204@tcp12:/lusty2/groups/production/prm03      /groups/production/pmr03      lustre    defaults,_netdev,flock                          0 0
   10.0.0.203@tcp12:10.0.0.204@tcp12:/lusty2/groups/cool-project/prm03    /groups/cool-project/prm03    lustre    defaults,_netdev,flock                          0 0
   ```
 * on a _compute node_:
   ```
   some-storage001.stor.local:/ifs/isilon11/home                         /home                         nfs4    defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   some-storage001.stor.local:/ifs/isilon11/env08                        /apps                         nfs4    defaults,_netdev,vers=4.0,noatime,nodiratime,ro 0 0
   some-storage001.stor.local:/ifs/isilon11/groups/ateam/tmp08           /groups/ateam/tmp08           nfs4    defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   some-storage001.stor.local:/ifs/isilon11/groups/colla/tmp08           /groups/colla/tmp08           nfs4    defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   some-storage001.stor.local:/ifs/isilon11/groups/production/tmp08      /groups/production/tmp08      nfs4    defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   some-storage001.stor.local:/ifs/isilon11/groups/cool-project/tmp08    /groups/cool-project/tmp08    nfs4    defaults,_netdev,vers=4.0,noatime,nodiratime    0 0
   ```
   ```