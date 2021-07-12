#jinja2: trim_blocks:False
# SSH client config for users on macOS

The following assumes:

 * you have a ```${HOME}/.ssh``` folder with SSH keys (as generated using the instructions for requesting accounts)
 * and that you received a notification with your account name and that your account has been activated
 * and that you are on the machine from which you want to connect to the cluster
 * and that this machine runs **macOS _Sierra_ 10.12.2 or newer**, which includes OpenSSH 7.3p1 or newer.  
   Older versions lack several OpenSSH features we need and are incompatible.

## 1. Configure your SSH client

We've compiled an AppleScript app to configure your SSH client, which will:

 * Create an SSH client config from scratch if none exists.
 * Append to an existing one leaving the config for other servers/machines untouched.
 * Update the config for {{ slurm_cluster_name | capitalize }} if the app is executed again.

#### Quick Install

 * Download the zipped [ssh-client-config-for-{{ slurm_cluster_name }}](../attachments/ssh-client-config-for-{{ slurm_cluster_name }}-macos.zip) AppleScript application.
 * Locate and unzip the downloaded archive, which will result in an ```ssh-client-config-for-{{ slurm_cluster_name }}``` application  
   (optionally with ```.app``` extension depending on your display preferences).
 * Start the ```ssh-client-config-for-{{ slurm_cluster_name }}``` app by double clicking in the ```Finder``` application.
 * Follow the instructions ...  
   Check the _Detailed Walkthrough_ below if you experience problems or skip to the *Log in to {{ slurm_cluster_name | capitalize }}* section.

#### Detailed Walkthrough

The ```ssh-client-config-for-{{ slurm_cluster_name }}``` app is a wrapper for an installation script that will be executed in the ```Terminal``` application.
It will configure your SSH client by:

 * Adding an ```Include conf.d/*``` directive to your main ```${HOME}/.ssh/config``` file
 * Adding a ```${HOME}/.ssh/conf.d/{{ slurm_cluster_name }}``` config file for the {{ slurm_cluster_name | capitalize }} specific code.

The ```ssh-client-config-for-{{ slurm_cluster_name }}``` app will guide you through the following steps:

 * Depending on your macOS version, you may receive a pop-up requesting permission to allow access to the ```Terminal``` application:  
   ![Allow access to the Terminal.app](img/ssh-client-config-macos-1.png)  
   Click _Ok_ to allow access to the ```Terminal```.  
   If you want to revoke this permission or change it back to allow later on, you can do so in 
    _System Preferences_ -> _Security & Privacy_ prefs -> _Privacy_ tab -> _Automation_
 * The ```ssh-client-config-for-{{ slurm_cluster_name }}``` app will open the configuration script in the ```Terminal``` application and prompt for your account name.  
   ![Type your account name](img/ssh-client-config-macos-2.png)  
   Type your account name as you received it from the helpdesk and hit the \[ENTER\] key on your keyboard.  
   Optionally you can specify an alternative location for your private key file.  
   (Just hit the \[ENTER\] key to use the default private key file path.)
 * Your SSH client will now be configured for logins to {{ slurm_cluster_name }} via the corresponding jumphost
   followed by a connection test: the script will try to login using the created config with the account you supplied and the ssh command  
   ```ssh {{ groups['jumphost'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}+{{ groups['user_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}```  
   Make sure you are connected to the internet and hit the \[ENTER\] key on your keyboard to start the connection test.  
   ![Test SSH connection](img/ssh-client-config-macos-3.png)
 * If this was the first time you use your private key for an SSH session, you will get prompted to supply the password for your private key.  
   ![Enter password for your private key](img/ssh-client-config-macos-4.png)  
   Note that this is the password you chose yourself when you created the public private key pair.
   We have no backup whatsoever; If you forgot the password, you will have to start over by creating a new key pair.
 * Done! Hit the \[ENTER\] key on your keyboard to exit the configuration script.  
   ![Done](img/ssh-client-config-macos-5.png)
 * If you made a mistake, you can simply run the ```ssh-client-config-for-{{ slurm_cluster_name }}``` app again to update/fix your config.

## 2 Login

You can now use the config and [login with your ssh client](../logins-macos-linux/)

-----

Back to operating system independent [instructions for logins](../logins/)
