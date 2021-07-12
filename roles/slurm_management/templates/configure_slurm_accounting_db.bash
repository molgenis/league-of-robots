#!/bin/bash

#
##
### Create Slurm DB for the accounting info of this cluster.
##
#
sacctmgr -i add cluster {{ slurm_cluster_name }}

#
##
### Create Quality of Service (QoS) levels.
##
#

#
# NOTE: First create entities with as little detail as possible.
#       Then modify the bare entities to include other params/settings.
#       This ensures entities will get updated when this script was updated and executed again.
#       When all params/settings would be specified during "create", 
#       then updates would not take effect as the "create" for existing entities will fail
#       with exit code 1 and the message "Nothing new added." printed to STDOUT.
#

#
# QoS leftover
#
sacctmgr -i create qos set Name='leftover'
sacctmgr -i modify qos Name='leftover' set \
    Description='Go Dutch: Quality of Service level for cheapskates with zero priority, but resources consumed do not impact your Fair Share.' \
    Priority=0 \
    UsageFactor=0 \
    GrpSubmit=30000 MaxSubmitJobsPU=10000 \
    GrpTRES=cpu=0,mem=0

sacctmgr -i create qos set Name='leftover-short'
sacctmgr -i modify qos Name='leftover-short' set \
    Description='leftover-short' \
    Priority=0 \
    UsageFactor=0 \
    GrpSubmit=30000 MaxSubmitJobsPU=10000 MaxWall=06:00:00

sacctmgr -i create qos set Name='leftover-medium'
sacctmgr -i modify qos Name='leftover-medium' set \
    Description='leftover-medium' \
    Priority=0 \
    UsageFactor=0 \
    GrpSubmit=30000 MaxSubmitJobsPU=10000 MaxWall=1-00:00:00

sacctmgr -i create qos set Name='leftover-long'
sacctmgr -i modify qos Name='leftover-long' set \
    Description='leftover-long' \
    Priority=0 \
    UsageFactor=0 \
    GrpSubmit=3000 MaxSubmitJobsPU=1000  MaxWall=7-00:00:00

#
# QoS regular
#
sacctmgr -i create qos set Name='regular'
sacctmgr -i modify qos Name='regular' set \
    Description='Standard Quality of Service level with default priority and corresponding impact on your Fair Share.' \
    Priority=10 \
    GrpSubmit=30000 MaxSubmitJobsPU=5000 \
    GrpTRES=cpu=0,mem=0

sacctmgr -i create qos set Name='regular-short'
sacctmgr -i modify qos Name='regular-short' set \
    Description='regular-short' \
    Priority=10 \
    Preempt='leftover-short,leftover-medium,leftover-long' \
    GrpSubmit=30000 MaxSubmitJobsPU=5000  MaxWall=06:00:00

sacctmgr -i create qos set Name='regular-medium'
sacctmgr -i modify qos Name='regular-medium' set \
    Description='regular-medium' \
    Priority=10 \
    Preempt='leftover-short,leftover-medium,leftover-long' \
    GrpSubmit=30000 MaxSubmitJobsPU=5000  MaxWall=1-00:00:00 \
    GrpTRES=cpu={{ [1, (cluster_cores_total | float * 0.6) | int] | max }},mem={{ [1000, (cluster_mem_total | float * 0.6) | int] | max }} \
    MaxTRESPU=cpu={{ [1, (cluster_cores_total | float * 0.4) | int] | max }},mem={{ [1000, (cluster_mem_total | float * 0.4) | int] | max }}

sacctmgr -i create qos set Name='regular-long'
sacctmgr -i modify qos Name='regular-long' set \
    Description='regular-long' \
    Priority=10 \
    Preempt='leftover-short,leftover-medium,leftover-long' \
    GrpSubmit=3000 MaxSubmitJobsPU=1000  MaxWall=7-00:00:00 \
    GrpTRES=cpu={{ [1, (cluster_cores_total | float * 0.3) | int] | max }},mem={{ [1000, (cluster_mem_total | float * 0.3) | int] | max }} \
    MaxTRESPU=cpu={{ [1, (cluster_cores_total | float * 0.15) | int] | max }},mem={{ [1000, (cluster_mem_total | float * 0.15) | int] | max }}

#
# QoS priority
#
sacctmgr -i create qos set Name='priority'
sacctmgr -i modify qos Name='priority' set \
    Description='High priority Quality of Service level with corresponding higher impact on your Fair Share.' \
    Priority=20 \
    UsageFactor=2 \
    GrpSubmit=5000  MaxSubmitJobsPU=1000 \
    GrpTRES=cpu=0,mem=0

sacctmgr -i create qos set Name='priority-short'
sacctmgr -i modify qos Name='priority-short' set \
    Description='priority-short' \
    Priority=20 \
    Preempt='leftover-short,leftover-medium,leftover-long' \
    UsageFactor=2 \
    GrpSubmit=5000  MaxSubmitJobsPU=1000   MaxWall=06:00:00 \
    MaxTRESPU=cpu={{ [1, (cluster_cores_total | float * 0.25) | int] | max }},mem={{ [1000, (cluster_mem_total | float * 0.25) | int] | max }}

sacctmgr -i create qos set Name='priority-medium'
sacctmgr -i modify qos Name='priority-medium' set \
    Description='priority-medium' \
    Priority=20 \
    Preempt='leftover-short,leftover-medium,leftover-long' \
    UsageFactor=2 \
    GrpSubmit=2500  MaxSubmitJobsPU=500   MaxWall=1-00:00:00 \
    GrpTRES=cpu={{ [1, (cluster_cores_total | float * 0.6) | int] | max }},mem={{ [1000, (cluster_mem_total | float * 0.6) | int] | max }} \
    MaxTRESPU=cpu={{ [1, (cluster_cores_total | float * 0.2) | int] | max }},mem={{ [1000, (cluster_mem_total | float * 0.2) | int] | max }}

