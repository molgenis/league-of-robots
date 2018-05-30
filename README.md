# gearshift

This repository contains playbooks and documentation for gcc's gearshift cluster.

## Git repository
All site specific configuration for the Gearshift cluster will be placed in this git repository.

## protected master.
The master branch is protected; updates will only be pushed to this branch after review.

## Ansible playbooks openstack cluster.
The ansible playbooks in this repository use roles from the [hpc-cloud](https://git.webhosting.rug.nl/HPC/hpc-cloud) repository.
The roles are imported here explicitely by ansible using ansible galaxy.
These roles install various docker images built and hosted by RuG webhosting. They are built from separate git repositories on https://git.webhosting.rug.nl.

## Deployment of openstack.
The steps below describe how to get from machines with a bare ubuntu 16.04 installed to a running openstack installation.


1. First import the required roles into this playbook:

   ```bash
   ansible-galaxy install -r requirements.yml --force -p roles
   ```

   ```bash
   ansible-galaxy install -r galaxy-requirements.yml
   ```

2. Generate an ansible vault password and put it in `.vault_pass.txt`. This could be done by running the following oneliner:

   ```bash
   tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1 > .vault_pass.txt
   ```

3. generate and encrypt the passwords for the various openstack components.

   ```bash
   ./generate_secrets.py
   ansible-vault --vault-password-file=.vault_pass.txt encrypt secrets.yml
   ```
   the secrets.yml can now safel be comitted. the `.vault_pass.txt` file is in the .gitignore and needs to be tranfered in a secure way.

4. Install the openstack cluster.

   ```bash
   ansible-playbook --vault-password-file=.vault_pass.txt site.yml
   ```

5. verify operation.

# Steps to upgrade openstack cluster.

# Steps to install Compute cluster on top of openstack cluster.
