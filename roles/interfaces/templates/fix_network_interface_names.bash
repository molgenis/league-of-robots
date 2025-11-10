#!/bin/bash
{% raw %}
set -u
set -e
set -o pipefail
#
# Our custom NamePolicy in /etc/systemd/network/99-default.link
# (to prevent problematic slot-based network interface names)
# can be ignored during boot due to bugs in udev and/or systemd
# even when the policy is explicitly included in the initramfs using
#    install_items+=" /etc/systemd/network/99-default.link
# in /etc/dracut.conf.d/predictable_network_interface_naming.conf
#
# The workaround is to rename the network interfaces late in the boot
# sequence, but before we try to mount shared file systems or use other
# things that require an explicitly named network interface.
#
# Renaming can be done with udev using something like this:
#
#    udevadm test /sys/class/net/<wrong_name>
#
# E.g.
#
#    udevadm test /sys/class/net/ens6
#
# Find the relevant network interfaces:
#  * Named by path
#  * Named by slot
#  * Renamed by Cloud Init
# Hence exclude for example on board and loopback devices.
# And add them to a list sorted by network interface index.
#
readarray -t network_interfaces_unsorted < <(find '/sys/class/net/' -maxdepth 1 -mindepth 1 -type l -regextype posix-extended -regex '(.*eth.*)|(.*enp.*)|(.*ens.*)|(.*rename.*)')
udevadm_version="$(udevadm --version)"
declare -a network_interfaces_sorted
for network_interface in "${network_interfaces_unsorted[@]}"; do
    if [[ "${udevadm_version%%[^0-9]*}" -ge 250 ]]; then
        if_index="$(udevadm info -q property --property=IFINDEX --value "${network_interface}")"
    else
        # Work around for older udevadm on EL 8.x. that does not support selecting specific properties for the output.
        if_index="$(udevadm info -q property "${network_interface}" \
                    | grep 'IFINDEX=' \
                    | sed 's|IFINDEX=\([1-9][0-9]*\)|\1|' \
                    | tr -d '\n')"
    fi
    network_interfaces_sorted["${if_index}"]="${network_interface}"
    printf 'INFO: Found network interface %s at index %d ...\n' "${network_interface}" "${if_index}"
done
#
# Apply udev rules to network interfaces sorted by index.
#
for network_interface_index in "${!network_interfaces_sorted[@]}"; do
    if [[ "${udevadm_version%%[^0-9]*}" -ge 250 ]]; then
        id_net_name=$(udevadm test "${network_interfaces_sorted[${network_interface_index}]}" | grep 'ID_NET_NAME=')
        printf 'INFO: (Re-)applied udev rules for network interface %s with index %d: %s.\n' "${network_interfaces_sorted[${network_interface_index}]}" "${network_interface_index}" "${id_net_name}"
    else
        # Work around for older udevadm on EL 8.x. that does not report ID_NET_NAME.
        id_net_name=$(udevadm test "${network_interfaces_sorted[${network_interface_index}]}")
        printf 'INFO: (Re-)applied udev rules for network interface %s with index %d.\n' "${network_interfaces_sorted[${network_interface_index}]}" "${network_interface_index}"

    fi
done
#
# NetworkManager does not know an interface got renamed;
# It notices
#    * the "old" network interface is gone and drops the connection.
#    * a new network interface appeared and will try to establish a connection.
# Give NetworkManager some time to configure the new network interface(s) automagically.
#
sleep 10
{% endraw %}
