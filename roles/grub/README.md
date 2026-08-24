# Tweaking the Grub bootloader

## GRUB_TIMEOUT

Some of the cloud environments are displaying the VM console with a substantial delay.
Therefore, in case of corrupted virtual machines, the grub display can be difficult to catch and edit.

This role sets the Grub timeout to a predefined time (60 seconds default configured in `defaults/main.yml`).
This should give ample of time to catch and edit the boot options upon booting.

## GRUB_DEFAULT

In RHEL/Alma/Rocky 9.3 the system can fail to automatically activate a new kernel update after

```
dnf update kernel
```

The default kernel is usually the one with offset 0 listed by

```
grubby --info=ALL
```

which should list kernels in reverse order by version number: newest kernel first.

Workaround when ```dnf``` fails to update the kernel is

#### 1. Configure GRUB_DEFAULT

This role will set ```GRUB_DEFAULT=saved``` in ```/etc/default/grub```

#### 2. Update grub.cfg

This role will

```
grub2-mkconfig  --update-bls-cmdline -o /boot/grub2/grub.cfg
```

when ```/etc/default/grub``` was changed;
This should change
```set default="0"```
into
```set default="${saved_entry}"```
in the ```/boot/grub2/grub.cfg``` config file.

#### 3. Manually set another kernel as the default.

You can check the current default kernel with:

```grubby --default-kernel```

List all available kernels with:

```
grubby --info=ALL
```

If that is not the one that should be used, then use ```grubby --set-default``` to change the default; E.g.
```
[root]# grubby --set-default /boot/vmlinuz-5.14.0-362.13.1.el9_3.x86_64
The default is /boot/loader/entries/e2b217c330724d869b4f2686057579d6-5.14.0-362.13.1.el9_3.x86_64.conf with index 2 and kernel /boot/vmlinuz-5.14.0-362.13.1.el9_3.x86_64
```
The ```saved_entry``` option reported by ```grub2-editenv list``` should now list that new default kernel; E.g.
```
[root]# grub2-editenv list
saved_entry=e2b217c330724d869b4f2686057579d6-5.14.0-362.13.1.el9_3.x86_64
```

Check:
```
fgrep linux /boot/loader/entries/*
```
When the output contains something like:
```
/boot/loader/entries/cbbb383c6a61406bbc99c05e6b23dba9-5.14.0-362.13.1.el9_3.x86_64.conf:linux /boot/vmlinuz-5.14.0-362.13.1.el9_3.x86_64
```
That is Ok (the checksum in the path may differ), but when it contains:
```
/boot/loader/entries/cbbb383c6a61406bbc99c05e6b23dba9-5.14.0-362.13.1.el9_3.x86_64.conf:linux /vmlinuz-5.14.0-362.13.1.el9_3.x86_64
```
it is wrong and the bootloader will look for the kernel in the wrong location. If that happens try to remove and re-install the specific kernel
```
dnf remove kernel-5.14.0-362.13.1.el9_3
dnf install kernel-5.14.0-362.13.1.el9_3
```
Now rerunning
```
grubby --set-default /boot/vmlinuz-5.14.0-362.13.1.el9_3.x86_64
```
should result in something like:
```
The default is /boot/loader/entries/cbbb383c6a61406bbc99c05e6b23dba9-5.14.0-362.13.1.el9_3.x86_64.conf with index 2 and kernel /boot/vmlinuz-5.14.0-362.13.1.el9_3.x86_64
```
with the correct path to the kernel listed at the end of the line. Next,
```
grub2-mkconfig --update-bls-cmdline -o /boot/grub2/grub.cfg
```
should report something like
```
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-5.14.0-362.13.1.el9_3.x86_64
Found initrd image: /boot/initramfs-5.14.0-362.13.1.el9_3.x86_64.img
Found linux image: /boot/vmlinuz-5.14.0-362.8.1.el9_3.x86_64
Found initrd image: /boot/initramfs-5.14.0-362.8.1.el9_3.x86_64.img
Found linux image: /boot/vmlinuz-0-rescue-cbbb383c6a61406bbc99c05e6b23dba9
Found initrd image: /boot/initramfs-0-rescue-cbbb383c6a61406bbc99c05e6b23dba9.img
Found linux image: /boot/vmlinuz-0-rescue-252dd9aa852f4772b9b50e13a981b03b
Found initrd image: /boot/initramfs-0-rescue-252dd9aa852f4772b9b50e13a981b03b.img
Adding boot menu entry for UEFI Firmware Settings ...
done
```
which should now also contain the correct path to the kernel.

See also:
https://unix.stackexchange.com/questions/170089/does-centos-7-incorrectly-sort-kernel-menu-entries-in-grub-cfg
*"If you examine /usr/libexec/grubby/grubby-bls for the function get_default_index,
you will see that it wraps through existing entries and defines their indexes starting with 0 and then incrementing."*

#### 4. Reboot server

Reboot the machine and confirm the machine booted the correct kernel:

```
[root]# shutdown -h now
```

#### 5. Log back in after reboot and check active kernel version

```
[admin]# uname -a
```
