#!/bin/bash

slurm_cluster_name='{{ slurm_cluster_name | capitalize }}'
slurm_notification_slack_webhook='{{ slurm_notification_slack_webhook[stack_dtap_state] }}'
{% raw %}
slurm_event_type='unspecified'

#
# Get commandline arguments.
#
while getopts "e:" opt
do
	case "${opt}" in
		e)
			slurm_event_type="${OPTARG^^}"
			;;
		\?)
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Invalid option -${OPTARG}. Try $(basename "${0}") -h for help."
			;;
		:)
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Option -${OPTARG} requires an argument. Try $(basename "${0}") -h for help."
			;;
		*)
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Unhandled option. Try $(basename "${0}") -h for help."
			;;
	esac
done

#
# Compile JSON message payload.
#
read -r -d '' message << EOM
{
	"type": "mrkdwn",
	"text": "*_${slurm_cluster_name}_ needs help*:  
Please check and fix my \`slurmbdbd\` and \`slurmctld\` on $(hostname)!  
The \`strigger\` command detected an event of type:
\`\`\`
${slurm_event_type}
\`\`\`
The \`scontrol ping\` command reports:
\`\`\`
$(scontrol ping | tr \" \')
\`\`\`
Systemd reports:
\`\`\`
$(systemctl status slurmdbd.service | tr \" \')
\`\`\`
\`\`\`
$(systemctl status slurmctld.service | tr \" \')
\`\`\`"
}
EOM

#
# Post message to Slack channel.
#
curl -X POST "${slurm_notification_slack_webhook}" \
	 -H 'Content-Type: application/json' \
	 -d "${message}"
{% endraw %}
