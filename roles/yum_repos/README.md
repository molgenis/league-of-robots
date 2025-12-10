# yum_repos: Manage yum/dnf repos.

This role can be used to manage all `yum` / `dnf` repos on machines,
which need to be linked to official/public repos directly.

Do **not** use this role to link a machine to self-hosted snapshots of repos
or systems like _Pulp_, which can be used to _freeze_ repos.
For _Pulp_ see the `pulp_client` role instead.

To make a repository locally (on the machine itself) check `yum_local` role instead.

This role will manage all `yum` / `dnf` repos on hosts; This means:
 * Apply configs and GPG key files for repos whose repo ID is listed in the `managed_yum_repos` variable for a machine.  
   See ```group_vars/all/vars.yml``` for defaults.
 * The repo ID listed in `managed_yum_repos` is used to lookup the config for the repo listed in the `yum_repos` variable.  
   See ```group_vars/all/vars.yml``` for defaults.  
   This allows setting `managed_yum_repos` to a subset of all repos from `yum_repos` for specific machines.
 * Unspecified options for repos listed in the `managed_yum_repos` variable will be left untouched.
 * **Delete** the `/etc/yum.repos.d/*.repo` repo config file on a machine,
   when not a single repo listed in that file is listed in the `managed_yum_repos` variable.
   (Except for repos in the `local_yum.repo` file, which may be created by the `yum_local` role and which is skipped by this role.)
 * Repos will remain untouched/preserved "as is", when at least one other repo listed in the same `*.repo` config file
   is listed in `managed_yum_repos` and therefore managed by this role.

Note:
* We do NOT use `ansible.builtin.yum_repository` any longer as there is no `ansible.builtin.dnf_repository` equivalent for newer distros.
* We do NOT install the _EPEL_ repo using the `epel-release` RPM with `ansible.builtin.package`,
  because on RedHat >= 8.x it will install `*.repo` files with broken links and broken paths to GPG key files.

#### Example code snippets for the `managed_yum_repos` and `yum_repos` variables:

In the example below
* The dict key `rocky9` must match the value of `os_distribution` in `group_vars/{{ stack_name }}/vars.yml`.  
  E.g. `os_distribution: 'rocky9'`
* The `baseos*` repos are examples of repos for which many settings are taken/used "as is" and left untouched.  
  This allows to OS the provide updates for the `baseurl`, `metalink` or `mirrorlist` options.
* The `epel*` repos are examples of repos for which everything is configured
  and for which the GPG key file will be downloaded from `gpgkeysource` and imported with `ansible.builtin.rpm_key`.

```
#
# Example to list which repos should be managed by this role on machines by listing all repo IDs explicitly.
#
managed_yum_repos:
  rocky9:
    - baseos
    - baseos-debug
    - baseos-source
    - epel
    - epel-debuginfo
    - epel-source
    - rsyslog
#
# Same as above, but instead of listing all repo IDs explicitly,
# we now use tags to select 2 groups/collections of repos that share the same tag
# and append 1 explicit repo ID to that list.
#
managed_yum_repos:
  rocky9: "{{ yum_repos['rocky9']
              | selectattr('tags', 'defined')
              | selectattr('tags', 'contains', 'core')
              | map(attribute='id')
              | union(yum_repos['rocky9']
                      | selectattr('tags', 'defined')
                      | selectattr('tags', 'contains', 'epel')
                      | map(attribute='id'))
              | union(['rsyslog']) }}"
yum_repos:
  rocky9:
    - file: rocky.repo
      id: baseos
      enabled: 1
      gpgcheck: 1
      tags:
        - distro
        - core
    - file: rocky.repo
      id: baseos-debug
      enabled: 0
      tags:
        - distro
        - core
    - file: rocky.repo
      id: baseos-source
      enabled: 0
      tags:
        - distro
        - core
    - file: epel.repo
      id: epel
      name: 'Extra Packages for Enterprise Linux 9 - $basearch'
      metalink: 'https://mirrors.fedoraproject.org/metalink?repo=epel-9&arch=$basearch&infra=$infra&content=$contentdir'
      enabled: 1
      gpgcheck: 1
      gpgkeysource: 'https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-9'
      tags:
        - epel
    - file: epel.repo
      id: epel-debuginfo
      name: 'Extra Packages for Enterprise Linux 9 - $basearch - Debug'
      metalink: 'https://mirrors.fedoraproject.org/metalink?repo=epel-debug-9&arch=$basearch&infra=$infra&content=$contentdir'
      enabled: 0
      gpgcheck: 1
      gpgkeysource: 'https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-9'
      tags:
        - epel
    - file: epel.repo
      id: epel-source
      name: 'Extra Packages for Enterprise Linux 9 - $basearch - Source'
      metalink: 'https://mirrors.fedoraproject.org/metalink?repo=epel-source-9&arch=$basearch&infra=$infra&content=$contentdir'
      enabled: 0
      gpgcheck: 1
      gpgkeysource: 'https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-9'
      tags:
        - epel
    - file: rsyslog.repo
      id: rsyslog
      name: 'rsyslog v8 (from Adiscon) for EPEL 9.'
      baseurl: 'https://rpms.adiscon.com/v8-stable/epel-9/$basearch'
      enabled: 1
      gpgcheck: 1
      gpgkeysource: 'https://rpms.adiscon.com/RPM-GPG-KEY-Adiscon'
```
