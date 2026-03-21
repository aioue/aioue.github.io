---
layout: post
title: Keeping a Canon PIXMA MG6250 alive on modern macOS
date: '2026-03-21 12:00:00'
tags: [macos, printing, scanning, canon, drivers]
hidden: false
---

Canon dropped macOS support for the PIXMA MG6250 after High Sierra (10.13). The hardware still works fine, but there are no official drivers for anything newer. I put together [canon-mg6250-mac-driver-bundle](https://github.com/aioue/canon-mg6250-mac-driver-bundle) - a set of shell scripts that extract and install Canon's last official drivers on current macOS, including Apple Silicon via Rosetta 2.

## The problem

Canon's High Sierra `.dmg` installers ship unsigned `.pkg` files that Gatekeeper blocks on modern macOS. Even if you force-install them, the printer filters are x86_64 binaries that won't run on Apple Silicon without Rosetta. The scanner driver needs its ICA bundle placed in the right location and a USB re-plug cycle before Image Capture will recognise it. None of this is documented anywhere obvious.

## What the bundle does

The repo contains Canon's original DMGs alongside install scripts that handle the extraction and placement:

- **Printer** - `deploy_printer_canon_full.sh` mounts the DMG, extracts the full `BJPrinter` tree and the official gzipped PPD, and copies them into `/Library`. A separate script creates a CUPS queue using Bonjour/IPP discovery via `ippfind`, so you don't need to know the printer's IP address.

- **Scanner** - `deploy_canon_scanner.sh` does the equivalent for the ICA scanner bundle: mount, extract, codesign removal (the old signatures fail validation on newer macOS), and install to `/Library/Image Capture/Devices`.

Everything runs through `hdiutil`, `pkgutil`, and `lpadmin` - no third-party dependencies.

## Quick start

Clone the repo and run two scripts:

```bash
# Printer (network/Bonjour)
cd printer-driver
./install_canon_mg6250_bonjour_network.sh

# Scanner (USB)
cd ../scanner-driver
./deploy_canon_scanner.sh
```

The printer script finds the device on the network automatically. The scanner requires a USB unplug/replug after install so that Image Capture picks up the new ICA bundle.

## Tested on

This has been verified on macOS Tahoe 26.3 (Apple Silicon) for both printing and scanning. The printer filters run under Rosetta 2 - if you haven't installed it yet, macOS will prompt you.

## Caveats

Classic PPD-based drivers are living on borrowed time. Apple and the CUPS project are moving toward driverless IPP Everywhere, and a future macOS release could drop PPD support entirely. For now, though, this gets a perfectly good multifunction printer back in service without buying new hardware.

The Canon DMGs are included in the repo for convenience but are Canon's software under Canon's license terms, not MIT. If you prefer, you can download them directly from [Canon's support site](https://www.canon-europe.com/support/consumer/products/printers/pixma/mg-series/pixma-mg6250.html?type=drivers&language=EN&os=macOS%2010.13%20(High%20Sierra)) and point the scripts at your copies.

Source: [aioue/canon-mg6250-mac-driver-bundle](https://github.com/aioue/canon-mg6250-mac-driver-bundle)
