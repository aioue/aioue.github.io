---
layout: post
title: Getting Proxmox root off USB on a DeskMini with no free slots
date: '2026-10-01T00:00:00+01:00'
tags: [proxmox, zfs, uefi, usb, homelab, deskmini]
hidden: false
---

The DeskMini X300M-STX that runs my Proxmox host has four storage connectors, and all of them were already taken by data:

| Connector | Drive | Pool |
|-----------|-------|------|
| M.2 M-key x2 | 2x Crucial P3 4TB | `fast` (mirror) |
| SATA x2 | 2x Samsung 870 QVO 2TB | `slow` (mirror) |
| M.2 E-key | Intel AX200 | Bluetooth passed to Home Assistant |

So the OS lived on a WD SN530 256GB in an RTL9210 USB-C enclosure on the front port. It worked, but it caused trouble in several ways:

- `rpool` filled to 100% on 2026-09-23 and took journald, pvescheduler and chrony down with it.
- The enclosure shares an xHCI controller (`05:00.3`) with the front USB-A port, where the rotating zrepl backup HDD lives. Backups corrupted after I raised the zrepl bandwidth limit from 50 to 75MiB/s.
- The initramfs needed `ZFS_INITRD_*_SLEEP` delays so the USB bridge had time to enumerate before the pool import.

## What I considered

Rear USB 3 SSD. The rear port is on the other controller (`05:00.4`), so a SATA SSD in a JMS578 enclosure there would have ended the contention with the backup HDD for about £40. Root would still have been on a USB bridge, though, and the RTL9210 enumeration races had already caused BIOS boot failures once.

Repartitioning the NVMe mirror. The layout would be 1G ESP, 256G `rpool` and the rest for `fast`, on both P3s. Mirrored, native NVMe, and the "proper" answer. But `fast` used whole disks, so this meant destroying the pool, booting a rescue ISO and restoring ~900G from a USB backup HDD that had just been corrupting data. Too much risk for a cleaner boot layout.

NVMe in the E-key slot. The Wi-Fi slot's root port (`00:02.4`) advertises PCIe Gen3 x1, and a passive E-to-M adapter is cheap. Linux would very likely see the SSD. Whether the X300 firmware would *boot* from that slot was unknown, and nothing short of a hardware test could prove it. It also meant moving the AX200's Bluetooth to a USB carrier, and the internal Bluetooth has been reliable for Home Assistant.

Rear USB 2.0. A fallback for the first option, never a plan.

## What I did

Root became a plain dataset on the existing `fast` mirror, and the only things left on USB are EFI system partitions:

```
fast/ROOT/pve-1     root, quota 64G, reservation 32G
fast/swap           8G zvol, volblocksize 4K
fast/proxmox/vms    guest disks (storage fast-vms)
fast/proxmox/vz     /var/lib/vz
2x SanDisk Ultra Fit 32GB: 2 GiB ESP (shim, GRUB, kernels, initramfs) + exFAT scratch
```

The sticks cost £14.18 for two. `proxmox-boot-tool` keeps both ESPs identical, and Secure Boot still works because they carry the same signed shim and GRUB. The quota stops a runaway root from eating data space, and the reservation stops data from squeezing the OS out, which is what killed `rpool` in September.

The trade-off is that root now shares `fast`'s failure domain. Losing one P3 still boots (degraded mirror, bootloader on the sticks). Losing both loses the data too, which was already true.

A stick ESP uses 273MB with three kernels, so 2 GiB is plenty. The sticks write at about 9MB/s sustained, which only matters during kernel updates.

## Order of operations

Everything except the cutover was online:

1. `f3probe`, `f3write` and `f3read` on both sticks. Each took about an hour at that write speed. Both were genuine 28.67GB with zero bad sectors.
2. Moved guest disks to `fast` with `qm move-disk` / `pct move-volume`, keeping the source copies. Moved `/var/lib/vz` with rsync.
3. Partitioned stick A, ran `proxmox-boot-tool format` and `init ... grub`, then rebooted with `efibootmgr --bootnext`. This rehearsal booted the *old* root from the stick, without the console.
4. Initial `zfs send rpool/ROOT/pve-1@migrate-1 | zfs recv -u ... fast/ROOT/pve-1` while running.

The cutover itself took about 20 minutes of downtime:

```bash
# guests down, pve-cluster stopped
zfs snapshot rpool/ROOT/pve-1@migrate-final
zfs send -i @migrate-1 rpool/ROOT/pve-1@migrate-final | zfs recv -u -F fast/ROOT/pve-1
mount -t zfs -o zfsutil fast/ROOT/pve-1 /mnt/newroot
# on the new root: root=ZFS=fast/ROOT/pve-1 in /etc/kernel/cmdline and grub.d/zfs.cfg,
# swap in fstab, proxmox-boot-uuids = sticks only, zpool.cache without rpool
zpool set bootfs=fast/ROOT/pve-1 fast
# chroot with /dev /proc /sys efivars bound:
update-initramfs -u -k all && proxmox-boot-tool refresh
# on the old root: drop the sticks from proxmox-boot-uuids, canmount=noauto
```

