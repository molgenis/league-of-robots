# SSH agent forwarding with OpenSSH on macOS / Linux / Unix

* Check if your private key was added to the SSH agent on your local _**client**_ by issuing the command  
  ```$your_client> ssh-add -l```  
* You should get a response with the key fingerprint of the private key you want to use.
* If instead you get the message ```The agent has no identities``` or ```Could not open a connection to your authentication agent```,  
  then you will need to add your private key:  
    * If your private key is located in the default path (```${HOME}/.ssh/id_ed25519```) you can use the following command:  
      ```$your_client> ssh-add```  
    * If your key is not located in the default path, you will have to specify which private key file to add:  
      ```$your_client> ssh-add /path/to/my/private.key```
* Login to {{ slurm_cluster_name | capitalize }} with SSH _agent forwarding_ enabled 
  can now be accomplished with the ```-A``` argument on the commandline like this:  
  ```$your_client> ssh -A {{ groups['jumphost'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}+{{ groups['user_interface'] | first | regex_replace('^' + ai_jumphost + '\\+','') }}```

_**Note**_: You **cannot** accomplish this by configuring a ```ProxyCommand``` directive in a  ```${HOME}/.ssh/conf.d/*``` config file on your local client computer.

-----

Back to operating system independent [instructions for data transfers](../datatransfers/)