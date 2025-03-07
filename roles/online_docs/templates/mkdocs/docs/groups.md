#jinja2: trim_blocks:False
# How to get a new group on the cluster

A department head or principal investigator can request a new group on the cluster(s).
The information needed to request a new group, includes:

 * Name of the group (umcg-xxx) Name is set in stone!
 * The names and mailing addresses of the:
    * Group owner(s)
    * Datamanager(s)
    * Group member(s)

For each of the persons mentioned above, we need a confirmation from the secretary on the end date of their contract with the UMCG.

 * The amount of data ([quota](../quota/)) you want to store on ```tmp``` and ```prm``` storage systems.

The minimum amount is 1 TB on each of these storage systems and that will cost 500 euro per year combined (so 250 euro/TB/year for tmp and 250 euro/TB/year for prm).
You can store your data on the prm storage system (this has regular backup to tape) and if you want to compute with it, stage the data on the tmp data storage, that is connected to the compute part of the cluster. The quota on tmp and prm can be different.

We expect the pricing system to change in the coming year, so data storage will become cheaper but co-investments 
will be asked to allow hardware investments and get a large part of the FAIR Share of the cluster.

 * The numbers of the UMCG research register under which your studies are registered and a project number or kostenplaats which will be billed for the annual costs.

You can share the details with [the helpdesk](../contact/), so we can draft a contract (Dienstverleningsovereenkomst) and proceed from there.


Once the group is made you can create a [public private key pair](../accounts/) and get access.
We have a [code of conduct](../coc_umcg_research_clusters/). This describes what we expect from the users and group owners on the cluster.
If you want to proceed with working our clusters, please read it and confirm by email to [the helpdesk](../contact/) that you read and understood it and will act accordingly (for both group owner and users).

We assume that you are familiar with some basic knowledge about Linux command line (shell) navigation and shell 
scripting. If you never worked on the command line, consider some Linux tutorials on the subject first and sign 
up for the RUG cluster course, see below.

WIKI HPC cluster RUG with announcements of cluster courses:
[Hábrók basis | Corporate Academy | Rijksuniversiteit Groningen (rug.nl)](https://wiki.hpc.rug.nl/habrok/introduction/courses#basic_habrok_course)






The minimal requirements for a main group are as follows:
 * Group leaders / PIs can request new main groups. When the main group is created they will be registered as the group owners.
 * Group owners are responsible for: 
    * Processing (accepting or rejecting) requests for group membership.
    * Securing funding and paying the bills. We need a kostenplaats/project number for billing the costs.
    * Appointing data managers for their group.

 * Data managers are responsible for the group's data on ```prm```, ```rsc``` (if available) and ```arc``` (if available) storage systems and
    * Ensure the group makes arrangements what to store how and where. E.g file naming conventions, file formats to use, etc.
    * Enforce the group's policy on what to store how and where by reviewing data sets produced by other group members on ```tmp``` file systems before migrating/copying them to ```prm``` or ```arc``` (if available).
    * Can put released versions of data sets on rsc storage, so it can be used as reference data by alle members of the group.
    * Have read-write access to all file systems including ```prm```, ```rsc``` (if available) and ```arc``` (if available).

 * Other regular group members:
    * Have read-only access to ```prm```, ```rsc``` (if available) and ```arc``` (if available) file systems to check-out existing data sets.
    * Have read-write access to ```tmp``` file systems to produce new results.
    * Can request a data manager to review and migrate a newly produced data set to ```prm``` or ```arc``` (if available) file systems.

 * A group has at least one owner and one data manager, but to prevent delays in processing membership request and data set reviews a group has preferably more than one owner and more than one data manager.
 * Optionally sub groups may be used to create more fine grained permissions to access data.
    * A sub group inherits group owners, data managers and quota limits from the main group.
    * All members of the sub group must be members of the main group.
    * The members of the sub group are a subset of the members of the main group.
