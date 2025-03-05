#jinja2: trim_blocks:False
# How to get a new group on the cluster

First you need to get a so called group on the Nibbler cluster. This needs to requested by a department head of 
Principal Investigator.

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
