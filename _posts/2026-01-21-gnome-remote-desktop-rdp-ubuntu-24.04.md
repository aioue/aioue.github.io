---
layout: post
title: Headless Wayland RDP with GNOME Remote Desktop on Ubuntu 24.04
date: '2026-01-21 15:00:00'
tags: [gnome-remote-desktop, ansible, guacamole, rdp]
---

Set up headless multi-user RDP access on Ubuntu 24.04 using GNOME Remote Desktop, following [official GNOME documentation](https://gitlab.gnome.org/GNOME/gnome-remote-desktop). Working Ansible configuration.

If you're working on OpenNebula [you'll need to modify the template first]({% post_url 2026-01-21-wayland-gnome-remote-desktop-under-opennebula %})

## Overview

GNOME Remote Desktop provides native RDP support in Ubuntu, making it ideal for:

- Headless VM access via Apache Guacamole
- Multi-user remote login to a graphical desktop
- Hardware-accelerated graphics with virtio-gpu

## Working Config

```yaml
# Configure Ubuntu desktop for Guacamole RDP access
# This role sets up a secure RDP connection via GNOME Remote Desktop service
# for seamless integration with Apache Guacamole HTML5 remote desktop gateway.

- name: Install packages
  become: true
  ansible.builtin.apt:
    name: "{{ package_name }}"
    autoremove: true
    state: present
  loop:
    - winpr-utils # Required for TLS certificate generation
    - gnome-remote-desktop # Provides the remote desktop service
    # Packages for hardware-accelerated graphics with virtio-gpu
    - mesa-utils
    - mesa-vulkan-drivers
    - libgl1-mesa-dri
  loop_control:
    loop_var: package_name
  notify:
    - Reboot if needed

- name: Allow client to pass locale environment variables and timezone
  become: true
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^#?AcceptEnv'
    line: 'AcceptEnv LANG LC_* TZ'
    state: present
    create: false
  notify: restart SSH

- name: Enable PasswordAuthentication for SSH
  become: true
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^#?PasswordAuthentication'
    line: 'PasswordAuthentication yes'
    state: present
    create: false
  notify: restart SSH

- name: Enable linger for admin user to maintain graphical session after reboot
  become: true
  command: loginctl enable-linger {{ guacamole_guest_admin_user }}
  changed_when: false

- name: Set graphical target as default boot target
  become: true
  systemd:
    name: graphical.target
    enabled: true

- name: Remove nomodeset from GRUB to enable graphics driver detection
  become: true
  lineinfile:
    path: /etc/default/grub
    regexp: '^GRUB_CMDLINE_LINUX_DEFAULT='
    line: 'GRUB_CMDLINE_LINUX_DEFAULT="quiet text"'
    backrefs: true

- name: Update GRUB configuration to apply boot parameter changes
  become: true
  command: update-grub
  notify:
    - Reboot if needed

- name: Apply immediate reboot if required by configuration changes
  meta: flush_handlers

# TLS certificate generation for secure RDP connections
# https://gitlab.gnome.org/GNOME/gnome-remote-desktop#tls-key-and-certificate-generation
- name: Generate TLS certificate and key for GNOME Remote Desktop
  become: true
  command: sudo -u gnome-remote-desktop sh -c 'winpr-makecert -silent -rdp -path ~/.local/share/gnome-remote-desktop tls'

# Configure GNOME Remote Desktop for headless multi-user remote login
# https://gitlab.gnome.org/GNOME/gnome-remote-desktop#headless-multi-user-remote-login
- name: Configure TLS key for RDP connections
  become: true
  command: sudo grdctl --system rdp set-tls-key ~gnome-remote-desktop/.local/share/gnome-remote-desktop/tls.key

- name: Configure TLS certificate for RDP connections
  become: true
  command: sudo grdctl --system rdp set-tls-cert ~gnome-remote-desktop/.local/share/gnome-remote-desktop/tls.crt

- name: Set RDP access credentials
  become: true
  command: sudo grdctl --system rdp set-credentials rdpuser rdppass

- name: Enable interactive input control for RDP sessions
  become: true
  command: sudo grdctl --system rdp disable-view-only

- name: Enable RDP protocol support in GNOME Remote Desktop
  become: true
  command: sudo grdctl --system rdp enable

- name: Enable GNOME Remote Desktop service to start at boot
  become: true
  command: sudo systemctl enable --now gnome-remote-desktop.service

- name: Restart GNOME Remote Desktop service to apply all configurations
  become: true
  command: sudo systemctl restart --now gnome-remote-desktop.service
```

