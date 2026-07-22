---
layout: post
title: Teaching an LLM to tune idle power on a DeskMini
date: '2026-07-22 23:15:00'
tags: [proxmox, bios, homelab, power, llm, cursor]
hidden: false
---

In [April I pulled apart the ASRock X300 BIOS](/2026/04/25/deconstructing-asrock-x300-bios-power-options/) and wrote down *which* knobs looked interesting. In July I finally ran the experiment: one change per reboot, wall power measured through a Zigbee IKEA plug in Home Assistant, with a Cursor agent doing the SSH, NVRAM writes, and log keeping.

This is a post about what happened when a language model met a physical machine — and why half the "obvious" savings never showed up on the plug.

## The setup

- **Host:** ASRock X300M-STX, Ryzen 5 PRO 5650G, BIOS **P2.20B**, Proxmox 8
- **Guests always on:** Home Assistant (VM 101, owns the Zigbee dongle), ubuntu-cloud (VM 102), tank (LXC 200)
- **Meter:** `sensor.plug2_ikea_energy_power` via Zigbee2MQTT (~10 s reporting interval)
- **Agent constraints:** headless only (no BIOS UI), one variable per cycle, full efivar backup before each NVRAM byte, stop if SSH fails after reboot

The agent wrote `measure-idle-power.sh` and `nvram-write-byte.sh` into [asrock-x300m-stx-bios](https://github.com/aioue/asrock-x300m-stx-bios) and appended every run to `results/power-tuning.csv`.

## What we changed

| Order | Change | Plug at idle (best effort) |
|-------|--------|----------------------------|
| 0 | Baseline | 26.1 W |
| 1 | `pcie_aspm=force` in GRUB | 25.5 W (~0 W) |
| 2 | VM 102 cores 8→4 | inconclusive (guest restart) |
| 5a | HD Audio off (NVRAM) | noisy post-reboot |
| 5b–5d | WLAN off, CPPC on, DF Cstates on | **stuck at 19.6 W** (bad data) |
| 5e | PM L1 SS on, then reverted on false alarm | 70 W spike → revert |
| 5e retry | PM L1 SS on again, proper idle wait | 23.0 → 24.2 W (noise) |
| Final | All NVRAM + ASPM + 4 cores | **~23 W** at `loadavg < 1` |

Net credible savings vs the first good baseline: **roughly 2–3 W**, not the 20+ W gap between my original "~45–50 W" observation and today's ~23 W. The big drop is mostly *measurement regime* (post-boot load, spinning USB disk, stuck plug readings) not a single heroic BIOS bit.

## Measurement lessons (the agent learned the hard way)

### 1. Wait for load, not wall clock

Post-reboot plug readings were useless while `loadavg` was 4–6 (guests still booting). A fixed "quick" 30 s wait wasn't enough. Waiting until **`loadavg < 1`** produced stable 23 W medians; the agent folded that into `measure-idle-power.sh --quick` (`QUICK_LOAD_MAX=1.0`).

The old settle loop also waited for plug samples within 3 W of each other. On this plug that could run **over an hour** and still fail. Load-gating is the practical compromise.

### 2. The IKEA plug can lie (briefly)

Fifteen consecutive samples at **exactly 19.6 W** across three reboots was a stuck MQTT value, not physics. When it unstuck, readings jumped to 50–70 W during high load and looked like a "regression" for PM L1 SS. Re-running with load settled showed **no real harm**.

### 3. PowerTOP is not a wall meter on AC

On a desktop with no battery, PowerTOP has **no ACPI discharge rate**. Per-device "Power est." values are rough guesses; our HTML reports only showed **activity %** anyway. PowerTOP was useful to confirm Ansible had already applied the safe tunables — not to measure watts. The plug stays authoritative for total system power.

## Why some options did nothing (or looked worse)

### `pcie_aspm=force` — ~0 W

Kernel says `PCIe ASPM is forcibly enabled` and policy is `powersupersave`, but `lspci` on the important endpoints still shows **`ASPM Disabled`**:

```
00:02.3  Renoir/Cezanne PCIe GPP Bridge   LnkCap: ASPM not supported
03:00.0  RTL8111 NIC                      LnkCtl: ASPM Disabled
01:00.0  Micron NVMe                      LnkCtl: ASPM Disabled
04:00.0  AX200 (vfio-pci → HA)            LnkCtl: ASPM Disabled
```

The **CPU-attached GPP bridges** to M.2 and the NIC slot do not advertise ASPM. Linux will not light up endpoint ASPM when the upstream port cannot participate. `pcie_aspm=force` overrides the global ACPI "disable ASPM" flag — it does not fabricate bridge capability.

iGPU and SATA bridges (`00:08.x`) *do* show `ASPM L0s L1 Enabled`. The hungry peripherals sit behind the wrong ports.

### PM L1 SS (BIOS) — NVRAM yes, links no

Writing `AMD_PBS_SETUP` offset `0x025` to `L1.1_L1.2` **sticks** in live read-back. But `L1SubCtl1` on NVMe/NIC/AX200 stays all `-` for the same reason: **L1 substates need ASPM L1 on the link first**. The BIOS setting is necessary but not sufficient on this board; without bridge ASPM it is effectively a no-op for those devices.

### CPPC, DF Cstates — deterministic, shallow idle

NVRAM bytes applied and match recommendations. `cpuidle` still tops out at **C3** — no CC6 visible in sysfs. These are "make Auto explicit" changes; community threads report the same C3-only symptom on similar ASRock + Ryzen boxes. DF Cstates may need **Power Supply Idle Control** (`0x0FC`, currently `0xFF` / invalid on live read-back) before package idle deepens — and that offset is deferred because USB boot recovery is not negotiable over SSH.

### HD Audio off, WLAN off — sub-watt, buried in noise

IFR estimates ~0.3–0.5 W each. At ±2 W plug jitter they will never show clearly in a 10-sample median. WLAN is off in NVRAM but `iwlwifi` is not loaded anyway — AX200 Wi-Fi is **vfio passthrough** to Home Assistant; the PCIe function stays active for the VM.

### VM 102 cores 8→4 — small or lost in noise

Idle vCPU overhead with `powersave` + EPP is already modest. Four fewer virtual cores might save a watt or two; we never got a clean A/B because the guest hash changed mid-series.

### False "increases"

Anything measured at `loadavg > 2` within six minutes of reboot is boot transients (ZFS import, HA, z2m, QEMU). The 47 W after HD Audio and the 70 W after PM L1 SS were in that bucket — not caused by the setting.

## What actually moved the needle

Honest accounting at **`loadavg < 1`**:

- **Operational baseline drift:** first "~45–50 W" vs settled **~23 W** with the same guests — measure idle, not "I glanced at HA after updates"
- **Cumulative small wins:** NVRAM bundle + existing Ansible power role + `pcie_aspm=force` (even if endpoint ASPM failed) ≈ **2–3 W** vs the first scripted baseline
- **Still on the table:** Power Supply Idle (`0x0FC`, needs physical-access safety), USB HDD spin policy, `iwlwifi` blacklist if Wi-Fi is truly unused, amdgpu on a headless host (wakeups show in PowerTOP)

## LLM in the loop — what worked

**Good fit:**

- Repetitive staged protocol (backup → one byte → reboot → verify → CSV)
- Parsing `read-live-bios-settings.py`, `lspci`, `zpool status`, dmesg tails
- Writing the measurement scripts and keeping `RESEARCH.md` honest when literature conflicts with live read-back

**Bad fit:**

- Deciding a 70 W plug reading meant "revert immediately" without checking load and link state
- Trusting PowerTOP for watts on an AC mini PC
- Letting the strict plug-spread settle loop run for 67 minutes

The useful pattern is **human sets policy** (one change, headless only, no `0x0FC`), **agent executes and documents**, **human sanity-checks** when physics and MQTT disagree.

## Tools

- Repo: [aioue/asrock-x300m-stx-bios](https://github.com/aioue/asrock-x300m-stx-bios) — runbook, CSV results, PowerTOP HTML captures, ASPM notes in `RESEARCH.md`
- Prior art: [Deconstructing an ASRock X300 BIOS for Proxmox power tuning](/2026/04/25/deconstructing-asrock-x300-bios-power-options/)

If you are chasing the last few watts on an X300: **verify bridge ASPM in `lspci` before believing GRUB or PM L1 SS did anything**, and **do not trust a smart plug until load has settled**.
