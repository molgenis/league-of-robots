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

 * Paste the contents of the public key as displayed in MobaKeyGen's *Public key for pasting into OpenSSH authorized_keys file* field in the email.
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