#jinja2: trim_blocks:False

# LSAAI accounts and groups

LSAAI instructions are available in three parts

1. [Overview](../lsaai) - brief description of LSAAI
2. [Regular users](../lsaai-users) - instructions for regular users creating an account
3. **Group managers** - instructions for data managers on how to manage users and groups


## 1. Login

 - [Login to LSAAI](https://perun.aai.lifescience-ri.eu/)
 - Go to [GGCC Virtual Organization](https://perun.aai.lifescience-ri.eu/organizations/3363) and browse the `Groups`

## 2. Adding users to a group

**Option A: Invite Users via Link**

 - From the group administration page, navigate to `Members` and select `Copy invitation link`. ([screenshot](img/lsaai_manager_3.png))
 - User clicks on the invitation URL: the system automatically submits a request to join the group for them.
 - Group administrator must navigate into `Group` > `Applications`, go into `pending` view (to show users that applied to join), then select and `Approve` them

**Option B: Add Users Manually**

 - Open the group and locate the `Members` tile (available to group administrators). ([screenshot](img/lsaai_manager_1.png))
 - Click `Add` and search for the person you wish to include. You can search by name or email address. ([screenshot](img/lsaai_manager_2.png))

## 3. Extending user group access

- Login to the [Perun](https://perun.aai.lifescience-ri.eu/organizations/3363/)
- Use `Groups` tab, and go to the group you wish to manage membership
- Select `Members` tab ([screenshot](img/lsaai_manager_4.png))
- Use drop-down `Filter by group status` (default is set to `ACTIVE`) and pick `EXPIRED`
- You will now see only users that have expired
- Click on username and in the new page, under `Group membership` next to the `Status: EXPIRED` you can select edit (pen) icon ([screenshot](img/lsaai_manager_5.png))
- Here you select from the three options and click `Change status` ([screenshot](img/lsaai_manager_6.png))

## 4. Removing user from a group

- Login to the [Perun](https://perun.aai.lifescience-ri.eu/organizations/3363/)
- Use `Groups` tab, and go to the group you wish to manage membership
- Select `Members` tab ([screenshot](img/lsaai_manager_4.png))
- Tick the checkboxes in front of the usernames you wish to remove
- Confirm with `Remove` ([screenshot](img/lsaai_manager_7.png))

## 5. Creating subgroups (data managers)

Data managers can create **project**, **release**, and **hierarchical** subgroups.
Perun **web interface should never used to make new subgroups**, instead the
**command line on the cluster** can be used in order to do it properly. 

User from the data-manager (`-dms`) group should run

```bash
   lsaai_subgroups.sh
```

The output lists all the groups which you can manage, and also prompts

```
Would you like to create a new [P]roject, [R]elease versioned dataset, or hierarchical [S]ubgroup?
```

where **[P]**roject

1. Enter the main group name (from the list shown).
2. Enter a project name (2–8 characters, letters/digits/underscore, not `dms`).
3. Press Enter to accept the default membership duration, or type a different number of days (see below).

==> Creates `[main group]-prj-[projectname]`

**[R]**elease (dataset + version)

1. Enter the main group name.
2. Press Enter to accept the default membership duration, or type a different number of days (see below).
3. Enter a dataset name (2–12 characters).
4. Enter a version name (2–6 characters).

==> Creates `[main group]-rel-[dataset]-[version]`

Hierarchical **[S]**ubgroup

1. Enter the full parent group name (must be under `[main group]-sub`, max 3 levels deep).
2. Enter a subgroup name (2–8 characters).
3. Press Enter to accept the default membership duration, or type a different number of days (see below).

==> Creates the new group directly under the parent you entered.

The **membership expiration** prompt

Every member added to the subgroup gets an expiration date, set this many days from
when they joined (default: **365 days**). When that date passes, their membership
automatically expires and they lose access to the group — they are not removed from
the group definition itself, but need to be renewed or reapply to regain access. This
is a safeguard so that access to project/release data doesn't linger indefinitely
after someone's involvement ends. You can enter a shorter or longer number of days if
365 doesn't fit the project's expected duration.

**Adding a user to a subgroup you created**

The script itself does not create individual user accounts. Once a subgroup exists:

- Share the group's membership link (printed at the end of the script) with the person who needs access, or use [Option A or B above](#32-adding-users-to-a-group) to add them via Perun.
- The person must **log out and log back in** to the cluster before access takes effect.
- Allow a few minutes for the change to propagate.
