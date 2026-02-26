---
layout: post
title: Ansible Proxmox Inventory and DHCP VMs
date: '2026-02-26 23:00:00'
tags: [ansible, proxmox, inventory, qemu, dhcp]
---

Fix for `community.general.proxmox` (now `community.proxmox.proxmox`) dynamic inventory not setting `ansible_host` for QEMU VMs with DHCP networking. Without this, you need `-e ansible_host=192.168.1.x` every time you target the VM.

## The Problem

The Proxmox inventory plugin has `want_proxmox_nodes_ansible_host` for nodes, but nothing equivalent for QEMU guests. For VMs using cloud-init with `ip=dhcp`, the plugin sets `proxmox_ipconfig0` to:

```json
{"ip": "dhcp"}
```

Not an actual address. The documented `compose` example from the plugin docs:

```yaml
compose:
  ansible_host: proxmox_ipconfig0.ip | default(proxmox_net0.ip) | ipaddr('address')
```

doesn't help — `"dhcp"` isn't an IP, and `proxmox_net0` only contains the MAC address and bridge config, not an IP.

## The Solution

If the QEMU guest agent is running (`agent: 1` in the VM config), the inventory plugin populates `proxmox_agent_interfaces` with live network data from inside the VM. This includes actual DHCP-assigned addresses.

The tricky part: the agent data uses hyphenated keys (`ip-addresses`, `mac-address`) which Jinja2 interprets as subtraction. You can't use `map(attribute='ip-addresses')` — it parses as `attribute='ip' - addresses`. Use `.get('ip-addresses', [])` instead.

```yaml
compose:
  ansible_host: >-
    ((proxmox_agent_interfaces | default([])
    | selectattr('name', 'equalto', 'eth0') | list | first | default({}))
    .get('ip-addresses', [])
    | ansible.utils.ipv4 | first | default(''))
    | ansible.utils.ipaddr('address')
    | default(ansible_host | default(inventory_hostname, true), true)
```

What this does:

1. Finds the `eth0` interface in `proxmox_agent_interfaces`
2. Extracts its `ip-addresses` list (working around the hyphenated key)
3. Filters to IPv4 only with `ansible.utils.ipv4`
4. Strips the CIDR suffix (`192.168.1.83/24` → `192.168.1.83`)
5. Falls back to existing `ansible_host` or `inventory_hostname` for hosts without agent data

The `default(..., true)` at the end is important — without the second argument, Jinja2's `default` only triggers on undefined variables, not on `None` or `False`. The `ipaddr` filter returns `False` for invalid input, and `want_proxmox_nodes_ansible_host` can set `ansible_host` to `None`.

## Requirements

- QEMU guest agent installed and running in the VM
- `agent: 1` in the VM config (so Proxmox queries the agent)
- `want_facts: true` in the inventory plugin config
- `ansible.utils` collection (included with the full `ansible` package)
- `netaddr` Python library (pulled in as a dependency of `ansible.utils`)

## Verification

```bash
ansible-inventory -i inventory/pve.proxmox.yaml --list 2>/dev/null \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
for host, vars in data['_meta']['hostvars'].items():
    print(f\"{host}: {vars.get('ansible_host', 'NOT SET')}\")"
```

```
homeassistant: homeassistant
pve: pve
tank: tank
ubuntu-cloud: 192.168.1.83
```
