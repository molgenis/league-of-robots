# openstack_networking role

This role can be used to create
 * _**networks**_ with _**subnets**_ and optionally _**routers**_ to bridge the network with another network.
 * _**security groups**_, which can be assigned to _**ports/interfaces**_ used by hosts and which use an IP from these _**networks**_.

## networks, subnets and optional routers

All networks used by the stack must be configured in `group_vars/{{ stack_name }}/vars.yml` using the `stack_networks` variable;
Not all networks must be used by all machines, but all networks used by any machine of the stack must be listed here:

```yaml
stack_networks:
  - name: string            # Required.
    cidr: 'ip/mask'         # Required.
    router:                 # Optional; used when network is bridged to another network using a router/gateway.
      next-hop-address: ip     # Required when router is added for this network.
      external_network: string # Required when router is added for this network.
                               # This is the name of the other network that is connected to the router for this network.
      name: string             # Optional and used when the router has a non-default name.
                               # When omitted the default name for the router is:
                               # "Router bridging {{ network['router']['external_network'] }} and {{ network['name'] }}"
    create: [true|false]    # Default is false and means the network is created by a cloud admin before running any code from this repo. 
                            # True means network is created by code from this repo.
    mtu_size: integer       # Optional. Note that a default value may differ per network or OpenStack cloud config.
```

## security groups

This role contains functionality to create a limited set of _**security groups**_ using specific names:

 *  ```{{ stack_prefix }}_jumphosts```
 *  ```{{ stack_prefix }}_ds```
 *  ```{{ stack_prefix }}_cluster```
 *  ```{{ stack_prefix }}_storage```
 *  ```{{ stack_prefix }}_irods```
 *  ```{{ stack_prefix }}_repo```
 *  ```{{ stack_prefix }}_webservers```
 *  ```{{ stack_prefix }}_logservers```

A _security group_ is only created when at least one host listed in `static_inventory/{{ stack_name }}.yml`
uses that _security group_ for at least one of its network interfaces;
see the description of the `host_networks` variable in [../interfaces/README.md](../interfaces/README.md) for details.

All _security groups_ use a hard coded, default set of _security group rules_.
See the code from [tasks/security_groups.yml](tasks/security_groups.yml) for details.

Some _security groups_ support customizations using the `security_group_mods`;
currently the only supported modification is allowing all incoming network traffic from (external) storage servers
using the `allow_ingress` key for `{{ stack_prefix }}_storage` _security groups_.
E.g.:

```yaml
security_group_mods:
  - name: "{{ stack_prefix }}_storage"
    allow_ingress:
      - ip/mask  # External machines not part of this stack that need to communicate with machines in this stack
                 # and which need to be added to the OpenStack security group rules for this network to allow network traffic.
```

## Related roles

#### Network interfaces for specific hosts

Which network is used by a specific host from the the stack is specified using `host_networks` in `static_inventory/{{ stack_name }}.yml`
See [../interfaces/README.md](../interfaces/README.md) for details.

#### Lustre network (lnet)

Which network interface is used by a specific host from the the stack for lnet - Lustre networking - is specified using `host_networks` in `static_inventory/{{ stack_name }}.yml`
See [../lustre_client/README.md](../lustre_client/README.md) for details.

#### Hostnames linked to network addresses in /etc/hosts

Which name is linked to an IP address in `/etc/hosts` on a specific host from the the stack is specified using `host_networks` in `static_inventory/{{ stack_name }}.yml`
See [../static_hostname_lookup/README.md](../static_hostname_lookup/README.md) for details.
...
