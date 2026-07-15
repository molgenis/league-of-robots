# Converting a stack from Rocky to Alma

## Pulp repo server

##### On the Ansible controller: Copy new, patched Lustre client to repo server.

 * You can fetch the RPMs from another repo server of already converted stack.
 * The folder for custom RPMs on the repo server is still named `umcg-rocky9`:
   this may be confusing, but it works.

```
admin=''
jumphost=''
stack_prefix=''
rsync -v --rsync-path='sudo -u repoadmin rsync' lustre-client*2.15.8-2* ${admin}@${jumphost}+${stack_prefix}-repo:/admin/repoadmin/umcg-rocky9/
```

##### On the repo server: Destroy Alternate Content Sources (acs), remotes, repositories, etc. still pointing to Rocky (vault) repos.

```
ssh ${admin}@${jumphost}+${stack_prefix}-repo
```

```
sudo -u repoadmin bash
cd
. ./pulp-cli.venv/bin/activate
. ./pulp-init.bash
#
pulp rpm acs destroy --name extras-vault-acs
pulp rpm acs destroy --name crb-vault-acs
pulp rpm acs destroy --name appstream-vault-acs
pulp rpm acs destroy --name baseos-vault-acs
#
pulp rpm repository destroy --name baseos
pulp rpm repository destroy --name appstream
pulp rpm repository destroy --name crb
pulp rpm repository destroy --name extras
#
pulp rpm remote destroy --name baseos-vault-acs-remote
pulp rpm remote destroy --name appstream-vault-acs-remote
pulp rpm remote destroy --name crb-vault-acs-remote
pulp rpm remote destroy --name extras-vault-acs-remote
#
pulp rpm remote destroy --name baseos-remote
pulp rpm remote destroy --name appstream-remote
pulp rpm remote destroy --name crb-remote
pulp rpm remote destroy --name extras-remote
```

##### Switch back to your Ansible controller: Redeploy pulp server role to recreate repos.

```
ansible-playbook -u ${admin} single_role_playbooks/pulp_server.yml -l repo --start-at-task 'Manage repos.' 
```

##### Switch back to repo server: Update all repos on pulp server.

```
ssh ${admin}@${jumphost}+${stack_prefix}-repo
```

```
sudo -u repoadmin bash
cd
. ./pulp-cli.venv/bin/activate
. ./pulp-init.bash
#
pulp-sync-publish-distribute all
pulp-refresh-acs
```

## Update all other machines: both Pulp clients and machines linked directly to the Alma repos.

##### On the machines to be converted: fix dnf release version and run conversion script

```
sudo su
cd
echo '9' > /etc/dnf/vars/releasever
dnf -y install efibootmgr  # Was missing on some, but not all machines.
curl -O https://raw.githubusercontent.com/AlmaLinux/almalinux-deploy/master/almalinux-deploy.sh
bash ./almalinux-deploy.sh
```

```
#
# Examples of using Ansible ad hoc commands to do this for many machines in one go.
#
ansible 'cpu_r6515:!nb-node-a01' -u "${admin}" --become -m ansible.builtin.shell -a 'echo "9" > /etc/dnf/vars/releasever'
ansible 'cpu_r6515:!nb-node-a01' -u "${admin}" --become -m ansible.builtin.shell -a 'cd; echo ${PWD}; dnf -y install efibootmgr'
ansible 'cpu_r6515:!nb-node-a01' -u "${admin}" --become -m ansible.builtin.shell -a 'cd; echo ${PWD}; curl -O https://raw.githubusercontent.com/AlmaLinux/almalinux-deploy/master/almalinux-deploy.sh'
ansible 'cpu_r6515:!nb-node-a01' -u "${admin}" --become -m ansible.builtin.shell -a 'cd; echo ${PWD}; bash ./almalinux-deploy.sh'
#
ansible 'cpu_r630:!nb-node-c01' -u "${admin}" --become -m ansible.builtin.shell -a 'echo "9" > /etc/dnf/vars/releasever'
ansible 'cpu_r630:!nb-node-c01' -u "${admin}" --become -m ansible.builtin.shell -a 'cd; echo ${PWD}; dnf -y install efibootmgr'
ansible 'cpu_r630:!nb-node-c01' -u "${admin}" --become -m ansible.builtin.shell -a 'cd; echo ${PWD}; curl -O https://raw.githubusercontent.com/AlmaLinux/almalinux-deploy/master/almalinux-deploy.sh'
ansible 'cpu_r630:!nb-node-c01' -u "${admin}" --become -m ansible.builtin.shell -a 'cd; echo ${PWD}; bash ./almalinux-deploy.sh'
```

