#jinja2: trim_blocks:False
# Generate a public/private key pair with MobaXterm on Windows

## Get MobaXterm - a terminal and key generator application

Your OS does not come with a default terminal and key generator application, so you will need to download and install one. 
There are many options all of which have their own pros and cons; we suggest you give [MobaXterm](https://mobaxterm.mobatek.net) version >= 12.3 a try 
as it features a key generator, terminal and graphical user interface for data transfers all-in-one.
The following steps use the *portable* version of *MobaXterm Home Edition*, which is free and does not need to be installed with an installer;
just download, unpack and execute.
If you want to use another terminal, key generator or data transfer app please consult their manuals...

### Launch MobaXterm key pair generator

 * 0: Check your MobaXterm version is **12.3 or newer** as older ones have a known bug and won't work.
 * 1: Launch MobaXterm and choose the ```MobaKeyGen (SSH key generator)``` from the tools as shown in the screenshot below.

![launch MobaKeyGen](img/MobaXterm1.png)

### Configure key pair generator

![Select key type](img/MobaXterm2.png)

 * 2: From the **parameters** section at the bottom of the window choose: ```Type of key to generate:``` **ED25519**
 * 3: Click the **Generate** button...

### Generate key pair

![Generate randomness and subsequently key pair](img/MobaXterm3.png)

 * 4: Yes you really have to move the mouse now: computers are pretty bad at generating random numbers and MobaKeyGen uses the coordinates of your mouse movement as a seed to generate a random number.

### Secure private key and save pair to disk

Your key pair was generated.

![Save keys](img/MobaXterm4.png)

Now make sure you:

 * 5:  Replace the comment in **Key comment** with  
       **your first initial followed by (optionally your middle name followed by) your family name** all in lowercase and without any separators like spaces, dots or underscores.  
       So if your name is _**Jack Peter Frank the Hippo**_, please use _**jthehippo**_ as comment, so we can easily identify the key as yours.
 * 6:  Secure your private key with a good password **before** saving the private key. DO NOT choose a simple password or even worse an empty one!
 * 7:  Confirm the password
 * 8:  Click the **Save public key** button.
 * 9:  Click the **Save private key** button.
 * 10: Select and copy all the text in the text box at the top of the window underneath **Public key for pasting into OpenSSH authorized_keys file**.
       You can paste it in the email you'll send in the next step.

## Request account and have the public key linked to your account

To request an account, [contact the helpdesk via email](../contact/) and
{% if 'gearshift' in slurm_cluster_name or 'nibbler' in slurm_cluster_name or 'talos' in slurm_cluster_name or 'vaxtron' in slurm_cluster_name %}
 * Make sure you have read the [Code of Conduct](../coc_umcg_research_clusters/) and tell us you agree with it using this email
{% endif %}
 * Paste the contents of the public key as displayed in MobaKeyGen's *Public key for pasting into OpenSSH authorized_keys file* field in the email.
 * Please motivate your account request and
     * For **guest** accounts to access only a data transfer machine associated with the cluster:
         * Specify the project your are working on and add your collaborators on CC.
     * For **regular** accounts to access the cluster:
         **Copy the template mail below and fill all the fields** (the yes/no field should have yes OR no).
         If everything is filled, please send it back to the HPC helpdesk and request access of the group owners (preferably in the same email by cc'ing (all) the group owner(s).<br>
         NOTE:<br>
          **[1] Make sure you include all group owners in the CC of the request - it will be approved only after the group owners approve access to their own group(s)**<br>
          **[2] All of the fields are mandatory for the account creation, failing to provide any of them will result in account not being created**<br>
          **[3] End date is valid if it is requested/confirmed by group owner (or department's secretary by sending email directly to the hpc.helpdesk@umcg.nl**<br>
          **[4] Code Of Conduct (COC) is available at the https://docs.gcc.rug.nl/nibbler/coc_umcg_research_clusters/**<br>
          template email:
---
          Dear groupowner and helpdesk,
          I would like to request an access account to the cluster.
          @the groupowners can you approve my access to your group by replying to this email.
| Term:                 | Information|
|-----------------------|--------------------------------------------------------|
| First Name            |          |
| Last Name     | |
| Email address     | |
| Public key    | |
| End date contract   | |
| Groups to access     | |
| I have read, understood and I agree to the UMCG HPC Code of Conduct | yes/no |

          Best,
          NAME
---


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
