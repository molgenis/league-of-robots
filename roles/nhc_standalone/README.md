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

## configuration of `check_journalctl`
Example stucture for `check_journalctl` configuration in `group_vars/{stack}/vars.yml`:

```yaml
nhc_journalctl_checks:
  deploy_admin_interface:
    - user: "root"
      lookback_min: 15
      tag: "CROND"
      pattern: "FAILED|error"
  chaperone:
    - user: "umcg-ogm-dm"
      lookback: 10
      tag: "OGM"
      pattern: "FAILED|exit code|backup FAILED"
```

- `group` defines the Ansible inventory group.
- `user` specifies the user to filter on.
- `lookback_min` defines how far back to search in logs.
- `tag` specifies the journalctl tag (`journalctl -t`).
- `pattern` defines the error pattern to match.

Make sure `lookback_min` matches how often the check runs.

## check_journalctl in NHC config

 Generate NHC journalctl checks only for the machines listed in the corresponding "machines" grouping. The defined checks in the `group_vars/vars.yml` end up in the `nhc_standalone.conf` as follows:
  
```text
* || check_journalctl "root" 15 CROND "FAILED|error"
* || check_journalctl "umcg-ogm-dm" 15 OGM "FAILED|exit code|backup FAILED"
```

The check reports a failure when a matching error is found within the configured lookback window. Logfiles are stored in `/run/nhc/nhc_standalone.*`

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
