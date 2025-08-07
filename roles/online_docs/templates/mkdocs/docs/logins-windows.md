#jinja2: trim_blocks:False
# SSH config and login to UI via Jumphost for users on Windows

There are two options to login to clusters from Windows

 1. (preferred) Either by using [MobaXterm client](#11-launch-mobaxterm-and-create-a-new-session) software which requires installation
 2. alternative option is to use built-in [OpenSSH software](#2-using-windows-openssh) that comes pre-installed with newer versions of Windows (10+)


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

### 2.1 Semi-automatic configuration with .bat script

You can download the executable script from here [logins-windows.bat](../logins-windows.bat) and use it to configure ssh connection for the {{ slurm_cluster_name }}.
 - Using Microsoft's Edge web browser: you will need to confirm that the file is safe **twice**  
   (see _Download_ icon, where you must select `Keep`, then `Show more` > `Keep anyway`)
 - Using other web browsers: the download itself is easier, but when you try to execute the script, you will get a `Windows protected` warning and you must click `More info` (small text at top left part of the window) followed by `Run anyway`.
 - Alternatively, you can simply follow the link [logins-windows.bat](../logins-windows.bat), select & copy the text, then paste into a file named `logins-windows.bat` on your windows machine. (The `.bat` filename extension is mandatory make the file executable.)

Once you have the file, run it and the rest of the configuration will be (for except two prompts) done almost automatically.

The configuration files will be stored inside the `C:\Users\[Username]\.ssh\` folder.

### 2.1 Manual configuration with

(to be updated)

If you are familiar with he SSH configuration files, and would like to create them manually, you can do that by editing the `%USERPROFILE%\.ssh` folder - which defaults to`C:\Users\[Username]\.ssh\`. Options about SSH configurations are further explained in the instructions for [Linux users](../logins-linux-config/).

There are **many** differences between the linux and windows OpenSSH configuration. One of the biggest is the difference beween linux `/` and windows `\` as directory path separator. But there are many more. Users that do not understand those differences, should use the MobaXterm or semi-automatic .bat script options above.


### 2.3 Connecting to the system

In order to connect to the {{ slurm_cluster_name }}

- first open Start menu, search and execute the `cmd` or `Command Prompt` program
- login to {{ slurm_cluster_name }} by using a command `ssh umcg-username@{{ groups['jumphost'] | first }}+{{ groups['user_interface'] | first }}`

### 2.4 Port forwarding to the compute nodes

Users can connect ports on own computer to the ports on the compute nodes behind the jumphosts - by using port forwarding (binding).
In order to do this, user must open another `cmd` environment and establish a connection with numbers of the ports to be forwarded

    ssh -J {{ groups['jumphost'] | first }} {{ groups['user_interface'] | first }} -L XXXXX:NODE:XXXXX

where

- `-J {{ groups['jumphost'] | first }}` specify which jumphost machine is going to be used in order oppening the connection to ...
- `{{ groups['user_interface'] | first }}` is the name of the machine that user will connect and have the command line started
- `-L XXXXX:NODE:XXXXX` defines the ports and machines to connect
    - `XXXXX` can be set to any port in the range (1024 < `XXXXX` <= 65535) as long it is **free** on both (your local and remote) servers,
    - note that this example binds the **same** `XXXXX` ports on both local as well as remote server - but this is not mandatory, they can be different,
    - `NODE` is the name of the remote server behind a jumphsot to which the ports should be forwarded.

More information about `ssh` options can be find on the [ssh man pages](https://man.openbsd.org/ssh).

### 2.5 Converting Putty .ppk key into OpenSSH format


Public/private keypairs created with `Putty` program are by default stored in the **P**utty **p**rivate **k**ey (ppk) format. The private keys files also have `.ppk` ending. The file format is not compatible with generic `OpenSSH` format (which most of ssh client programs use) and the key must either be recreated (and public part sent to helpdesk) or existing private key must be converted into more usable OpenSSH format.

In order to convert an existing keypair from Putty into OpenSSH format

- `puttygen.exe` can be downloaded from [Putty webpage](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html)
- run program > click `Load` > select ppk (private key)
- to store the PUBLIC part of the keypair into OpenSSH format, select all the text inside `Key`: `Public key for pasting into OpenSSH authorized_keys file` and save it in a file with `.pub` ending (like `username.pub`)
- to store PRIVATE part of the keypair (while still loaded the same ppk key)
  - click `Conversions`
  - `Export OpenSSH key` > confirm
  - store same filename but **without** any ending (simply a username for a filename should be descriptive enough)

-----

Back to operating system independent [instructions for logins](../logins/)