ansible-playbook -u ${admin} single_group_playbooks/cluster_part1.yml -l compute_node
ansible-playbook -u ${admin} single_group_playbooks/cluster_part2.yml -l compute_node
ansible-playbook -u ${admin} single_group_playbooks/compute_node.yml -l compute_node

##### On the Ansible controller: rerun all playbooks.

```
. ./lor-init
lor-config ${stack_prefix}
ansible-playbook -u ${admin} single_group_playbooks/repo.yml -l repo
ansible-playbook -u ${admin} single_group_playbooks/data_transfer.yml -l data_transfer
ansible-playbook -u ${admin} single_group_playbooks/cluster_part1.yml -l cluster
ansible-playbook -u ${admin} single_group_playbooks/cluster_part2.yml -l cluster
ansible-playbook -u ${admin} single_group_playbooks/sys_admin_interface.yml -l sys_admin_interface
ansible-playbook -u ${admin} single_group_playbooks/deploy_admin_interface.yml -l deploy_admin_interface
ansible-playbook -u ${admin} single_group_playbooks/user_interface.yml -l user_interface
ansible-playbook -u ${admin} single_group_playbooks/compute_node.yml -l compute_node
ansible-playbook -u ${admin} single_group_playbooks/jumphost.yml -l jumphost
```

Check if everything works and remove `/etc/nologin` from jumphost.

## Warnings we may need to take a look at at a later date.

```
warning: /etc/shadow created as /etc/shadow.rpmnew
#
warning: /var/lib/unbound/root.key saved as /var/lib/unbound/root.key.rpmsave
#
warning: /etc/ssh/moduli created as /etc/ssh/moduli.rpmnew
#
Created symlink /etc/systemd/system/dbus-org.bluez.service → /usr/lib/systemd/system/bluetooth.service.
Created symlink /etc/systemd/system/bluetooth.target.wants/bluetooth.service → /usr/lib/systemd/system/bluetooth.service.
#
Warning: The unit file, source configuration file or drop-ins of auditd.service changed on disk. Run 'systemctl daemon-reload' to reload units.
#
warning: /etc/cloud/cloud.cfg created as /etc/cloud/cloud.cfg.rpmnew
#
warning: /etc/ssh/sshd_config created as /etc/ssh/sshd_config.rpmnew
#
Failed to set unit properties on kdump.service: Unit kdump.service is masked.
#
  Running scriptlet: wireplumber-0.5.12-1.el9.x86_64                  2186/2186 
Unit /usr/lib/systemd/user/wireplumber.service is added as a dependency to a non-existent unit pipewire.service.
#
```

## Debugging / Trouble shooting

```
#
# Check Lustre client status and force reinstall using DKMS if kernel modules are missing.
#
dkms status
dkms install lustre-client/2.15.8
dkms status
```

```
#
# Delete conflicting pipewire-jack-audio-connection-kit packages
#
dnf remove -y pipewire-jack-audio-connection-kit
```

```
./almalinux-deploy.sh: line 1329: efibootmgr: command not found
#
# When that happens, install efibootmgr using DNF and rerun the conversion script.
#
dnf install -y efibootmgr
bash ./almalinux-deploy.sh
```

NHC may complain about 1 MB less RAM on Slurm clients like this:
```
Low RealMemory (reported:63785 < 100.00% of configured:63786)
```
When that happens for any of the machines in the stack, then
 * Update value in the `static_inventory` and
 * Redeploy `single_role_playbooks/slurm.yml` for the **entire** stack.