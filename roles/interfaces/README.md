# Network interfaces

### Commands for debugging and config files used.

```
#
# Track what udev does
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
