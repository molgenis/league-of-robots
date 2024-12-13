# update role

This role manages updates via `yum` or `dnf`.
It will update all packages except for `slurm*,irods*`, which are version locked
and can only be updated by dedicated roles for configuring those services.

## Reboots

This role will use the needs-restarting utility in either the `yum` or the `dnf` variant
to determine if the machine needs to be rebooted for example for a kernel update.
This role will always check the need for a reboot and reboot if needed.

## Automatic updates

By default a _cron job_ for `yum` or _systemd timer_ for `dnf` is installed to enable automatic updates
and automatic reboots too if necesssary. When a machine should not receive automatic updates, then you can set
```
autoupdate_enabled: false
```
in `group_vars` or overrule it for a specific host in the `static_inventory`.
