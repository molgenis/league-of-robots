#jinja2: trim_blocks:False
# SSH client config for users on Linux/Unix

The following assumes:

 * you have a ```${HOME}/.ssh``` folder with SSH keys (as generated using the instructions for requesting accounts)
 * and that you received a notification that your account has been activated
 * and that you are on the machine from which you want to connect to the cluster.
 * and that this machine has **OpenSSH 7.3p1 or newer**.  
   Older versions lack several OpenSSH features we need and are incompatible.

## 1. Create required directories and files if they do not exist yet

```
mkdir -p -m 700 "${HOME}/.ssh/"
mkdir -p -m 700 "${HOME}/.ssh/tmp/"
mkdir -p -m 700 "${HOME}/.ssh/conf.d/"
touch "${HOME}/.ssh/config"
touch "${HOME}/.ssh/known_hosts"
touch "${HOME}/.ssh/conf.d/{{ slurm_cluster_name }}"
chmod -R go-rwx "${HOME}/.ssh"
```

## 2. Configure Certificate Authority's (CA) public key to verify the identity of cluster servers

Append the public key from the Certificate Authority we used to sign the host keys of our machines to your ```${HOME}/.ssh/known_hosts``` file.  
Open a terminal and copy paste the following commands:
```
#
# Create new known_hosts file and append the UMCG HPC CA's public key.
#
printf '%s\n' \
            "@cert-authority {% for jumphost in groups['jumphost'] %}{{ jumphost | regex_replace('^' + ai_jumphost + '\\+','')}}*,{% if public_ip_addresses is defined and public_ip_addresses[jumphost] | length %}{{ public_ip_addresses[jumphost] }},{% endif %}{% endfor %}{% for adminhost in groups['administration'] %}*{{ adminhost | regex_replace('^' + ai_jumphost + '\\+','')}},{% endfor %}*{{ stack_prefix }}-* {{ lookup('file', ssh_host_signer_ca_private_key+'.pub') }} for {{ slurm_cluster_name }}" \
    > "${HOME}/.ssh/known_hosts.new"
if [[ -e "${HOME}/.ssh/known_hosts" ]]; then
    #
    # When user already had a known_hosts file, then 
    # remove a potentially outdated CA public key for the same machines based on the slurm_cluster_name: {{ slurm_cluster_name }}
    # and append all other lines to the new known_hosts file. 
    #
    sed '/^\@cert-authority .* for {{ slurm_cluster_name }}$/d' "${HOME}/.ssh/known_hosts" \
| sort >> "${HOME}/.ssh/known_hosts.new"
fi
#
# Make new known_hosts file the default.
#
mv "${HOME}/.ssh/known_hosts.new" "${HOME}/.ssh/known_hosts"
```

## 3. Add include directive to main SSH config file

Use a text editor to add the following line
```
Include conf.d/*
```
to the beginning of your ```${HOME}/.ssh/config``` file.
Important: this _Include_ directive must precede any lines containing _Host_ or _Match_ directives,
otherwise the _Include_ will only apply to a specific set of hosts.

## 4. Create SSH config file for {{ slurm_cluster_name | capitalize }}

Now we need to configure transparent multi-hop SSH for {{ slurm_cluster_name | capitalize }}.
Open your ```${HOME}/.ssh/conf.d/{{ slurm_cluster_name }}``` file in a text editor and add the lines below.

* Replace all occurrences of _**youraccount**_ with the account name you received from the helpdesk.
* Edit the line ```IdentityFile "~/.ssh/id_ed25519"``` to point to the private key file you generated if you did not save it in the default location, which is "~/.ssh/id_ed25519".

