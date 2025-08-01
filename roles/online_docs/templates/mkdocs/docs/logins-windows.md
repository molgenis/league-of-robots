#jinja2: trim_blocks:False
# SSH config and login to UI via Jumphost for users on Windows

There are two options to login to clusters from Windows

 1. (preferred) Either by using MobaXterm client software which requires installation
 2. alternative option is to use built-in OpenSSH software that comes pre-installed with newer versions of Windows (10+)


## 1. MobaXterm option

The instructions below assume:

 * you've already downloaded _**[MobaXterm](https://mobaxterm.mobatek.net)**_ to generate a pair of SSH keys (using the instructions for requesting accounts)
 * and verified your _**MobaXterm**_ version is **12.3 or newer** (older ones have a known bug and won't work.)
 * and will now use _**MobaXterm**_ to login to the cluster
 * and that you received a notification with your account name and that your account has been activated
 * and that you are on the machine from which you want to connect to the cluster.

If you prefer another terminal application consult the corresponding manual.

### 1.1 Launch MobaXterm and create a new session

![launch MobaXterm](img/MobaXterm5.png)

 * Launch _**MobaXterm**_ version **12.3 or newer** and click the _**Session**_ button from the top left of the window.
 * A _**Session settings**_ window will popup.

### 1.2 Configure a new session

![Configure MobaXterm session](img/MobaXterm6.png)

 * Session type
    * 1: Select _**SSH**_.
 * Basic SSH settings tab
    * 2: _Remote host_ field: Use the name of the User Interface (UI) _**{{ groups['user_interface'] | first }}**_ .
    * 3: _Specify username_ field: Use your _**account name**_ as you received it by email from the helpdesk.
 * Advanced SSH settings tab:
    * 4: _Use private key_ field: Select the _**private key file**_ you generated previously.

![Configure MobaXterm session](img/MobaXterm7a.png)

 * Network settings tab
    * Click on the large _**SSH gateway (jump host)**_ button.

![Configure MobaXterm session](img/MobaXterm7b.png)

 * SSH jump hosts popup window
    * 5: _Gateway host_ field: Use _**{{ first_jumphost_address }}**_ for the _Jumphost_ address.
    * Optional: _Port_ field: The default port for SSH is _**22**_ and this is usually fine. 
      However if you encounter a network where port 22 is blocked, you can try port 443. (Normally used for HTTPS, but our Jumposts can use it for SSH too.)
    * 6: _Username_ field: Use your _**account name**_ as you received it by email from the helpdesk (same as for 3).
    * 7: Select _Use SSH key_ and
    * 8: Click the small button to select the _**private key file**_ you generated previously (same as for 4).  
      **Important**: the path to the selected private key will be shown.
      Depending on how you browsed to the private key file, the path may 
        * Either start with a drive letter, colon and single backslash.  
          E.g. ```H:\path\to\private_key.ppk```  
          This is fine and should work.
        * Or start with two backslashes.  
          E.g. ```\\path\to\private_key.ppk```  
          This won't work and MobaXterm will fail silently: no login, no error, no nothing.  
          Use a different route in the GUI to browse to your private key file such that the path starts with a drive letter, colon and single backslash.
    * 9: Click _**OK**_

 * Back in the network settings tab
    * 10: Click _**Ok**_

### 1.3 Password (popup)

![Configure MobaXterm session](img/MobaXterm8.png)

 * MobaXterm should now produce a popup window where you can enter the _**password**_ to decrypt the private key.
    * Note this is the password you chose yourself when you created the key pair.
    * You are the only one that ever knew this password; we have no copy/backup whatsoever on the server side. 
      If you forgot the password, the private key is useless and you will have to start over by creating a new key pair.

### 1.4 Password again (prompt)

![Configure MobaXterm session](img/MobaXterm9a.png)

MobaXterm should now start a session and login to the _Jumphost_ resulting in

 * a session tab (left part of the window with white background) and 
 * a terminal where you can type commands (right part of the screen with black background).

In the terminal tab _**MobaXterm**_ will try to login from the _Jumphost_ to the _User Interface (UI)_ with the same private key file. 
This may require retyping the password to decrypt the private key a second time, this time in the terminal tab.

### 1.5 Session established

You have now logged in to the UI {{ groups['user_interface'] | first }}.

![Configure MobaXterm session](img/MobaXterm9b.png)

The left part of the window with white background switched to a file browser, 
while the right part remains a terminal where you can type commands.


## 2. Using Windows OpenSSH

### 2.1 Configuring session

##### 2.1.1 Configure Certificate Authority's (CA) public key to verify the identity of cluster servers

Append the public key from the Certificate Authority we used to sign the host keys of our machines to your ```${HOME}/.ssh/known_hosts``` file.  
Open a terminal and copy paste the following commands:
```
#
# Create new known_hosts file and append the UMCG HPC CA's public key.
#
printf '%s\n' \
            "@cert-authority {{ known_hosts_hostnames }} {{ lookup('file', ssh_host_signer_ca_private_key + '.pub') }} for {{ slurm_cluster_name }}" \
    > "${HOME}/.ssh/known_hosts.new"
if [[ -e "${HOME}/.ssh/known_hosts" ]]; then
    #
    # When user already had a known_hosts file, then 
    # remove a potentially outdated CA public key for the same machines based on the slurm_cluster_name: {{ slurm_cluster_name }}
    # and append all other lines to the new known_hosts file. 
    #
    sed '/^\@cert-authority .* for {{ slurm_cluster_name }}$/d' "${HOME}/.ssh/known_hosts" \
| sort >> "${HOME}/.ssh/known_hosts.new"
fi
#
# Make new known_hosts file the default.
#
mv "${HOME}/.ssh/known_hosts.new" "${HOME}/.ssh/known_hosts"
```

## 2.1.2 Add include directive to main SSH config file

Use a text editor to add the following line
```
Include conf.d/*
```
to the beginning of your ```${HOME}/.ssh/config``` file.
Important: this _Include_ directive must precede any lines containing _Host_ or _Match_ directives,
otherwise the _Include_ will only apply to a specific set of hosts.

## 4. Create SSH config file with generic settings

Now we need to configure some generic settings for transparent multi-hop SSH.
Open your ```${HOME}/.ssh/conf.d/generic``` file in a text editor and add the lines below.

```
#
# Generic stuff for key management.
#
IgnoreUnknown UseKeychain
    UseKeychain yes
IgnoreUnknown AddKeysToAgent
    AddKeysToAgent yes
#
# Universal jumphost settings for triple-hop SSH.
#
Host *+*+*
    ProxyCommand ssh -x -q $(echo "${JUMPHOST_USER:-%r}")@$(echo %h | sed 's/+[^+]*$//') -W $(echo %h | sed 's/^[^+]*+[^+]*+//'):%p
```

## 5. Create SSH config file for {{ slurm_cluster_name | capitalize }}

Now we need to configure transparent multi-hop SSH for {{ slurm_cluster_name | capitalize }}.
Open your ```${HOME}/.ssh/conf.d/{{ slurm_cluster_name }}``` file in a text editor and add the lines below.

* Replace all occurrences of _**youraccount**_ with the account name you received from the helpdesk.
* Edit the line ```IdentityFile "~/.ssh/id_ed25519"``` to point to the private key file you generated if you did not save it in the default location, which is "~/.ssh/id_ed25519".


### Download .bat file

You can download the script from here [logins-windows.bat](../logins-windows.bat)

 - but **you will twice need to confirm that the file is safe and that your really want to store it** (Under download you will need to click `Keep`, then `Show more` > `Keep anyway`)
 - alternatively you can open the link and copy the file content and paste on your Windows computer and save it with 'windows-login.bat' filename

Once you execute the file, the configuration will be done almost automatically.

-----

Back to operating system independent [instructions for logins](../logins/)
