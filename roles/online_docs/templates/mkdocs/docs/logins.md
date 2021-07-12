#jinja2: trim_blocks:False
# How to start a session and connect to a User Interface server

## User Interface (UI) and Jumphost servers

![logins always via jumphost](img/logins.svg)

To submit jobs, check their status, test scripts, etc. you need to login on a _**User Interface (UI)**_ server using SSH.
Each cluster has its own _**UI**_ and the one for the {{ slurm_cluster_name | capitalize }} HPC cluster is named _**{{ groups['user_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}**_.
The UI and various other servers that make up the cluster receive updates during scheduled maintenance, 
but as this disrupts the processing of jobs, scheduled maintenance is planned only ~twice a year.

Not applying updates for several months could become a serious security risk for machines that are directly accessible via the internet.
Therefore the servers of the {{ slurm_cluster_name | capitalize }} cluster are on an internal network that is not directly accessible from the internet.
In order to access the UI you will need to hop via a _**Jumphost**_, 
which is a security hardened machine that is not in any way involved in the processing of jobs nor in storing data and does receive daily (security) updates.
In order to apply/activate security patches the _Jumphost_ may be temporarily unavailable, which means you cannot login to the _UI_ and hence cannot manage jobs nor create new ones, 
but existing jobs (running or queued) won't be affected and the cluster will continue to process those.
The _**Jumphost**_ for the {{ slurm_cluster_name | capitalize }} HPC cluster is named _**{{ groups['jumphost'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}{% if slurm_cluster_domain | length %}.{{ slurm_cluster_domain }}{% endif %}**_

## Request an account

First make sure you have an account. If you are new, please [follow these instructions to request an account](../accounts/).

## SSH client config and log in to UI via Jumphost

Configure your SSH client with the instructions for your operating system:

 * Configuration and login instructions for [Windows clients](../logins-windows/).
 * Configuration instructions for [macOS clients](../logins-macos-config/).
 * Configuration instructions for [Linux/Unix clients](../logins-linux-config/).
 * Login instructions for [macOS/Linux/Unix clients](../logins-macos-linux/).
