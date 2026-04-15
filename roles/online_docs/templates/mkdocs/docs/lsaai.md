#jinja2: trim_blocks:False

# LSAAI accounts

This page is written in three parts

1. [Overview](#1-overview) - brief description of LSAAI
2. [Regular users](#2-regular-users) - instructions for regular users creating an account
3. [Group managers](#3-group-managers) - instructions for group managers

## 1. Overview

In short

 - Create LSAAI Account: Register for an LSAAI account if you do not already have one.
 - Request VO Access: Log in to LSAAI and request to join the designated Virtual Organization.
 - Request Group Access: Navigate to the group listing and request access to the relevant groups.
 - Finalize: Upload your public SSH key. Access to the cluster will be granted automatically upon key validation.

### 1.1. What is LSAAI

It is an **identity and access management** system designed for the European Life Science research community. It enables researchers to use a single digital identity—leveraging their existing institutional or community accounts—to securely access shared data and computing resources.

Users can request and manage their own access credentials.

Group owners and data managers can manage group membership themselves or delegate this responsibility to others.

### 1.2. Key Functions

It provides following key functions

- **User management**
    - Identity Consolidation: Link multiple login methods (like your university account and ORCID) into one persistent Life Science ID
    - Access credentials management: allows users to self-manage their SSH public keys for remote server access
- **Virtual Organization (VO) Management**
    - Provide separated environments for communities and projects, outside of the main LSAAI community
    - VO allows full control over managing user access and groups
- **Resource Authorization**
    - Control which groups or individuals have permission to use specific services or datasets across different research infrastructures

## 2. Regular users


The registration process varies depending on your home organization.

- **For RUG and UMCG Members**

    University of Groningen (RUG) and UMCG are already members of the LSAAI community.

    - **Timeline:** Account creation takes only a few minutes.
    - **Process:** Select your organization from the list and log in with your institutional credentials.

- **For Other Organizations**

    If your organization is not yet a member of the LSAAI community

    - **Approval:** You must wait for manual access approval by LSAAI administrators.
    - **Requirements:** Admins may contact you to request additional information.

To request access to the **GGCC Virtual Organization (VO)**, you must first possess a **LifeScience AAI (LSAAI)** account.

### 2.1. Create LSAAI Account

Please note that following steps may differ from user to user, as it depends on their previous LSAAI accounts - therfore **some users might need to skip some of the steps**.

1.  **Visit the Login Portal** Navigate to the [LifeScience Login](https://perun.aai.lifescience-ri.eu/) page. ([image 1](img/lsaai_user_1.png))
2.  **Select Organization** Choose your home institution and log in. ([image 2](img/lsaai_user_2.png))
3.  **Register New Account** If no account is found, you will see a "No user account found" message. Click **Proceed to register for an account**.   ([image 3](img/lsaai_user_3.png))
4.  **Fill Application** Complete the application form to join the LifeScience LSAAI community. ([image 4](img/lsaai_user_4.png))
5.  **Accept Policies** Accept the Acceptable Use Policy and click **Submit**. ([image 5](img/lsaai_user_5.png))
6.  **Verify Email** Check your inbox for a verification email and follow the link to activate your account. ([image 6](img/lsaai_user_7.png))

**If your organization is not part of the LifeScience community, you may need to wait** for administrative approval before proceeding to the next step.

---

### 2.2. Requesting GGCC VO Access

Once your account is created and you log in to LifeScience, you may see a message stating: *"Login, but no service available yet"* ([image 8](img/lsaai_user_8.png)). You must now join the GGCC Virtual Organization.

#### Option A: Join the GGCC Virtual Organization

You can request general membership by visiting the registrar:

* **Link:** [Request GGCC Membership](https://signup.aai.lifescience-ri.eu/registrar/?vo=ggcc) ([image 9](img/lsaai_user_9.png))
* Follow the prompts to join the VO and specific groups as needed.

#### Option B: Join via Invitation Link

If a project lead has provided you with a **specific group invitation link**:

* Clicking the link will automatically generate an access request on your behalf.
* You should see a confirmation: *"You have successfully applied for membership."*

---

### 2.3. Final Approval

In both cases, access to **HPC groups** is granted only after **group administrators** approve your request.

* You will receive a notification email once your access has been provisioned.
* You can then proceed to use the GGCC computing resources.

### 2.4. Adding and managing ssh keys to access clusters

Accessing the clusters requires an SSH public-private key pair (see instructions on how to make for [Linux/Mac](../generate-key-pair-openssh/) and [Win](../generate-key-pair-mobaxterm/)).

 - Upload: Add your **public** key to your [LSAAI profile](https://profile.aai.lifescience-ri.eu/) > Authentication > [SSH keys](https://profile.aai.lifescience-ri.eu/profile/auth/sshKeys).
([image 9](img/lsaai_ssh.png))
 - Wait: It typically takes a few minutes for the key to propagate to the clusters.
 - Connect: Log in using your private key.

Note: If you lose your key or forget your passphrase, simply generate a new pair and update your profile at the link above.

---

## 3. Group managers

### 3.1. Login

 - [Login to LSAAI](https://perun.aai.lifescience-ri.eu/)
 - Go to [GGCC Virtual Organization](https://perun.aai.lifescience-ri.eu/organizations/3363) and browse the `Groups`

### 3.2. Adding users to a group

**Option A: Invite Users via Link**

 - From the group administration page, navigate to `Members` and select `Copy invitation link`. [screenshot](img/lsaai_manager_3.png)
 - User clicks on the invitation URL: the system automatically submits a request to join the group for them.
 - Group administrator must navigate into `Group` > `Applications`, go into `pending` view (to show users that applied to join), then select and `Approve` them

**Option B: Add Users Manually**

 - Open the group and locate the `Members` tile (available to group administrators). ([screenshot](img/lsaai_manager_1.png))
 - Click `Add` and search for the person you wish to include. You can search by name or email address. ([screenshot](img/lsaai_manager_2.png))

### 3.4. Extending user group access

1. Login to the [Perun](https://perun.aai.lifescience-ri.eu/organizations/3363/)
2. Use `Groups` tab, and go to the group you wish to manage membership
3. Select `Members` tab ([screenshot](img/lsaai_manager_4.png))
  3.1. Use drop-down `Filter by group status` (default is set to `ACTIVE`) and pick `EXPIRED`
  3.2. You will now see only users that have expired
  3.3. Click on username and in the new page, under `Group membership` next to the `Status: EXPIRED` you can select edit (pen) icon ([screenshot](img/lsaai_manager_5.png))
  3.4. Here you select from the three options and click `Change status` ([screenshot](img/lsaai_manager_6.png))

### 3.3. Removing user from a group

1. Login to the [Perun](https://perun.aai.lifescience-ri.eu/organizations/3363/)
2. Use `Groups` tab, and go to the group you wish to manage membership
3. Select `Members` tab ([screenshot](img/lsaai_manager_4.png))
4. Tick the checkboxes in front of the usernames you wish to remove
5. Confirm with `Remove` ([screenshot](img/lsaai_manager_7.png))

