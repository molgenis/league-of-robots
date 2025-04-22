#jinja2: trim_blocks:False
# Data transfers - Push to or pull from {{ slurm_cluster_name | capitalize }} User Interface via Jumphost with GUI on macOS

On macOS you can use _**SSHFS**_ (SSH File System) to browse the file systems of the {{ slurm_cluster_name | capitalize }} cluster directly in the _**Finder**_
With SSHFS you will use the _**S**ecure **F**ile **T**ransfer **P**rotocol_, which is basically _FTP_ tunneled over an _SSH_ connection.

**Important**: starting from _**macOS 15.x Sequoia**_ Apple has deprecated the use of kernel extensions (kexts),
which will no longer work without overriding system security settings.
For file systems developers are now supposed to use a new API instead,
but this API is not finished yet nor properly documented yet, so cannot be used.
Therefore we currently advise against the use of _**FUSE for macOS**_
and suggest to use ```rsync``` on the command line instead to transfer data securely.
For details: 
 * [https://github.com/macfuse/macfuse/issues/987](https://github.com/macfuse/macfuse/issues/987)
 * [https://github.com/macfuse/macfuse/issues/1025](https://github.com/macfuse/macfuse/issues/1025)

## SFTP with SSHFS in the Finder

_SSHFS_ simulates a file system over a normal SSH connection and depends on the _FUSE libraries_, which extend the native macOS file handling capabilities via third-party file systems.
**Important**: SSHFS is great for browsing file systems and transferring data.
You may also open a remote file read-only in an application on your Mac for a quick peak at it's content,
but you should not open a remote file in read-write mode and start to make changes unless you want to get surprising results;
When you loose the network connection, for example due to unstable WiFi or when you put your Mac to sleep,
you may loose unsaved changes or worse end up with "half modified" corrupt files.
So when you want to modify a remote file, transfer a copy from the remote server to your local Mac, 
make changes to the copy, save them and transfer the updated file to the server.

### 1. Install FUSE for macOS

 * Download and install _**FUSE for macOS**_ from [https://osxfuse.github.io/](https://osxfuse.github.io/)
 * Note: when you are on _macOS Catalina_ or newer, you may get a security warning like this:  
   ![InstallFuseForMacOS](img/osxfuse-1.png)  
   Open the _Security Preferences_ pane from _System Preferences_ and  
   ![InstallFuseForMacOS](img/osxfuse-2.png)  
   1: Open the lock to make changes and  
   2: Allow the system to load the Fuse for macOS kernel extensions developed by _Benjamin Fleischer_

### 2. Install SSHFS for macOS

 * Download and install _**SSHFS**_ from [https://osxfuse.github.io/](https://osxfuse.github.io/)

### 3. Download and run mount-cluster-drives app

 * Download and unzip the [mount-cluster-drives](../attachments/mount-cluster-drives-macos.zip) AppleScript application.
 * Locate the ```mount-cluster-drives``` app, **right click** in the ```Finder``` application and select _**Open**_ from the contextual pop-up menu:
   ![Launch mount-cluster-drives.app](img/mount-cluster-drives-0b.png)  
   Note: when you are on macOS _Catalina_ or newer, you may get a security warning like this:  
   ![Launch mount-cluster-drives.app](img/mount-cluster-drives-0d.png)  
   Select _**Open**_ to continue. 
   (If you started the app by double clicking as opposed to choosing _Open_ from the contextual pop-up menu, 
   the window will look similar, but will lack the _Open_ button allowing you only to _Cancel_ or _Move to Bin_)
 * Depending on your macOS version, you may receive a pop-up requesting permission to allow access to the ```Finder``` application:  
   ![Allow access to the Finder.app](img/mount-cluster-drives-1.png)  
   Click _Ok_ to allow access to the ```Finder```.  
   If you want to revoke this permission or change it back to allow later on, you can do so in 
    _System Preferences_ -> _Security & Privacy_ prefs -> _Privacy_ tab -> _Automation_
 * The ```mount-cluster-drives``` app will mount the file systems of all configured clusters in a sub directory of your home dir named ```ClusterDrives```.  
   ![ClusterDrivesInFinder](img/mount-cluster-drives-2.png)  
   You can now drag and drop files in the ```Finder``` to transfer to / from {{ slurm_cluster_name | capitalize }}.
 * To unmount the _SSHFS_ shares click the eject button behind the name of the share.

##### Technical Details

Some technical details for the curious who like to know how this works or need to debug connection issues:

The ```mount-cluster-drives``` app parses special comment lines like this:
```
#
# Special comment lines parsed by our mount-cluster-drives script to create sshfs mounts.
# (Will be ignored by OpenSSH.)
# {% set sshfs_jumphost = groups['jumphost'] | first %}
# {% set sshfs_ui = groups['user_interface'] | first %}
#SSHFS {{ sshfs_ui }}_groups={{ sshfs_jumphost }}+{{ sshfs_ui }}:/groups/
#SSHFS {{ sshfs_ui }}_home={{ sshfs_jumphost }}+{{ sshfs_ui }}:/home/<youraccount>/
#
```
in the OpenSSH client configuration file for {{ slurm_cluster_name | capitalize }} ```${HOME}/.ssh/conf.d/{{ slurm_cluster_name }}```,
which was created by the ```ssh-client-config-for-{{ slurm_cluster_name }}``` app 
from the OpenSSH client configuration [instructions for macOS clients](../logins-macos/) page.

The parsed comment lines result in the following mount commands:
```
sshfs -o "defer_permissions,follow_symlinks,noappledouble,noapplexattr,reconnect,auto_xattr,auto_cache,connecttimeout=10,volname={{ sshfs_ui }}_groups" \
         "{{ sshfs_jumphost }}+{{ sshfs_ui }}:/groups/" \
         "~/ClusterDrives/{{ sshfs_ui }}_groups"
sshfs -o "defer_permissions,follow_symlinks,noappledouble,noapplexattr,reconnect,auto_xattr,auto_cache,connecttimeout=10,volname={{ sshfs_ui }}_home" \
         "{{ sshfs_jumphost }}+{{ sshfs_ui }}:/home/<youraccount>"
         "~/ClusterDrives/{{ sshfs_ui }}_home"
```

If you have access to multiple clusters, which were configured in a similar way, you may have multiple _SSHFS_ mounts,
which are all mounted with the same ```mount-cluster-drives``` app.

-----

Back to operating system independent [instructions for data transfers](../datatransfers/)
