# SSH Host Signer role
An Ansible role to securely sign SSH host keys with an SSH certificate authority.
* The CA private key never leaves your local machine. 
* Based on https://galaxy.ansible.com/chrisgavin/ansible-ssh-host-signer
  * Extended with option to use HostCertificates only for certain key types.
    By default all host keys found on the target machine are signed, but
    * `HostKey` and matching `HostCertificate` directives are only added to the SSH config file for the key types specified.
    * Any `HostKey` and matching `HostCertificate` directives for keys that do not match the key type regex will be removed from the SSH config.

Note: adding the public key of the CA as cert in /etc/ssh/ssh_known_hosts is relocated to the `ssh` (client) role.

## Requirements
The machine running this playbook is expected to have an `ssh-keygen` binary on the path. It should be new enough to support SSH CAs.

## Variables
* `ssh_host_signer_ca_keypair_dir` - (defaults to `/etc/ssh`)
* `ssh_host_signer_ca_private_key` - The path to the CA key used to sign host keys. (defaults to `{{ ssh_host_signer_ca_keypair_dir }}/ca_key`)
* `ssh_host_signer_id` - The ID of the certificate to be generated. (defaults to `{{ ansible_fqdn }}`)
* `ssh_host_signer_hostnames` - The comma separated list of hostnames for which the certificate should be valid. (defaults to `{{ ansible_fqdn }},{{ ansible_hostname }}`)
* `ssh_host_signer_key_directory` - The path on the server to look for SSH host keys to sign. (defaults to `/etc/ssh/`)
* `ssh_host_signer_key_types` - The types of keys for which to use a HostCertificate. (defaults to `.*`)
  The is a regex that must match the key file names (we do not check if the key type in the name of the file matches the actual content of the key file.)
* `ssh_host_signer_ssh_config` - The path to the SSH config file which the certificates will be added to. (defaults to `/etc/ssh/sshd_config`)
