---
layout: post
title: Reading an ASM2464PD enclosure's firmware before flashing it
date: '2026-10-12 00:30:00'
tags: [firmware, reverse-engineering, usb4, nvme, asmedia, ugreen, homelab]
hidden: false
---

My UGREEN CM642 is a USB4 NVMe enclosure built on an ASMedia ASM2464PD. Under sustained load it drops off my Mac mini, and it runs hot. UGREEN support has no fan-curve firmware and offered the public ASMedia `250717` zip, which [one owner](https://www.reddit.com/r/UsbCHardware/comments/1bt10ue/ugreen_40gbps_nvme_ssd_enclosure_mac_os/) reports made their disconnects worse. I wanted to know what ASMedia's flasher (MPTool) would do to the unit before I let it, and whether I could read enough of the chip to undo it.

Two existing projects did much of the groundwork: [tinygrad/asm2464pd-firmware](https://github.com/tinygrad/asm2464pd-firmware) (stock ASM2464PD firmware, decompilation, an 8051 emulator, and `flash.py`/`e4_flash.py` host tools) and [cyrozap/usb-to-pcie-re](https://github.com/cyrozap/usb-to-pcie-re) (notes on the ASM236x/246x vendor SCSI commands). I checked what they say against this Ugreen firmware and unit using [REA](https://www.npmjs.com/package/rea-agents) (a reverse-engineering MCP server), Ghidra, radare2 and a few Cursor agents. The unit shipped on `240229850000`, and I flashed `250417_85_00_00` early on 2026-10-12.

Most of what follows is what static analysis could and could not tell me. Whether the flash fixes the disconnects is not known yet.

## What Update FW touches

Update FW rewrites the config tables as well as the code. Every row in ASMedia's production logs fills VID, PID, revision and strings from the INI. The INI on the tools ISO would have turned this unit into PID `2464`, serial `AAAABBBB...`, strings `USB4_TBT` / `SSD Enclosure`. I wrote an INI holding the unit's live values and used only that. MPTool quirks that cost time:

- The INI must be called `as_mp_Toolv0.6.ini` and sit beside the EXE. Any line starting with `;` gives an invalid-line dialog, so the file cannot carry comments.
- Start refuses with "FW check is incorrect" unless the bin is named `AS_USB4_*`. My backup, saved as `firmware-240229850000.bin`, was rejected until I renamed it `AS_USB4_240229_85_00_00.bin` and matched `fw_binary_name` in the INI.
- Standalone Config Check plus Play did nothing on my build. The Check Configuration dialog's Read Config and Read U4 Config buttons work, and I used them to record both tables before unplugging.
- W/R Test, Format Type and Partition Type all write to the SSD. Only Update FW is safe.

There is no downgrade gate. The EXE's embedded defaults set every `check_*` key (`check_fw_version`, `check_vid`, `check_pid` and so on) to 0, and the ISO's INI has no `[chk_item]` section, so nothing compares versions. Browsing to an older bin raised no complaint. The same Reddit owner reports going `250717` down to `241129` and back up to `250417`. I have not flashed backwards from `250417` myself.

## Flash the same image back first

Before the real flash I flashed the existing `240229` image over itself with the exact-identity INI, then read everything back. After that, Update FW had changed:

| Area | Change |
|------|--------|
| SPI window (130,560 B) | 2 bytes at 98049-98050, `60 13` to `FF FF`, in the padding after the image |
| Config table 0 | 16 bytes, mostly `FF` replaced by the INQUIRY text `ASMT` and `2462 NVME`, plus the CRC tail |
| Config table 1 | 2 bytes |
| Serial, strings, VID/PID | none |

So the config tables are rewritten from the INI, and the padding past the image survives, so within the window I can read there was no full-chip erase on the Update FW path. Static analysis of the firmware had only reached "likely" on that point. The null flash was the evidence. If you are about to flash a unit you cannot replace, this is the cheapest drill I know of.

## What the old firmware shows statically

The flash file is a wrapped image:

```
0x0000   little-endian uint32 length (98006)
0x0004   8051 image body
 +0x200  BCD version, 24 02 29 85 00 00 = 240229850000
end      6-byte trailer, a5 b6 5b 36 08 54
```

It is 8051 code. The bank layout below matches tinygrad's emulator (`BANK1_FILE_BASE = 0xFF6B`) and I confirmed it against this image. The low 32 KiB is fixed and the upper 32 KiB is banked by SFR `0x96` bit 0, with bank 1 starting at file offset `0xFF6B`. In Ghidra, import the two banks as separate programs at `0x0000` and `0x8000`, with processor `8051:BE:16:default`. Disassembling straight through the file produces nonsense around the jump tables, so start from `lcall` targets.

Vendor commands are SCSI CDBs dispatched from a table in bank 1. The table keys in this image are `E0` to `E5` and `E8`. The meanings are from tinygrad's `flash.py` and cyrozap's notes (cyrozap documents `E2` as a flash read taking a byte and a 32-bit count), and I checked the `E0`, `E1`, `E2` and `E4` behaviour on the unit:

| Opcode | Use |
|--------|-----|
| `E0 50 <slot>` | read a 128-byte config table |
| `E1 50 <slot>` | write a config table |
| `E2` | read SPI flash |
| `E3` | write SPI flash |
| `E4` | firmware version, 6 bytes BCD |
| `E5` | poke, the route to reading arbitrary flash |
| `E8 51` | reset |

The firmware's SPI driver uses the same registers as [tinygrad's asm2464pd-firmware](https://github.com/tinygrad/asm2464pd-firmware) (`0xC8A1` to `0xC8AD`, buffer at XDATA `0x7000`, found by scanning for `MOV DPTR,#imm16`). So tinygrad's register map is valid for this Ugreen build.

The write path matters for erase scope. The `E3` worker only does write-enable and page program (`0x02`). Erase appears to be a separate state machine using 4 KiB sector erase (`0x20`) with a preset address of `0x18000`. A 64 KiB block erase (`0xD8`) routine appears reachable from the `E1` config write, but only on slot 0. Config shares the first erase block with the start of the firmware, which is why tinygrad's `flash.py` saves and restores config around its erase. I first read that routine as the slot 1 path, and a second model reviewing my notes caught it. I only ever drilled slot 1.

Two other REA findings are about tooling. REA's firmware tools lean on binwalk, which finds no signatures in this custom container, so the layout above was worked out by hand. Ghidra ships no native decompiler for arm64 Linux, so my arm64 devcontainer could import and disassemble but not decompile. I ran decompilation on an x86_64 VM.

## E2 and the dump you cannot get

`E2 <region> <len u32 big-endian>` reads the flash. It cannot seek: each read returns the start of the selected window, capped at `0xFF00` (65,280) bytes per transfer. Two reads, `E2 50` then `E2 D0`, give 130,560 bytes. That covers the 98,016-byte image plus `FF` padding. A longer second read fails with CHECK CONDITION, ILLEGAL REQUEST 05/24. The flash is a 512 KiB Puya P25D40H (per a [CM642 teardown on chongdiantou.com](https://www.chongdiantou.com/archives/304319.html), in Chinese), so about 381 KiB is out of reach over `E2`.

The unreachable part includes things you would want in a backup. The config tables sit at SPI `0x000-0x0FF` and the bootstub at `0x100`, below the window. The config bytes appear nowhere in the 130,560 bytes I read (that layout comes from [tinygrad commit c2c36aa](https://github.com/tinygrad/asm2464pd-firmware/commit/c2c36aa9023fa15d40ffb77ea54c54221ff07bec), not from reading the chip). Config comes out over `E0` instead, and the bootstub is not backed up at all.

The remaining routes are `E5` poke reads, which I did not try on a unit I wanted to keep, and a hardware programmer. I own one, but I judged this board to have no usable pads. A USB-dead brick would have been unrecoverable, and I flashed knowing that.

The second `E2` region byte also contradicts the disassembly. The gate at the start of the handler accepts only `0x50` and `0x51`, and there is no `0xD0` compare anywhere in the image. On the live unit `D0` returns the rest of the image, seamless with the first read, while `51` returns `FF` padding. I could not explain that statically, and the mechanism is still open. Probe the device read-only before trusting a gate you found in a disassembler. Two tool traps from the same exercise: an old "full dump" script requested a 459,008-byte second leg that always failed, and tinygrad's `flash.py` writes placeholder tables and ends with `E8 51`, which leaves the bridge down until you unplug it.

## Config tables and the Thunderbolt DROM

Table 0 holds the USB identity: serial, manufacturer, product strings and VID/PID. Table 1 holds the USB4 identity: strings, a component ID, test ID, `bcdDevice`, and the TBT3 vendor, model and revision. `E0` slots 2 to 7 all return ILLEGAL REQUEST, so there are only two. The INI field names map straight onto the bytes.

On a Mac, none of that is what you see. The enclosure shows up as a USB4 PCIe tunnel (`IOThunderboltSwitchUSB4`, `Protocol: PCI-Express`), and the identity macOS reads is a 102-byte Thunderbolt DROM. Its strings and IDs derive from the config tables. Its first 16 bytes, a UUID-like ID, do not appear in the firmware, the SPI window, either config table or the MPTool EXE (I searched as-is, reversed and word-swapped). They look per-unit and unbacked. Capture the DROM with `ioreg`, because `system_profiler` returns empty over SSH (TCC).

## What 250417 changed

After the flash I read back over SCSI and from the Mac:

- Both config tables are byte-identical to before, and so is the DROM.
- 84,169 of the 130,560 SPI bytes differ. The version field at `0x200` accounts for three of them (`24 02 29` to `25 04 17`, suffix unchanged). Code moved everywhere, so a raw diff says little.
- `Chg2 10G` and `Chg2 20G` became `[Spd 10G]` and `[Spd 20G]`, and `UPS_Rst_Assert` became `USP_Rst_Assert`.
- New strings: `L1:Training OS2`, `Fail-Auto`, `[TargetErr]`, `[TxRtyErr]`. `[1 sec time out]` is still there, relocated.

That points at USB4 link training and error handling. The [same Reddit owner](https://www.reddit.com/r/UsbCHardware/comments/1bt10ue/ugreen_40gbps_nvme_ssd_enclosure_mac_os/) reports `250417` staying on USB4, but I have no evidence tying these strings to that.

Right after the flash, `E4` and MPTool's FW column still showed `240229850000` while the image body said `250417850000`. The version buffer at XDATA `0x07F0` is filled at init: Ghidra shows code in the new image at `0x5E44` writing `25 04 17 85 00 00` there. Judge a flash by the body at `0x200` and the identity, and re-read `E4` after a power cycle, which I have not done yet.

## The fan

I found nothing in the bridge's flash window or its vendor commands that touches the fan. ASMedia's [MPTool manual](https://egpu.io/wp-content/uploads/wpforo/attachments/16981/16713-ASM2464PDMPToolUserManual.pdf) lists a separate `mcu_fw_enable` key, which I left at 0. Over USB there is no hwmon node or temperature sensor, and with no SSD fitted there was no NVMe SMART either. I have no evidence that this update changes fan behaviour.

## So far

A one-minute sustained read on a sacrificial WD SN530, on `240229` and again on `250417`, gave zero disconnects and about 1 GB/s both times. `diskutil` and the Thunderbolt link fields on the Mac are unchanged, and the DROM is identical. One minute says nothing about the failure I actually have, which shows up after hours and after sleep. I am running the real SSD on it now, with the original image, config tables and INI saved for a rollback.

## Sources

- [tinygrad/asm2464pd-firmware](https://github.com/tinygrad/asm2464pd-firmware): `flash.py` CDB shapes, SPI register map, 8051 bank layout, flash layout notes
- [cyrozap/usb-to-pcie-re](https://github.com/cyrozap/usb-to-pcie-re): ASM236x/246x vendor opcode notes
- [ASMedia MPTool user manual](https://egpu.io/wp-content/uploads/wpforo/attachments/16981/16713-ASM2464PDMPToolUserManual.pdf) (egpu.io mirror): Update FW scope, INI keys
- [Station-Drivers ASM2464 list](https://www.station-drivers.com/index.php/en/component/remository/Drivers/Asmedia/ASM-2464-NVMe-USB-4.x-Controller-(40Gbps)/orderby,2/page,3/lang,en-gb/?Itemid=0): the `250417_85_00_00` bin
- [r/UsbCHardware thread](https://www.reddit.com/r/UsbCHardware/comments/1bt10ue/ugreen_40gbps_nvme_ssd_enclosure_mac_os/): one CM642-15976 owner's firmware history
- [CM642 teardown on chongdiantou.com](https://www.chongdiantou.com/archives/304319.html) (Chinese): flash chip part number
- `ASM246xMPTool.exe`, its INI and the production logs on UGREEN's and ASMedia's tools: downgrade gate, identity rewrite

I did this with Cursor agents (Claude doing most of the work, with GLM models reviewing the notes before the writes). I made the decisions about what to write to the unit.
