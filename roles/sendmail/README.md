# Sendmail

Is by default installed on the system, except if the variable `sendmail_configure` set to `false`.

## Why?

The fail2ban has a dependency on the package `esmtp`. This is a newer lighter SMTP client version.
But the newer versions of RHEL 9.6 detects this package, and it is used as a default SMTP client.
The `alternatives --display mta` shows it is being used. This means that it will be used for all emails.
But since we don't have configured mail relay server on the systems, and `esmtp` does not work with
local mail delivery (that is to `/var/mail/[user]` which is a symlink to `/var/spool/mail/[user]`),
therefore any email delivery will fail - after a trillion attmepts. It will also log EVERY failed
attempt into systemd journal logs (and `/var/log/messages`).
