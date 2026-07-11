# lustre_client role

This role can install the _Lustre_ client RPM packages and configure `lnet` (the Lustre network).

## Lustre RPMs

The Lustre client is a kernel module, which must be recompiled for every new kernel
and hence also for each kernel security update. There are two versions:

1. The *kmod* packages contain a precompiled client kernel module compatible with specific kernels.
1. The *DKMS* packages, which provide _Dynamic Kernel Module Support_.

We use the *DKMS* flavor, which will detect a new kernel on (re)boot and
will automatically try to recompile het Lustre kernel module for that new kernel.
This gives a client a chance of having a functional Lustre client after a kernel update was installed.
In practice however the Lustre code will often break when a kernel is updated and then the compilation will fail.
Also note that (re)compiling the Lustre kernel module can result in long (re)boot times.

#### Patched / custom / beta Lustre RPMs

In many cases we need newer RPMs for bug fixes and other patches.
When this is the case we need to:

 * Make sure this role was already (partially) deployed on a _Deploy Admin Interface machine (DAI)_ in order to install all dependencies.
 * Fetch the Lustre source code on the _DAI_
 * Patch the source code where necessary (see below)
 * Compile code and create RPMs with instructions from  
   lustre-client-dkms: https://wiki.lustre.org/Compiling_Lustre#Lustre_Client_(DKMS_Packages_only)  
   lustre-client:      https://wiki.lustre.org/Compiling_Lustre#Lustre_Client_(All_other_Builds)
 * The builds will produce several RPMs, but we need only two:
   * `lustre-client-dkms-[version].el9.noarch.rpm`: contains the Lustre DKMS code in order to compile the kernel module.
   * `lustre-client-[version].el9.x86_64.rpm`:      contains the precompiled client-side lustre tools like `lctl`.
   Add these two custom RPMs to the `cpel` repo on our (Pulp) repo servers.
 * (Re)run this role to install the RPMs from the (Pulp) repo servers.

#### For EL 9.3 we need a patched Lustre >= 2.15.4, because Lustre 2.15.3 will no longer compile with DKMS.

At the time this was written 2.15.4 was not yet released and we need to
 * Fetch the source code for 2.15.4-RC2
 * Patch that to remove the dependency on python2, which is not available in EL 9.x
   Simply change "#!/usr/bin/env python2" to "#!/usr/bin/env python3" in contrib/scripts/branch_comm
   That script is only used to manage the source code in git and not used by Lustre itself: we do not need it.
 * Use the procedure above to compile `lustre-*2.15.4_RC2-1.el9.*.rpm` RPMs.

#### For EL 9.4 we need Lustre >= 2.15.5, because Lustre 2.15.4 will no longer compile with DKMS.

At the time this was written 2.15.5 was not yet released and we need to
 * Fetch the source code for 2.15.5-RC1
 * Use the procedure above to compile `lustre-*2.15.5_RC1-1.el9.*.rpm` RPMs.

#### For EL >= 9.5 we need Lustre >= 2.15.6, because Lustre 2.15.5 will no longer compile with DKMS.

At the time this was written 2.15.6 was not yet released and we need to
 * Fetch the source code for 2.15.6-RC1
 * Use the procedure above to compile `lustre-*2.15.6_RC1-1.el9.*.rpm` RPMs.
Update: a newer kernel update in EL 9.5 broke the 2.15.6 GA release; we need to:
 * Fetch the source code for the 2.15.x branch containing 2.15.6
   and then same additional patches back ported on top of that:
   * For issue see: https://jira.whamcloud.com/browse/LU-18085
   * For patch set description see: https://review.whamcloud.com/c/fs/lustre-release/+/57007
   * Fetch the "snapshot" from https://git.whamcloud.com/?p=fs%2Flustre-release.git;a=commit;h=a71369eb9cb0aa89ede41cb01b2cd9cdcd8e9680
 * Update build number 1 -> 2.
    * In `lustre.spec.in` change:
          ```Release: 1%{?dist}```
      into:
          ```Release: 2%{?dist}```
    * In `lustre-dkms.spec.in` change:
          ```%define buildid 1```
      into:
          ```%define buildid 2```
 * Execute:
      ```autogen.sh```
 * Use the procedure above to compile ```lustre-*2.15.6-2.el9.*.rpm``` RPMs.

#### For EL >= 9.8 we need Lustre >= 2.15.8, because Lustre 2.15.8 will no longer compile with DKMS.

Kernel security updates in EL 9.8 for the high impact Bad Epoll & Janusacape LPE bugs broke the 2.15.8 release.
At the time this was written 2.15.9 was not yet released and we need to:
 * Fetch the source code for 2.15.8 from https://github.com/lustre/lustre-release/releases/tag/2.15.8
 * The macro `from_timer()` was renamed to `timer_container_of()` and this change was backported to older kernels by RedHat,
   but the Lustre 2.15.8 release has not been updated for that change yet.
   The main Lustre branch was updated for many changes including this one, but this has not yet been back ported to Lustre 2.15.x.
   * For issue see: https://jira.whamcloud.com/browse/LU-20071
   * For patch set description see: https://review.whamcloud.com/c/fs/lustre-release/+/65797
 * Download that path set as a file that can be applied with the `patch` command.
   * Find the download button on the patch set description page and download `c131e65.diff.zip`
   * Unzip to get `c131e65.diff`
 * Apply the patch
      ```
      tar -xvzf lustre-release-2.15.8.tar.gz
      cd lustre-release-2.15.8
      patch -p1 < ../c131e65.diff
      ```
 * Update build number 1 -> 2.
    * In `lustre.spec.in` change:
          ```Release: 1%{?dist}```
      into:
          ```Release: 2%{?dist}```
    * In `lustre-dkms.spec.in` change:
          ```%define buildid 1```
      into:
          ```%define buildid 2```
 * Execute:
      ```bash ./autogen.sh```
 * Use the procedure above to compile ```lustre-*2.15.8-2.el9.*.rpm``` RPMs.

## Configuring lnet

The majority of the _Lustre network (lnet)_ can be configured automatically and/or use defaults,
but we do need to specify which **network interface** to use for which **lnet**.
This is accomplished by adding an `lnet` key to the relevant networks from the `host_networks`
for machines on which we need Lustre mounts.
E.g. for a machine named `{{ stack_prefix}}-node-c01`,
which uses _network interface_ ```eth1``` with an IP from the `vlan1068` network for _lnet_ `tcp20`,
you would specify this in `static_inventory/[stack_name].yml`:
```yaml
---
all:
  children:
    .......
    compute_node:
      children:
        .......
        cpu_vm:  # Must be item from {{ slurm_partitions }} variable defined in group_vars/{{ stack_name }}/vars.yml
          hosts:
            {{ stack_prefix}}-node-c01:
              .......
              host_networks:
                - name: other_network
                  .......
                - name: vlan1068
                  security_group: "{{ stack_prefix }}_storage"
                  nmstate_interface:
                    name: eth1
                  lnet:
                    name: tcp20
                - name: another_network
                  .......
              .......
...
```
