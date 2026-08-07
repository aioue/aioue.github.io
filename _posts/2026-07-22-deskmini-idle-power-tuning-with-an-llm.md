---
layout: post
title: Teaching an LLM to tune idle power on a DeskMini
date: '2026-07-22 23:15:00'
last_modified_at: '2026-07-25'
tags: [proxmox, bios, homelab, power, llm, cursor]
hidden: false
---

In [April I mapped the ASRock X300 BIOS knobs](/2026/04/25/deconstructing-asrock-x300-bios-power-options/). In July I ran the experiment for real: one change per reboot, wall power from a Zigbee IKEA plug, with a Cursor agent doing SSH, NVRAM writes, and CSV logging.

## Setup

- ASRock X300M-STX, Ryzen 5 PRO 5650G, BIOS **P2.20B**, Proxmox
- Guests always on: HA (VM 101), ubuntu-cloud (VM 102), tank (LXC 200)
- Meter: `zigbee2mqtt/plug2_ikea_energy` (~10 s cadence)
- Headless only: one NVRAM byte per cycle, full VarStore backup, stop if SSH fails

Scripts and results live in [asrock-x300m-stx-bios](https://github.com/aioue/asrock-x300m-stx-bios) (`measure-idle-power.sh`, `nvram-write-byte.sh`, `results/power-tuning.csv`).

## Result

Settled idle at the plug (`loadavg < 1`, no ZFS scrub/zrepl in flight): **~23–26 W**.

Credible savings vs the first good scripted baseline (~26 W): **about 2–3 W**. The earlier "~45–50 W" figure was mostly measurement regime (post-boot load, stuck MQTT samples), not a single BIOS win.

Load-gated v2 rows (the ones worth trusting):

| State | Plug median |
|-------|-------------|
| 5a HD Audio off only | 29.5 W |
| + WLAN off | 23.6 W |
| + CPPC Enabled | 25.9 W |
| + DF Cstates Enabled | 25.7 W |
| PM L1 SS (separate A/B) | ~0 W vs noise |

## What didn't pay off

**`pcie_aspm=force`** - kernel enables the global policy, but Renoir GPP bridges to M.2 and the NIC advertise `ASPM not supported`. Endpoint `LnkCtl` stays ASPM Disabled. Force does not invent bridge capability.

**PM L1 SS** - NVRAM sticks at L1.1+L1.2, but L1 substates need ASPM L1 on the link first. Same bridge problem → no measurable plug delta. Left enabled; no harm.

**CPPC / DF Cstates** - deterministic Enabled instead of Auto. Still **C3 max**, no CC6. Package deep idle likely needs Power Supply Idle (`0x0FC`), which we deferred (live `0xFF`, USB boot risk).

**PowerTOP watts** - unavailable on AC desktops without a battery. Useful for tunables audit only; the plug is the wall meter.

## Measurement gotchas

- Sample only after **`loadavg < 1` for 2 consecutive checks** and no ZFS scrub/send or active zrepl sync. Early post-reboot samples look like "regressions".
- The IKEA plug can stick (15× identical 19.6 W) then jump; compare medians at matched idle load.
- Strict plug-spread settle loops can run for an hour on this meter - load+ZFS gating is enough.

## LLM in the loop

Good at staged protocol, parsing `lspci` / NVRAM read-back, and writing scripts. Bad at treating a 70 W post-reboot spike as causal without checking load, and at trusting PowerTOP for watts. Pattern that worked: **human sets policy, agent executes and logs, human sanity-checks when MQTT and physics disagree.**

Final applied profile (for BIOS flash recovery): [FINAL-APPLIED-SETTINGS.md](https://github.com/aioue/asrock-x300m-stx-bios/blob/main/FINAL-APPLIED-SETTINGS.md). Prior art: [BIOS deconstruction](/2026/04/25/deconstructing-asrock-x300-bios-power-options/).
