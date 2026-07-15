# Basic security

## Role Variables

See `defaults/main.yml` for variables and their defaults.

**It is _very_ important that you quote the 'yes' or 'no' values. Failure to do so may lock you out of your server.**

Hence these values are not "YAML" booleans and you cannot use `true` or `false`.
These values must end up in the sshd.conf as `yes` or `no` and therefore must be treated as strings in YAML.

- The state of the SSH daemon. Typically this should remain `started`.
  ```
    basic_security_sshd_state: started
  ```

- The state of the `restart ssh` handler. Typically this should remain `restarted`.
  ```
    basic_security_ssh_restart_handler_state: restarted
  ```

- Whether to install/enable `fail2ban`. You might not want to use fail2ban if you're already using some other service for login and intrusion detection (e.g. [ConfigServer](http://configserver.com/cp/csf.html)).
  ```
    basic_security_fail2ban_enabled: true
  ```

- The name of the template file used to generate `fail2ban`'s configuration.
  ```
    basic_security_fail2ban_custom_configuration_template: "jail.local.j2"
  ```

## Posix dependency

The `fail2ban` on newer RHEL/Alma/Rocky versions >=9.6 now has a dependency on the `esmtp` package.
This is a newer lighter SMTP client version and it is used as a default SMTP client.
The `alternatives --display mta` shows it is being used. This means that it will be used for all emails.
But since we don't have email relay configured on our systems, and `esmtp` does not work with
local mail delivery to `/var/mail/[user]`, which is a symlink to `/var/spool/mail/[user]`,
any email delivery will fail. But it will also log EVERY failed attempt - filling logs by
writing into systemd journal logs and `/var/log/messages`. And after a disk is full the server will
fail.
This roles installs `postfix`, and keeps the default values, which works
and is compatible with another role in LoR depending on `postfix`.
