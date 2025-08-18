# Create a stratum 0 cvmfs_server (silo-*)

Minimal configuration can be found in ```/etc/cvmfs/default.local```
 * Respositories to mount
 * Proxy server that is used for the connection (default = direct)

Some commands to check the setup of your stratum 0 server:
 * Check client configuration: ```cvmfs_config chksetup```
 * Check mounts: ```cvmfs_config probe```
 * Check used settings: ```cvmfs_config showconfig```

Create a new repo and publish:
 * ```cvmfs_server mkfs [repo_name]```
 * ```cvmfs_server transaction [repo_name]```
 * ```cd /cvmfs/[repo_name]/``` and make changes
 * ```cvmfs_server publish -a [tag] [repo_name]```
 * check created repo: ```cvmfs_server info [repo_name]```

In order to mount the newly created repo on the client (startum 1), these configurations are needed on the client:
 * Add [repo_name] to ```CVMFS_REPOSITORIES``` in ```/etc/cvmfs/default.local```
 * Create ```/etc/cvmfs/config.d/[repo_name].conf``` and set
    * ```CVMFS_SERVER_URL=http://[cvmfs_server_ip]/cvmfs/[repo_name]```
    * ```CVMFS_PUBLIC_KEY=/etc/cvmfs/keys/[repo_name].pub```
 * Copy ```/etc/cvmfs/keys/[repo_name].pub``` to the client

NOTE:
- When repo is in production, add a cronjob to renew the master key every first and 15th day of the month:
```0 9 1,15 * * root /usr/bin/cvmfs_server resign [repo_name]``` (it expires after 30 days)

- For testing purposes, the client role is only deployed on talos. When moving to prodcution, please change the hosts in single_role_playbooks/cvmfs_client.yml.
