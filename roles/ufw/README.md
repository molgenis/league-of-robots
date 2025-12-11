# UFW Role (Ubuntu/Debian )

This Ansible role secures an Ubuntu/Debian server using **UFW**.  

### Features

- Default deny incoming, allow outgoing policy
- Allows essential ports (SSH by default)
- Allows all traffic on specified internal interfaces

---

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `firewall_allowed_ports` | `[22]` | Ports that should be allowed |
| `firewall_internal_interfaces` | `[enp0s1, enp3s0 etc...]` | Interfaces where all internal traffic is allowed |

---