```
#
# Generic stuff: only for macOS clients.
#
IgnoreUnknown UseKeychain
    UseKeychain yes
IgnoreUnknown AddKeysToAgent
    AddKeysToAgent yes
#
# Host settings.
#
Host {% for jumphost in groups['jumphost'] %}{{ jumphost | regex_replace('^' + ai_jumphost + '\\+','')}}* {% endfor %}{% raw %}{% endraw %}
    #
    # Default account name when not specified explicitly.
    #
    User youraccount
    #
    # Prevent timeouts
    #
    ServerAliveInterval 60
    ServerAliveCountMax 5
    #
    # We use public-private key pairs for authentication.
    # Do not use password based authentication as fallback,
    # which may be confusing and won't work anyway.
    #
    IdentityFile "~/.ssh/id_ed25519"
    PasswordAuthentication No
    #
    # Multiplex connections to
    #   * reduce lag when logging in to the same host in a second terminal
    #   * reduce the amount of connections that are made to prevent excessive DNS lookups
    #     and to prevent getting blocked by a firewall, because it thinks we are executing a DoS attack.
    #
    # Name/location of sockets for connection multiplexing are configured using the ControlPath directive.
    # In the ControlPath directive %C expands to a hashed value of %l_%h_%p_%r, where:
    #    %l = local hostname
    #    %h = remote hostname
    #    %p = remote port
    #    %r = remote username
    # This makes sure that the ControlPath is
    #   * a unique socket that is local to machine on which the sessions are created,
    #     which means it works with home dirs from a shared network file system.
    #     (as sockets cannot be shared by servers.)
    #   * not getting to long as the hash has a fixed size not matter how long %l_%h_%p_%r was.
    #
    ControlMaster auto
    ControlPath ~/.ssh/tmp/%C
    ControlPersist 1m
#
# Expand short jumphost names to FQDN or IP address.
#{% if public_ip_addresses is defined and public_ip_addresses | length %}{% for jumphost in groups['jumphost'] %}
Host {{ jumphost | regex_replace('^' + ai_jumphost + '\\+','') }}
    HostName {{ public_ip_addresses[jumphost | regex_replace('^' + ai_jumphost + '\\+','')] }}{% endfor %}{% else %}
Host {% for jumphost in groups['jumphost'] %}{{ jumphost | regex_replace('^' + ai_jumphost + '\\+','') }} {% endfor %}{% if slurm_cluster_domain | length %}!*.{{ slurm_cluster_domain }}{% endif %}
    HostName %h{% if slurm_cluster_domain | length %}.{{ slurm_cluster_domain }}{% endif %}{% endif %}
#
# Universal jumphost settings for triple-hop SSH.
#
Host *+*+*
    ProxyCommand ssh -x -q $(echo %h | sed 's/+[^+]*$//') -W $(echo %h | sed 's/^[^+]*+[^+]*+//'):%p
#
# Double-hop SSH settings to connect via Jumphosts{% if slurm_cluster_domain | length %}{{ slurm_cluster_domain }}{% endif %}.
#
Host {% for jumphost in groups['jumphost'] %}{{ jumphost | regex_replace('^' + ai_jumphost + '\\+','')}}+* {% endfor %}{% raw %}{% endraw %}
    ProxyCommand ssh -x -q $(echo "${JUMPHOST_USER:-%r}")@$(echo %h | sed 's/+[^+]*$//'){% if slurm_cluster_domain | length %}.{{ slurm_cluster_domain }}{% endif %} -W $(echo %h | sed 's/^[^+]*+//'):%p
#
# Sometimes port 22 for the SSH protocol is blocked by firewalls; in that case you can try to use SSH on port 443 as fall-back.
# Do not use port 443 by default for SSH as it officially assigned to HTTPS traffic
# and some firewalls will cause problems when trying to route SSH over port 443.
#
Host {% for jumphost in groups['jumphost'] %}{{ jumphost | regex_replace('^' + ai_jumphost + '\\+','')}}443+* {% endfor %}{% raw %}{% endraw %}
    ProxyCommand ssh -x -q $(echo "${JUMPHOST_USER:-%r}")@$(echo %h | sed 's/443+[^+]*$//'){% if slurm_cluster_domain | length %}.{{ slurm_cluster_domain }}{% endif %} -W $(echo %h | sed 's/^[^+]*+//'):%p -p 443
```

## 5. Login

Done! You can now use the config and [login with your ssh client](../logins-macos-linux/)

-----

Back to operating system independent [instructions for logins](../logins/)
