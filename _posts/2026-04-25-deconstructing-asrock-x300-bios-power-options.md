---
layout: post
title: Deconstructing an ASRock X300 BIOS for Proxmox power tuning
date: '2026-04-25 13:30:00'
tags: [proxmox, bios, homelab, power]
hidden: false
---

My Proxmox host is an ASRock X300M-STX with a Ryzen 5 PRO 5650G: always on, quiet, enough for a handful of VMs and containers. The power and virtualisation knobs that matter live in the BIOS, often under opaque labels.

ASRock's `P2.20B` BIOS for this board enables ACS/ARI behaviour, so PCIe devices land in cleaner IOMMU groups without `pcie_acs_override`. I wanted to keep that and still figure out what the board does for idle power.

## Pulling the BIOS apart

The useful path was:

1. Extract the AMI UEFI image with `UEFIExtract`.
2. Run `ifrextractor` against the right Setup, AMD CBS, AMD PBS, and AMD Overclocking modules.
3. Search the IFR output for settings like `C-state`, `CPPC`, `Power Supply Idle`, `ASPM`, `L1`, `IOMMU`, `ACS`, and `ARI`.
4. Compare the extracted offsets with live `efivarfs` values on the running Proxmox host.

The last step matters. A saved BIOS profile file is not the same thing as live UEFI variables. It can show that bytes changed, but it does not reliably tell you "this byte is `AmdSetup` offset `0x145`". Live read-back from `/sys/firmware/efi/efivars/` is much more useful.

## What was worth looking at

The obvious CPU-side settings were mostly already sane. Linux was using `amd-pstate-epp`, CPPC was effectively working, and CPU idle states were active. Changing BIOS values from `Auto` to `Enabled` would mostly be about determinism, not a guaranteed idle-power win.

The PCIe side was more interesting. The NVMe drives, Realtek LAN, and Intel AX200 endpoint all showed ASPM disabled. Some endpoints advertise L1 or L1 substates, but the platform/root-port side decides whether Linux can safely enable the link. That makes the BIOS `PM L1 SS` setting a good candidate for careful staged testing, not something to blindly force with `pcie_aspm=force`.

The other high-value candidates were more mundane:

- Leave Bluetooth enabled, because I actually use it.
- Potentially disable only Wi-Fi, since the AX200 exposes Wi-Fi over PCIe and Bluetooth over USB.
- Disable unused HD audio on a headless server, but only after confirming the live variable path.
- Treat ECO mode as a load-power cap, not an idle-power fix.

## IOMMU and caveats

On `P2.20B`, both NVMe drives, LAN, Wi-Fi, iGPU functions, USB controllers, and SATA land in separate IOMMU groups without a kernel ACS override. I would not trade that away for a watt or two.

Less helpful: one expected `Setup` efivar was missing on the live host, and one `Power Supply Idle Control` offset read back outside the IFR option list. That is why I prefer a read-only collector and staged changes over writing NVRAM from a table of offsets.

Source and notes: [aioue/asrock-x300m-stx-bios](https://github.com/aioue/asrock-x300m-stx-bios)

July 2026 follow-up (IKEA plug measurements, headless NVRAM writes, LLM-driven reboot loops): [Teaching an LLM to tune idle power on a DeskMini](/2026/07/22/deskmini-idle-power-tuning-with-an-llm/).
