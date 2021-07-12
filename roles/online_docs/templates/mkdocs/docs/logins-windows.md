#jinja2: trim_blocks:False
# SSH config and login to UI via Jumphost for users on Windows

The instructions below assume:

 * you've already downloaded _**[MobaXterm](https://mobaxterm.mobatek.net)**_ to generate a pair of SSH keys (using the instructions for requesting accounts)
 * and verified your _**MobaXterm**_ version is **12.3 or newer** (older ones have a known bug and won't work.)
 * and will now use _**MobaXterm**_ to login to the cluster
 * and that you received a notification with your account name and that your account has been activated
 * and that you are on the machine from which you want to connect to the cluster.

If you prefer another terminal application consult the corresponding manual.

###### Launch MobaXterm and create a new session

![launch MobaXterm](img/MobaXterm5.png)

 * Launch _**MobaXterm**_ version **12.3 or newer** and click the _**Session**_ button from the top left of the window.
 * A _**Session settings**_ window will popup.

###### Configure a new session

![Configure MobaXterm session](img/MobaXterm6.png)

 * Session type
    * 1: Select _**SSH**_.
 * Basic SSH settings tab
    * 2: _Remote host_ field: Use the name of the User Interface (UI) _**{{ groups['user_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}**_ .
    * 3: _Specify username_ field: Use your _**account name**_ as you received it by email from the helpdesk.
 * Advanced SSH settings tab:
    * 4: _Use private key_ field: Select the _**private key file**_ you generated previously.

![Configure MobaXterm session](img/MobaXterm7a.png)

 * Network settings tab
    * Click on the large _**SSH gateway (jump host)**_ button.

![Configure MobaXterm session](img/MobaXterm7b.png)

 * SSH jump hosts popup window
    * 5: _Gateway host_ field: Use the _Jumphost_ {% if public_ip_addresses is defined and public_ip_addresses | length %}IP address _**{{ public_ip_addresses[groups['jumphost'] | first] }}**_{% else %}address _**{{ groups['jumphost'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}{% if slurm_cluster_domain | length %}.{{ slurm_cluster_domain }}{% endif %}**_{% endif %}.
    * Optional: _Port_ field: The default port for SSH is 22 and this is usually fine. 
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

###### Password (popup)

![Configure MobaXterm session](img/MobaXterm8.png)

 * MobaXterm should now produce a popup window where you can enter the _**password**_ to decrypt the private key.
    * Note this is the password you chose yourself when you created the key pair.
    * You are the only one that ever knew this password; we have no copy/backup whatsoever on the server side. 
      If you forgot the password, the private key is useless and you will have to start over by creating a new key pair.

###### Password again (prompt)

![Configure MobaXterm session](img/MobaXterm9a.png)

MobaXterm should now start a session and login to the _Jumphost_ resulting in

 * a session tab (left part of the window with white background) and 
 * a terminal where you can type commands (right part of the screen with black background).

In the terminal tab _**MobaXterm**_ will try to login from the _Jumphost_ to the _User Interface (UI)_ with the same private key file. 
This may require retyping the password to decrypt the private key a second time, this time in the terminal tab.

###### Session established

You have now logged in to the UI {{ groups['user_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}.

![Configure MobaXterm session](img/MobaXterm9b.png)

The left part of the window with white background switched to a file browser, 
while the right part remains a terminal where you can type commands.

-----

Back to operating system independent [instructions for logins](../logins/)
