#jinja2: trim_blocks:False
# The {{ slurm_cluster_name | capitalize }} HPC cluster

The {{ slurm_cluster_name | capitalize }} High Performance Compute (HPC) cluster is a typical [computer cluster](https://en.wikipedia.org/wiki/Computer_cluster),
that uses _poor man's parallellization_ using relatively cheap _commodity hardware_: 
the total workload is split in many small jobs (a.k.a. tasks) that process a chunk of data each. 
The jobs are submitted to a workload manager, which distributes them efficiently over the compute nodes.

## Key Features

The key features of the {{ slurm_cluster_name | capitalize }} cluster include:

 * Linux OS: [CentOS](https://www.centos.org/) 7.x with [{{ repo_manager | capitalize }}]({{ external_hrefs[repo_manager] }}) for package distribution/management.
 * Completely virtualised on an [OpenStack](https://www.openstack.org/) cloud
 * Deployment of HPC cluster with [Ansible playbooks](https://docs.ansible.com/ansible/latest/index.html) under version control in a Git repo: [league-of-robots](https://github.com/rug-cit-hpc/league-of-robots)
 * Job scheduling: [Slurm Workload Manager](https://slurm.schedmd.com/)
 * Account management:
    * Local admin users+groups provisioned using Ansible.
    * Regular users+groups in a dedicated LDAP for this cluster and provisioned either with Ansible playbook too or using info from federated AAIM.
 * Module system: [Lmod](https://github.com/TACC/Lmod)
 * Deployment of (Bioinformatics) software using [EasyBuild](https://github.com/easybuilders/easybuild)

## Cluster Components

{{ slurm_cluster_name | capitalize }} consists of various types of servers and storage systems. 
Some of these can be accessed directly by users, whereas others cannot be accessed directly.

![cluster](img/cluster-small.svg)

 * Jumphost:
     * For all users
     * Security hardened machine for multi-hop SSH access to UI, DAI & SAI.
     * Nothings else: no job management, no mounts of shared file systems, no homes, no /apps, etc.
 * User Interface (UI):
     * Logins for all users (via the jumphost).
     * Slurm tools/commands installed job management: submitting batch jobs, canceling batch jobs, interactive jobs, job profiling, etc.
     * Read-only access to software, modules and reference data deployed with EasyBuild + Lmod in /apps/…
     * Both tmp and prm folders from large, shared, parallel file systems mounted (with root squash) for data transfers/staging.
 * Deploy Admin Interface (DAI):
     * Logins only for deploy admins (via the jumphost).
     * For deployment of centrally managed software or reference data sets using:
       Ansible playbooks + Lmod + EasyBuild
     * No Slurm tools/commands installed, so no accidental job management.
     * Read-write access to software, modules and reference data deployed with EasyBuild+Lmod in /apps/...
     * No access to large, shared, parallel file systems.
 * Sys Admin Interface (SAI):
     * Loging only for sys admins (via the jumphost).
     * Used to manage and monitor the cluster components: generate quota and Slurm usage reports, run cron jobs, etc.
     * Runs Slurm scheduling daemon that determines when jobs will be executed on which nodes.
     * Access to (complete) large shared parallel file systems (without root squash).
 * Compute Nodes:
     * No direct logins.
     * Crunch batch jobs submitted to Slurm workload manager.

## Naming Themes

{{ slurm_cluster_name | capitalize }} is part of the _League of Robots_ - a collection of HPC clusters - that use the same themes for naming various components:

 * Cluster itself and UIs are named after robots.  
   Production cluster are named after robots from the [Futurama scifi sitcom](https://futurama.fandom.com/wiki/Category:Robots).
   Test/development clusters are named after other robots.  
   E.g.: {{ slurm_cluster_name | capitalize }} UI = _{{ groups['user_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}_
 * Jumphosts are named after rooms preceding other rooms.  
   E.g.: {{ slurm_cluster_name | capitalize }} Jumphost = _{{ groups['jumphost'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}{% if slurm_cluster_domain | length %}.{{ slurm_cluster_domain }}{% endif %}_
 * Other machines that are part of the cluster and only accessible using internal network interfaces (schedulers, compute nodes, account servers, etc.)  
   will use a two character prefix _{{ stack_prefix }}_ followed by a dash and the function of the machine.  
   E.g. {{ slurm_cluster_name | capitalize }} compute node = _{{ groups['compute_vm'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}_
 * SAIs & DAIs may be named after root/carrot varieties or simply use the two character prefix _{{ stack_prefix }}_ plus function of the machine.  
   E.g.: {{ slurm_cluster_name | capitalize }} DAI = _{{ groups['deploy_admin_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}_  
   E.g.: {{ slurm_cluster_name | capitalize }} SAI = _{{ groups['sys_admin_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}_
