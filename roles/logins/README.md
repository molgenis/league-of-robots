# Cgroups limitation

Systemd manages all the users slices. They are in located under `user.slice`.
Cgroups v2 can be managed separately, but users cannot be moved into those after
systemd already manages user (and breaking this functionality would not be a
smart approach).

Therefore we manage total user resource limitation on the individual uses slice.

This is done automatically after user is loged into the system via ssh.

A line of

```
     session    optional     pam_exec.so /etc/security/limitedusers.sh
```

is added to `/etc/pam.d/sshd`. A file `/etc/security/limitedusers.sh` calls the

`systemctl` and sets the user's .slice to limit CPU and RAM limits.

In this way users get limited resources ONLY when login via ssh.

Slurm is not managed under `user.slice`, but has jobs placed under `system.slice`, like
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

TLDR: Users slice limits are NOT same as slurm slice limits.

Users that get elevated permissions, are still on the SAME slice limitation as
user that executed su or sudo command.
