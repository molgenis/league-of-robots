#!/bin/bash

set -e
set -u
set -o pipefail

{% raw %}
output_folder="/mnt/umcgst02/quota_reports/$(date +%Y)"
output_file="$(date +%m)-quota_report_$(hostname)"

#create output folder if it does not exist.
mkdir -p -m 0750 "${output_folder}"

# run quota script and dismiss home folders
/root/quota -a -p | { head -4; sed -n -e '/\/groups\//,/[-]+/p'; } > "${output_folder}/${output_file}"
{% endraw %}
