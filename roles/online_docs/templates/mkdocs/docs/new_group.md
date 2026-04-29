#jinja2: trim_blocks:True
# How to get a new group on the cluster

A department head or principal investigator can request a new group on the cluster(s).
The information needed to request a new group, includes:

 * Name of the group: umcg-[groupname] -  **NAME IS SET IN STONE!**
 * The names and mailing addresses of the:
    * Group owner(s)
    * Datamanager(s)
    * Group member(s)

For each of the persons mentioned above, we need a confirmation of the enddate of their contract. If the person is employed by the UMCG, we need the confirmation from their secretary.

## Minimal requirements

The minimal requirements for a main group are as follows:

 * Group leaders / PIs can request new main groups. When the main group is created they will be registered as the 
group owners.
 * Group owners are responsible for
    * Processing (accepting or rejecting) requests for group membership.
    * Securing funding and paying the bills.
    * Appointing data managers for their group.
    * Approving user membership.
 * Data managers are responsible for the group's data on ```prm```, ```rsc``` (if available) and ```arc``` (if 
available) storage systems and
    * Ensure the group makes arrangements what to store how and where. E.g file naming conventions, file formats 
to use, etc.
    * Enforce the group's policy on what to store how and where by reviewing data sets produced by other group 
members on ```tmp``` file systems before migrating/copying them to ```prm``` or ```arc``` (if available).
    * Can put released versions of data sets on ```rsc``` storage, so it can be used as reference data by all 
members of the group.
    * Have read-write access to all file systems including ```prm```, ```rsc``` (if available) and ```arc``` (if 
available).
    * Our ```arc``` is substantially cheaper compared to our ```prm``` storage, for sleeping datasets this might be a good option for your data. See [archive](../archive) for more information.
 * Other _regular_ group members:
    * Have read-only access to ```prm```, ```rsc``` (if available) and ```arc``` (if available) file systems to 
check-out existing data sets.
    * Have read-write access to ```tmp``` file systems to produce new results.
    * Can request a data manager to review and migrate a newly produced data set to ```prm``` or ```arc``` (if 
available) file systems.
 * A group has at least one owner and one data manager, but to prevent delays in processing membership request 
and data set reviews a group has preferably more than one owner and more than one data manager.
 * Optionally sub groups may be used to create more fine grained permissions to access data.
    * A sub group inherits group owners, data managers and quota limits from the main group.
    * All members of the sub group must be members of the main group.
    * The members of the sub group are a subset of the members of the main group.

 * The amount of data ([quota](../storage/#quota)) you want to store on ```tmp``` and ```prm``` storage systems.
    * The minimum amount is 1 TB on each of these storage systems and that will cost 500 euro per year combined (so 250 euro/TB/year for tmp and 250 euro/TB/year for prm).
    * You can store your data on the prm storage system (this has regular backup to tape) and if you want to compute with it, stage the data on the tmp data storage, that is connected to the compute part of the cluster. The quota on tmp and prm can be different.

 * The numbers of the UMCG research registry under which your studies are registered and a project number or kostenplaats which will be billed for the annual costs.

You can share the details with [the helpdesk](../contact/), so we can draft a contract (Dienstverleningsovereenkomst) and proceed from there.

## What's next?

Once the group is made all group members can create a [public private key pair](../accounts/) and get access. We 
have a [code of conduct](../coc_umcg_research_clusters/). This describes what we expect from the users and group 
owners on the cluster. If you want to proceed with working our clusters, please read it and confirm by email to [the helpdesk](../contact/) that you read and understood it and will act accordingly (for both group owner and users).

We assume that you are familiar with some basic knowledge about Linux command line (shell) navigation and shell 
scripting. If you never worked on the command line, consider some Linux tutorials on the subject first and sign 
up for the RUG cluster course: [Hábrók basis | Corporate Academy | Rijksuniversiteit Groningen (rug.nl)](https://wiki.hpc.rug.nl/habrok/introduction/courses#basic_habrok_course)

See [https://umcg.topdesk.net/](https://umcg.topdesk.net/) the Scientific Research Support page of the UMCG, for all you scientific research support questions.


## When you want to leave

When, for what ever reason, you would like to leave the group, see below a few scenarios we could think of, accompanied with the steps to take.

- **You are retiring or going to work in another facility. But the group remains active.**
	- Assign or ask a new person to be the new group owner. We prefer to have 2 group owners. 
	  This new group owner is then also responsible for the bill and correct data management.
- **You no longer need the group anymore for calculating.**
	- Make sure all regular users have followed the [when you leave](../storage/#when-you-leave) steps. If everybody did their job right, no data remains on TMP. Ask your data managers to manage this, to keep everybody on their toes.
	- All data sets are accompanied by a README with the correct information (your name and contact information, responsible PIs, retention time, project numer, used in article/project, data source (human, mouse,....), tissue type (blood, fibroblasts, heart biopt,...), data type (array, NGS, longread,....), .)
	- If only sleeping data sets remain, we have an [archive](../archive) option. This is substantially cheaper compared to PRM storage. Ask [the helpdesk](../contact/) to help setup an archive for your group.
	- It is really important to state the retention time. After this date, the responsible PI should re-evaluate this data set and notify the [the helpdesk](../contact/) the data can be deleted or has an updated DMP. See [health-ri.nl](https://www.health-ri.nl/sites/healthri/files/2025-06/Handreiking-evaluatie-biobankcollecties_juni2025_0.pdf) for guidelines concerning bio bank collections, but can be applicable on other data set, if you need some guidelines concerning the decision making.  
- **You no longer need to store your sleeping dataset.**
	- Email the helpdesk that we can delete all data remaining in the group. 
	- we will delete all data and remove the group completely from all the clusters. 
- **If you calculated on the cluster, please also follow the [when you leave](../storage/#when-you-leave) steps.**

If one of these scenarios is not applicable to you, or anything is uncleare please contact [the helpdesk](../contact/). 
Together we can figure out how to proceed.

#### Final note

If you fail your responsibilities, and leave your group without following the above guidelines, we will consider your former group as legacy data. We, as HPC admins, are not responsible for making decision concerning data. In practice this will mean we will ask the department head what we should do with the data. The department head has 2 options. 
1. Delete all data and the group.
2. Assign a new data custodian, who is then responsible for the data and has to make sure it is again documented according the UMCG research code.





