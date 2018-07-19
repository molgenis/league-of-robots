# Technical design for HPC cluster Gearshift #

Table of Contents:

* [Summary](#-summary)
* [Goals](#-goals)
* [Technical Design](#-technical-design)
* [Security](#-security)

---

# <a name="Summary"/> Summary

The Gearshift cluster will be the first UMCG Research IT cluster (HPC Generation 3).
This cluster will replace the aging GCC Research clusters (HPC Generation 2) **_Boxy_** and **_Calculon_**
In design, technology, tooling and administration it will form the blueprint for future UMCG Research IT HPC clusters.
The cluster will be using:

 * OpenStack Ocata cloud-technology for its main components: compute, networking, authentication and local storage
 * DELL/EMC Isilon storage for shared **_tmp_** storage.
 * Lustre storage for shared **_prm_** storage.

Deployment of its components will be done by Ansible-playbooks, and OpenStack-services will be run in Docker-containers.

---

# <a name="Goals"/> Goals

 * **Robustness**: The cluster is characterized by the atomized build of its components.
   This makes underlying hardware-components easily replaceable, with built-in redundancy for the main-services.
 * **Flexibility**: The compute-cluster itself is a virtual cluster.
   Through the use of Ansible-playbooks it is possible to replace and deploy new clusters when needed on the same hardware.
   These playbooks can be predefined, or created when needed.
 * **Portable**: using Ansible-playbooks in combination with Docker-containers for running OpenStack-services 
   makes it possible to build new clusters virtually independent of underlying hardware.
 * **Independent**: virtually all components are housed within the cluster itself.

---

# <a name="Technical-Design"/> Technical design

## Hardware

The cluster contains the following hardware components:

 - 12 x Dell Poweredge R630, with 2 1TB SAS, and 2 1.6TB SSD's
 - 4 x Dell/EMC Isilon X410 – 136T
 - 1 x Mellanox Infiniband 18-ports switch
 - 1 x Dell Networking S3048-ON 48-ports 1Gb-switch
 - 1 x Dell Networking S6000-ON 32-ports 40Gb-switch

### Global design

The cluster consists of 12 servers and 4 storage units, connected to 2 network-switches, and 1 interconnect-switch for the storage-units.
The base OS for the servers will be Ubuntu 16.04 LTS, with OpenStack Ocata as the platform of choice for running all full VMs.
All VMs in the cluster will run Centos 7.3.
The OpenStack services will each run in a separate Docker container also based on Ubuntu 16.04 LTS.

Figure 1. Global design Gearshift-cluster

 ![](./media/media/image2.jpeg)

### OpenStack design

All OpenStack services run in separate Docker containers.
The *gs-openstack* node is the controller for all essential OpenStack services: 
Nova-controller, Neutron-controller, Keystone (authentication) and Horizon (GUI).
The OpenStack infrastructure will rely on a RabbitMQ cluster as the messaging service for communication within an OpenStack-service.
This cluster will contain 3 nodes: 1 on the *gs-openstack* node and one on each of the *gs-compute01* and *gs-compute02* nodes.
The entire OpenStack configuration will use a MariaDB Galera cluster with 3 cluster members: *gs-openstack*, *gs-compute01* and *gs-compute02*.

The *gs-compute* nodes will furthermore contain 2 additional OpenStack services in a docker container: Nova-compute and Cinder-volume.
Cinder-volume will be providing the /local mount on all Compute VMs.

 ![](./media/media/image3.jpeg)
 Figure 2. OpenStack-design

### Network design

The cluster will be connected to 4 separate networks:

 * VLAN  13 - 10 Gbit: for external connections
 * VLAN 983 -  1 Gbit: for management and cluster communication
 * VLAN 984 -  1 Gbit: for Out-of-band communication with IDRAC / IPMI management controllers
 * VLAN 985 - 10 Gbit: for communication with storage-arrays (NFS / Lustre mounts)

The cluster network will be served by OpenStack Neutron, and will contain 3 networks.
These networks will be created over Linux bridges on the OpenStack hypervisors.
The *gs-openstack* (controller) will have 2 bridges.
One bridge will serve a 10G network for external connections (VLAN 13), 
the other will serve 2 networks for management (VLAN 983) and storage (VLAN 985) (Figure 3).
The *gs-compute[0-9]* nodes will have 1 bridge, for management (VLAN 983) and storage (VLAN 985).
These networks will be tunneled to the VMs (Figure 4).
The compute VMs will have 2 networks: management (VLAN 983) and storage (VLAN 985).

Figure 3. Network design for gs-openstack controller node

 ![](./media/media/image4.jpeg)

Figure 4. Network design for gs-compute[0-9] node

 ![](./media/media/image5.jpeg)

Figure 5. Network design for gs-vcompute[0-9] virtual compute node

 ![](./media/media/image6.jpg)

### Compute cluster design

The compute cluster will contain 11 compute VMs, based on Centos 7.3,
which will have access local storage, and 2 storage-arrays for shared storage (figure 6).
The /apps, /groups/${group}/tmp01 and /home folders will be served by the Isilon-storage array in Data Centre Eemspoort (DCE).
The /groups/${group}/prm01/ folders will be served by a Lustre FS from the *data handling* storage facilities in Data Centre DUO.

All access to the compute cluster (logins) is exclusively via SSH.
All logins (inbound SSH traffic) from both internal (RUG/UMCG) as well as from external networks 
require a double hop via the proxy VM *airlock.hpc.rug.nl* as stepping stone (Figure 6).
Several machines may use direct connections to external networks for outbound traffic 
(E.g. Apspera or rsync over SSH or SFTP data transfers initiated on a UI or DAI).

Scheduling for the cluster will be done by a dockerized SLURM instance hosted on the gs-controller.

Figure 6. Compute-cluster-design

 ![](./media/media/image7.jpeg)

### Administration/management design

The cluster uses several VMs for administration/managment of the cluster hardware, software, jobs and users.
These VMs are created on the OpenStack controller node (gs-openstack), and are based on Centos7.3 (figure 7).

 - **airlock.hpc.rug.nl**
   - Proxy (stepping stone)
   - For SSH access to UI, SAI and DAI servers

 - **gearshift.hpc.rug.nl**
   - User Interface (**UI**)
   - For SLURM job management: submitting batch jobs, canceling batch jobs, interactive jobs, job profiling, etc.
   - Logins for users via Proxy

 - **imperator.hpc.rug.nl**
   - Sys Admin Interface (**SAI**)
   - For monitoring cluster health, quota reports, SLURM usage reports and various cron-jobs.
   - Logins only for sys admins via Proxy

 - **sugarsnax.hpc.rug.nl**
   - Deploy Admin Interface (**DAI**).
   - For deployment of software, modules and reference data using
     - Ansible playbooks + Lmod + EasyBuild
   - Logins only for deploy admins via Proxy

 Figure 7

 ![](./media/media/image8.jpeg)

### Tooling

#### Git repository

 All tooling used to create the OpenStack cluster and the virtual
 compute cluster is available from the *gearshift* git repository. This
 repository is hosted at *git.webhosting.rug.nl* A local checkout of
 this repository is sufficient to roll out a new cluster during this
 process, a password (ansible vault) will be generated with which all
 passwords used will be encrypted. This password is not stored in the
 repository. Deployment commands are documented in the *README.md* of
 the gearshift repository.

#### Ansible

The ansible playbooks in this repository use ansible roles from the hpc-cloud repository.
The roles are imported here explicitly by ansible using ansible galaxy.
The roles install various docker images built and hosted by RUG webhosting.
The docker images are built by jenkins from separate git repositories on
 [ https://git.webhosting.rug.nl ](https://git.webhosting.rug.nl/)
and uploaded to the docker repository.

#### Monitoring

Both the HPC cluster and the OpenStack cluster on which the HPC cluster is installed will be monitored.
Resource usage and performance characteristics of the dockerized OpenStack components will be reported 
to an externally running Prometheus server using the cadviser tool.
The Prometheus server will also monitor various metrics of the physical host using the node\_exporter tool.
These metrics will be visualized using Grafana.
Grafana will run on the same VM as the Prometheus server.
Both Grafana and Prometheus server will run inside Docker containers on this VM.

| What                                                 | How                                                                | Where                                       | Who |
| ---------------------------------------------------  | ------------------------------------------------------------------ | --------------------------------------------| --- |
| OpenStack components <br/> (Resource usage & health) | cadvisor & prometheus                                              | gs-openstack & gs-compute*                  | CIT |
| Server stats                                         | node exporter                                                      | all servers physical and virtual            | CIT |
| File integrity & security                            | Stealth check by nagios <br/> https://github.com/fbb-git/stealth   | al UI, DAI, SAI & Proxy servers             | CIT |
| Slurm node health                                    | LBNL Node Health Check  <br/> https://github.com/mej/nhc           | gs-vcompute*                                | CIT |
| Integrity of everything deployed with EasyBuild      | check_integrity.bash <br/> https://github.com/molgenis/depad-utils | DAI                                         | GCC |
| FileSystem Quota reporting                           | quota.bash <br/> https://github.com/molgenis/cluster-utils         | DAI                                         | GCC |
| SLURM cluster usage reporting                        | slurm_report.bash <br/> https://github.com/molgenis/cluster-utils  | DAI                                         | GCC |
| Account expiration and group memberships             | COmanage                                                           | SURF SCZ COmanage                           | GCC |
| SLURM Job Profiling                                  | SLURM plugin & grafana                                             | SAI/DAI?                                    | GCC |

#### DNS

All gearshift-nodes are placed in the rug.nl DNS.
This DNS-server is based on BIND, and provides DNS for both the internal and external networks within the cluster.

| Subnet        | DNS servers                     |
| ------------- | ------------------------------- |
| 172.23.40.0   | 172.23.40.247 and 172.23.40.248 |
| 172.23.34.0   | 172.23.32.247 and 172.23.32.248 |

#### Spacewalk

The compute nodes of the virtual HPC cluster will be installed using packages from the *spacewalk.hpc.rug.nl* server.
Packages for the cluster will be placed in a channel named *umcg-research.*

ToDo: Channel versioning!
      We need a "freeze" of packages per piece of infra (e.g. a cluster) and per maintenance window.

Since this server is only needed during installation and upgrades of the compute cluster, it is not redundant.
An ansible playbook is available in the *hpc/spacewalk* repository on *git.webhosting.rug.nl.*
With this playbook it is possible to build a new Spacewalk server within 15 minutes.

### Storage Design

Storage will be provided from three different sources:

#### 1 Gearshift Isilon

 * Location: Datacenter Eemspoort
 * Isilon OneFS version 8.0.0.*
 * 4 nodes
 * External networks:
   * Storage     172.23.32.0/22 DNS 172.23.32.247/248
   * Management  172.23.40.0/24
 * Internal networks:
   * 128.128.121.1 - 128.128.121.128 /24
   * 128.128.122.2 - 128.128.122.128 /24
   * 128.128.123.3 - 128.128.123.128 /24
 * NFS mounts

| Mount Source                              | Mount Destination            | Mode       | Clients |
| ----------------------------------------- | ---------------------------- | ---------- | ------- |
|```/ifs/umgcst10/apps/```                  |```/apps/```                  | read-only  | gs-vcompute* virtual compute nodes & UIs |
|```/ifs/umgcst10/apps/```                  |```/.envsync/umcgst10/apps/```| read-write | DAIs    |
|```/ifs/umgcst10/groups/${group}/tmp01/``` |```/groups/${group}/tmp01/``` | read-write | gs-vcompute* virtual compute nodes |
|```/ifs/umgcst10/home/```                  |```/home/```                  | read-write | gs-vcompute* virtual compute nodes, UIs & DAIs |

#### 2 Datahandling Lustre

 * Location: Datacenter DUO
 * Lustre version 2.10.*
 * External networks:
     * Storage     172.23.32.0/22
 * Lustre mounts

| Mount Source                              | Mount Destination            | Mode       | Clients |
| ----------------------------------------- | ---------------------------- | ---------- | ------- |
|```/???/groups/${group}/prm01/```          |```/groups/${group}/prm01/``` | read-write | UIs & SAIs |

#### 3 Local storage on hypervisors.

 * Location: each gs-vcompute* virtual compute node will mount a local SSD via Cinder Block-storage.
 * ext4 mounts:

| Mount Source                              | Mount Destination            | Mode       | Clients |
| ----------------------------------------- | ---------------------------- | ---------- | ------- |
|```/dev/sd?/```                            |```/apps/```                  | read-write | DAIs    |
|```/dev/sd?/```                            |```/local/```                 | read-write | gs-vcompute* virtual compute nodes |

### Logging

All systems (physical and virtual) will log:

 * Locally in /var/log/
 * Remotely by sending logs to a central logging server, based on Logstash/Elastic search.
   This server will be served outside the Gearshift cluster infra, but within the CIT infrastructure.

ToDo: List of local log files that will be forwarded to the remote log server:

 * /var/log/audit/audit.log
 * /var/log/cron
 * /var/log/nhc.log
 * /var/log/messages
 * /var/log/munge/munged.log
 * /var/log/secure
 * /var/log/slurmd.log
 * /var/log/slurmctld.log
 * /var/log/yum.log

### User authentication and authorization-attributes

User authentication and authorization will be done via the Comanage for the Science Collaboration Zone (SCZ). All authentication will be 2-factor, and the authorization workflow will be designed and maintained by GCC. 

The following attributes will be part of the authorization process. The item marked with * will be provisioned by Comanage (All personalized attributes are examples in this scheme):

User:

dn: uid=r.rohde@rug.nl,ou=users,ou=bbmri,o=co 
objectClass: ndsLoginProperties
objectClass: inetOrgPerson
objectClass: ldapPublicKey
objectClass: Top
objectClass: organizationalPerson
objectClass: Person
objectClass: posixAccount
cn: Remco Rohde *
gidNumber: 10000001
homeDirectory: /home/10000001
sn: Rohde *
uid: r.rohde@rug.nl *
uidNumber: 10000001 
description: Me, Myself and I 
givenName: Remco *
loginDisabled: FALSE
loginShell: /bin/bash
mail: r.rohde@rug.nl *
mobile: +31 6123456 *
o: Rijksuniversiteit Groningen *

Group:

dn: cn=TestRSGroup01:Members,ou=groups,ou=bbmri,o=co
objectClass: Top
objectClass: groupOfNames
cn: TestRSGroup01:Members *
description: TestRSGroup01:Members
member: uid=r.rohde@rug.nl,ou=users,ou=bbmri,o=co *


---

# <a name="Security"/> Security

Several measures are in place to ensure security for hardware and software in the entire infrastructure:

 * The hardware-infrastructure is housed in an RUG datacentre.
   Access is only possible through an official procedure.
   There are several access codes / keys in place for both rooms & enclosures.
 * All SSH logins by regular (non-admin) users are handled by a proxy machine as stepping stone.
   Proxy machines are secured with an *iptables* type firewall, limiting traffic to SSH over TCP ports 22 and 80.
 * (Security) updates:
   * Proxy machines receive daily security updates and are rebooted automagically weekly to ensure updated kernels are used max 7 days after the update.
   * All other machines:
     * either block all incoming traffic on external network interfaces (on UI, DAI and SAI)
     * or do not have external network interfaces at all
     * Receive updates during bi-annual scheduled maintenance. 
 * Network separation will be established via private VLANS.
 * OpenStack security will be implemented, limiting TCP/IP-ports on a need-only basis to the underlying VMs.
 * Dockerized OpenStack services will be deployed via Ansible playbooks. 
   All security keys and passwords (OpenStack accounts, database accounts etc.) related to OpenStack will be stored in an encrypted and password-protected Ansible vault.
 * Access to the OpenStack infrastructure will be handled by Keystone, both for authentication and authorization.

