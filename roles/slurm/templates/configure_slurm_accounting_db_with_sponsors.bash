#jinja2: trim_blocks:True, lstrip_blocks: True
#!/bin/bash

set -e
set -u
set -o pipefail

section_header='##########################################################################\n'
item_separator='--------------------------------------------------------------------------\n'
#
##
### Lists of groups and sponsors
##
#
declare -A sponsors=(
{% for sponsor in sponsors %}
	['{{ sponsor["name"] }}']='{{ sponsor["slurm_shares"] }}'
{% endfor %}
)
declare -A groups=(
{% for regular_group in regular_groups %}
	{% if regular_group['sponsor'] is defined %}
	['{{ regular_group["name"] }}']='{{ regular_group["sponsor"] }}'
	{% endif %}
{% endfor %}
)
#
##
### Create Slurm DB for the accounting info of this cluster.
##
#
printf -- "${section_header}"
printf 'Managing clusters\n'
printf -- "${section_header}"
cluster_found="$(sacctmgr --parsable2 --noheader show cluster '{{ slurm_cluster_name }}' format=Cluster)"
if [[ "${cluster_found}" != "{{ slurm_cluster_name }}" ]]; then
	sacctmgr -i add cluster "{{ slurm_cluster_name }}"
else
	printf 'Cluster "%s" already exists.\n' "{{ slurm_cluster_name }}"
fi
#
##
### Create Quality of Service (QoS) levels.
##
#
# NOTE: First create entities with as little detail as possible.
#       Then modify the bare entities to include other params/settings.
#       This ensures entities will get updated when this script was updated and executed again.
#       When all params/settings would be specified during "create", 
#       then updates would not take effect as the "create" for existing entities will fail
#       with exit code 1 and the message "Nothing new added." printed to STDOUT.
#
printf -- "${section_header}"
printf 'Managing QoS levels\n'
printf -- "${section_header}"
declare -a qos_levels=(
	'leftover'
	'leftover-short'
	'leftover-medium'
	'leftover-long'
	'regular'
	'regular-short'
	'regular-medium'
	'regular-long'
	'priority'
	'priority-short'
	'priority-medium'
	'priority-long'
	'interactive'
	'interactive-short'
	'ds'
	'ds-short'
	'ds-medium'
	'ds-long'
)
for qos_level in "${qos_levels[@]}"; do
	qos_level_found="$(sacctmgr --parsable2 --noheader show qos "${qos_level}" format=Name)"
	if [[ "${qos_level_found}" != "${qos_level}" ]]; then
		sacctmgr -i create qos "${qos_level}"
	else
		printf 'QoS "%s" already exists.\n' "${qos_level}"
	fi
	printf -- "${item_separator}"
