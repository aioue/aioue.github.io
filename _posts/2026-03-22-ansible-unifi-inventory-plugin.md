---
layout: post
title: Dynamic Ansible inventory from a UniFi controller
date: '2026-03-22 16:00:00'
tags: [ansible, unifi, inventory, networking]
hidden: false
---

[aioue.network](https://github.com/aioue/ansible-unifi-inventory) is an Ansible collection that turns your UniFi OS controller into a dynamic inventory source. It queries clients (and optionally devices) from a UDM, UCG, or similar controller and makes them available as Ansible hosts, grouped by connection type, VLAN, SSID, and network name.

## Install

```bash
ansible-galaxy collection install git+https://github.com/aioue/ansible-unifi-inventory.git
```

Or in `requirements.yml`:

```yaml
collections:
  - name: aioue.network
    source: https://github.com/aioue/ansible-unifi-inventory.git
    type: git
```

## Inventory file

Create `unifi.yaml` (or whatever you like):

```yaml
plugin: aioue.network.unifi
url: "https://192.168.1.1"
token: "your-api-token"
site: "default"
verify_ssl: false
last_seen_minutes: 30
```

Supports API token auth (preferred) or username/password for a local admin account with 2FA disabled. All settings can also come from environment variables (`UNIFI_URL`, `UNIFI_TOKEN`, etc.).

## What you get

```
$ ansible-inventory -i unifi.yaml all --graph
@all:
  |--@unifi_clients:
  |  |--phone
  |  |--laptop
  |  |--Kitchen Echo
  |  |--pc
  |  |--nas
  |--@unifi_wireless_clients:
  |  |--phone
  |--@unifi_wired_clients:
  |  |--pc
  |  |--nas
  |--@network_default:
  |  |--laptop
  |--@network_iot:
  |  |--Kitchen Echo
  |--@vlan_30:
  |  |--Kitchen Echo
  |--@ssid_iot:
  |  |--Kitchen Echo
```

Groups are created automatically:

- `unifi_clients`, `unifi_wireless_clients`, `unifi_wired_clients` - by connection type
- `network_<name>` - by UniFi network name
- `vlan_<id>`, `vlan_<name>` - by VLAN
- `ssid_<name>` - by wireless SSID

Each host gets `ansible_host` set to its IP (IPv4 preferred, IPv6 fallback), plus variables like `mac`, `vlan`, `network`, `ssid`, `is_wired`, `last_seen_iso`, switch port, AP MAC, and manufacturer OUI.

With `include_devices: true`, UniFi infrastructure (APs, switches, gateways) appears too, grouped by device type (`unifi_uap`, `unifi_usw`, etc.) with firmware version and adoption status.

## Caching

API results are cached locally for 30 seconds by default (`cache_ttl`). First run takes 2-10 seconds; subsequent runs within the TTL window are near-instant. Set `cache_ttl: 0` to disable.

## Use case

I use this alongside the Proxmox dynamic inventory to manage everything on my LAN. The UniFi inventory gives me ad-hoc access to any client that's shown up on the network - useful for deploying SSH keys to new machines, checking which devices are on which VLAN, or targeting a group of hosts by network segment without maintaining a static inventory file.

Source: [aioue/ansible-unifi-inventory](https://github.com/aioue/ansible-unifi-inventory)
