#jinja2: trim_blocks:False

# LSAAI instructions for regular users

LSAAI instructions are available in three parts

1. [Overview](../lsaai) - brief description of LSAAI
2. **Regular users** - instructions for regular users creating an account
3. [Group managers](../lsaai-dms) - instructions for data managers on how to manage users and groups

## 1. Overview

In short

 - **Create LSAAI Account**: Register for an LSAAI account if you do not already have one.
 - Request VO Access: (will be automatically approved) Log in to LSAAI and request to join the designated Virtual Organization.
 - Request Group Access: You should receive a link from group manager, which you can follow in order to request access to the group (the request needs to be manually approved).
 - Finalize: Upload your public SSH key. Access to the cluster will be granted automatically upon key validation.

are steps needed for a regular user to do, in order to login to a cluster

## 2. Registration

You must have **LifeScience AAI (LSAAI)** user account, before you can request access to the **GGCC Virtual Organization (VO)**, **Request access to the Group** or access HPC systems.

When you create your user account, it will be linked to your **home organization email account**.

- If your home organization is already part of the LSAAI community

    **University of Groningen (RUG) and UMCG are already part of the LSAAI community**, then the

    - Timeline: Account creation takes only a few minutes.
    - Process: Select your organization from the list and log in with your institutional credentials.

- For organizations that are **not yet part of LSAAI community**, the registration take extra steps

    - Approval: You must wait for manual access approval by LSAAI administrators.
    - Requirements: Admins may contact you to request additional information.

## 3. Create LSAAI Account

Please note that following steps may differ from user to user, as it depends on their previous LSAAI accounts - therfore **some users might need to skip some of the steps**.

1.  **Visit the Login Portal** Navigate to the <a target="_blank" href="https://perun.aai.lifescience-ri.eu/">LifeScience Login</a> page. ([image 1](img/lsaai_user_1.png))
2.  **Select Organization** it is important to **choose your home institution** to log in. ([image 2](img/lsaai_user_2.png))
3.  **Register New Account** If no account is found, you will see a "No user account found" message. Click **Proceed to register for an account**.   ([image 3](img/lsaai_user_3.png))
4.  **Fill Application** Complete the application form to join the LifeScience LSAAI community. ([image 4](img/lsaai_user_4.png))
5.  **Accept Policies** Accept the Acceptable Use Policy and click **Submit**. ([image 5](img/lsaai_user_5.png))
6.  **Verify Email** Check your inbox for a verification email and follow the link to activate your account. ([image 6](img/lsaai_user_7.png))

**If your organization is not part of the LifeScience community, you may need to wait** for administrative approval before proceeding to the next step.

---

## 4. Requesting GGCC VO Access

Once your account is created and you log in to LifeScience, you may see a message stating: *"Login, but no service available yet"* ([image 8](img/lsaai_user_8.png)). You must now join the GGCC Virtual Organization.

### Option: you received Invitation Link

If a project lead has provided you with a **specific group invitation link**

* Clicking the link will automatically generate an access request on your behalf.
* You should see a confirmation: *"You have successfully applied for membership."*

### Option: Join the GGCC Virtual Organization

You can request general membership by visiting the registrar

* **Link:** to <a href="https://signup.aai.lifescience-ri.eu/registrar/?vo=ggcc" target="_blank" >Request GGCC Membership</a> ([image 9](img/lsaai_user_9.png))
* Follow the prompts to join the VO and specific groups as needed.


---

## 5. Request access to the Group

You should receive a link from the group managers that allows you to request access; please note that requests are **approved manually**.

* After a request, you should receive a notification email which will inform you if you access request was granted or denied.
* You can then proceed to update your ssh keys (next step) in order to use the GGCC computing resources.

Again, access to the **groups** is granted only after group managers **manually** approve your request.

## 6. Adding and managing ssh keys to access clusters

Accessing the clusters requires an SSH public-private key pair (see instructions on how to make for [Linux/Mac](../generate-key-pair-openssh/) and [Win](../generate-key-pair-mobaxterm/)).

 - Upload: Add your **public** key to your <a href="https://profile.aai.lifescience-ri.eu/" target="_blank">LSAAI profile!</a> > Authentication > <a href="https://profile.aai.lifescience-ri.eu/profile/auth/sshKeys" target="_blank" >SSH Keys</a>.

([image 9](img/lsaai_ssh.png))
 - Wait: It typically takes a few minutes for the key to propagate to the clusters.
 - Connect to the cluster
    - **remember: your accountname / username is the email address** that you are using to login into the LSAAI
    - follow the [login instructions](../logins/) using this username

Note: If you lose your key or forget your passphrase, simply generate a new pair and update your profile at the link above.