## Key Steps Explained

### 1. Package Installation

The `winpr-utils` package provides `winpr-makecert` for generating TLS certificates. The Mesa packages enable hardware-accelerated graphics when running on VMs with virtio-gpu.

### 2. Session Persistence

`loginctl enable-linger` ensures user sessions survive after logout, which is essential for headless RDP access.

### 3. Boot Configuration

Setting `graphical.target` and removing `nomodeset` from GRUB ensures the system boots into a graphical environment with proper driver detection. Not needed if you started off with a Desktop system rather than installing `ubuntu-desktop-minimal` [over a server install]({% post_url 2026-01-21-wayland-gnome-remote-desktop-under-opennebula %}).

### 4. TLS Certificates

Certificates are generated using `winpr-makecert` and stored in `~gnome-remote-desktop/.local/share/gnome-remote-desktop/`. Running as the `gnome-remote-desktop` user ensures correct ownership.

### 5. System-Wide RDP

Using `grdctl --system` configures the system-wide RDP service for multi-user headless access, as opposed to per-user desktop sharing.

## Verifying the Setup

After running the playbook, verify the configuration:

```bash
sudo grdctl --system status --show-credentials
```

You should see:

```
Overall:
    Unit status: active
RDP:
    Status: enabled
    Port: 3389
    TLS certificate: /var/lib/gnome-remote-desktop/.local/share/gnome-remote-desktop/tls.crt
    TLS key: /var/lib/gnome-remote-desktop/.local/share/gnome-remote-desktop/tls.key
    Username: rdpuser
    Password: rdppass
```

## macOS RDP Client Fix

If using Windows App (formerly Microsoft Remote Desktop) on macOS, edit your `.rdp` file:

```
use redirection server name:i:1
```

See: <https://www.reddit.com/r/Ubuntu/comments/1n8pq1e/rdp_to_ubuntu_from_the_windows_app_on_macos/>

## Ubuntu 25.10 Considerations

A [detailed troubleshooting guide for Ubuntu 25.10](https://ezone.co.uk/blog/working-headless-rdp-with-gnome-remote-desktop-on-ubuntu-25-10.html) documents some differences that may require changes:

| Aspect | Ubuntu 24.04 | Ubuntu 25.10 |
|--------|--------------|--------------|
| Certificate tool | `winpr-makecert` | OpenSSL (alternative) |
| Certificate path | `~gnome-remote-desktop/.local/share/gnome-remote-desktop/` | `/var/lib/gnome-remote-desktop/` |
| Permissions | Implicit (runs as gnome-remote-desktop user) | May need explicit `chmod 600`/`644` |

### OpenSSL Alternative for Certificates

If `winpr-utils` becomes unavailable or problematic, use OpenSSL instead:

```bash
sudo openssl req -newkey rsa:2048 -nodes \
    -keyout /var/lib/gnome-remote-desktop/rdp-tls.key \
    -x509 -days 365 \
    -out /var/lib/gnome-remote-desktop/rdp-tls.crt \
    -subj "/CN=$(hostname)"

sudo chown gnome-remote-desktop:gnome-remote-desktop /var/lib/gnome-remote-desktop/rdp-tls.*
sudo chmod 600 /var/lib/gnome-remote-desktop/rdp-tls.key
sudo chmod 644 /var/lib/gnome-remote-desktop/rdp-tls.crt
```

Approach is fundamentally the same across versions. Test on 25.10 before upgrading production systems.

## References

- [GNOME Remote Desktop GitLab](https://gitlab.gnome.org/GNOME/gnome-remote-desktop)
- [Ubuntu 25.10 RDP Guide](https://ezone.co.uk/blog/working-headless-rdp-with-gnome-remote-desktop-on-ubuntu-25-10.html)
