#jinja2: trim_blocks:False
# Technical specifications of the High Performance Computing (HPC) environment on {{ slurm_cluster_name | capitalize }}

## Software

Key ingredients of the High Performance Computing (HPC) environment of the {{ slurm_cluster_name | capitalize }} cluster

 * Linux OS: [{{ cluster_os_name }}]({{ external_hrefs[cluster_os_name] }})
   version {{ cluster_os_version }}
   {% if cluster_repo_manager | default('none') != 'none' -%}
   with [{{ cluster_repo_manager | capitalize }}]({{ external_hrefs[cluster_repo_manager] }}) for package distribution/management
   {%- endif %}
 * Job scheduling: [Slurm Workload Manager](https://slurm.schedmd.com/) {{ slurm_version.stdout }}
 * Module system: [Lmod](https://github.com/TACC/Lmod) {{ lmod_version.stdout }}
 * Deployment of (Bioinformatics) software: [EasyBuild](https://github.com/easybuilders/easybuild)

## Servers

 * Jumphosts: _{% for server in groups['jumphost'] %}{{ server}}{% if not loop.last %}, {% endif %}{% endfor %}_
 * User Interfaces (UIs): _{% for server in groups['user_interface'] %}{{ server }}{% if not loop.last %}, {% endif %}{% endfor %}_
 * Deploy Admin Interfaces (DAIs): _{% for server in groups['deploy_admin_interface'] %}{{ server }}{% if not loop.last %}, {% endif %}{% endfor %}_
 * Sys Admin Interfaces (SAIs): _{% for server in groups['sys_admin_interface'] %}{{ server }}{% if not loop.last %}, {% endif %}{% endfor %}_
 * Compute Nodes: _{% for server in groups['compute_node'] %}{{ server }}{% if not loop.last %}, {% endif %}{% endfor %}_
{% if groups['chaperone'] is defined %}
 * Chaperones: _{% for server in groups['chaperone'] %}{% if hostvars[server]['ansible_host'] is defined %}{{ hostvars[server]['ansible_host'] }}{% else %}{{ server }}{% endif %}{% if not loop.last %}, {% endif %}{% endfor %}_
{% endif %}

## Shared Storage

A Logical File System (LFS) is usually a piece of a larger Physical File System (PFS) that serves a specific need for a specific user group. 
In case it as a network file system you could call it a _share_. 
In addition to LFS-ses for _home dirs_ and the centrally deployed _software_  and _reference data_ the {{ slurm_cluster_name | capitalize }} HPC cluster has access to the following LFS-ses:

{% if lfs_mounts | selectattr('lfs', 'search', 'arc[0-9]+$') | list | length -%}
 * Available _arc_ LFS-ses: {% for mount in lfs_mounts | selectattr('lfs', 'search', 'arc[0-9]+$') | list %}{{ mount.lfs }}{% if not loop.last %}, {% endif %}{% endfor %}
{% endif -%}
{% if lfs_mounts | selectattr('lfs', 'search', 'prm[0-9]+$') | list | length -%}
 * Available _prm_ LFS-ses: {% for mount in lfs_mounts | selectattr('lfs', 'search', 'prm[0-9]+$') | list %}{{ mount.lfs }}{% if not loop.last %}, {% endif %}{% endfor %}
{% endif-%}
{% if lfs_mounts | selectattr('lfs', 'search', 'rsc[0-9]+$') | list | length -%}
 * Available _rsc_ LFS-ses: {% for mount in lfs_mounts | selectattr('lfs', 'search', 'rsc[0-9]+$') | list %}{{ mount.lfs }}{% if not loop.last %}, {% endif %}{% endfor %}
{% endif -%}
{% if lfs_mounts | selectattr('lfs', 'search', 'tmp[0-9]+$') | list | length -%}
 * Available _tmp_ LFS-ses: {% for mount in lfs_mounts | selectattr('lfs', 'search', 'tmp[0-9]+$') | list %}{{ mount.lfs }}{% if not loop.last %}, {% endif %}{% endfor %}
{% endif -%}

## Resources available to Slurm jobs
{% for partition in slurm_partitions %}
  {% set partition_max_cpu_cores_per_node = groups[partition['name']] | map('extract', hostvars, 'slurm_max_cpu_cores_per_node') | first %}
  {% set partition_max_mem_per_node       = groups[partition['name']] | map('extract', hostvars, 'slurm_max_mem_per_node') | first %}
  {% set partition_local_disk_per_node    = groups[partition['name']] | map('extract', hostvars, 'slurm_local_disk') | first %}
  {% set partition_node_features          = groups[partition['name']] | map('extract', hostvars, 'slurm_features') | first %}
#### {{ partition.name }} partition
| Resource            | Amount/value                             |
|:------------------- | ----------------------------------------:|
| Number of nodes     | {{ groups[partition['name']] | length }} |
| Cores/node          | {{ partition_max_cpu_cores_per_node }}   |
| RAM/node \(MB\)     | {{ partition_max_mem_per_node }}         |
| Storage/node \(MB\) | {{ partition_local_disk_per_node  }} |
| Node features       | {{ partition_node_features }}            |
{% endfor %}
