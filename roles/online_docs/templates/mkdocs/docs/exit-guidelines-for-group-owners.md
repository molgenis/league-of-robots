# Exit Guidelines for group owners

These guidelines should be used in case you stop using the cluster.
So you leave the cluster neat and organized, and important data stored in the correct location.

Thank you in advance for taking the time to clean up your group, very much appreciated.  

#### First some general remarks. 
TMP is for calculating, this is not backed-up. PRM is for storage of important data, this is backed-up. We now also privide an archive option, for sleeping datasets. Archive is substanially cheaper compared to PRM storage.
As you might know by our [code of conduct](/../coc_umcg_research_clusters/), you are obliged to work according the [UMCG research code](https://researchcode.umcgresearch.org/en/).
According to the UMCG research code, you are obliged to have a [Data Management Plan (DMP)](https://umcg.zenya.work/portal/#/document/99b46c52-2c81-4193-b688-ad5a01d1a496?scope=global&searchText=data%20management%20plan) for your project(s).
In this DMP, a lot of information gathered concerning your project, including retention time, and where you are supposed to store your data.
Your project should also be documented in [PaNaMa](https://panama-rms.eu/).

Stated in the [UMCG research code](https://researchcode.umcgresearch.org/en/):
- *"The head of the department is responsible for all scientific research conducted at or from the department."*
- *"A principal investigator is available and responsible for all aspects of a study"*
- *"The study's research goals and methods are laid down in a high-quality and complete research protocol with a DMP"*

To sum it up, you, as a group owner, you are responsible for paiying the bill, but also for the work conducted in your group. You are oblidged to make sure the projects/studies in your group are documented accordingly and up to UMCG standards.  

#### The steps to follow:

We can think of a few scenarios for when a group owner wants to leave the cluster.
- **You are retiring or going to work in another facility. But the group remains active.**
	- Assign or ask a new person to be the new group owner. We prefer to have 2 group owners. 
	  This new group owner is then also responsible for the bill and correct data management.
- **You no longer need the group anymore for calculating.**
	- Make sure all regular users have followed the [Exit guidelines for general users](/../exit-guidelines-for-general-users). If everybody did their job right, no data remains on TMP. Ask your data managers to manage this, to keep everybody on their toes.
	- All data sets are accompanied by a README with the correct information (your name and contact information, responsible PIs, retention time, project numer, used in article/project, data source (human, mouse,....), tissue type (blood, fibroblasts, heart biopt,...), data type (array, NGS, longread,....), .)
	- If only sleeping data sets remain, we have an archive option. This is substantially cheaper compared to PRM storage. Ask [the helpdesk](../contact/) to help setup an archive for your group.
	- It is really important to state the retention time. After this date, the responsible PI should re-evaluate this data set and notify the [the helpdesk](../contact/) the data can be deleted or has an updated DMP. See [health-ri.nl](https://www.health-ri.nl/sites/healthri/files/2025-06/Handreiking-evaluatie-biobankcollecties_juni2025_0.pdf) for guidelines concerning bio bank collections, but can be applicable on other data set, if you need some guidelines concerning the decision making.  
- **You no longer need to store your sleeping dataset.**
	- Email the helpdesk that we can delete all data remaining in the group. 
	- we will delete all data and remove the group completely from all the clusters. 
- **If you calculated on the cluster, please also follow the [Exit guidelines for general users](/../exit-guidelines-for-general-users).**

If one of these scenarios is not applicable to you, or anything is uncleare please contact [the helpdesk](../contact/). 
Together we can figure out how to proceed.

#### Final note

If you fail your responsibilities, and leave your group without following the above guidelines, we will consider your former group as legacy data. We, as HPC admins, are not responsible for making decision concerning data. In practice this will mean we will ask the department head what we should do with the data. The department head has 2 options. 
1. Delete all data and the group.
2. Assign a new data custodian, who is then responsible for the data and has to make sure it is again documented according the UMCG research code.