done
#
##
### Update Quality of Service (QoS) levels.
##
#
# QoS leftover
#
sacctmgr -i modify qos Name='leftover' set \
	Description='Go Dutch: Quality of Service level for cheapskates with zero priority, but resources consumed do not impact your Fair Share.' \
	Priority=0 \
	UsageFactor=0 \
	GrpSubmit=30000 MaxSubmitJobsPU=10000 \
	GrpTRES={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu=0,{% endif %}cpu=0,mem=0
sacctmgr -i modify qos Name='leftover-short' set \
	Description='leftover-short' \
	Priority=0 \
	UsageFactor=0 \
	GrpSubmit=30000 MaxSubmitJobsPU=10000 MaxWall=06:00:00
sacctmgr -i modify qos Name='leftover-medium' set \
	Description='leftover-medium' \
	Priority=0 \
	UsageFactor=0 \
	GrpSubmit=30000 MaxSubmitJobsPU=10000 MaxWall=1-00:00:00
sacctmgr -i modify qos Name='leftover-long' set \
	Description='leftover-long' \
	Priority=0 \
	UsageFactor=0 \
	GrpSubmit=3000 MaxSubmitJobsPU=1000  MaxWall=7-00:00:00
printf -- "${item_separator}"
#
# QoS regular
#
sacctmgr -i modify qos Name='regular' set \
	Description='Standard Quality of Service level with default priority and corresponding impact on your Fair Share.' \
	Priority=10 \
	GrpSubmit=30000 MaxSubmitJobsPU=5000 \
	GrpTRES={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu=0,{% endif %}cpu=0,mem=0
sacctmgr -i modify qos Name='regular-short' set \
	Description='regular-short' \
	Priority=10 \
	Preempt='leftover-short,leftover-medium,leftover-long' \
	GrpSubmit=30000 MaxSubmitJobsPU=5000  MaxWall=06:00:00
sacctmgr -i modify qos Name='regular-medium' set \
	Description='regular-medium' \
	Priority=10 \
	Preempt='leftover-short,leftover-medium,leftover-long' \
	GrpSubmit=30000 MaxSubmitJobsPU=5000  MaxWall=1-00:00:00 \
	GrpTRES={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu={{ slurm_qos_limits['regular-medium']['group']['gpus'] }},{% endif %}cpu={{ slurm_qos_limits['regular-medium']['group']['cores'] }},mem={{ slurm_qos_limits['regular-medium']['group']['mem'] }} \
	MaxTRESPU={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu={{ slurm_qos_limits['regular-medium']['user']['gpus'] }},{% endif %}cpu={{ slurm_qos_limits['regular-medium']['user']['cores'] }},mem={{ slurm_qos_limits['regular-medium']['user']['mem'] }}
sacctmgr -i modify qos Name='regular-long' set \
	Description='regular-long' \
	Priority=10 \
	Preempt='leftover-short,leftover-medium,leftover-long' \
	GrpSubmit=3000 MaxSubmitJobsPU=1000  MaxWall=7-00:00:00 \
	GrpTRES={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu={{ slurm_qos_limits['regular-long']['group']['gpus'] }},{% endif %}cpu={{ slurm_qos_limits['regular-long']['group']['cores'] }},mem={{ slurm_qos_limits['regular-long']['group']['mem'] }} \
	MaxTRESPU={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu={{ slurm_qos_limits['regular-long']['user']['gpus'] }},{% endif %}cpu={{ slurm_qos_limits['regular-long']['user']['cores'] }},mem={{ slurm_qos_limits['regular-long']['user']['mem'] }}
printf -- "${item_separator}"
#
# QoS priority
#
sacctmgr -i modify qos Name='priority' set \
	Description='High priority Quality of Service level with corresponding higher impact on your Fair Share.' \
	Priority=20 \
	UsageFactor=2 \
	GrpSubmit=5000  MaxSubmitJobsPU=1000 \
	GrpTRES={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu=0,{% endif %}cpu=0,mem=0
sacctmgr -i modify qos Name='priority-short' set \
	Description='priority-short' \
	Priority=20 \
	Preempt='leftover-short,leftover-medium,leftover-long' \
	UsageFactor=2 \
	GrpSubmit=5000  MaxSubmitJobsPU=1000   MaxWall=06:00:00 \
	MaxTRESPU={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu={{ slurm_qos_limits['priority-short']['user']['gpus'] }},{% endif %}cpu={{ slurm_qos_limits['priority-short']['user']['cores'] }},mem={{ slurm_qos_limits['priority-short']['user']['mem'] }}
sacctmgr -i modify qos Name='priority-medium' set \
	Description='priority-medium' \
	Priority=20 \
	Preempt='leftover-short,leftover-medium,leftover-long' \
	UsageFactor=2 \
	GrpSubmit=2500  MaxSubmitJobsPU=500   MaxWall=1-00:00:00 \
	GrpTRES={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu={{ slurm_qos_limits['priority-medium']['group']['gpus'] }},{% endif %}cpu={{ slurm_qos_limits['priority-medium']['group']['cores'] }},mem={{ slurm_qos_limits['priority-medium']['group']['mem'] }} \
	MaxTRESPU={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu={{ slurm_qos_limits['priority-medium']['user']['gpus'] }},{% endif %}cpu={{ slurm_qos_limits['priority-medium']['user']['cores'] }},mem={{ slurm_qos_limits['priority-medium']['user']['mem'] }}
sacctmgr -i modify qos Name='priority-long' set \
	Description='priority-long' \
	Priority=20 \
	Preempt='leftover-short,leftover-medium,leftover-long' \
	UsageFactor=2 \
	GrpSubmit=250   MaxSubmitJobsPU=50   MaxWall=7-00:00:00 \
	GrpTRES={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu={{ slurm_qos_limits['priority-long']['group']['gpus'] }},{% endif %}cpu={{ slurm_qos_limits['priority-long']['group']['cores'] }},mem={{ slurm_qos_limits['priority-long']['group']['mem'] }} \
	MaxTRESPU={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu={{ slurm_qos_limits['priority-long']['user']['gpus'] }},{% endif %}cpu={{ slurm_qos_limits['priority-long']['user']['cores'] }},mem={{ slurm_qos_limits['priority-long']['user']['mem'] }}
printf -- "${item_separator}"
#
# QoS interactive
#
sacctmgr -i modify qos Name='interactive' set \
	Description='Highest priority Quality of Service level for interactive sessions.' \
	Priority=30 \
	UsageFactor=1 \
	MaxSubmitJobsPU=1 \
	GrpTRES={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu=0,{% endif %}cpu=0,mem=0
sacctmgr -i modify qos Name='interactive-short' set \
	Description='interactive-short' \
	Priority=30 \
	Preempt='leftover-short,leftover-medium,leftover-long,regular-short' \
	UsageFactor=1 \
	MaxSubmitJobsPU=1   MaxWall=06:00:00 \
	MaxTRESPU={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu={{ slurm_qos_limits['interactive-short']['user']['gpus'] }},{% endif %}cpu={{ slurm_qos_limits['interactive-short']['user']['cores'] }},mem={{ slurm_qos_limits['interactive-short']['user']['mem'] }}
printf -- "${item_separator}"
#
# QoS ds
#
sacctmgr -i modify qos Name='ds' set \
	Description='Data Staging Quality of Service level for jobs with access to prm storage.' \
	Priority=10 \
	UsageFactor=1 \
	GrpSubmit=5000  MaxSubmitJobsPU=1000 \
	GrpTRES={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu=0,{% endif %}cpu=0,mem=0
sacctmgr -i modify qos Name='ds-short' set \
	Description='ds-short' \
	Priority=10 \
	UsageFactor=1 \
	GrpSubmit=5000  MaxSubmitJobsPU=1000   MaxWall=06:00:00 \
	MaxTRESPU={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu=0,{% endif %}cpu=4,mem=4096
sacctmgr -i modify qos Name='ds-medium' set \
	Description='ds-medium' \
	Priority=10 \
	UsageFactor=1 \
	GrpSubmit=2500  MaxSubmitJobsPU=500   MaxWall=1-00:00:00 \
	GrpTRES={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu=0,{% endif %}cpu=2,mem=2048 \
	MaxTRESPU={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu=0,{% endif %}cpu=2,mem=2048
sacctmgr -i modify qos Name='ds-long' set \
	Description='ds-long' \
	Priority=10 \
	UsageFactor=1 \
	GrpSubmit=250   MaxSubmitJobsPU=50   MaxWall=7-00:00:00 \
	GrpTRES={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu=0,{% endif %}cpu=1,mem=1024 \
	MaxTRESPU={% if slurm_cluster_gpus_total | int > 0 %}gres/gpu=0,{% endif %}cpu=1,mem=1024
#
##
### Create accounts and assign QoS to accounts.
##
#
printf -- "${section_header}"
printf 'Managing accounts\n'
printf -- "${section_header}"
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
printf -- "${item_separator}"
#
# Create 'users' account in addition to the default 'root' account.
#
account_found="$(sacctmgr --parsable2 --noheader show account 'users' format=Account)"
if [[ "${account_found}" != 'users' ]]; then
	sacctmgr -i create account users Descr=scientists Org=various
else
	printf 'Account "%s" already exists.\n' 'users'
fi
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
printf -- "${item_separator}"
#
# Create/update sponsor accounts.
#
for sponsor in "${!sponsors[@]}"; do
	account_found="$(sacctmgr --parsable2 --noheader show account "${sponsor}" format=Account)"
	if [[ "${account_found}" != "${sponsor}" ]]; then
		sacctmgr -i create account "${sponsor}" FairShare="${sponsors[${sponsor}]}" \
			Descr=sponsor Org=various Parent=users
	else
		printf 'Account for sponsor "%s" already exists.\n' "${sponsor}"
	fi
	account_found="$(sacctmgr --parsable2 --noheader show account "${sponsor}" withassoc format=ParentName,Account,Share,Desc,Org)"
	if [[ "${account_found}" != "users|${sponsor}|${sponsors[${sponsor}]}|sponsor|various" ]]; then
		sacctmgr -i modify account "${sponsor}" set FairShare="${sponsors[${sponsor}]}" \
			Descr=sponsor Org=various Parent=users
	else
		printf 'Account for sponsor "%s" already up-to-date: nothing modified.\n' "${sponsor}"
	fi
	printf -- "${item_separator}"
done
#
# Create/update group accounts.
#
# Use fairshare=parent only for (group) accounts to flatten the tree.
# We use the groups only for reporting and not for differentiation in fair share factors.
# See: https://bugs.schedmd.com/show_bug.cgi?id=3491
#
# When using nested accounts sacctmgr will always report "nothing has changed" as long as
# the parent for the account is unchanged. Hence when we detected some values need to be changed 
# and issue an "sacctmgr modify ..." command, then it will fail with
#     sacctmgr: error: Request didn't affect anything
#     Error with request: Data has not changed since time specified
# and return exit code 1
# The workaround is to check and update if necessary the parent separately from
# checking and updating if necessary all other group account values.
#
for group in "${!groups[@]}"; do
	account_found="$(sacctmgr --parsable2 --noheader show account "${group}" format=Account)"
	if [[ "${account_found}" != "${group}" ]]; then
		sacctmgr -i create account "${group}" Parent="${groups[${group}]}" Descr=group Org=various FairShare=parent
	else
		printf 'Account for group "%s" already exists.\n' "${group}"
	fi
	account_found="$(sacctmgr --parsable2 --noheader show account "${group}" withassoc format=ParentName,Account)"
	if [[ "${account_found}" != "${groups[${group}]}|${group}" ]]; then
		sacctmgr -i modify account "${group}" set Parent="${groups[${group}]}"
	else
		printf 'Parent of account for group "%s" already up-to-date: nothing modified.\n' "${group}"
	fi
	account_found="$(sacctmgr --parsable2 --noheader show account "${group}" withassoc format=Account,Share,Desc,Org)"
	if [[ "${account_found}" != "${group}|parent|group|various" ]]; then
		sacctmgr -i modify account "${group}" set Descr=group Org=various FairShare=parent
	else
		printf 'Account for group "%s" already up-to-date: nothing modified.\n' "${group}"
	fi
	printf -- "${item_separator}"
done
#
##
### Example code to check whether the above worked out well.
##
#
# List all associations to verify the required accounts exist and the right (default) QoS.
#
#sacctmgr show assoc tree format=Cluster%8,Account,User%-30,Share%5,QOS%-222,DefaultQOS%-8
#
# List all QoS and verify pre-emption settings.
#
#sacctmgr show qos format=Name%15,Priority,UsageFactor,GrpTRES%30,GrpSubmit,GrpJobs,MaxTRESPerUser%30,MaxSubmitJobsPerUser,MaxJobsPerUser,MaxTRESPerJob,MaxWallDurationPerJob,Preempt%45
