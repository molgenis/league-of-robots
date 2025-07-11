# static_hostname_lookup role

The role creates the `/etc/hosts` file for local, static hostname resolution.
The following entries are created:

## Stack hosts
  * All IP adresses for the host on which the `/etc/hosts` file is created.
  * IP addresses for other hosts of the same stack when the IP address is from a network,
    which is also used by the host on which the `/etc/hosts` file is created.

A minimal entry is:

```yaml
{{ ip_address }}    {{ host_name }}_{{ network_name }}
```

Hence the name is a combination of host and network name, which is essential to specify a specific IP address / network interface
when a machine has more than one.

When the host has a Fully Qualified Domain Name (FQDN) specified in `group_vars/{{ stack_name }}/ip_addresses.yml`,
then this will be added to create an entry like this:

```yaml
{{ ip_address }}    {{ fqdn }}    {{ fqdn_with_domain_part_removed }}    {{ host_name }}_{{ network_name }}
```

When the IP address is for a network interface that is listed in `host_networks` and has `add_hostname_to_ip_address: true`,
then the entry will look like this:

```yaml
{{ ip_address }}    {{ host_name }}    {{ host_name }}_{{ network_name }}
```

The `host_networks` variable is usually specified in `static_inventories/{{ stack_name }}.yml`;
See [../interfaces/README.md](../interfaces/README.md) for details on how to use `host_networks`.

WARNING: When a machine has more than one network interface with `add_hostname_to_ip_address: true`,
you may get unexpected behaviour as some libraries / software will then resolve the `host_tname` to multiple IP addresses
while others may return only the first or only the last IP address for the `host_name`.
Likewise, not assigning the `host_name` to any IP address can also cause problems and is a mis configuration.
Hence a sane config for a host has **minimal one and maximal one network interface with `add_hostname_to_ip_address: true`**

When the host has both a Fully Qualified Domain Name (FQDN) and `add_hostname_to_ip_address: true` for an interface,
then the combined entry will look like this:

```yaml
{{ ip_address }}    {{ fqdn }}    {{ fqdn_with_domain_part_removed }}    {{ host_name }}    {{ host_name }}_{{ network_name }}
```

## Additional (external) hosts

Entries for additional machines can be specified with:

```yaml
additional_etc_hosts:
  - group: {{ stack_name }}
    nodes:
      - name: {{ machine_name }}
        network: {{ network_name }}
```

This will create entries in `/etc/hosts` like this:

```yaml
{{ ip_address }}    {{ machine_name }}
```

## Logs servers

When the stack has `cluster_class: type` defined,
then entries will added to `/etc/hosts` for all public IP address of the logs servers of the specified class like this:

```yaml
{{ ip_address }}    {{ logs_server_host_name }}
```
