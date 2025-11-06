#
# Read-only credentials for querying one or more LDAP domains configured in SSSD
# with Bash scripts like those from the cluster-utils module.
#
# This file was deployed with Ansible and can be sourced in Bash.
#
declare -a domain_names=({% for ldap_domain, ldap_config in ldap_domains.items() %}'{{ ldap_domain }}'{% if not loop.last %} {% endif %}{% endfor %})
declare -A domain_configs=(
{% for ldap_domain, ldap_config in ldap_domains.items() %}
    [{{ ldap_domain }}_uri]='{{ ldap_config['uri'] }}'
    [{{ ldap_domain }}_search_base]='{{ ldap_config['base'] }}'
    [{{ ldap_domain }}_bind_dn]='{{ ldap_credentials[ldap_domain]['readonly']['dn'] }}'
    [{{ ldap_domain }}_bind_pw]='{{ ldap_credentials[ldap_domain]['readonly']['pw'] }}'
    [{{ ldap_domain }}_user_object_class]='{{ ldap_config['user_object_class'] | default('posixAccount') }}'
    [{{ ldap_domain }}_user_ssh_public_key]='{{ ldap_config['user_ssh_public_key'] | default('sshPublicKey') }}'
    [{{ ldap_domain }}_user_expiration_date]='{{ ldap_config['user_expiration_date'] | default('loginExpirationTime') }}'
    [{{ ldap_domain }}_user_expiration_regex]='{{ ldap_config['user_expiration_regex'] | default('^([0-9]{4})([0-9]{2})([0-9]{2}).+Z$') }}'
    [{{ ldap_domain }}_group_object_class]='{{ ldap_config['group_object_class'] | default('posixGroup') }}'
{% endfor %}
)