To build a cache file without `rpool`, point the pools you want at a temporary cache file, copy it, then set the property back:

```bash
zpool set cachefile=/tmp/newcache fast
zpool set cachefile=/tmp/newcache slow
cp /tmp/newcache /mnt/newroot/etc/zfs/zpool.cache
zpool set cachefile="" fast; zpool set cachefile="" slow
zdb -C -U /tmp/newcache | grep -E '^[a-z]+:$'   # zdb wants an absolute path
```

The old SSD stayed bootable and untouched as rollback media until I unplugged it.

## Gotchas

Port-based USB passthrough grabs whatever is plugged in. An old `usb0: host=2-1` on an unrelated VM claimed the front stick the moment it went in, and crashed QEMU. Pass devices through by `vendor:product`. That stale passthrough may also explain some of the backup trouble.

`proxmox-boot-tool init <part>` without `grub` installs systemd-boot, which is unsigned, so Secure Boot rejects it. Always `init <part> grub`.

Stopping `pve-cluster` breaks key-based SSH. On PVE `/root/.ssh/authorized_keys` is a symlink into `/etc/pve/priv`, and `/etc/pve` disappears with pmxcfs. An Ansible ControlMaster socket that happened to still be open saved me. sshd also reads `authorized_keys2`, so the controller key now lives there too.

The `zfspool` storage plugin imports its pool when the storage activates. With the old SSD still plugged in, `local-zfs` would have imported `rpool` on the new root. `pvesm set local-zfs --disable 1` before copying `config.db`.

`umount -R` on chroot bind mounts under a shared-propagation `/` can unmount the host's own `/dev` and `/run`. Run `mount --make-rprivate /mnt/newroot` first.

`grub-install` owns the NVRAM entry called `proxmox`. Every `proxmox-boot-tool init` deletes all entries with that label and adds one, first in BootOrder, for whichever stick was just initialised. Initialising stick B silently took stick A's entry. Each stick now has its own labelled entry:

```bash
efibootmgr -c -d /dev/disk/by-id/usb-...A -p 1 -L "PVE stick A" -l '\EFI\proxmox\shimx64.efi'
efibootmgr -c -d /dev/disk/by-id/usb-...B -p 1 -L "PVE stick B" -l '\EFI\proxmox\shimx64.efi'
```

A small script deletes stray `proxmox` entries and restores A, B first. It runs at boot and from an apt `DPkg::Post-Invoke` hook, so GRUB upgrades cannot reorder things.

The firmware drops a disk's NVRAM entry by itself once the disk has been absent for a boot. Rolling back to the old SSD now means F11, or recreating its entry with `efibootmgr -c`.

## Keeping a pulled stick current

The `zz-proxmox-boot` kernel hook refreshes every ESP that is present and skips the rest with a warning. Plug a stick back in after a kernel update and it still carries the old kernels. A udev rule fixes that:

```
ACTION=="add", SUBSYSTEM=="block", KERNEL!="zd*", ENV{DEVTYPE}=="partition", \
  ENV{ID_PART_ENTRY_TYPE}=="c12a7328-f81f-11d2-ba4b-00a0c93ec93b", ENV{ID_FS_UUID}=="?*", \
  TAG+="systemd", ENV{SYSTEMD_WANTS}+="proxmox-esp-sync@%E{ID_FS_UUID}.service"
```

The service compares the stick's `vmlinuz-*` and `initrd.img-*` with `/boot` and runs `proxmox-boot-tool refresh` only if they differ, so the coldplug event on every boot writes nothing. `KERNEL!="zd*"` skips guest EFI disks, which are zvols with their own ESPs.

In the unit, use `%i`, not `%I`. Unescaping turns the `-` in a FAT UUID like `A096-CEFC` into `/`, and the script then could not find the stick.

## Result

Both sticks have boot-tested, and the host runs from internal NVMe with nothing on USB in the boot path except the bootloader. The box is also more portable: the NVMe mirror plus either stick is the whole system.

zrepl stays at 50MiB/s until the backup HDD is back and has scrubbed clean. It will share a controller with stick B, not with root.

I did this with a Cursor agent (Claude) doing the SSH work and Composer subagents running the stick tests, validation and repo changes in parallel, much as in the [idle power tuning](/2026/07/22/deskmini-idle-power-tuning-with-an-llm/). It wrote a runbook first, asked before anything destructive, and caught the NVRAM and SSH gotchas as they happened. I made the storage decisions.
