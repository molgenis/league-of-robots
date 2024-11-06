# Role to include variables from other stack groups.

## group_vars/[stack_name]/ip_addresses[manual|openstack|azure].yml

The `ip_addresses.yml` files contain
 - manually created IP addresses for machines of the stack that are manually deployed - that is, they 
   are neither deployed with OpenStack nor Azure APIs.
 - IPs generated with a playbook that creates machines by talking to the OpenStack API
   and using the template from `group_vars/template/ip_addresses_openstack.yml.j2`
 - likewise IPs generated with a playbook that creates machines by talking to the Azure API
   and using the template from `group_vars/template/ip_addresses_azure.yml.j2`

The data structure in an `ip_addresses.yml` file is a 2 level deep nested dict.
For machines it can be something like this:

```
ip_addresses:
  machine:
    some_internal_network_name:
      address: 10.10.1.1
      netmask: /32
    another_internal_network_name:
      address: 10.10.3.1
      netmask: /32
      publicly_exposed: true  # This internal IP is linked to a public (floating) IP.
    public_network_name:
      address: 123.1.2.3
      netmask: /32
      fqdn: 'machine.some.domain'
```

For network ranges for external systems/networks defined in `group_vars/all/ip_addresses.yml` it can be something like this:

```
ip_addresses:
  institute:
    some_network_range_name:
      address: 123.321.123.0
      netmask: /24
    another_network_range_name:
      address: 111.222.111.0
      netmask: /24
      desc: 'a description of what this subnet is used for.'
```

## Data structures provided by this role

The info from all `ip_addresses.yml` files (recursively) found in the group_vars is combined into 2 data structures,
which are available to other roles when a dependency in this role is defined in the role's `meta/main.yml` like this:

```
dependencies:
    - role: include_vars_from_other_groups
```

#### 1. ip_addresses per stack

```
stack_name:
  ip_addresses:
    machine:
      some_internal_network_name:
        address: 10.10.1.1
        netmask: /32
      another_internal_network_name:
        address: 10.10.3.1
        netmask: /32
        publicly_exposed: true  # This internal IP is linked to a public (floating) IP.
      public_network_name:
        address: 123.1.2.3
        netmask: /32
        fqdn: 'machine.some.domain'
all:
  ip_addresses:
    institute:
      some_network_range_name:
        address: 123.321.123.0
        netmask: /24
      another_network_range_name:
        address: 111.222.111.0
        netmask: /24
        desc: 'a description of what this subnet is used for.'
```

To find a specific item you will need 3 keys:

 * `{{ stack_name }}`
 * `{{ node_name }}` (a machine or institute)`
 * `{{ network_name }}`

E.g. for the example data structure listed above:
```
{{ lookup('vars', item['stack_name'])['ip_addresses']['my_machine']['public_network_name']['address'] }}
```


#### 2. Combined network info in one dict for all items from all stacks.

This can be used for lookups by the name of an item when you do not know in which stack an item was located.

```
all_ip_addresses:
  my_machine:
    some_internal_network_name:
      address: 10.10.1.1
      netmask: /32
    another_internal_network_name:
      address: 10.10.3.1
      netmask: /32
      publicly_exposed: true  # This internal IP is linked to a public (floating) IP.
    public_network_name:
      address: 123.1.2.3
      netmask: /32
      fqdn: 'machine.some.domain'
  other_institute:
    some_network_range_name:
      address: 123.321.123.0
      netmask: /24
    another_network_range_name:
      address: 111.222.111.0
      netmask: /24
      desc: 'a description of what this subnet is used for.'
```

To find a specific item you will need 2 keys:

 * `{{ node_name }}` (a machine or institute)`
 * `{{ network_name }}`

E.g. for the example data structure listed above:
```
{{ all_ip_addresses['other_institute']['some_network_range_name']['address'] }}"
```

