#jinja2: trim_blocks:False
# Request an account

## 1. Accounts, security and privacy.

#### Asymmetric key cryptography

We use asymmetric key cryptography to secure accounts. Hence you will get an account name, but no password. Instead of a password we use two digital keys:

 * A private key
 * A public key

The private key can be used to encrypt data (close the lock) and the associated public key can be used to decrypt the data (open the lock).
As the name suggests the public key is not secret; you can share this with everyone, publish it on your website, etc.
Hence your public key cannot be _compromised_, because it's intended to be public.
The private key on the other hand must be private; if it gets stolen your account is compromised and can be abused.
Therefore, [contact us](../contact/) immediately if you ever suspect your private key may have been stolen/copied!

For additional details and background see [WikiPedia: Asymmetric Key Cryptography](http://en.wikipedia.org/wiki/Public-key_cryptography)

When you try to login you use the private key on the client side to encrypt a small piece of data containing a request to login.
The cluster uses your public key on the server side to decrypt the login request: if this was successful the server has verified that you have the private key corresponding to the public key and will let you in.

The benefit of using key pairs as opposed to passwords is that the secret used to login can remain private if you create the key pair yourself and send _**only**_ the public key to the helpdesk.
Hence we do not have a copy/record/backup of your private key on the server side: if you loose the private key, you have to create a new pair and send the new public key to the helpdesk.

#### Security & Privacy

* When you request an account your email address will be added automatically to a low volume mailinglist, 
  which is used for information regarding the clusters like maintenance announcements.
* When you use the cluster and are logged in:
  * You can secure the content of files/folders, so only you or only members of a specific group can access the content either with read-only or with read-write permissions.  
    This requires setting the desired permissions for files or folders, which is your own responsibility. When you specify wrong permissions, data may be accessible for others.
  * You **cannot** secure the meta data of files/folders.
    * Hence things like file or folder names, time stamps, size, owner, group, etc. can always be seen by anyone who is logged in.
    * This also applies to the name of and resources requested for job script files: all users can see the meta-data of all queued and all running jobs.  
  Therefore **never ever put privacy sensitive data in the meta-data of files or folders**!
  * Your full name, email address, group memberships and role in a group (regular user or data manager or group owner) are visible to all other users.

## 2. Generate a public/private key pair

Use the instructions for your operating system:

 * Instructions for [Windows clients](../generate-key-pair-mobaxterm/).
 * Instructions for [macOS clients](../generate-key-pair-openssh/).
 * Instructions for [Linux/Unix clients](../generate-key-pair-openssh/).