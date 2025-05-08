#!/bin/bash

_logger_tag="limitedusers"
_uid="$(id -u "${PAM_USER}")"
_user="${PAM_USER}"
logger -t "${_logger_tag}" "[$0] runing under uid '$(id -u)' for user with uid '${_uid}'"

# limit cpu resources
{% if ansible_facts.processor_nproc >= 8 %}
_cpuquota={{ ansible_facts.processor_nproc*10 }}  # cpus >= 8, each user gets 10% of total cpus
{% elif ansible_facts.processor_nproc > 1 %} 
_cpuquota={{ ansible_facts.processor_nproc*20 }} # cpus >=1 and cpus < 8, each user gets 20% of total cpus
{% else %}
_cpuquota="33" # cpus = 1, each user gets 33% of total cpus
{% endif %}

# limit memory resources
{% if ansible_facts.memory_mb.real.total >= 100000 %}
_memlimit="{{ ansible_facts.memory_mb.real.total / 25 }}" # memory > 100GB, each user gets 4% of total memory
{% elif ansible_facts.memory_mb.real.total >= 2000 %} 
_memlimit="{{ ansible_facts.memory_mb.real.total / 10 }}" # memory > 2G and memory < 100G, each user gets 10% of all memory
{% else %}
_memlimit="{{ ansible_facts.memory_mb.real.total / 3 }}" # memory < 2G, each user gets 33% of all memory
{% endif %}

_groups=$(id -nG "${_uid}" 2>/dev/null)
if [ "${_uid}" -gt 1000 ] && ! echo "${_groups}" | grep -qw "admin"; then
   logger -t "${_logger_tag}" "[$0] changing non-admin/regular user (uid ${_uid}) slice limit: ${_cpuquota}% of CPU and ${_memlimit}M of RAM."
   systemctl set-property user-"${_uid}".slice MemoryAccounting=true CPUAccounting=true CPUQuota="${_cpuquota}%" MemoryMax="${_memlimit//\.*}M"
   # IPAddressAllow="10.10.1.1/24"
fi
