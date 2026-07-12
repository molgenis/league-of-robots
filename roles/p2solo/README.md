# p2solo

The **p2solo** Ansible role prepares a Debian/Ubuntu Linux system for use with Oxford Nanopore MinION / P2 Solo workflows.  
The role includes the following major components:

1. Disabling automatic system updates  
2. Installing the standalone MinKNOW software according to the official Linux installation documentation  
3. Applying required system-level dependencies and configuration needed for MinKNOW operation and device support

This role is intended for Debian-based systems within the p2solo environment.

---

## Functionality

### 1. disable-autoupdate

This task disables automatic updates on Debian systems.  
It performs the following actions:

- Replaces `/etc/apt/apt.conf.d/10periodic` with a configuration where all periodic APT actions are set to `"0"`.
- Stops and disables the `unattended-upgrades.service` and `unattended-upgrades.timer`.
- Masks the systemd timer to prevent it from being re-enabled.
- Keeps the MOTD update notification script (`90-updates-available`) executable, so update counts remain visible.
- Leaves release-upgrade notifications enabled.

This ensures automatic background updating is disabled while administrators continue to see available update counts at login.

---

### 2. standalone-minknow installation (backup procedure)

The engineer from Oxford Nanopore performs the primary installation of MinKNOW on the system.  
The task included in this role provides a **fallback or backup installation method** that can be used if the manual installation is not available or needs to be repeated later.

The backup installation task follows the steps described in the official MinKNOW Linux documentation:

- Ensuring required system dependencies are present  
- Installing or configuring necessary components such as udev rules  
- Downloading and installing the MinKNOW Debian package.  
- Optionally installing additional components if needed  

The procedure implemented here aligns with the guidelines in:

https://nanoporetech.com/document/experiment-companion-minknow#installing-minknow-on-linux

This backup installation should only be used when the primary installation performed by the Nanopore engineer is not available.

---

