# Cgroups limitation

## PAM

Systemd manages all users slices. These slices are located under main `user.slice`.
Cgroups v2 can be managed separately, but users still cannot be moved into those
because systemd already exclusively manage user slice.

Therefore we manage user's resource availability, with help of systemd slice
modification. Limitation on the slice is per individual user.

This is done with helper script, that gets automatically executed every time a
new user logs into the system via ssh.

This is done with the following line in the `/etc/pam.d/sshd` file

```
     session    optional     pam_exec.so /etc/security/limitedusers.sh
```

A script `/etc/security/limitedusers.sh` is called at the login, but upon error
the login stil gets processed.

## Script

The script uses systemd's command line tool `systemctl` to modify the CPU and RAM limit of the user's slice. 

Script controls users that

 - have UID > 1000
 - are not part of the admin group

Users that get elevated permissions, are still on the SAME slice limitation as
user that executed su or sudo command.

## systemd control groups vs slurm

TLDR: Users slice limits are NOT same as slurm slice limits.

Slurm has job placed under `system.slice`, and the resources are managed there.
It is not managed under `user.slice`. Therefore `pam.d/sshd` is not conflicting
with the `slurm` jobs.

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

## Memory control

Memory of the cgroups is limited to whatever is set as the `memory.max` value. But
note that this field is limiting only resident set size of the memory, therefore
it will not (!) limit memory consumption of the additional swapped space.

Simply put: if there is limit of `memory.max=100MB`, user can still use 1G of
total memory, where 100M is placed in memory and the rest of the 900M will be
placed in swap.

## More information

 - https://systemd.io/CONTROL_GROUP_INTERFACE/
 - https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html
 - https://www.freedesktop.org/software/systemd/man/latest/pam_systemd.html
 - https://man.archlinux.org/man/pam_exec.8.en
 - https://man7.org/linux/man-pages/man8/pam_systemd.8.html
 - https://docs.kernel.org/admin-guide/cgroup-v2.html


