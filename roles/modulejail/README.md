# modulejail role

`modulejail` is a single POSIX shell script that shrinks the kernel-module attack surface on Linux machines by
 writing a `modprobe.d` _blocklist_ containing every kernel module that
 * is not in use at the moment `modulejail` is executed and
 * which is not listed in a built-in _profile_ nor in an optional allowlist.

For details see:

 * https://github.com/jnuyens/modulejail
 * https://modulejail.com/
 * https://linuxsecurity.com/features/linux-kernel-module-hardening-modulejail

## Configuration

`modulejail_enforce` can be set to `false` (default) or `true`
 * `false`: will configure `modulejail` to only log module load events using `logger`, but will not block the loading of kernel modules.
 * `true`: will enforce the block list and log module load events using `logger`.

`modulejail_allowed_kernel_modules` is a list of kernel modules that must be added to an allow list,
so they will never get added to the block list when the module was not loaded at the time `modulejail` was executed.

## Monitoring

You can check what `modulejail` did using `journalctl`. E.g.:
```
journalctl -t modulejail --since '1 day ago'
```