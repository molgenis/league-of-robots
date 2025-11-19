# Firewall Role (Ubuntu + optional iptables inclusion)

This Ansible role secures an Ubuntu server using **UFW**.  
It can also **include an iptables  role** when running on RedHat-based systems (e.g., Rocky 9).

### Features

- Default deny incoming, allow outgoing policy
- Allows essential ports (SSH by default)
- Allows all traffic on specified internal interfaces

---

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `firewall_allowed_ports` | `[22,80,443]` | Ports that should be allowed |
| `firewall_internal_interfaces` | `[eth0, eth1 etc...]` | Interfaces where all internal traffic is allowed |

---
