#jinja2: trim_blocks:False
# SSH login to UI via Jumphost for users on macOS, Linux or Unix

The following assumes:

 * your [request for an account](../accounts/) was approved and processed.
 * you configured your _OpenSSH client_ using the instructions for either [macOS](../logins-macos-config/) or [Linux/Unix](../logins-linux-config/) depending on your OS.

## Log in to {{ slurm_cluster_name | capitalize }} on the commandline in a Terminal

Note: If you only need to transfer data and prefer a Graphical User Interface (GUI), you can skip the instructions for working on the commandline below and go straight to 
[Keep - What is stored where on {{ slurm_cluster_name | capitalize }}](../storage/) and [Data transfers - How to move data to / from {{ slurm_cluster_name | capitalize }}](../datatransfers/)

If you want to transfer data using the commandline or analyze data on the cluster using jobs:

 * You can login to the _UI_ named ```{{ groups['user_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}``` 
   with the account as specified in your ```${HOME}/.ssh/conf.d/{{ slurm_cluster_name }}``` 
   via the _Jumphost_ named ```{{ groups['jumphost'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}{% if slurm_cluster_domain | length %}.{{ slurm_cluster_domain }}{% endif %}``` 
   using the alias ```{{ groups['jumphost'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}+{{ groups['user_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}```. 
   Type the following command in a terminal:

        ssh {{ groups['jumphost'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}+{{ groups['user_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}

 * In order to override the account name specified in your ```${HOME}/.ssh/conf.d/{{ slurm_cluster_name }}``` you can use:

        ssh some_other_account@{{ groups['jumphost'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}+{{ groups['user_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}

 * If necessary, you can do tripple hops starting with a _Jumphost_ like this:

        ssh jumphost+intermediate_server+destination_server

 * In case you are on a network where the default port for _SSH_ (22) is blocked by a firewall you can try to setup _SSH_ over port 443, which is the default for HTTPS and almost always allowed, using an alias like this:

        ssh {{ groups['jumphost'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}443+{{ groups['user_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}

## Frequent Asked Questions (FAQs) and trouble shooting

 * Q: Why do I get the error ```Bad configuration option: IgnoreUnknown```?  
   A: Your OpenSSH client is an older one that does not understand the ```IgnoreUnknown``` configuration option.
      You have to comment/disable the  
      ```# Generic stuff: only for macOS clients```  
      section listed at the top of the ```${HOME}/.ssh/conf.d/{{ slurm_cluster_name }}``` config file.
 * Q: Why do I get the error ```muxserver_listen bind(): No such file or directory.```?  
   A: You may have failed to create the ```${HOME}/.ssh/tmp``` folder or the permissions on this folder are wrong.
 * Q: Why do I get the error ```ControlPath too long```?  
   A: The ```ControlPath ~/.ssh/tmp/%C``` line in your ```${HOME}/.ssh/conf.d/{{ slurm_cluster_name }}``` file expands to a path that is too long.
      Change the ```ControlPath``` line in your ```${HOME}/.ssh/conf.d/{{ slurm_cluster_name }}``` file to create a shorter path for the automagically created sockets.
 * Q: Why do I get the error ```ssh_exchange_identification: Connection closed by remote host```?  
   A: Either this server does not exist (anymore). You may have a typo in the name of the server you are trying to connect to.
      Check both the command you typed as well as your ```${HOME}/.ssh/conf.d/{{ slurm_cluster_name }}``` for typos in server names.  
      Or you are using the wrong private key. If your private key is not saved with the default name in the default location,
      check if the correct private key file is specified both for the ```ProxyCommand``` and ```IdentityFile``` directives 
      in your ```${HOME}/.ssh/conf.d/{{ slurm_cluster_name }}```.
 * Q: Why do I get the error ```Permission denied (publickey).```?  
   A: This error can be caused by various configuration issues:
     * Either you are using the wrong account name
     * or you are using the wrong private key file
     * or the permissions on your ```${HOME}/.ssh/``` dir and/or on its content are wrong
     * or your account is misconfigured on our account server.  
   Firstly, check your account name, private key and permissions.  
   Secondly, check if you can login to the _Jumphost_ with a single hop using

              ssh {{ groups['jumphost'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}

        * If you can login to the _Jumphost_, but cannot use double hop SSH to login to the _UI_ via the _Jumphost_,
          you may have to add your private key to the SSH agent on you local machine. 
          To check which private key(s) are available to your SSH agent you can list them with on your local computer with:

                  ssh-add -l

        * If you cannot login and get:

                  The agent has no identities.

          then you have to add your private key with the ```ssh-add``` command, which should return output like this:

                  Identity added: /path/to/your/home/dir/.ssh/id_ed25519 (key_comment)

          Your private key should now be listed when you check with ```ssh-add -l```, which should look like this:

                  256 SHA256:j/ZNnUvHYW3U$wgIapHw73SnhojjxlWkAcGZ6qDX6Lw key_comment (ED25519)

     If that did not resolve the issue, then increase the verbosity to debug connection problems (see below).
   
 * Q: Can I increase the verbosity to debug connection problems?  
   A: Yes try adding ```-vvv``` like this:  
   ```ssh -vvv youraccount@{{ groups['jumphost'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}+{{ groups['user_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}```  
   If that does not help to figure out what is wrong please [contact the helpdesk](../contact/) and
     * Do include:
        1. The command you used for your failed login attempt
        2. The output of that failed login attempt with ```-vvv``` debugging enabled
        3. A copy of your ```${HOME}/.ssh/config``` file.
        4. A copy of your ```${HOME}/.ssh/conf.d/{{ slurm_cluster_name }}``` file.
     * **Never ever send us your private key**; It does not help to debug your connection problems, but will render the key useless as it is no longer private.

-----

Back to operating system independent [instructions for logins](../logins/)
