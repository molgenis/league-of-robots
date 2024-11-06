# League of Robots

##### _develop_ branch CI status

[![CircleCI](https://circleci.com/gh/rug-cit-hpc/league-of-robots/tree/develop.svg?style=svg)](https://circleci.com/gh/rug-cit-hpc/league-of-robots/tree/develop)

##### _master_ branch CI status

[![CircleCI](https://circleci.com/gh/rug-cit-hpc/league-of-robots/tree/master.svg?style=svg)](https://circleci.com/gh/rug-cit-hpc/league-of-robots/tree/master)

## About this repo

This repository contains playbooks and documentation to deploy *stacks* of virtual machines working together.
Most of these stacks are virtual Linux HPC clusters, which can be used as *collaborative, analytical sandboxes*.
All production clusters were named after robots that appear in the animated sitcom [Futurama](https://en.wikipedia.org/wiki/Futurama).
Test/development clusters were named after other robots.

#### Software/framework ingredients

The main ingredients for (deploying) these clusters:

 * [Ansible playbooks](https://github.com/ansible/ansible) for system configuration management.
 * [OpenStack](https://www.openstack.org/) for virtualization. (Note that deploying the OpenStack itself is not part of the configs/code in this repo.)
 * [Pulp](https://pulpproject.org/) to create freezes of Linux distros.
 * [CentOS 7](https://www.centos.org/) as OS for the virtual machines.
 * [Slurm](https://slurm.schedmd.com/) as workload/resource manager to orchestrate jobs.

#### Branches and Releases
The master and develop branches of this repo are protected; updates can only be merged into these branches using reviewed pull requests.
Once a while we create releases, which are versioned using the format ```YY.MM.v``` where:

 * ```YY``` is the year of release
 * ```MM``` is the month of release
 * ```v``` is the first release in that month and year. Hence it is not the day of the month.

E.g. ```19.01.1``` is the first release in January 2019.

#### Code style and naming conventions

We follow the [Python PEP8 naming conventions](https://www.python.org/dev/peps/pep-0008/#naming-conventions) for variable names, function names, etc.

## Clusters

This repo currently contains code and configs for the following clusters:

 * Talos: Development cluster hosted by the [Center for Information Technology (CIT) at the University of Groningen](https://www.rug.nl/society-business/centre-for-information-technology/).
 * Gearshift: [UMCG](https://www.umcg.nl) Research IT production cluster hosted by the [Center for Information Technology (CIT) at the University of Groningen](https://www.rug.nl/society-business/centre-for-information-technology/).
 * Nibbler: [UMCG](https://www.umcg.nl) Research IT production cluster hosted by the [Center for Information Technology (CIT) at the University of Groningen](https://www.rug.nl/society-business/centre-for-information-technology/).
 * Hyperchicken: Development cluster hosted by [The European Bioinformatics Institute (EMBL-EBI)](https://www.ebi.ac.uk/) in the [Embassy Cloud](https://www.embassycloud.org/).
 * Fender: [Solve-RD](solve-rd.eu/) production cluster hosted by [The European Bioinformatics Institute (EMBL-EBI)](https://www.ebi.ac.uk/) in the [Embassy Cloud](https://www.embassycloud.org/).

Deployment and functional administration of all clusters is a joined effort of the
[Genomics Coordination Center (GCC)](http://wiki.gcc.rug.nl/)
and the 
[Center for Information Technology (CIT)](https://www.rug.nl/society-business/centre-for-information-technology/)
from the [University Medical Center](https://www.umcg.nl) and [University](https://www.rug.nl) of Groningen,
in collaboration with [ELIXIR compute platform](https://www.elixir-europe.org/platforms/compute),
[EXCELERATE](https://www.elixir-europe.org/about-us/how-funded/eu-projects/excelerate),
[EU-Solve-RD](http://solve-rd.eu/),
[European Joint Programme on Rare Diseases](https://www.ejprarediseases.org/) and
[CORBEL](https://www.corbel-project.eu/home.html) projects.

#### Cluster components

The clusters are composed of the following type of machines:

 * **Jumphost**: security-hardened machines for SSH access.
 * **User Interface (UI)**: machines for job management by regular users.
 * **Deploy Admin Interface (DAI)**: machines for deployment of bioinformatics software and reference datasets without root access.
 * **Sys Admin Interface (SAI)**: machines for maintenance / management tasks that require root access.
 * **Compute Node (CN)**: machines that crunch jobs submitted by users on a UI.
 
The clusters use the following types of storage systems / folders:

| Filesystem/Folder           | Shared/Local | Backups | Mounted on           | Purpose/Features |
| :-------------------------- | :----------: | :-----: | :------------------- | :--------------- |
| /home/${home}/              | Shared       | Yes     | UIs, DAIs, SAIs, CNs | Only for personal preferences: small data == tiny quota.|
| /groups/${group}/prm[0-9]/  | Shared       | Yes     | UIs, DAIs            | **p**e**rm**anent storage folders: for rawdata or *final* results that need to be stored for the mid/long term. |
| /groups/${group}/tmp[0-9]/  | Shared       | No      | UIs, DAIs, CNs       | **t**e**mp**orary storage folders: for staged rawdata and intermediate results on compute nodes that only need to be stored for the short term. |
| /groups/${group}/scr[0-9]/  | Local        | No      | Some UIs             | **scr**atch storage folders: same as **tmp**, but local storage as opposed to shared storage. Optional and available on all UIs. |
| /local/${slurm_job_id}      | Local        | No      | CNs                  | Local storage on compute nodes only available during job execution. Hence folders are automatically created when a job starts and deleted when it finishes. |
| /mnt/${complete_filesystem} | Shared       | Mixed   | SAIs                 | Complete file systems, which may contain various `home`, `prm`, `tmp` or `scr` dirs. |

## Other stacks

Some other stacks of related machines are:

 * ```docs_library```: web servers hosting documentation.
 * ```jenkins_server```: Continues Integration testing server.
 * ...: iRODS machines

## Deployment phases

Deploying a fully functional stack of virtual machines from scratch involves the following steps:

 1. Configure physical machines
    * Off topic for this repo.
 2. Deploy OpenStack virtualization layer on physical machines to create an OpenStack cluster.
    * Off topic for this repo.
    * For the _Shikra_ cloud, which hosts the _Talos_ and _Gearshift_ HPC clusters
      we use the ansible playbooks from the [hpc-cloud](https://git.webhosting.rug.nl/HPC/hpc-cloud) repository
      to create the OpenStack cluster.
    * For other HPC clusters we use OpenStack clouds from other service providers _as is_.
 3. Create, start and configure virtual networks and machines on an OpenStack cluster.
    * This repo.
 4. Deploy bioinformatics software and reference datasets.
    * Off topic for this repo.
    * We use the ansible playbook from the [ansible-pipelines](https://github.com/molgenis/ansible-pipelines) repository
      to deploy Lua + Lmod + EasyBuild. The latter is then used to install bioinformatics tools.

---

## Details for phase 3. Create, start and configure virtual environment(s).

#### 0. Clone this repo and configure a generic Python virtual environment.

```bash
mkdir -p ${HOME}/git/
cd ${HOME}/git/
git clone https://github.com/rug-cit-hpc/league-of-robots.git
cd league-of-robots
#
# Create Python virtual environment (once)
#
python3 -m venv python.venv
#
# Activate virtual environment.
#
source python.venv/bin/activate
#
# Install OpenStack SDK (once) and other python packages.
#
pip3 install --upgrade pip
pip3 install wheel
pip3 install setuptools  # No longer part of default Python >= 3.12.x, but we need it.
pip3 install ruamel.yaml
pip3 install netaddr
#
# Package dnspython is required for Ansible lookup plugin community.general.dig
#
pip3 install dnspython
#
# On macOS only to prevent this error:
# crypt.crypt not supported on Mac OS X/Darwin, install passlib python module.
#
pip3 install passlib
#
# Optional: install Ansible and the Ansible linter with pip.
# You may skip this step if you already installed Ansible by other means.
# E.g. with HomeBrew on macOS, with yum or dnf on Linux, etc.
#
# Ansible core 2.16 from Ansible 9.x is latest version compatible with Mitogen.
#
pip3 install 'ansible<10' # For running playbooks on your local laptop as Ansible control host.
pip3 install 'ansible<6' # For running playbooks directly on chaperone machines running RHEL8.
pip3 install ansible-lint
#
# Optional: install Mitogen with pip.
# Mitogen provides an optional strategy plugin that makes playbooks a lot (up to 7 times!) faster.
# See https://mitogen.networkgenomics.com/ansible_detailed.html
#
pip3 install mitogen
```

#### 1. Python virtual environment: install packages to manage OpenStack environment

```bash
pip3 install openstacksdk
pip3 install openstackclient
```

#### 2. Import the required roles and collections for the playbooks.

```bash
source python.venv/bin/activate
export ANSIBLE_ROLES_PATH="${VIRTUAL_ENV}/ansible/ansible_roles/:"
export ANSIBLE_COLLECTIONS_PATH="${VIRTUAL_ENV}/ansible/:"
ansible-galaxy install -r requirements.yml
```

Note: the default location where these dependencies will get installed with the ```ansible-galaxy install``` command is ```${HOME}/.ansible/```,
which may conflict with versions of roles and collections required for other repos.
Therefore we set ```ANSIBLE_ROLES_PATH``` and ```ANSIBLE_COLLECTIONS_PATH``` to use a custom path for the dependencies inside the virtual environment we'll use for this repo.

#### 3. Python virtual environment: install packages to manage Azure environment

Make sure you already executed `ansible-galaxy install ... ` (see previous step).

```bash
  pip install azure-cli # if issues occur, try to version lock it to azure-cli==2.61.0 azure azcollection >= 2.6.0 works with it
  _azure_pip_requirements="$(find "${VIRTUAL_ENV}" -path "*/azure/azcollection/requirements.txt")"
  pip install -r "${_azure_pip_requirements}"
```

See also Galaxy Ansible [Azure Azcollection > Documentation](https://galaxy.ansible.com/ui/repo/published/azure/azcollection/docs/)

#### 4. Create a `vault_pass.txt`.

The vault password is used to encrypt/decrypt the ```secrets.yml``` file per *stack_name*, 
which will be created in the next step if you do not already have one.
In addition a second vault passwd is used for various files in ```group_vars/all/``` and which contain settings that are the same for all *stacks*.
If you have multiple *stacks* with their own vault passwd you will have multiple vault password files. 
The pattern ```.vault*``` is part of ```.gitignore```, so if you put the vault passwd files in the ```.vault/``` subdir,
they will not accidentally get committed to the repo.

* To generate a new Ansible vault password and put it in ```.vault/vault_pass.txt.[stack_name|all]```, use the following oneliner:
  ```bash
  LC_ALL=C tr -cd '[:alnum:]' < /dev/urandom | fold -w60 | head -n1 > .vault/vault_pass.txt.[stack_name|all]
  ```
* Or to use an existing Ansible vault password create ```.vault/vault_pass.txt.[stack_name|all]``` and use a text editor to add the password.
* Make sure the ```.vault/``` subdir and it's content is private:
  ```bash
  chmod -R go-rwx .vault/
  ```

#### 5. Configure Ansible settings including the vault.

To create a new *stack* you will need ```group_vars``` and a static inventory for that *stack*:

* See the ```static_inventories/*.yml``` files for existing stacks for examples.  
  Create a new ```static_inventories/[stack_name].yml```.
* Create a ```group_vars/[stack_name]/``` folder with a ```vars.yml```.  
  You'll find and example ```vars.yml``` file in ```group_vars/template/```.  
  To generate a new ```secrets.yml``` with new random passwords for the various daemons/components and encrypt this new ```secrets.yml``` file:
  ```bash
  #
  # Activate Python virtual env created in step 0.
  #
  source python.venv/bin/activate
  #
  # Configure this repo for a specific cluster.
  # This will set required ENVIRONMENT variables including
  # ANSIBLE_VAULT_IDENTITY_LIST='all@.vault/vault_pass.txt.all, [stack_name]@.vault/vault_pass.txt.[stack_name]'
  #
  . ./lor-init
  lor-config [stack_prefix]
  #
  #
  # Create new secrets.yml file based on a template and encrypt it with the vault password.
  #
  ./generate_secrets.py group_vars/template/secrets.yml group_vars/[stack_name]/secrets.yml
  ansible-vault encrypt --encrypt-vault-id [stack_name] group_vars/[stack_name]/secrets.yml 
  ```
  The encrypted ```secrets.yml``` can now safely be committed.  
  The ```.vault/vault_pass.txt.[stack_name]``` file is excluded from the repo using the ```.vault*``` pattern in ```.gitignore```.

To use use an existing encrypted ```group_vars/[stack_name]/secrets.yml```:

* Add a ```.vault/vault_pass.txt.[stack_name]``` file to this repo and use a text editor to add the vault password to this file.

#### 6. Configure the Certificate Authority (CA).

We use an SSH public-private key pair to sign the host keys of all the machines in a cluster.
This way users only need the public key of the CA in their ```~.ssh/known_hosts``` file
and will not get bothered by messages like this:
```
The authenticity of host '....' can't be established.
ED25519 key fingerprint is ....
Are you sure you want to continue connecting (yes/no)?
```
* The default filename of the CA private key is ```[stack_name]-ca```
  A different CA key file must be specified using the ```ssh_host_signer_ca_private_key``` variable defined in ```group_vars/[stack_name]/vars.yml```
* The filename of the corresponding CA public key must be the same as the one of the private key suffixed with ```.pub```
* The password required to decrypt the CA private key must be specified using the ```ssh_host_signer_ca_private_key_pass``` variable defined in ```group_vars/[stack_name]/secrets.yml```,
  which must be encrypted with ```ansible-vault```.
* Each user must add the content of the CA public key to their ```~.ssh/known_hosts``` like this:
  ```
  @cert-authority [names of the hosts for which the cert is valid] [content of the CA public key]
  ```
  E.g.:
  ```
  @cert-authority reception*,*talos,*tl-* ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDWNAF....VMZpZ5b9+5GA3O8w== UMCG HPC Development CA
  ```
* Example to create a new CA key pair with the ```ed25519``` algorithm and encryption after that:
  ```bash
  ssh-keygen -t ed25519 -a 101 -f ssh-host-ca/[stack_name]-ca -C "CA key for [stack_name]"
  ansible-vault encrypt --encrypt-vault-id [stack_name] ssh-host-ca/[stack_name]-ca
  ```

#### 7. Build Prometheus Node Exporter

* Make sure you are a member of the `docker` group.
  Otherwise you will get this error:
  ```
  ERRO[0000] failed to dial gRPC: cannot connect to the Docker daemon.
  Is 'docker daemon' running on this host?: dial unix /var/run/docker.sock: connect:
  permission denied
  context canceled
  ```
* Execute:
  ```bash
  cd promtools
  ./build.sh
  ```

#### 8. Generate munge key and encrypt it using Ansible Vault.

Execute:
```bash
mkdir -p files/[stack_name]
dd if=/dev/urandom bs=1 count=1024 > files/[stack_name]/munge.key
ansible-vault encrypt --encrypt-vault-id [stack_name] files/[stack_name]/munge.key
```
The encrypted ```files/[stack_name]/munge.key``` can now be committed safely.

#### 9. Generate TLS certificate, passwords & hashes for the LDAP server and encrypt it using Ansible Vault.

If you do not configure any LDAP domains using the ```ldap_domains``` variable (see *ldap_server* role for details) in ```group_vars/[stack_name]/vars.yml```,
then the machines for the [stack_name] _stack_ will use local accounts created on each machine and this step can be skipped.

If you configured ```ldap_domains``` in ```group_vars/[stack_name]/vars.yml``` and all LDAP domains have  ```create_ldap: false```,
then this _stack_ will/must use an external LDAP, that was configured & hosted elsewhere, and this step can be skipped.

If you configured one or more LDAP domains with ```create_ldap: true```; E.g.:
   ```
   ldap_domains:
     stack:
       create_ldap: true
       .....
     other_domain:
       some_config_option: anothervalue
       create_ldap: true
       .....
   ```
Then this _stack_ will create and run its own LDAP server. You will need to create:
  * For the LDAP server:
    * A self-signed TLS certificate.
    * _Password_ & corresponding _hash_ for the LDAP ```root``` account.
  * For each LDAP domain hosted on this LDAP server:
    * A ```readonly``` account with a correct _dn_, _password_ and corresponding _hash_.
    * An ```admin``` account with a correct _dn_, _password_ and corresponding _hash_.

##### 9a TLS certificate for LDAP server.

Create key and CA certificate with one command
   ```
   openssl req -x509 -nodes -days 1825 -newkey rsa:4096 -keyout files/[stack_name]/ldap.key -out files/[stack_name]/ldap.crt
   ```

where you must correctly provide the following values

   ```
     Country Name (2 letter code) [XX]:NL
     State or Province Name (full name) []:Groningen
     Locality Name (eg, city) [Default City]:Groningen
     Organization Name (eg, company) [Default Company Ltd]:UMCG
     Organizational Unit Name (eg, section) []:GCC
     Common Name (eg, your name or your server's hostname) []:ladap
     Email Address []:hpc.helpdesk@umcg.nl
 
   ```

Note that the `Common Name` must be the address of the ldap server. Based on the type of the network access to the machine:
  - if internal network only is going to be used, then input short name (like `fd-dai` or `ladap`),
  - if it is going to be used externally then provide fqdn (like `ladap.westeurope.cloudapp.azure.com`).


   ```
   openssl dhparam -out files/[stack_name]/dhparam.pem 4096
   ansible-vault encrypt --encrypt-vault-id [stack_name] files/[stack_name]/ldap.key
   ansible-vault encrypt --encrypt-vault-id [stack_name] files/[stack_name]/ldap.crt
   ansible-vault encrypt --encrypt-vault-id [stack_name] files/[stack_name]/dhparam.pem
   ```
The encrypted files in ```files/[stack_name]/``` can now be committed safely.

##### 9b passwords and hashes for LDAP accounts.

When an OpenLDAP server is created, you will need passwords and corresponding hashes for the LDAP _root_ account
as well as for functional accounts for at least one LDAP domain. Therefore the minimal setup in ```group_vars/[stack_name]/secrets.yml``` is something like this:

```
openldap_root_pw: ''
openldap_root_hash: ''
ldap_credentials:
  stack:
    readonly:
      dn: 'cn=readonly,dc={{ use stack_name here }},dc=local'
      pw: ''
      hash: ''
    admin:
      dn: 'cn={{ use stack_prefix here }}-admin,dc={{ use stack_name here }},dc=local'
      pw: ''
      hash: ''
```

In this example the LDAP domain named ```stack``` is used for users & groups, that were created for and are used only on this _stack_ of infra.
You may have additional LDAP domains serving as other sources for users and groups.

The `pw` values may have been already generated with the ```generate_secrets.py``` script in step 3.
If you added additional LDAP domains later you can, decrypt the ```group_vars/[stack_name]/secrets.yml``` with ```ansible-vault```,
rerun the ```generate_secrets.py``` script to generate additional password values and re-encrypt ```secret.yml``` with ```ansible-vault```.

For each ```pw``` you will need to generate a corresponding hash. You cannot use ```generate_secrets.py``` for that,
because it requires the ```slappasswd```. Therefore, you have to login on the OpenLDAP servers and use:
```
/usr/local/openldap/sbin/slappasswd \
    -o module-path='/usr/local/openldap/libexec/openldap' \
    -o module-load='argon2' -h '{ARGON2}' \
    -s 'pw_value'
```
The result is a string with 6 ```$``` separated values like this:
```
'{ARGON2}$argon2id$v=19$m=65536,t=2,p=1$7+plp......nDs5J!dSpg$ywJt/ug9j.........qKcdfsgQwEI'
```
For the record:
1. ```{ARGON2}```: identifies which hashing schema was used.
2. ```argon2id```: lists which Argon 2 algorithm was used.
3. ```v=19```: version of the Argon 2 algorithm.
4. ```m=65536,t=2,p=1```: lists values used for arguments for the Argon 2 algorithm.
5. ```7+plp......nDs5J!dSpg```: The base64 encoded radom salt that was added by ```slappasswd```
6. ```ywJt/ug9j.........qKcdfsgQwEI````: The base64 encoded hash.

Use the **_entire_** strings as the ```hash``` values in ```group_vars/[stack_name]/secrets.yml```.

#### 10. Running playbooks.

There are two _wrapper playbooks_:

1. `openstack.yml`:
   * Creates virtual resources in OpenStack: networks, subnets, routers, ports, volumes and finally the virtual machines.
   * Interacts with the OpenstackSDK / API on localhost.
   * Uses a static inventory from `static_inventories/*.yaml` parsed with our custom inventory plugin `inventory_plugins/yaml_with_jumphost.py`
1. `cluster.yml`:
   * Configures the virtual machines created with the `openstack.yml` playbook.
   * Has no dependency on the OpenstackSDK / API.
   * Uses a static inventory from `static_inventories/*.yaml` parsed with our custom inventory plugin `inventory_plugins/yaml_with_jumphost.py`

The _wrapper playbooks_ execute several _roles_ in the right order to create the complete `stack`.
_Playbooks_ from the `single_role_playbooks/` or `single_group_playbooks/` sub directories can be used to
(re)deploy individual roles or all roles for only a certain type of machine (inventory group), respectively.
These shorter subset _playbooks_ can save a lot of time during development, testing or regular maintenance.

##### openstack.yml

* Login to the OpenStack web interface -> _Identity_ -> _Application Credentials_ -> click the _Create Application Credential_ button.  
  This will result in a popup window: specify _Name_, _Expiration Date_, _Expiration Time_, leave the rest empty / use defaults
  and click the _Create Application Credential_ button.  
  In the new popup window click the _Download openrc file_ button and save the generated  `*-openrc.sh` file in the root of the repo.
* Configure environment and run playbook:
  ```bash
  #
  # Activate Python virtual env created in step 0.
  #
  source python.venv/bin/activate
  #
  # Initialize the OpenstackSDK
  #
  source ./[Application_Credential_Name]-openrc.sh
  #
  # Configure this repo for deployment of a specific stack.
  #
  source ./lor-init
  lor-config [stack_prefix]
  ansible-playbook openstack.yml
  ```

##### cluster.yml

###### Deployment order: local admin accounts and signed host keys must come first

Without local admin accounts we'll need to use

* Either a ```root``` account for direct login
* Or a _default_ user account for the image used to create the VMs.  
  This account must be able to ```sudo su``` to become the root user.

In our case the CentOS cloud image comes with a default ```centos``` user.

Note that:

* Direct login as root will be disabled by the playbook for security reasons,
  so you will need a local admin account to become root using sudo.
* An admin account must be local, so it does not depend on an external account management server like an LDAP.
* An admin account must have a home dir **not** in /home,
  because we will mount home dirs for regular users from shared storage system over a network
  and admin accounts must **not** depend on a ```~/.ssh/authorized_keys``` from an external storage system.
* The default ```centos``` account will become useless after the first steps of the playbook have been deployed,
  because its home dir with ```~/.ssh/authorized_keys```is located in /home,
  which will vanish when we mount homes from shared storage.
  Changing the location of the default ```centos``` account is not trivial and can result in a situation where you lock yourself out.

Therefore the first step is to create additional local admin accounts:

* whose home dir is not located in /home and
* who are allowed to ```sudo su``` to the root user.

Without signed host keys, SSH host key checking must be disabled for this first step.
The next step is to deploy the signed host keys.
Once these first two steps have been deployed, the rest of the steps can be deployed with a local admin account and SSH host key checking enabled, which is the default.

###### SSH client config: using the dynamic inventory and jumphosts

In order to reach machines behind the jumphost you will need to configure your SSH client.
The templates for the documentation are located in this repo at:  
[roles/online_docs/templates/mkdocs/docs/](roles/online_docs/templates/mkdocs/docs/)  
Deployed docs can currently be found at:  
[http://docs.gcc.rug.nl/](http://docs.gcc.rug.nl/)  
Once configured correctly you should be able to do a multi-hop SSH via a jumphost to a destination server using aliases like this:
* For login with the same account on both jumphost and destination:
  ```bash
  ssh user@jumphost+destination
  ```
* For login with a different account on the jumphost:
  ```bash
  export JUMPHOST_USER='user_on_jumphost'
  ssh user_on_destination@jumphost+destination
  ```

###### Some examples for the *Talos* development cluster:

* Configure the dynamic inventory and jumphost for the *Talos* test cluster:
  ```bash
  export AI_PROXY='reception'
  export ANSIBLE_INVENTORY='static_inventories/talos_cluster.yml'
  export ANSIBLE_VAULT_IDENTITY_LIST='all@.vault/vault_pass.txt.all, talos@.vault/vault_pass.txt.talos_cluster'
  ```
  This can also be accomplished with less typing by sourcing an initialisation file, which provides the ```lor-config``` function 
  to configure these environment variables for a specific cluster/site:
  ```bash
  . ./lor-init
  lor-config tl
  ```
* Define accounts used to deploy playbooks
  ```bash
  #
  # CentOS 7.x default_cloud_image_user = centos
  # Rocky 9.x default_cloud_image_user = cloud-user
  #
  default_cloud_image_user='centos|cloud-user'
  lor_admin_user='your_admin_account'
  ```
* Firstly, create the jumphost, which is required to access the other machines.  
  Deploy the signed hosts keys and create local admin accounts with ```init.yml``` and
  configure other stuff on the jumphost (contains amongst others the settings required to access the other machines behind the jumphost)
  with ```cluster.yml```:
  ```
  ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u "${default_cloud_image_user}" -l 'jumphost' single_group_playbooks/init.yml
  ansible-playbook -u "${lor_admin_user}" -l 'jumphost' cluster.yml
  ```
* Secondly, deploy the rest of the machines in the same order.  
  For ```init.yml``` you must (temporarily) set ```JUMPHOST_USER``` for access to the jumphost to _your local admin account_,
  because the ```${default_cloud_image_user}``` user will no longer be able to login to the jumphost:
  ```bash
  export JUMPHOST_USER="${lor_admin_user}" # Requires SSH client config as per end user documentation: see above.
  ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u "${default_cloud_image_user}" -l '!jumphost' single_group_playbooks/init.yml
  unset JUMPHOST_USER
  ansible-playbook -u "${lor_admin_user}" -l '!jumphost' cluster.yml
  ```
* (Re-)deploying only a specific role - e.g. *rsyslog_client* - on the previously deployed test cluster *Talos*
  ```bash
  ansible-playbook -u "${lor_admin_user}" single_role_playbooks/rsyslog_client.yml
  ```

#### 11. Verify operation.

See the end user documentation, that was generated with the ```online_docs``` role for instructions how to submit a job to test the cluster.
