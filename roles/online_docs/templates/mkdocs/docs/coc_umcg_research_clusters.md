# Code of Conduct UMCG Research IT High Performance Compute Clusters
Version 26-9-2024

The following is the Code of Conduct that the Investigator agrees to abide by as a user of the UMCG HPC clusters. 
Failure to abide by any term within this Code of Conduct may result in revocation of approved access to any or 
all data and groups obtained through the HPC clusters.

The code of conduct consists of 2 parts: part 1 for the user, part 2 for the owner of a group on the cluster

## Part 1: Rules for users of the UMCG HPC cluster:
- Permission to access the HPC cluster is limited to users who have completed the UMCG
e-learing: "Privacy in research". If you have a contract (aanstelling) with the UMCG go to lms.umcg.nl and search 
for privacy to find the e-learing. If this does not work or you do not have a UMCG contract please go to:
[Privacy in Research - GDPR / AVG (E-learning only; PWO)](https://umcg.capp12.nl/open-courses/recourses/699/storefront)
- Permission to access the HPC cluster is limited to scientists that have signed this Code of Conduct and 
submitted a pdf scan of the signed document in sRAM or mailed it to [the helpdesk](../contact/).
- In addition users of the HPC cluster also have to abide by the UMCG IT User Guidelines (accessible via 
https://umcg.zenya.work/portal/ search for “UMCG Richtlijn IT Gebruik”).
- Users of the HPC cluster need to abide by the Research Code UMCG, accessible via
https://umcg.zenya.work/portal/ search for “Research Code UMCG” or via this link:
[UMCG research code](https://researchcode.umcgresearch.org/en/w/introduction)
- Users of the HPC cluster are obliged to adhere to the UMCG clear-screen policy: assure no unauthorized people 
can read your screen. When you leave your computer you must lock the screen.
- Human-related data is only allowed to be uploaded to the HPC cluster when in line with the obtained informed 
consent.
- Raw data or processed data that contain potentially identifiable information data shall not be downloaded from 
the HPC cluster to private or institutional computers, unless approved by the data controller.
- Cluster users are bound to GDPR and other relevant regulations.
- Cluster users are responsible for reporting inadvertent data release, breach of data
security, or other data management incidents contrary to the terms of data access
specified in this Code of Conduct to the [HPC helpdesk](../contact/)
- in case of a potential data breach this needs to be reported to the UMCG privacy work organisation by phone via 
+31(0)50-3611111; or via the Orange SOS button on the UMCG Intranet page and also to the [HPC helpdesk](../contact/) 
- Only use pseudonimized or anonimyzed data on the UMCG HPC cluster.
- Do not store the key of your pseudonimisation on the cluster. The key should be stored in RedCap.
- Do not store any data containing names, addresses, or any other contact information or identifiers of study 
participants or patients (such as UMCG patient numbers) on the HPC cluster.
- You agree not to use any data on the cluster to identify or contact individual subjects.
- You agree to preserve, at all times, the confidentiality of information and data. In
particular, You undertake not to use, or attempt to use data to compromise or otherwise infringe the 
confidentiality of information on data subjects and their right to privacy.
- Before and after downloading of a dataset users must compute checksums of the data and check this to ensure 
data integrity.
- You accept that the UMCG and the Genomics Coordination Center Consortium accept no liability for direct, 
indirect, consequential or incidental, damages or losses arising from any use of the HPC cluster by anyone, or 
arising from the unavailability of, or break in access to, the HPC cluster for whatever reason.

### General
- We assume that you are familiar with some basic knowledge about Linux command line (shell) navigation and shell 
scripting. If you never worked on the command line, consider some Linux tutorials on the subject first and sign 
up for the RUG cluster courses.  
[Hábrók basis | Corporate Academy | Rijksuniversiteit Groningen (rug.nl)](https://www.rug.nl/corporate-academy/courses/habrok-basis?lang=en)  
[Hábrók geavanceerd | Corporate Academy | Rijksuniversiteit Groningen (rug.nl)](https://www.rug.nl/corporate-academy/courses/habrok-advanced?lang=en)
- We expect you to exploit our documentation before asking for help:
<http://docs.gcc.rug.nl/>

### Mailing List
- We communicate upcoming events (e.g. maintenance downtimes) on our low volume
mailing list. You will automatically be subscribed to this list during activation of your
cluster account.

### Security
- Do not share your account
- If using public key authentication, never share your private key (also not with our helpdesk!). If you by 
accident shared your private key with anyone (including our helpdesk) you have to make a new keypair and send the 
public key to [the helpdesk](../contact/).

### General Communication with the Cluster Administrators
- Please [mail us](../contact/) for questions, issues or comments regarding our clusters.
- Do not use the personal email address of a cluster administrator. This is important
because it keeps all administrators informed about the ongoing problem-solving process, and if one administrator 
is not available, another administrator can help you with your question.
- For each new problem, start a new conversation with a new subject. Avoid writing to us by replying to an old 
answer mail from the last problem that you received from us or even worse by replying to a mailing list email you 
received from us.

### Problem-Solving Process
- Exploit resources provided by your institute/research group before asking our staff about domain-specific 
problems. We make an effort to help you, but we are no experts in your field, hence a colleague from your group 
who uses the cluster to solve a similar problem like you do might be a better first contact
- Ask Google for help before contacting us. We often also just “google” for an answer, and then forward the 
outcome to you.
- Do not ask for/expect step-by-step solutions to a problem. Sometimes we give step-by-step instructions, but 
generally you should use our answers to do some refined research on the problem. If you still stuck, we are happy 
to provide further support
- Always give an exact as possible description of the problem. Provide your username,
error messages, the path to the job script, the id of the job, and other hints that make the problem-solving 
process as economic as possible (screenshots are very welcome).

### Housekeeping
- Clean up your home directory frequently, in particular before asking for an increase of your quota limit
- Do not save thousands of files in a single directory. Distribute the files to subdirectories.
- If you have any results from your computations that you want to store, do not keep them on the temporary (tmp) 
storage systems but as the datamanager of your group to move them to the permanent (prm) filesystem. Data on the 
prm filesystem is regularly backed up to tape whereas data on tmp is not. If anything happens to the tmp 
filesystem all data on there can be gone with no possibility to restore it.

### Job Submission
- Before submitting the same job a hundred times, please verify that the job finishes
successfully. We often experience that hundreds of jobs getting killed due to an invalid path referenced in the 
job script.

### Cluster Performance
- **DO NOT** run resource-intensive computations directly on the login node AKA submit
node AKA Head node. This will have a negative impact on the performance of the whole cluster. Instead, generate a 
job script that carries out the computations and submit this job script to the cluster using sbatch.
- **DO NOT** run server applications (PostgreSQL server, web server, ...) on the front-end server (submit hosts). 
Such a program usually run as a background process (daemon) rather than being under the direct control of an 
interactive user. We will immediately kill such processes.

## Part 2: Rules for owners of a group on the UMCG HPC cluster:
The rules for users (part 1 of this Code of Conduct) also apply for group owners
Group owners are responsible for:
  
- the research project should be registered in the UMCG research register
- the data inside their group
- giving or rejecting access to their group including the end-date of acces given.
- appointing data managers for their group
- paying the annual costs associated with their cluster group. For this the group owner will need to provide a budget number or “kostenplaats”.

### Conclusion and signature:

I read and understand the UMCG HPC Code of Conduct. I declare that I will abide by it and will act accordingly. I 
understand that failure to adhere to the Code of Conduct will have repercussions for my access to the HPC 
cluster.

Please, sign this Code of Conduct and send a scanned copy to [the helpdesk](../contact/).

We wish you many fruitful computations!

Name: <u>____________________________________________</u>

Role (please tick appropriate boxes):  
&#x25a2; cluster user  
&#x25a2; owner of a group on the cluster  

Date: <u>____________________________________________</u>

Signature: <u>____________________________________________</u>