sacctmgr -i create qos set Name='priority-long'
sacctmgr -i modify qos Name='priority-long' set \
    Description='priority-long' \
    Priority=20 \
    Preempt='leftover-short,leftover-medium,leftover-long' \
    UsageFactor=2 \
    GrpSubmit=250   MaxSubmitJobsPU=50   MaxWall=7-00:00:00 \
    GrpTRES=cpu={{ [1, (cluster_cores_total | float * 0.3) | int] | max }},mem={{ [1000, (cluster_mem_total | float * 0.3) | int] | max }} \
    MaxTRESPU=cpu={{ [1, (cluster_cores_total | float * 0.1) | int] | max }},mem={{ [1000, (cluster_mem_total | float * 0.1) | int] | max }}

#
# QoS interactive
#
sacctmgr -i create qos set Name='interactive'
sacctmgr -i modify qos Name='interactive' set \
    Description='Highest priority Quality of Service level for interactive sessions.' \
    Priority=30 \
    UsageFactor=1 \
    MaxSubmitJobsPU=1 \
    GrpTRES=cpu=0,mem=0

sacctmgr -i create qos set Name='interactive-short'
sacctmgr -i modify qos Name='interactive-short' set \
    Description='interactive-short' \
    Priority=30 \
    Preempt='leftover-short,leftover-medium,leftover-long,regular-short' \
    UsageFactor=1 \
    MaxSubmitJobsPU=1   MaxWall=06:00:00 \
    MaxTRESPU=cpu={{ [1, (vcompute_max_cpus_per_node | float * 0.5) | int] | max }},mem={{ [1000, (vcompute_max_mem_per_node | float * 0.5) | int] | max }}

#
# QoS ds
#
sacctmgr -i create qos set Name='ds'
sacctmgr -i modify qos Name='ds' set \
    Description='Data Staging Quality of Service level for jobs with access to prm storage.' \
    Priority=10 \
    UsageFactor=1 \
    GrpSubmit=5000  MaxSubmitJobsPU=1000 \
    GrpTRES=cpu=0,mem=0

sacctmgr -i create qos set Name='ds-short'
sacctmgr -i modify qos Name='ds-short' set \
    Description='ds-short' \
    Priority=10 \
    UsageFactor=1 \
    GrpSubmit=5000  MaxSubmitJobsPU=1000   MaxWall=06:00:00 \
    MaxTRESPU=cpu=4,mem=4096

sacctmgr -i create qos set Name='ds-medium'
sacctmgr -i modify qos Name='ds-medium' set \
    Description='ds-medium' \
    Priority=10 \
    UsageFactor=1 \
    GrpSubmit=2500  MaxSubmitJobsPU=500   MaxWall=1-00:00:00 \
    GrpTRES=cpu=2,mem=2048 \
    MaxTRESPU=cpu=2,mem=2048

sacctmgr -i create qos set Name='ds-long'
sacctmgr -i modify qos Name='ds-long' set \
    Description='ds-long' \
    Priority=10 \
    UsageFactor=1 \
    GrpSubmit=250   MaxSubmitJobsPU=50   MaxWall=7-00:00:00 \
    GrpTRES=cpu=1,mem=1024 \
    MaxTRESPU=cpu=1,mem=1024

#
##
### Create accounts and assign QoS to accounts.
##
#

#
# Create 'users' account in addition to the default 'root' account.
#
sacctmgr -i create account users \
    Descr=scientists Org=various

#
# Assign QoS to the root account.
#
sacctmgr -i modify account root set \
    QOS=priority,priority-short,priority-medium,priority-long

sacctmgr -i modify account root set \
    QOS+=leftover,leftover-short,leftover-medium,leftover-long

sacctmgr -i modify account root set \
    QOS+=regular,regular-short,regular-medium,regular-long

sacctmgr -i modify account root set \
    QOS+=ds,ds-short,ds-medium,ds-long

sacctmgr -i modify account root set \
    QOS+=interactive,interactive-short

sacctmgr -i modify account root set \
    DefaultQOS=priority

#
# Assign QoS to the users account.
#
sacctmgr -i modify account users set \
    QOS=regular,regular-short,regular-medium,regular-long

sacctmgr -i modify account users set \
    QOS+=priority,priority-short,priority-medium,priority-long

sacctmgr -i modify account users set \
    QOS+=leftover,leftover-short,leftover-medium,leftover-long

sacctmgr -i modify account users set \
    QOS+=ds,ds-short,ds-medium,ds-long

sacctmgr -i modify account users set \
    QOS+=interactive,interactive-short

sacctmgr -i modify account users set \
    DefaultQOS=regular

#
##
### Example code to check whether the above worked out well.
##
#

#
# List all associations to verify the required accounts exist and the right (default) QoS.
#
#sacctmgr show assoc tree format=Cluster%8,Account,User%-30,Share%5,QOS%-222,DefaultQOS%-8

#
# List all QoS and verify pre-emption settings.
#
#sacctmgr show qos format=Name%15,Priority,UsageFactor,GrpTRES%30,GrpSubmit,GrpJobs,MaxTRESPerUser%30,MaxSubmitJobsPerUser,MaxJobsPerUser,MaxTRESPerJob,MaxWallDurationPerJob,Preempt%45
