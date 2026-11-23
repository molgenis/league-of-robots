# nhc_standalone role

This role installs [Node Health Check](https://github.com/mej/nhc) (NHC) as a _standalone_ application.
That means _NHC_ is not executed by a resources manager like _Slurm_.
For deployment of _NHC_ on _Slurm clients_ see the `slurm` role instead.

# nhc_standalone custom add-ons

nhc_standalone was extended with additional `check_journalctl` check and a custom `nhc-wrapper` with Slack notifications.

## Prerequisites
- Deployment of the role is limited to a list of inventory `groups` specified in:
  `single_role_playbooks/nhc_standalone.yml`
- Slack notification channels are available and webhooks are configured for the custom `nhc-wrapper`.

## Configuration

NHC_standalone roles is deployed to the specified target hosts via:
     `single_role_playbooks/nhc_standalone.yml`

### configuration of `check_journalctl`

Example stucture for `check_journalctl` configuration in `group_vars/{stack}/vars.yml`:

```
nhc_extras:
  [hostname_inventory or group]:
    - '[nhc_function_name] [arguments]'
    - ...
```
for example

```
nhc_extras:
  ldap_server:
   - 'check_journalctl "" "15" "CROND" ""'
   - 'check_systemctl_running slapd-ltb.service'
```

where arguments `check_journalctl` are in format

1. `user` [username] specifies the user to filter on, can be only one user. Can be also empty to match logs of all users.
2. `lookback_min` [number] defines how far back to search in logs.
3. `tag` [string] specifies the journalctl tag (`journalctl -t`).
4. `pattern` [strings|separated|by|pipe|symbol] defines the error pattern to match
    Either of the patterns is being looked for (OR).
    By DEFAULT if there are no patterns provided, the script will look for
    `FAILED|status=[1-9]|exit code|segfault|fail|error` as defined in the `custom.nhc`

Make sure `lookback_min` matches how often the check runs.

Example

```text
* || check_journalctl "root" 15 ldap_backup ""
* || check_journalctl "root" 15 CROND "FAILED|error"
* || check_journalctl "umcg-ogm-dm" 15 OGM "FAILED|exit code|backup FAILED"
```

**Note: the function checks that `[user]` AND at least one of the `[PATTERNS]` match!**


### configuration of `check_systemctl_running`


```
    * || check_ps_service -u root -S -m 'sshd:' sshd
```

does not work for all services, as they are not executed with the `[service_name]:` format.

therefore `check_systemctl_running` function was added

```
nhc_extras:
  [inventory_hostname or group]:
   - 'check_systemctl_running slapd-ltb.service'
```

## NHC logs

The check reports a failure when a matching error is found within the configured lookback window.

Logfiles are stored in `/run/nhc/nhc_standalone.*`

## nhc-wrapper and Slack notifications

The custom `nhc-wrapper` based on the original  NHC version, but is extended with Slack notification functionality.  when the configured notification conditions are met `production` or `development` channels are notified.

The webhooks are configured in `group_vars/all/notification_webhooks.yml`: `slurm_notification_slack_webhook[stack_dtap_state]`

## Debugging

Run NHC in standalone debug mode:

```bash
/usr/sbin/nhc-wrapper -N -P nhc_standalone -D /run/nhc/ -X 15h -A "-a"
```

Inspect the deployed nhc_wrapper config to be sane:

```bash
cat /etc/nhc/nhc_standalone.conf
```

Inspect the NHC status output files:

```bash
cat /run/nhc/nhc_standalone.*
```
