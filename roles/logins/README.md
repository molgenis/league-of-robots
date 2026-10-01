# Cgroups limitation

## PAM

Systemd manages all users slices. These slices are located under main `user.slice`.
Cgroups v2 can be managed separately, but users cannot be moved into another slice hierarchy,
because `systemd` already exclusively manages user slices.

Therefore we manage user's resource availability by modifying systemd user slices.
Limitation on the slice is per individual user.
It is currently not possible to configure limits for specific groups of users.

User slice limits are applied using the `/etc/pam-script.d/limitedusers.sh` helper script,
that gets automatically executed every time a user logs into the system via a new ssh session.

This is done with the following line in the `/etc/pam.d/sshd` file

```
     session    optional     pam_exec.so /etc/pam-script.d/limitedusers.sh
```

In case there is an error in `/etc/pam-script.d/limitedusers.sh`, the login stil gets processed.

## Script limitedusers.sh

The script uses systemd's command line tool `systemctl` to modify the CPU and RAM limit of the user's slice. 

Script controls users that

 - have UID > 1000
 - are not part of the admin group

Users that gain elevated permissions by switching to another account using `su` or `sudo` are still on the *same* slice
and hence cannot escape the limits from their original login account.

You can inspect your own limits using `systemctl`:
```bash
systemctl show "user-$(id -u).slice" | fgrep CPUQuotaPerSecUSec=
systemctl show "user-$(id -u).slice" | fgrep MemoryMax=
```
or alternatively read the values from:
```bash
cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/cpu.max
cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/memory.max
```

## systemd control groups for slurm

TLDR: Users slice limits are NOT same as slurm slice limits.

Slurm has jobs placed under the `system.slice`, and the resources are managed there.
It is not managed under `user.slice`.
Therefore the limits configured by the `limitedusers.sh` script do not affect `slurm` jobs.

```
└─system.slice (#55)
  ...
  ├─slurmstepd.scope … (#7441)
  │ → user.invocation_id: 591b4001bb8144119c36bb401921be0e
  │ → user.delegate: 1
  │ ├─job_614 (#480003)
  │ │ └─step_0 (#480047)
  │ │   ├─slurm (#480135)
  │ │   │ └─1434237 slurmstepd: [614.0]
  │ │   └─user (#480091)
  │ │     └─task_0 (#480223)
  │ │       ├─1434243 /usr/bin/bash
  │ │       ├─1434285 systemd-cgls
  │ │       └─1434286 less
  │ └─system (#7493)
  │   └─33563 /usr/sbin/slurmstepd infinity
```

This can be nicely observed with `systemd-cgls`.

#### CPU control

CPU is limited using the `cpu.max` value.
Note that this limit contains two values
 * The first value is the amount of CPU time a user can consume
 * per the second value == the duration over which the usage is computed and over which the limit is enforced.
The values are in micro seconds.

When the CPU limit is set with `systemctl` a different unit is used: % of a CPU core.
E.g. 100% equals 1 CPU core, 250% equals 2,5 CPU core, etc.

When the CPU limit is reported with `systemctl` yet another unit is used: CPUQuotaPerSecUSec,
which stands for the the amount of time per 1 second of CPU time.

Example:
 * On system with 4 cores, `limitedusers.sh` will set the limit for CPU usage to 20% of total CPUs available.
 * `4 cores * 100% = 400% total CPU`
 * `4 cores *  20% =  80% CPU per user`
 * `cpu.max = 80000 100000`  
   So the period over which the limit is enforced is 100000 / 1000 = 100 milli seconds.  
   And the user's slice is 80000 / 1000 = 80 milli seconds per that period of 100 milli seconds.
 * `CPUQuotaPerSecUSec=800ms`  
   Note that this is by definition per second and therefore 10 times higher than the cpu.max limit,  
   which was reported per 100 milli seconds.

#### Memory control

Memory is limited using the `memory.max` value.
Note that this limit only applies to the _resident set size_ of the memory.
Therefore it will **not** limit memory consumption of additional swapped space nor of virtual memory.

Simply put: when `memory.max=100MB` a user can still use 1 GB memory total,
where 100 MB is placed in real memory and the rest of the 900 MB will be placed in swap space.

#### Local Disk Bandwidth control

If control groups is set to

    `IOAccounting=true IOReadBandwidthMax="/ 10M" IOWriteBandwidthMax="/ 10M"`

then a test file write

```
    dd if=/dev/zero of=/tmp/test bs=1M count=100 conv=fdatasync status=progress
    100+0 records in
    100+0 records out
    104857600 bytes (105 MB, 100 MiB) copied, 11.5569 s, 9.1 MB/s
```

can produce following output

```
   [root@portal ~]# systemd-cgtop -i
   Control Group                      Tasks   %CPU   Memory  Input/s Output/s
   user.slice                            15    1.5   160.7M       0B     9.8M
   user.slice/user-1088.slice             6      -   113.0M       0B     9.8M
   /                                    158    1.0   381.8M       0B     4.9M
   dev-hugepages.mount                    -      -    20.0K        -        -
   dev-mqueue.mount                       -      -    36.0K        -        -
   init.scope                             1      -    48.7M        -        -
   sys-fs-fuse-connections.mount          -      -     4.0K        -        -
   sys-kernel-config.mount                -      -     4.0K        -        -
```

## Script pam_screen_reaper.sh

The script is added to authselect's
 - `/etc/pam.d/postlogin`, to start at the first (multiplexed!) sshd connection, and to the
 - `/etc/pam.d/sudo` - to start at `sudo -u ...-dm/ateambot` sessions
It checks on the behalf of running user if there are older screen session or not.
The PAM script is the only viable option, since
 - /etc/ssh/sshrc is limited to ssh logins (and thus not sudo), and
 - /etc/profile is shell depended therefore it works only for bash, but not for zsh and other shells

## More information

 - https://systemd.io/CONTROL_GROUP_INTERFACE/
 - https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html
 - https://www.freedesktop.org/software/systemd/man/latest/pam_systemd.html
 - https://man.archlinux.org/man/pam_exec.8.en
 - https://man7.org/linux/man-pages/man8/pam_systemd.8.html
 - https://docs.kernel.org/admin-guide/cgroup-v2.html


