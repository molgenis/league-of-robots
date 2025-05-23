#!/bin/bash

{% raw %}

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
readarray -t wrong_network_interface_names < <(find '/sys/class/net/' -maxdepth 1 -mindepth 1 -type l -regextype posix-extended -regex '(.*ens.*)|(.*rename.*)')
for wrong_network_interface_name in "${wrong_network_interface_names[@]}"; do
    udevadm test "${wrong_network_interface_name}"
done

#
# NetworkManager does not know an interface got renamed;
# It notices
#    * the "old" network interface is gone and drops the connection.
#    * a new network interface appeared and will try to establish a connection.
# Give NetworkManager some time to configure the new network interface automagically.
#
sleep 5

{% endraw %}
