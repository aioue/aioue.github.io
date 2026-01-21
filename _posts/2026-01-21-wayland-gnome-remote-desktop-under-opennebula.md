---
layout: post
title: Ubuntu Desktop VM for RDP on OpenNebula
date: '2026-01-21 17:00:00'
tags: [opennebula, ubuntu, rdp, gnome-remote-desktop, virtualization]
---

Transform the [OpenNebula Marketplace](https://marketplace.opennebula.io/) Ubuntu Server 24.04 image into an RDP-capable desktop VM. This is part 1 of getting RDP working — see [part 2 for GNOME Remote Desktop configuration]({% post_url 2026-01-21-gnome-remote-desktop-rdp-ubuntu-24.04 %}).

## VM Template Configuration

### Video/Graphics Support

Add to your OpenNebula template before starting the VM:

```
VIDEO = [
  TYPE = "virtio",
  VRAM = "187500" ]
```

VirtIO video adapter with ~183 MB VRAM for desktop environments and RDP sessions.

### Network Configuration (Critical for RDP)

**This solved RDP connecting but showing only a black screen.**

Switch to NetworkManager instead of systemd-networkd:

```
CONTEXT = [
  ...
  NETCFG_TYPE = "nm",
  ... ]
```

Without this, RDP connections establish but the desktop session fails to render.

## Software Changes

### Desktop Environment

Install the minimal GNOME desktop:

```bash
apt install --no-install-recommends ubuntu-desktop-minimal
```

The `--no-install-recommends` flag significantly reduces install time.

### Remove cloud-init

Prevent conflicts with OpenNebula contextualisation:

```bash
apt remove cloud-init
apt-mark hold cloud-init
```

### Set Default Boot Target

Change from CLI to graphical boot:

```bash
systemctl set-default graphical.target
```

Required when converting a server install to desktop.

Shutdown and save your VM as a new desktop template, [start up a new VM with it, and proceed with Part 2]({% post_url 2026-01-21-gnome-remote-desktop-rdp-ubuntu-24.04 %})

## Troubleshooting: Black Screen

If RDP connects but shows only black:

1. Verify `NETCFG_TYPE = "nm"` in the VM template CONTEXT section
2. Check NetworkManager: `systemctl status NetworkManager`
3. Verify boot target: `systemctl get-default` should return `graphical.target`
