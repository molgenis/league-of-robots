# Ansible Role: slurm

This role configures Slurm on both management machines and compute nodes.

## Custom RPMs

We use custom, patched RPMs for Slurm;
see [../documentation/Patching_Slurm.md](../documentation/Patching_Slurm.md) for details.
The custom RPMs must be added to a repo for custom packages on the Pulp server used by the _stack_.
To prevent this `slurm` role from accidentally installing the wrong, not patched slurm version,
the custom versions use a suffix in the version number,
which is defined in the `group_vars` for a _stack_ using the `slurm_version` variable.
E.g.
```yaml
slurm_version: 24.11.4-1.el9.umcg
```

## Slurm accounts, users, groups and their sponsors

Slurm uses _accounts_ to manage shares of resources.
The _shares_ in Slurm are a virtual currency that is used to determine a job's priority;
When a Slurm _account_ recently used less than its share,
then jobs submitted by that account will get a higher prio
and when a Slurm _account_ recently used more resources then what it is entitled to based on its shares,
then jobs submitted by that account will get a lower priority.
Note that _fair share_ based on slurm _shares_ and recent resource usage is not the only factor in determining job prio,
which is also influenced by accrued queue time and Quality of Service (QoS) level.

The Slurm _accounts_ are not to be confused with a user's login _account_.
Slurm _accounts_ can be nested and a user has an _association_ to a Slurm _account_.
This also means users can have an association to multiple Slurm _accounts_.

#### Slurm version < 24.11.x

We use:
```
users: [shares=1]
  |- groupA: [shares=parent]
  |    |- userX [shares=1]
  |    `- userY [shares=1]
  |- groupB [shares=parent]
  |    |- userX [shares=1]
  |    `- userZ [shares=1]
  `- groupC [shares=parent]
       `- userZ [shares=1]
```
This means all users are treated equally; they have the same amount of shares: 1.
The group based slurm accounts are only use to monitor how much resources are consumed by the groups. 
When a user submits a job, the Slurm `job_submit.lua` plugin
 * automatically detects the group based on the path where the submitted job script is located on the file system.
 * automatically creates a Slurm _account_ for the group if it did not already exist
 * automatically associates the user to that Slurm group _account_

#### Slurm version >= 24.11.x

We use something like this:
```yaml
users: [shares=1]
  |- sponsor1 [shares=250]
  |    |- groupA: [shares=parent]
  |    |    |- userX [shares=1]
  |    |    `- userY [shares=1]
  |    |- groupB [shares=parent]
  |    |    |- userX [shares=1]
  |    |    `- userZ [shares=1]
  `- sponsor2 [shares=12]
       `- groupC [shares=parent]
            `- userZ [shares=1]
```
This means groups are not treated equally; they are supported by a sponsor with a certain amount of slurm shares.
All groups and users that are a member of the the same sponsor account are treated equally;
Groups inherit the shares from the sponsor and users all have the same amount of shares: 1.
The group based slurm accounts are only use to monitor how much resources are consumed by the groups within the sponsor's account.
When a user submits a job, the Slurm `job_submit.lua` plugin
 * automatically detects the group based on the path where the submitted job script is located on the file system.
 * checks if a Slurm _account_ for the group exist in the slurm _account_ of the sponsor;
   If it does not, then it cannot be created automatically and the Slurm `job_submit.lua` plugin will reject the job.
 * automatically associates the user to the Slurm group _account_ if necessary.

The Slurm _accounts_ of the groups and sponsors are created/updated when the _slurm_ role is (re)deployed
using data structures in the stack's _group\_vars_ like this:
```yaml
sponsors:
  - name: sponsor1
    slurm_shares: 250
  - name: sponsor2
    slurm_shares: 12
regular_groups:
  # Note, for chaperone machines this is controlled in the static_inventories.
  - "{{ data_transfer_only_group }}"  # Not used for Slurm config
  - "{{ envsync_group }}"             # Not used for Slurm config
  - "{{ functional_admin_group }}"    # Not used for Slurm config
  - 'groupA'
  - 'groupB'
  - 'groupC'
group_sponsors:
  groupA: sponsor1
  groupB: sponsor1
  groupC: sponsor2
```
