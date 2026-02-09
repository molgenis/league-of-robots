# Azure networking

## Intro

This is one of three Azure roles

 - [azure_general](../azure_general/README.md) role creates Azure group which contains the network, VMs, network interfaces and security groups. This helps with an overview of used and available Azure resources.
 - [azure_networking](../azure_networking/README.md) role defines and manages the entire network: networks, sub-networks and security groups within the individual Azure group.
 - [azure_computing](../azure_computing/README.md) role defines and manages the VMs, their storage, network interfaces, public IPs and private IPs inside the individual Azure group.


## About internal network and public IP

The network is created with internal IPs for each VM in the network.
Next, public IPs together with _security_groups_ are assigned to those interfaces.
Note the _CIDR_ for each public network is defined for internal IPs and not for public IPs.

## Security groups in general

Explaining security groups on the case of Azure.

When `azure.yml` playbook is deployed, it creates
 - security group(s)
 - network and
 - subnetwork
using this role and in the specified order.

In order to create a network it must have `create: true`, which defaults to false.
E.g. in `group_vars/{{ stack_name }}/vars.yml`:
```
azure_networks:
  - name: "{{ stack_prefix }}_external"
    cidr: '10.10.1.0/24'
    create: true
```
When the `create` attribute is `false` or omitted, the network must have been pre-created by an admin on the Azure cloud.

In `static_inventory/{{ stack_name }}.yml` individual hosts can specify which of the networks they use
and which `security_group` must be applied to the corresponding network interface/port:

```
azure_flavor: "Standard_DS1_v2"
host_networks:
  - name: "{{ stack_prefix }}_external"
    security_group: "{{ stack_prefix }}_external"
    assign_floating_ip: true
```

## Different security groups

 - For internal management networks we use variables:
   ```
   azure_networks:
     name: "{{ stack_prefix }}_internal_management"
     cidr: 10.10.1.0/24
     create: true
   ```
   and `security_group: "{{ stack_prefix }}_cluster` for the individual host network ports/interfaces. 
   Make sure you define correct CIDR.

 - For `logservers` security groups we must define network
   ```
   azure_networks:
     name: "{{ stack_prefix }}_external"
     cidr: 10.10.1.0/24
     create: true
   ```
   and `security_group: "{{ stack_prefix }}_logserver` for the individual host network ports/interfaces. 
   Log servers are publicly available, so no CIDR needed: why is it specified in the example above???.

## Security groups working together

Note about security groups of Azure
 - they work differently than Openstack
 - security groups can be combined, but they need to be correctly weighted in order to work
 - the weights with lower number have bigger priority
 - therefore the following structure is used
    - 1xx are for publicly exposed ports
    - 2xx for network cidr limited port access
    - 3xx are for everything else: storage or vlans ports

## Networks and subnets

Deyployment will fail if security groups are not assigned on the
 - subnetworks
 - VMs network interfaces

## FQDN of machines

Since machine CAN get more than 1 public IP, the FQDN of that IP is created in format

`{{ stack_prefix }}-{{ inventory_hostname }}-{{ network.name | hash | first 4 letters }}.[ azure location public DNS ]`

an example for logs_library earl2 for logs_external network

`logs-earl2-6b85.westeurope.cloudapp.azure.com`
