#jinja2: trim_blocks:False
# Generate a public/private key pair with OpenSSH on macOS and Linux

## Generate a key pair with OpenSSH

### Open a terminal/shell

 * On **macOS**: A terminal app is already part of the OS by default. Optionally you may want to install the [XQuartz X server](http://xquartz.macosforge.org/) for graphical apps.  
   Open the Terminal application, which is located in _**Applications**_ -> _**Utilities**_ -> _**Terminal.app**_.
 * On **Linux / Unix**: A terminal app is already part of the OS by default and usually you also already have an X window server installed for graphical apps. Consult your distro documentation for details.

### Generate key pair

To generate a key pair with OpenSSH, type the following command:
```no-highlight
ssh-keygen -t ed25519 -C "your_comment_see_below"
```
As comment/label for your keys please use **your first initial followed by (optionally your middle name followed by) your family name** all in lowercase and without any separators like spaces, dots or underscores. 
So if your name is _**Jack Peter Frank the Hippo**_, please use _**jthehippo**_ as comment, so we can easily identify the key as yours.

### Select where to store the key pair

The ssh-keygen application will now ask you where you want to save the private key:
```no-highlight
Enter file in which to save the key (/path/to/your/home_dir/.ssh/id_ed25519): <return>
```
By default it will be stored in your ```~/.ssh/``` folder where ```~``` is your home directory.
The public key will be stored in the same location as the private key, start with the same name as the private key and have a ```.pub``` suffix.  

WARNING:

 1. Accepting the default will overwrite an existing key pair,
    so only accept the default if you either do not have a default key pair yet
    or if you want to replace your default key pair.
 2. If you create a key pair in a non-default location, 
    you will need to explicitly specify which key file to use when you start a session.
    Consult the OpenSSH manual for details.

### Secure the private key

Secure your private key with a good password. DO NOT choose a simple password or even worse an empty one!
```no-highlight
Enter passphrase (empty for no passphrase): <Type the passphrase>
```
Note: this is a password to encrypt your private key. It is not a password for you account. 
The ssh-keygen command will now generate two files. In case you chose the default location these will be:

 * Your private key in ```~/.ssh/id_ed25519```
 * Your public key in ```~/.ssh/id_ed25519.pub```

If you forgot to add a password to your private key or if you want to change the password later on, you can add a (new) password to your existing private key with:
```no-highlight
ssh-keygen -p -f ~/.ssh/id_ed25519
```

## Request account and have the public key linked to your account

To request an account, [contact the helpdesk via email](../contact/) and

 * Attach the ```~/.ssh/id_ed25519.pub``` public key file generated with the ```ssh-keygen``` command.  
   If you cannot see / find the public key file, you most likely stored the file in a folder starting with a ```.```; e.g. in your ```~/.ssh``` folder which is the default.
   Folders and files that start with a ```.``` are *hidden* files and not displayed by default.
   On macOS you can press ```<Shift>+<Cmd>+<.>``` to toggle the visibility of hidden files in *Open...* and *Save...* dialog windows.
   Please use a search engine for a solution to display hidden files in other situations like Finder windows or on other platforms.
 * Please motivate your account request and
     * For **guest** accounts to access only a data transfer machine associated with the cluster:
         * Specify the project your are working on and add your collaborators on CC.
     * For **regular** accounts to access the cluster:
         * Specify the groups you want to become a member of in order to access specific data sets. 
           Put all group owners of the corresponding groups on CC and ask them to approve your request in a reply to the helpdesk. 
           If you do not know who the group owners are, please consult a colleague or your boss / P.I. / team lead / project lead / etc.
         * Please add a staff member of the department/group where you are appointed or the project you are involved in on CC and 
           ask him/her to confirm your appointment/involvement and the expiration date of your contract in a reply to the helpdesk. 
           We will then setup your cluster account with the same expiration date.  
           (A staff member can be the secretary of your department or your boss / P.I. / team lead / project lead / etc.)  
       Please note: we cannot give you access until we have received both approval from at least one group owner and a confirmation for the expiration date of your contract/collaboration.
 * Never ever email/give anyone your private key! If you do, the key is no longer *private* and useless for security: trash the key pair and start over by generating a new pair.
 * If you ever suspect that your private key may have been compromised (laptop got stolen, computer got infected with a virus/trojan/malware, etc.): 
    * [notify the helpdesk](../contact/) immediately, so we can revoke the public key for the compromised private key
    * and start over by generating a new pair.

## Start using servers/services

 * Once you get notified by email that your account is ready you can proceed to [login](../logins/)
 * If you want to request access to an additional group, send your request by email to the helpdesk and with the corresponding group owners on CC.
   You can lookup the group owners yourself on the cluster using:

             module load cluster-utils
             colleagues -g <groupname>