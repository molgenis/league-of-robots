# Network interfaces

## On EL >= 8.x - Network Manager, nmstate, cloud-init, udev and systemd

On Enterprise Linux these tools all try to fiddle with network settings and it can become a complicated mess.

### Network Manager & nmstate

Network Manager kind of works, but do not try to use the `nmtui` text based User Interface nor any GUI.
Use the `nmcli` command line interface instead.
By default NetworkManager creates _connections_ for network _devices_ using problematic names.
E.g. `System wired 1`: such _connection_ names are confusing and handling in code is problematic due to the spaces in the names.
Network Manager also has a habit of creating yet another _connection_ instead of modifying the existing one
when you try to change/update something.

Therefore we use [nmstate](https://nmstate.io/) and its command line tool `nmstatectl` to control Network Manager.
The network interface config files used by `nmstate` are stored in

```
/etc/nmstate/*.yml
```

When such a `*.yml` is deployed successfully with

```
nmstatectl apply /etc/nmstate/natwork_name.yml
```

it will result in a corresponding

```
nmstatectl apply /etc/nmstate/natwork_name.applied
```

and `nmstatectl` will refuse to apply the `*.yml` again unless the corresponding `*.applied` is removed first.

To check the current state of the network connections and devices:

```
#
# List all network connections using Network Manager.
#
nmcli connection show
#
# List all network devices using Network Manager.
#
nmcli device status
#
# List the state of a network device using nmstate;
# nmstate does not differentiate between connections and devices:
# it always operates directly on a network device and
# changes to the state of a network interface are automagically reflected
# in the corresponsing Network Manager connection.
#
nmstatectl show [device]
```

### udev & systemd: Predictable Network Interface Names

> systemd/udev will automatically assign predictable, stable network interface names for all local Ethernet, WLAN and WWAN interfaces.

For additional details see [systemd - Predictable Network Interface Names](https://systemd.io/PREDICTABLE_INTERFACE_NAMES/)

The exec summary:
 * Old interface naming resulted in names like `eth0`, `eth1`, `eth2`, etc. for ethernet devices
   and depends on the order in which the kernel discoveres network interfaces.
 * This is problematic when an interface was added or removed, because it could result in a new order
   and hence result in changed names of network devices after a reboot.
 * The new interface naming depends on _udev rules_.
   By default these are applied in the following order of precedence
    1. `keep`: previously assigned names are kept.
    1. `kernel`: the kernel claims that the name it has set for a device is predictable (example: `lo` for loopback device).
    1. `database`: name based on entry in udev's Hardware Database.
    1. `onboard`: name based on Firmware/BIOS provided index numbers for on-board devices (example: eno1).
    1. `slot`: name based on Firmware/BIOS provided PCI Express hotplug slot index numbers (example: ens1).
    1. `path`: name based on physical/geographical path to the connector of the hardware (example: enp3s0).
    1. `mac`: name based the MAC address of the interfaces (example: enx2317d1ca25ab)
    1. `classic`: last resort if all of the above failed, then use "unpredictable" old style naming by the kernel (example: eth0)
   In theory this should result in stable network interface names when interfaces are added or removed
   **as long as the _udev rules_ are stable**.
 * In practice however the latter is a problem:
    * Updates for `udev` in minor updates for Enterprise Linux have result in changed rules.
    * Firmware updates may result in presenting the hardware differently to BIOS/EFI,
      resulting in different names even when the rules have not changed.
 * Therefore every minor bugfix update can now result in changed network interface names after reboot
   even when no interfaces were added nor removed: network interface names may be even less predictable then before.

We use a patched list (of precedence) of `udev` _rules_:

```
NamePolicy=kernel database onboard path slot
```

* `slot` based naming rules changed several times and are less stable than `path` based rules.
  Therefore we prefer `path` based naming over `slot` based naming.
* `keep` was removed, because it is problematic when trying to enforce a custom set of naming rules.
  Moreover it is problematic when a machine is re-deployed later and the rules changed:
  The redeployed one will follow the new rules, but the exact same generation of hardware that was previously deployed,
  will continue to use the old rules. This may result for example in for compute nodes of the same type.
* `mac` is not used because it the most unpredictable making it impossible to predict the name of interfaces
  for machines of the same generation of hardware when the config for the first machine is known.

This functionality to generate predictable network interface names is the future,
but to prevent breaking already deployed machines, which may or may not already use predictable network interface names,
there is no default defined.
In order to explicitly enable or explicitly disable predictable network interface names,
the `enable_predictable_network_interface_names` variable must be set to either `true` or `false`
* in `group_vars/{{ stack_name }}/vars.yml` for a the complete stack or
* in `static_inventory/{{ stack_name }}.yml` for specific machines.

When `enable_predictable_network_interface_names` is undefined, this role will skip configuration of how network interfaces should be named.

Switching `enable_predictable_network_interface_names` for an already running machine from `true` to `false` or vice versa,
will modify the `net.ifnames` kernel boot parameter in the GRUB bootloader config,
followed by rebuilding the kernel image and rebooting the machine.  
**IMPORTANT: this may break other services** like `lnet` for Lustre or `iptables` to configure a firewall
and which use network interface names in their configs.
**In the worst case scenario you may have locked yourself out of the machine after reboot**,
because the firewall is not configured to allow traffic to the new network interface name.

### cloud-init

[Network config via _cloud-init_](https://cloudinit.readthedocs.io/en/latest/reference/network-config.html)
is required to configure at least a first network interface when the machine is provisioned.
Once we can login via SSH and deploy Ansible playbooks, we can change the network configuration for that interface
or add/remove additional interfaces. _Cloud-init_ configures _Network Manager_,
but uses the old _ifcfg scripts_ file format with files located in `/etc/sysconfig/network-scripts/`
instead of the new _keyfile_ file format with files located in `/etc/NetworkManager/system-connections/`.

Therefore we first let _cloud-init_ configure network when the machine is provisioned
and once we can deploy this role we use it to disable network configuration by _cloud-init_.

## Configuring network settings using this interfaces role

Configure all networks used by the stack in `group_vars/{{ stack_name }}/vars.yml`;
Not all networks must be used by all machines, but all networks used by any machine of the stack must be listed here:

```yaml
stack_networks:
  - name: string
    cidr: 'ip/mask'
    router:
      next-hop-address: ip
      external_network: string
      name: string
    create: [true|false]
    mtu_size: integer
security_group_mods:
  - name: "{{ stack_prefix }}_storage"
    allow_ingress:
      - ip/mask  # External machines not part of this stack that need to communicate with machines in this stack
                 # and which need to be added to the OpenStack security group rules for this network to allow network traffic.
```

Example for the Talos test cluster:

```yaml
stack_networks:
  - name: vlan1337  # Internal management for VMs and BMs
    cidr: '172.23.68.0/24'
    router:
      next-hop-address: '172.23.68.1'
      external_network: vlan16
      name: vlan1337
  - name: "{{ stack_prefix }}_internal_management"
    cidr: '10.10.1.0/24'
    router:
      next-hop-address: '10.10.1.1'
      external_network: vlan16
    create: true
    mtu_size: '1450'
  - name: vlan1068  # Private Lustre
    cidr: '172.23.60.0/24'
security_group_mods:
  - name: "{{ stack_prefix }}_storage"
    allow_ingress:
      - 172.23.60.161/32  # Lustre server
      - 172.23.60.162/32  # Lustre server
      - 172.23.60.163/32  # Lustre server
      - 172.23.60.164/32  # Lustre server
```

Configure which network to use and on which interface per machine in `static_inventory/{{ stack_name }}.yml`:

```yaml
---
all:
  children:
    [inventory_group]:
      hosts:
        [inventory_hostname]:
          host_networks:
            - name: string
              security_group: string
              assign_floating_ip: [true|false]  # Default is false when omitted.
              add_hostname_to_ip_address: [true|false]  # Default is false when omitted; see static_hostname_lookup role.
              #
              # Details for nmstate in the same YAML syntax/structure as for a single item from the
              # "interfaces" key in the YAML output from nmstatectl or as listed in nmstate config files; See
              #     https://nmstate.io/
              # for details. Note that
              #     * Not all nmstate interface configuration options have been implemented (yet):
              #       See roles/interfaces/templates/interface_template_nmstate.j2 for supported options.
              #     * Not all options need to be specified; omitted options will use defaults.
              #       The minimal config specifies only the interface "name" and will use DHCP.
              #     * When you privision a machine from a new generation of hardware or a new OS version,
              #       which may use changed udev rules, you may not know the names of the interfaces.
              #       In that case leave the nmstate_interface key out or disable it with a comment
              #       for the first deployment, check the interface names once you can login via SSH,
              #       then append nmstate_interface details and re-deploy the interfaces role.
              #
              nmstate_interface:
                name: string  # E.g. enp3s0
            - name: string
              security_group: string
              #
              # Example for configuring the metric of the newtwork route for this interface manually
              # to enforce a certain order of precedence when multiple routes are possible.
              #
              nmstate_interface:
                name: string  # E.g. enp4s0
                ipv4:
                  auto-route-metric: integer  # Integer below 100 to increae priority for this route.
            - name: string
              security_group: string
              #
              # On Merlin cloud only network interfaces from a dedicated management network for bare metal deployment
              # can be attached automatically to machines upon initial instance launch.
              # Network interfaces for all additional networks must be configured after boot.
              #
              attach_port_on_instance_launch: false
              #
              # Example for configuring a tagged VLAN interface on a base interface,
              # which may use an untagged VLAN, after initial provisioning of the machine.
              # In this case DHCP is disabled and a specific IP is configured: this IP
              # must not be specified here as it will get looked up automagically from:
              #     group_vars/{{ stack_name }}/ip_addresses.yml.
              #
              nmstate_interface:
                name: base_interface_name.vlan_ID  # Must use this format. E.g. enp4s0.1068
                type: vlan
                vlan:
                  id: integer
                  base-iface: string  # E.g. enp4s0
                ipv4:
                  dhcp: false
```

Example with subset of machines for the Talos test cluster:

```yaml
---
all:
  children:
    jumphost:
      hosts:
        reception:
          host_networks:
            - name: vlan1337
              security_group: "{{ stack_prefix }}_jumphosts"
              assign_floating_ip: true
              add_hostname_to_ip_address: true
              nmstate_interface:
                name: enp3s0
    user_interface:
      hosts:
        talos:
          host_networks:
            - name: vlan1337
              security_group: "{{ stack_prefix }}_cluster"
              add_hostname_to_ip_address: true
              nmstate_interface:
                name: enp4s0
            - name: vlan1068
              security_group: "{{ stack_prefix }}_storage"
              nmstate_interface:
                name: enp3s0
            - name: "{{ stack_prefix }}_internal_management"
              security_group: "{{ stack_prefix }}_cluster"
              nmstate_interface:
                name: enp5s0
                ipv4:
                  auto-route-metric: 80
    compute_node:
      children:
        cpu_r6515:
          hosts:
            tl-node-b01:
              host_networks:
                - name: vlan1337
                  security_group: "{{ stack_prefix }}_cluster"
                  add_hostname_to_ip_address: true
                  nmstate_interface:
                    name: enp65s0np0
                - name: vlan1068
                  security_group: "{{ stack_prefix }}_storage"
                  attach_port_on_instance_launch: false  # Not possible for bare metal on Merlin. Must configure NICs after boot.
                  nmstate_interface:
                    name: enp65s0np0.1068
                    type: vlan
                    vlan:
                      id: 1068
                      base-iface: enp65s0np0
                    ipv4:
                      dhcp: false
```

### Commands for debugging and config files used.

```
#
# Track what udev does; this command will also rename the network interface according to udev rules when possible
# Possible means:
#   * When the new interface name as determined by the udev rules is not already used by another interface
#   * When there are no other config files that already enforce some other name;
#     E.g. previously named interfaces listed in /etc/udev/rules.d/70-persistent-net.rules will not get renamed.
#
sudo udevadm test /sys/class/net/[current_interface_name]

#
# Order of naming schemes used by udev
#
/usr/lib/systemd/network/99-default.link
#
# Slot-based naming scheme has priority over path-based naming scheme,
# but is not stable: was introduced later and the removed again for virtual network interfaces,
# because it can cause naming conflicts.
# To rename an interface based on slot into one based on path, we must:
#  * Change the naming scheme priorities/order.
#  * Prevent the machine from re-using the previously assigned interface names (the "keep" policy).
#
# Create override in /etc/systemd/network/99-default.link
#
mkdir -m 755 /etc/systemd/network
cp /usr/lib/systemd/network/99-default.link /etc/systemd/network/99-default.link
#
# and change:
#
#NamePolicy=keep kernel database onboard slot path
#AlternativeNamesPolicy=database onboard slot path
NamePolicy=kernel database onboard path slot
AlternativeNamesPolicy=database onboard path slot

#
# Also delete /etc/udev/rules.d/70-persistent-net.rules, which will contain the outdated info.
#
rm /etc/udev/rules.d/70-persistent-net.rules

#
# Update the device names for the NetworkManager network connection.
# See https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html-single/configuring_and_managing_networking/index#configuring-user-defined-network-interface-names-by-using-udev-rules_consistent-network-interface-device-naming
# Temporarily add both old and new device name to the connection profile, reboot and then remove the old name.
# E.g. for
#   * old slot-based device name ens3 and
#   * new path-based device name enp0s3
# use:
nmcli connection modify 'System ens3' connection.interface-name ""
nmcli connection modify 'System ens3' match.interface-name "enp0s3 ens3"

#
# IMPORTANT: Update the list of internal & external network interfaces in
#     /etc/sysconfig/iptables-init.bash
# before rebooting! Failure to do that means you will be locked out on reboot.
#

#
# Reboot.
#
shutdown -r now
#
# When the renaming worked and you can no longer login,
# you  most likely have a mistake in the firewall config.
# Use the console to check the names of network interfaces in /etc/sysconfig/iptables-init.bash
#

#
# Remove the old device name from the NetworkManager connection profile.
# E.g. for
#   * old slot-based device name ens3 and
#   * new path-based device name enp0s3
# use:
nmcli connection modify 'System ens3' match.interface-name "enp0s3"
nmcli connection up 'System ens3'
```
