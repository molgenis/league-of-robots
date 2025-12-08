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
 * **Delete** the config for any repo not listed in the `managed_yum_repos` variable.
 * Unspecified options for repos listed in the `managed_yum_repos` variable will be left untouched.

Note:
* We do NOT use `ansible.builtin.yum_repository` any longer as there is no `ansible.builtin.dnf_repository` equivalent for newer distros.
* We do NOT install the _EPEL_ repo using the `epel-release` RPM with `ansible.builtin.package`,
  because on RedHat >= 8.x it will install `*.repo` files with broken links and broken paths to GPG key files.

#### Example code snippet for the ```yum_repos``` variable:

In the example below
* The dict key `rocky9` must match the value of `os_distribution` in `group_vars/{{ stack_name }}/vars.yml`.  
  E.g. `os_distribution: 'rocky9'`
* The `baseos*` repos are examples of repos for which many settings are taken/used "as is" and left untouched.  
  This allows to OS the provide updates for the `baseurl`, `metalink` or `mirrorlist` options.
* The `epel*` repos are examples of repos for which everything is configured
  and for which the GPG key file will be downloaded from `gpgkeysource` and imported with `ansible.builtin.rpm_key`.

```
managed_yum_repos:
  rocky9:
    - baseos
    - baseos-debug
    - baseos-source
    - epel
    - epel-debuginfo
    - epel-source
yum_repos:
  rocky9:
    - file: rocky.repo
      id: baseos
      enabled: 1
      gpgcheck: 1
    - file: rocky.repo
      id: baseos-debug
      enabled: 0
    - file: rocky.repo
      id: baseos-source
      enabled: 0
    - file: epel.repo
      id: epel
      name: 'Extra Packages for Enterprise Linux 9 - $basearch'
      metalink: 'https://mirrors.fedoraproject.org/metalink?repo=epel-9&arch=$basearch&infra=$infra&content=$contentdir'
      enabled: 1
      gpgcheck: 1
      gpgkeysource: 'https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-9'
    - file: epel.repo
      id: epel-debuginfo
      name: 'Extra Packages for Enterprise Linux 9 - $basearch - Debug'
      metalink: 'https://mirrors.fedoraproject.org/metalink?repo=epel-debug-9&arch=$basearch&infra=$infra&content=$contentdir'
      enabled: 0
      gpgcheck: 1
      gpgkeysource: 'https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-9'
    - file: epel.repo
      id: epel-source
      name: 'Extra Packages for Enterprise Linux 9 - $basearch - Source'
      metalink: 'https://mirrors.fedoraproject.org/metalink?repo=epel-source-9&arch=$basearch&infra=$infra&content=$contentdir'
      enabled: 0
      gpgcheck: 1
      gpgkeysource: 'https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-9'
```
