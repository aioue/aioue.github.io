---
layout: post
title: 'Zero to Synology DSM on Proxmox: headless Arc install in about 2 minutes'
date: '2026-07-31 12:00:00'
tags: [homelab, proxmox, synology, xpenology, arc, automation]
hidden: false
---

Arc Loader can run Synology DSM in a Proxmox VM without Synology hardware. The usual install path is Config Mode in a browser (`http://<ip>:7080`) - fine once, tedious if you rebuild test VMs or want reproducible lab setups.

This post documents a **headless path**: seed the loader config over SSH, reboot into Arc **Automated Mode**, and land on the **DSM Web Assistant** (`:5000`) in about **2 minutes** from first loader boot on a **2-core, 4 GB RAM** VM (Ryzen 5600G-class host, Arc 3.1.0, DSM 7.2.2-72806, DS923+).

Scripts: **[arc-loader-automated](https://github.com/aioue/arc-loader-automated)**

The scripts include small workarounds for headless use (p1 `/automated`, `arc.offline`, and similar). I tried upstream first - see [Upstream](#upstream) below.

## Who this is for

- You already run **Proxmox** and want a disposable DSM VM for backups, testing, or lab work.
- You know your **model**, **platform**, and **PAT URL/hash** (or can copy them from a working Arc install).
- You are comfortable SSHing to Proxmox and the Arc loader (`root` / `arc`).

Not covered here: picking a Synology model, licensing grey areas, or production hardening. Arc is community tooling; treat lab VMs as disposable.

## What you need

| Item | Example |
|------|---------|
| Proxmox host | SSH as `root` |
| Arc loader image | `arc.img` from [Arc releases](https://github.com/AuxXxilium/arc/releases) on the host, e.g. `/var/lib/vz/template/iso/arc.img` |
| Free VMID + name | Pick an unused ID - do not assume VM 104 is free |
| `sshpass` on Proxmox | For loader hop (`root` / `arc`) |
| Outbound HTTPS | PAT download; seed sets `arc.offline: false` |

Secure Boot must be **off** - Arc ships unsigned boot artifacts. The scripts create OVMF with `pre-enrolled-keys=0`.

## One command (fresh VM)

```bash
git clone https://github.com/aioue/arc-loader-automated.git
cd arc-loader-automated

export PVE_HOST=192.168.1.10
export ARC_VMID=105
export ARC_VM_NAME=xpenology-arc-lab

./run-from-scratch.sh --yes
```

`--yes` is required for the destroy step. The script **refuses** to delete a VM unless its **name**, **OVMF bios**, and **sata0 boot layout** match an Arc loader - so an unrelated guest on the same VMID is safe.

Output when done:

```
DSM Web Assistant: http://192.168.x.x:5000
```

Open that URL and complete the DSM first-boot wizard (admin user, skip Synology account if you like). Create a storage pool on the data disk in **Storage Manager** - still a GUI step.

## What the scripts do

```mermaid
flowchart LR
  A[Create VM] --> B[Loader boots]
  B --> C[Seed user-config.yml]
  C --> D[Reboot automated_arc]
  D --> E[arc.sh builds on console]
  E --> F[DSM :5000]
```

1. **Create VM** - q35, OVMF, 2 vCPU, 4 GB RAM, `sata0` = Arc loader, `sata1` = data disk (default 40 GB).
2. **Seed** `/mnt/p1/user-config.yml` with `yq` only - model, platform, DSM version, PAT URL/hash, `arc.offline: false`.
3. **Trigger** Automated Mode - touch `/mnt/p1/automated` **and** `/mnt/p3/automated`, `grub-editenv next_entry=automated`, reboot.
4. **Wait** - loader downloads PAT, builds, boots DSM. ~2 minutes on the test hardware above.

### Why not Config Mode?

Config Mode (`:7080`) works well for first-time model selection. For repeat installs, seeding YAML and rebooting is faster and scriptable. **DS923+ is locked in Arc 3.x** - you must seed the model explicitly; do not rely on automated mode to pick it.

### Why not SSH into arc.sh directly?

Calling Arc library functions over SSH without a TTY breaks dialog helpers and can corrupt `user-config.yml`. Automated Mode runs `arc.sh` on the **loader console** where dialog works - same as the web terminal, but triggered by grub.

## Customize model / disk / VMID

```bash
./run-from-scratch.sh \
  --vmid 106 \
  --name my-dsm-lab \
  --memory 8192 \
  --data-disk-gb 80 \
  --model DS920+ \
  --platform geminilake \
  --productver 7.2 \
  --buildnum 72806 \
  --pat-url 'https://global.download.synology.com/download/...' \
  --pat-hash 'abc123...' \
  --yes
```

Reuse a running loader without recreating the VM:

```bash
./configure-and-build.sh 192.168.1.41 --model DS923+ --platform r1000
```

## Timing

Measured **2026-07-31** on Proxmox, disposable test VM:

| Phase | Approx. |
|-------|---------|
| Loader first boot → SSH ready | ~30–45 s |
| Seed + automated reboot + PAT build | ~75–90 s |
| **First loader boot → DSM `:5000`** | **~2 min** |

VM create/import time (copying `arc.img` to storage) is extra on first run; subsequent rebuilds skip import if you use `--skip-create`.

## Gotchas we hit (so you don't)

| Symptom | Cause | Fix |
|---------|--------|-----|
| Stuck in Config Mode (`force_arc`) | Missing `/mnt/p1/automated` | Scripts touch both p1 and p3 markers |
| Build stuck at `confdone=true`, `builddone=false` | `arc.offline: true` with PAT set | Seed sets `arc.offline: false` |
| SSH script exits silently | `set -u` in trigger script | Arc libs use unset vars; trigger avoids `-u` |
| SSH fails after reboot | Stale Proxmox `known_hosts` | Cleared before each hop |

## What's still manual

- DSM first-boot wizard (`:5000`)
- Storage pool on the data disk
- SSH enable in DSM, packages, backup tasks - your use case

## Upstream

Before publishing [arc-loader-automated](https://github.com/aioue/arc-loader-automated), I opened small PRs against [AuxXxilium/arc](https://github.com/AuxXxilium/arc) - bug fixes, docs, and helpers - each with repro steps on Arc 3.1.0. Example: [#9536](https://github.com/AuxXxilium/arc/pull/9536) (p1 `/automated` for grub `automated_arc`). They were closed without merge.

That is fine. The useful pattern in open source is: try upstream first, then ship what works in your own repo so others do not rediscover the same traps. These scripts are that layer - workarounds baked in, no dependency on Arc accepting the patches.

## Links

- Scripts: [github.com/aioue/arc-loader-automated](https://github.com/aioue/arc-loader-automated)
- Arc Loader: [github.com/AuxXxilium/arc](https://github.com/AuxXxilium/arc)
- Issues: [github.com/aioue/arc-loader-automated/issues](https://github.com/aioue/arc-loader-automated/issues)

Questions or improvements: open an issue on the repo.
