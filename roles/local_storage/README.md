# local_storage role

This role mounts local file systems and supported both mounting devices as well as bind mounts.
A folder for the _mount point_ will be created automatically,
but the location where the _mount point_ is created must already exist.
Hence the order of of mounts may be relevant;
for example when a bind mount must be created in a location on an extra file system that must be mounted first.

The `local_storage` role uses two variables that must be configured in the `group_vars` or `static_inventory`:

* **`local_mounts`**: List of devices to mount (or folders to bind mount). (**Required**)
* **`local_mount_subfolders`**: List of subfolders to create on the local mounts. (**Optional**)


## Defining file systems to be mounted

Examples below for:
 * Mounting a real device first
 * Then mounting a sub folder from that device as bind mount elsewhere
 * And finally mounting a Virtual Drive (VD) from a DELL PERC RAID controller,
   which may be detected as a random device name after (re)boot.

```yaml
  local_mounts:
    - mount_point: '/staging'
      device: 'LABEL=staging'
      mounted_owner: root
      mounted_group: root
      mounted_mode: '0755'
      mount_options: 'defaults,noatime,nofail'
      type: xfs
    - mount_point: '/local'
      device: '/staging/slurm'
      mounted_owner: root
      mounted_group: root
      mounted_mode: '0755'
      mount_options: 'bind,nofail'
      type: none
    - mount_point: "{{ slurm_local_scratch_dir }}"
      device: dynamic  # A value must be present in order to update it on-the-fly during role execution.
      label: local
      perc_controller: 0
      perc_virtual_drive: 239
      mounted_owner: root
      mounted_group: root
      mounted_mode: '0755'
      mount_options: >-
        rw,relatime
        {%- if ansible_facts['os_family'] == 'RedHat' and
               ansible_facts['distribution_major_version'] >= '8' -%}
          ,nofail,x-systemd.device-timeout=10
        {%- endif -%}
      type: ext4
```

Note:
 * The `device` will be formatted if it isn't formatted yet.
 * The `device` should be listed the same way it is listed in `/etc/fstab`
   and can be identified using a `LABEL`, an `UUID` or a path like `/dev/vdb`.
 * Specifically for PERC RAID controllers: we cannot reliably know the `device` up front
   as it can change after each (re)boot with modern Linux kernels.
   Therefore `device` must be set to `dynamic` and the `perc_controller` and `perc_virtual_drive`
   number must be defined; these will be used by this role to detect the `device` dynamically.
   Next that `device` can be formatted and labelled with `label`,
   which can then be used to mount the file system.

## Defining subfolders to be created on the mounted file systems

Optionally the `local_storage` role can create subfolders on the mounted file systems.
Below is an example for a GD stack:

```yaml
local_mount_subfolders:
  - mount_point: '/groups'
    machines: "{{ groups['data_transfer'] }}"
    folders:
      - rel_paths:
          - "{{ data_transfer_only_group }}"
        mode: '2750'
        owner: root
        group: "{{ data_transfer_only_group }}"
      - rel_paths:
          - umcg-genomescan
          - umcg-gst
        mode: '2770'
        owner: root
  - mount_point: '/staging'
    machines: "{{ groups['dragen'] }}"
    folders:
      - rel_paths:
          - development
        mode: '0770'
        owner: umcg-atd-ateambot
        group: umcg-atd
      - rel_paths:
          - slurm
        mode: '0755'
        owner: root
        group: root
```

Note: 
 * Specifying the `group` is optional. When left out the `group` will default to the same value as the item from `rel_paths`.
   This is useful when `rel_paths` contains a list of subfolders for groups, which should all be put in their own `group`.
