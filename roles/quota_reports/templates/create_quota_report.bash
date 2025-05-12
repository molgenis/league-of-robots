#!/bin/bash

set -e
set -u
set -o pipefail

quota_reports_folder="{{ quota_reports_folder }}"
{% raw %}
output_folder="${quota_reports_folder}/$(date +%Y)"
output_file="$(date +%m)-quota_report_$(hostname)"

# Create output folder if it does not exist.
mkdir -p -m 0750 "${quota_reports_folder}"
mkdir -p -m 0750 "${output_folder}"

# run quota script and dismiss home folders
/root/quota -a -p | { head -4; sed -n -e '/\/groups\//,/[-]+/p'; } > "${output_folder}/${output_file}"

# Add results of total file system size to output file
df -h >> "${output_folder}/${output_file}"
{% endraw %}
