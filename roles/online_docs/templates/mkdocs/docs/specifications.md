#jinja2: trim_blocks:False
# Technical specifications of the High Performance Computing (HPC) environment on {{ slurm_cluster_name | capitalize }}

## Software

Key ingredients of the High Performance Computing (HPC) environment of the {{ slurm_cluster_name | capitalize }} cluster

 * Linux OS: [CentOS](https://www.centos.org/) {{ hostvars[groups['user_interface'][0]]['ansible_distribution_version'] }} with [{{ repo_manager | capitalize }}]({{ external_hrefs[repo_manager] }}) for package distribution/management.
 * Job scheduling: [Slurm Workload Manager](https://slurm.schedmd.com/) {{ slurm_version.stdout }}
 * Module system: [Lmod](https://github.com/TACC/Lmod) {{ lmod_version.stdout }}
 * Deployment of (Bioinformatics) software: [EasyBuild](https://github.com/easybuilders/easybuild)

## Virtual Servers

 * Jumphosts: _{% for server in groups['jumphost'] %}{{ server | regex_replace('^' + ai_jumphost + '\\+','')}}{% if not loop.last %}, {% endif %}{% endfor %}_
 * User Interfaces (UIs): _{% for server in groups['user_interface'] %}{{ server | regex_replace('^' + ai_jumphost + '\\+','')}}{% if not loop.last %}, {% endif %}{% endfor %}_
 * Deploy Admin Interfaces (DAIs): _{% for server in groups['deploy_admin_interface'] %}{{ server | regex_replace('^' + ai_jumphost + '\\+','')}}{% if not loop.last %}, {% endif %}{% endfor %}_
 * Sys Admin Interfaces (SAIs): _{% for server in groups['sys_admin_interface'] %}{{ server | regex_replace('^' + ai_jumphost + '\\+','')}}{% if not loop.last %}, {% endif %}{% endfor %}_
 * Compute Nodes: _{% for server in groups['compute_vm'] %}{{ server | regex_replace('^' + ai_jumphost + '\\+','')}}{% if not loop.last %}, {% endif %}{% endfor %}_

## Shared Storage

A Logical File System (LFS) is usually a piece of a larger Physical File System (PFS) that serves a specific need for a specific user group. 
In case it as a network file system you could call it a _share_. 
In addition to LFS-ses for _home dirs_ and the centrally deployed _software_  and _reference data_ the {{ slurm_cluster_name | capitalize }} HPC cluster has access to the following LFS-ses:

 * Available _tmp_ LFS-ses: {% if lfs_mounts | selectattr('lfs', 'search', 'tmp[0-9]+$') | list | length %}{% for mount in lfs_mounts | selectattr('lfs', 'search', 'tmp[0-9]+$') | list %}{{ mount.lfs }}{% if not loop.last %}, {% endif %}{% endfor %}{% else %}None{% endif %}
 * Available _prm_ LFS-ses: {% if lfs_mounts | selectattr('lfs', 'search', 'prm[0-9]+$') | list | length %}{% for mount in lfs_mounts | selectattr('lfs', 'search', 'prm[0-9]+$') | list %}{{ mount.lfs }}{% if not loop.last %}, {% endif %}{% endfor %}{% else %}None{% endif %}
 * Available _arc_ LFS-ses: {% if lfs_mounts | selectattr('lfs', 'search', 'arc[0-9]+$') | list | length %}{% for mount in lfs_mounts | selectattr('lfs', 'search', 'arc[0-9]+$') | list %}{{ mount.lfs }}{% if not loop.last %}, {% endif %}{% endfor %}{% else %}None{% endif %}

## Resources available to Slurm jobs

| Resource            | Amount/value/name                            |
|:------------------- | --------------------------------------------:|
| Compute nodes       | {{ vcompute_hostnames }}                     |
| Cores/node          | {{ vcompute_max_cpus_per_node }}             |
| RAM/node \(MB\)     | {{ vcompute_max_mem_per_node }}              |
| Storage/node \(MB\) | {{ vcompute_local_disk | default(0, true) }} |
| Node features       | {{ vcompute_features }}                      |

