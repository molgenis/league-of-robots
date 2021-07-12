# League of Robots

## About this repo

This repository contains playbooks and documentation to deploy virtual Linux HPC clusters, which can be used as *collaborative, analytical sandboxes*.
All production clusters were named after robots that appear in the animated sitcom [Futurama](https://en.wikipedia.org/wiki/Futurama).
Test/development clusters were named after other robots.

#### Software/framework ingredients

The main ingredients for (deploying) these clusters:

 * [Ansible playbooks](https://github.com/ansible/ansible) for system configuration management.
 * [OpenStack](https://www.openstack.org/) for virtualization. (Note that deploying the OpenStack itself is not part of the configs/code in this repo.)
 * [Spacewalk](https://spacewalkproject.github.io/index.html) to create freezes of Linux distros.
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
 * Hyperchicken: Development cluster cluster hosted by [The European Bioinformatics Institute (EMBL-EBI)](https://www.ebi.ac.uk/) in the [Embassy Cloud](https://www.embassycloud.org/).
 * Fender: [Solve-RD](solve-rd.eu/) production cluster hosted by [The European Bioinformatics Institute (EMBL-EBI)](https://www.ebi.ac.uk/) in the [Embassy Cloud](https://www.embassycloud.org/).

Deployment and functional administration of all clusters is a joined effort of the
[Genomics Coordination Center (GCC)](http://wiki.gcc.rug.nl/)
and the 
[Center for Information Technology (CIT)](https://www.rug.nl/society-business/centre-for-information-technology/)
from the [University Medical Center](https://www.umcg.nl) and [University](https://www.rug.nl) of Groningen, in collaboration with [ELIXIR compute platform](https://www.elixir-europe.org/platforms/compute), [EXCELERATE](https://www.elixir-europe.org/about-us/how-funded/eu-projects/excelerate), [EU-Solve-RD](http://solve-rd.eu/), European Joint Project for Rare disease and [CORBEL](https://www.corbel-project.eu/home.html) projects.

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

## Deployment phases

Deploying a fully functional virtual cluster from scratch involves the following steps:

 1. Configure physical machines
    * Off topic for this repo.
 2. Deploy OpenStack virtualization layer on physical machines to create an OpenStack cluster.
    * Off topic for this repo.
    * For the _Shikra_ cloud, which hosts the _Talos_ and _Gearshift_ HPC clusters
      we use the ansible playbooks from the [hpc-cloud](https://git.webhosting.rug.nl/HPC/hpc-cloud) repository
      to create the OpenStack cluster.
    * For other HPC clusters we use OpenStack clouds from other service providers as is.
 3. Create, start and configure virtual machines on an OpenStack cluster to create a Slurm HPC cluster.
    * This repo.
 4. Deploy bioinformatics software and reference datasets.
    * Off topic for this repo.
    * We use the ansible playbook from the [ansible-pipelines](https://github.com/molgenis/ansible-pipelines) repository
      to deploy Lua + Lmod + EasyBuild. The latter is then used to install bioinformatics tools.

---

## Details for phase 3. Create, start and configure virtual machines on an OpenStack cluster to create a Slurm HPC cluster.

#### 0. Clone this repo and configure Python virtual environment.

```bash
mkdir -p ${HOME}/git/
cd ${HOME}/git/
git clone https://github.com/rug-cit-hpc/league-of-robots.git
cd league-of-robots
#
# Create Python virtual environment (once)
#
python3 -m venv openstacksdk.venv
#
# Activate virtual environment.
#
source openstacksdk.venv/bin/activate
#
# Install OpenStack SDK (once) and other python packages.
#
pip3 install openstacksdk
pip3 install ruamel.yaml
```

#### 1. First import the required roles and collections for the playbooks:

```bash
ansible-galaxy install -r galaxy-requirements.yml
```

Note: the default location where these dependencies will get installed with the above command is ```${HOME}/.ansible/```.

#### 2. Create a `vault_pass.txt`.

The vault password is used to encrypt/decrypt the ```secrets.yml``` file per cluster, 
which will be created in the next step if you do not already have one.
In addition a second vault passwd is used for various files in ```group_vars/all/``` and which contain settings that are the same for all clusters.
If you have multiple HPC clusters with their own vault passwd you will have multiple vault password files. 
The pattern ```.vault*``` is part of ```.gitignore```, so if you put the vault passwd files in the ```.vault/``` subdir,
they will not accidentally get committed to the repo.

* To generate a new Ansible vault password and put it in ```.vault/vault_pass.txt.[name-of-the-cluster|all]```, use the following oneliner:
  ```bash
  LC_ALL=C tr -cd '[:alnum:]' < /dev/urandom | fold -w60 | head -n1 > .vault/vault_pass.txt.[name-of-the-cluster|all]
  ```
* Or to use an existing Ansible vault password create ```.vault/vault_pass.txt.[name-of-the-cluster|all]``` and use a text editor to add the password.
* Make sure the ```.vault/``` subdir and it's content is private:
  ```bash
  chmod -R go-rwx .vault/
  ```

#### 3. Configure Ansible settings including the vault.

To create a new virtual cluster you will need ```group_vars``` and an static inventory for that HPC cluster:

* See the ```static_inventories/*_hosts.ini``` files for existing clusters for examples to create a new ```[name-of-the-cluster]*_hosts.ini```.
* Create a ```group_vars/[name-of-the-cluster]_cluster/``` folder with a ```vars.yml```.  
  You'll find and example ```vars.yml``` file in ```group_vars/template/```.  
  To generate a new ```secrets.yml``` with new random passwords for the various daemons/components and encrypt this new ```secrets.yml``` file:
  ```bash
  #
  # Activate Python virtual env created in step 0.
  #
  source openstacksdk.venv/bin/activate
  #
  # Configure this repo for a specific cluster.
  # This will set required ENVIRONMENT variables including
  # ANSIBLE_VAULT_IDENTITY_LIST='all@.vault/vault_pass.txt.all, [name-of-the-cluster]@.vault/vault_pass.txt.[name-of-the-cluster]'
  #
  . ./lor-init
  lor-config [name-of-the-cluster]
  #
  #
  # Create new secrets.yml file based on a template and encrypt it with the vault password.
  #
  ./generate_secrets.py group_vars/template/secrets.yml group_vars/[name-of-the-cluster]_cluster/secrets.yml
  ansible-vault encrypt --encrypt-vault-id [name-of-the-cluster] group_vars/[name-of-the-cluster]_cluster/secrets.yml 
  ```
  The encrypted ```secrets.yml``` can now safely be committed.  
  The ```.vault/vault_pass.txt.[name-of-the-cluster]``` file is excluded from the repo using the ```.vault*``` pattern in ```.gitignore```.

To use use an existing encrypted ```group_vars/[name-of-the-cluster]_cluster/secrets.yml```:

* Add a ```.vault/vault_pass.txt.[name-of-the-cluster]``` file to this repo and use a text editor to add the vault password to this file.

#### 4. Configure the Certificate Authority (CA).

We use an SSH public-private key pair to sign the host keys of all the machines in a cluster.
This way users only need the public key of the CA in their ```~.ssh/known_hosts``` file
and will not get bothered by messages like this:
```
The authenticity of host '....' can't be established.
ECDSA key fingerprint is ....
Are you sure you want to continue connecting (yes/no)?
```
* The filename of the CA private key is specified using the ```ssh_host_signer_ca_private_key``` variable defined in ```group_vars/[name-of-the-cluster]_cluster/vars.yml```
* The filename of the corresponding CA public key must be the same as the one of the private key suffixed with ```.pub```
* The password required to decrypt the CA private key must be specified using the ```ssh_host_signer_ca_private_key_pass``` variable defined in ```group_vars/[name-of-the-cluster]_cluster/secrets.yml```,
  which must be encrypted with ```ansible-vault```.
* Each user must add the content of the CA public key to their ```~.ssh/known_hosts``` like this:
  ```
  @cert-authority [names of the hosts for which the cert is valid] [content of the CA public key]
  ```
  E.g.:
  ```
  @cert-authority reception*,*talos,*tl-* ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDWNAF....VMZpZ5b9+5GA3O8w== UMCG HPC Development CA
  ```
* Example to create a new CA key pair with the ```ed25519``` algorithm:
  ```bash
  ssh-keygen -t ed25519 -a 101 -f ssh-host-ca/ca-key-file-name -C "CA key for ..."
  ```

#### 5. Build Prometheus Node Exporter

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

#### 6. Generate munge key and encrypt using the ansible-vault.

Execute:
```bash
dd if=/dev/urandom bs=1 count=1024 > roles/slurm_management/files/[name-of-the-cluster]_munge.key
ansible-vault encrypt --encrypt-vault-id [name-of-the-cluster] roles/slurm_management/files/[name-of-the-cluster]_munge.key
```
The encrypted ```[name-of-the-cluster]_munge.key``` can now safely be committed.

#### 7. Running playbooks.

There are two playbooks:

1. `deploy-os_servers.yml`:
   * Creates virtual resources in OpenStack: networks, subnets, routers, volumes and finally the virtual machines.
   * Interacts with the OpenstackSDK / API on localhost.
   * Uses a static inventory from `static_inventories/*.ini`
1. `cluster.yml`:
   * Configures the virtual machines created with the `deploy-os_servers.yml` playbook.
   * Has no dependency on the OpenstackSDK / API.
   * Uses the `inventory.py` dynamic inventory script.

##### deploy-os_servers.yml

* Login to the OpenStack web interface -> _Identity_ -> _Application Credentials_ -> click the _Create Application Credential_ button.  
  This will result in a popup window: specify _Name_, _Expiration Date_, _Expiration Time_, leave the rest empty / use defaults
  and click the _Create Application Credential_ button.  
  In the new popup window click the _Download openrc file_ button and save the generated  `*-openrc.sh` file in the root of the repo.
* Configure environment and run playbook:
  ```bash
  #
  # Activate Python virtual env created in step 0.
  #
  source openstacksdk.venv/bin/activate
  #
  # Initialize the OpenstackSDK
  #
  source ./[Application_Credential_Name]-openrc.sh
  #
  # Configure this repo for deployment of a specifc HPC cluster.
  #
  source ./lor-init
  lor-config [name-of-the-cluster]
  ansible-playbook -i static_inventories/[name-of-the-cluster]_hosts.ini deploy-os_servers.yml
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

Without signed host keys, SSH host key checking must be disbled for this first step.
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
  export AI_INVENTORY='static_inventories/talos_hosts.ini'
  export AI_PROXY='reception'
  export ANSIBLE_VAULT_IDENTITY_LIST='all@.vault/vault_pass.txt.all, talos@.vault/vault_pass.txt.talos'
  ```
  This can also be accomplished with less typing by sourcing an initialisation file, which provides the ```lor-config``` function 
  to configure these environment variables for a specific cluster/site:
  ```bash
  . ./lor-init
  lor-config talos
  ```
* Firstly, create the jumphost, which is required to access the other machines.
* Create local admin accounts.
* Deploy the signed hosts keys.
* Configure other stuff on the jumphost, which contains amongst others the settings required to access the other machines behind the jumphost.
  ```bash
  export ANSIBLE_HOST_KEY_CHECKING=False
  ansible-playbook -i inventory.py -u centos          -l 'jumphost' single_role_playbooks/admin_users.yml
  ansible-playbook -i inventory.py -u [admin_account] -l 'jumphost' single_role_playbooks/ssh_host_signer.yml
  export ANSIBLE_HOST_KEY_CHECKING=True
  ansible-playbook -i inventory.py -u [admin_account] -l 'jumphost' cluster.yml
  ```
* Secondly, deploy the rest of the machines in the same order.
  For creation of the local admin accounts you must (temporarily) set ```JUMPHOST_USER``` for the jumphost to _your local admin account_,
  because the ```centos``` user will no longer be able to login to the jumphost.
  ```bash
  export ANSIBLE_HOST_KEY_CHECKING=False
  export JUMPHOST_USER=[admin_account] # Requires SSH client config as per end user documentation: see above.
  ansible-playbook -i inventory.py -u centos          -l 'repo,cluster'      single_role_playbooks/admin_users.yml
  ansible-playbook -i inventory.py -u root            -l 'docs'              single_role_playbooks/admin_users.yml
  unset JUMPHOST_USER
  ansible-playbook -i inventory.py -u [admin_account] -l 'repo,cluster,docs' single_role_playbooks/ssh_host_signer.yml
  export ANSIBLE_HOST_KEY_CHECKING=True
  ansible-playbook -i inventory.py -u [admin_account] -l 'repo,cluster,docs' cluster.yml
  ```
* (Re-)deploying only a specific role - e.g. *slurm_management* - on the previously deployed test cluster *Talos*
  ```bash
  ansible-playbook -i inventory.py -u [admin_account] single_role_playbooks/slurm_management.yml
  ```

#### 8. Verify operation.

See the end user documentation, that was generated with the ```online_docs``` role for instructions how to submit a job to test the cluster.
