---
layout: post
title: Windows 11 IoT LTSC on Proxmox, unattended, with remote access and a privacy trim
date: '2026-11-19 08:00:00'
tags: [proxmox, windows, ansible, winrm, ovmf, tpm, homelab]
hidden: false
---

I keep one Windows VM for vendor tools that only ship as EXEs. It is Windows 11 IoT Enterprise LTSC 2024 (the evaluation edition, build 26100) on Proxmox. Ansible builds it on the Proxmox host, installs unattended, and a script on a CD turns on guest agent, WinRM and a privacy trim at first logon. This is what the build needed and what bit me.

## VM hardware

The hardware, roughly as the role sets it:

```bash
qm create 105 --name win-fw --machine q35 --bios ovmf --ostype win11 \
  --cores 4 --cpu host --memory 6144 \
  --efidisk0 fast-vms:1,efitype=4m,pre-enrolled-keys=1,ms-cert=2023k \
  --tpmstate0 fast-vms:1,version=v2.0 \
  --sata0 fast-vms:64,cache=none,discard=on,ssd=1 \
  --net0 e1000,bridge=vmbr0,link_down=1
```

- The install disk is SATA and the NIC is `e1000` because Setup has no VirtIO drivers. VirtIO comes later from `virtio-win.iso`.
- `cache=none`. I have no UPS, so no writeback.
- `link_down=1` stops Setup trying OneSettings over the network and failing with `0x80072EE7`. The Autounattend also sets `DynamicUpdate` to disabled. The role raises the link after install.
- Install ISO on `ide2`, Autounattend ISO on `ide0`.

## Autounattend

Build a small ISO containing `Autounattend.xml` (`genisoimage -J -r`) and attach it next to the installer. Things that bit me:

- `PlainText=false` does not mean "base64 of the UTF-16LE password". WSIM appends the literal word `Password` first. Both the LocalAccount and the AutoLogon `<Password>` need it:

  ```bash
  printf '%s' 'hunter2Password' | iconv -f UTF-8 -t UTF-16LE | base64
  ```

  The raw encoding makes Setup create the account and then fail with `0x8007000d`. oobeldr reports `0x8030000B` (exit 4), and the reboot then shows `0x8030000C`, which is the failed pass and not a second bug.
- The `oobeSystem` pass needs `Microsoft-Windows-International-Core`. WinPE locale settings alone leave OOBE asking for region and keyboard.
- Set `language="neutral"` on the components. `/IMAGE/INDEX` is `1` for this eval ISO.
- OVMF shows "Press any key to boot from CD or DVD" on a blank disk. If you miss it, BdsDxe says there is nothing bootable. A small host script sends a key with `qm sendkey` right after `qm start`.
- While the installer runs, boot order is `ide2;sata0`. A script watches the used size of the zvol and switches to `sata0;ide2;ide0` at 5 GiB so the reboot into the installed system never loops back to the CD.

The last piece is a `FirstLogonCommands` entry that registers a scheduled task:

```xml
<CommandLine>powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\cm642-firstlogon.ps1</CommandLine>
```

The scripts reach `C:\Windows\Setup\Scripts` from the `$OEM$` folder on the Autounattend ISO.

## The seed task

The task runs at logon and at startup, every two minutes for two hours, as the admin account with highest privileges. Each run looks for a CD carrying `ENABLE-REMOTE.ps1` and `virtio-win-gt-x64.msi`, and exits quietly if either is missing. So the order of things does not matter: the watch script attaches both ISOs when the install is far enough along, and the next tick does the work. When the script finishes it writes `C:\Users\Public\cm642-remote-ready.txt`, and later runs exit at once.

`ENABLE-REMOTE.ps1` does three things.

1. Installs `virtio-win-gt-x64.msi`. Copy it off the CD first, because `msiexec` returns 1619 when run straight from the drive. The guest tools matter more than the QEMU guest agent MSI alone: that MSI starts the `QEMU-GA` service, but without the `vioserial` driver it cannot talk to Proxmox. The gt package installs both.
2. Marks the network Private and turns on WinRM:

   ```powershell
   Enable-PSRemoting -Force -SkipNetworkProfileCheck
   New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System `
     -Name LocalAccountTokenFilterPolicy -PropertyType DWord -Value 1 -Force
   Get-NetFirewallRule -Name WINRM-HTTP-In-TCP | Set-NetFirewallRule -RemoteAddress 192.168.1.0/24
   ```

   `LocalAccountTokenFilterPolicy=1` is what lets a local admin over NTLM get an elevated token. The firewall change limits port 5985 to the LAN.
3. The privacy trim below.

## Ansible over WinRM

```yaml
# host_vars/<vm hostname>.yml
ansible_connection: winrm
ansible_user: fwadmin
ansible_password: "{{ windows_iot_fwadmin_password }}"
ansible_port: 5985
ansible_winrm_transport: ntlm
ansible_winrm_scheme: http
ansible_winrm_server_cert_validation: ignore
```

The controller needs `pywinrm`. I have not moved the VM's configuration into Ansible tasks yet. For now the connection is used for ad-hoc work, and I have driven the seed script through it with pywinrm.

## Resolution

Nothing in the guest sets it. The size comes from QEMU, through two device properties that Proxmox has no option for (virtio-vga defaults to 1280x800):

```bash
qm set 105 --vga virtio,memory=32
qm set 105 --args "-global virtio-vga.xres=1920 -global virtio-vga.yres=1080"
```

`qm showcmd 105` shows both `-global` lines, and the live device agrees:

```bash
echo "info qtree" | qm monitor 105 | grep -A3 'virtio-vga'
#   edid = true
#   xres = 1920 (0x780)
#   yres = 1080 (0x438)
```

The device has EDID on, and the guest shows `Red Hat VirtIO GPU DOD controller` (from `virtio-win-gt`, version 100.103.104.30200) running at 1920x1080 with no logon script involved. The `std` VGA is used while Setup runs, because Setup has no virtio display driver. The settings only apply after a stop and start, not a reboot.

The role also has a `Set-DisplayResolution.ps1` that calls `ChangeDisplaySettings`. Nothing runs it, and the guest has no `set-display.log` and no scheduled task for it. I did not need it.

## The privacy trim

IoT LTSC already ships without the Store apps, Copilot, Teams and the other consumer packages. I looked at what [tiny11builder](https://github.com/ntdevlabs/tiny11builder) removes from a consumer image and kept the parts that still apply here: registry policies and scheduled tasks. Nothing is deleted and no component is removed, so it is reversible. tiny11's hardware-check bypasses do nothing here, because the VM already has TPM 2.0 and Secure Boot (both read back from the guest). The only provisioned Appx package on this image is Edge, so there is little for its package removal to do either. It is appended to `ENABLE-REMOTE.ps1` after the ready marker, and every step goes through a wrapper that logs and carries on:

```powershell
function Invoke-Step {
    param([string]$Name, [scriptblock]$Action)
    try {
        $ErrorActionPreference = 'Stop'   # function scope: non-terminating errors become catchable
        & $Action
        Write-Log "debloat ok: $Name"
    }
    catch {
        Write-Log "debloat FAILED: $Name :: $($_.Exception.Message)"
    }
}
```

The ready marker is written first, so a failure here cannot undo the WinRM setup. The `Stop` line makes non-terminating cmdlet errors catchable, so a partial failure is logged as FAILED and not as ok.

What it sets:

| Item | Change |
|------|--------|
| Telemetry | `DataCollection\AllowTelemetry=0` (honoured on Enterprise), `DiagTrack` and `dmwappushservice` stopped and disabled |
| CEIP | `SQMClient\Windows\CEIPEnable=0`, and the CEIP, Compatibility Appraiser, `Autochk\Proxy` and WER `QueueReporting` tasks disabled |
| Consumer content | `CloudContent`: `DisableWindowsConsumerFeatures`, `DisableConsumerAccountStateContent`, `DisableCloudOptimizedContent` all `1`, plus the `ContentDeliveryManager` values at `0` |
| Advertising ID | `AdvertisingInfo\DisabledByGroupPolicy=1` and the per-user `Enabled=0` |
| Ink and input harvesting | `InputPersonalization` restrictions, `HarvestContacts=0`, `Input\TIPC\Enabled=0` |
| Chat and Teams | `Windows Chat\ChatIcon=3`, Teams `DisableInstallation=1`, `TaskbarMn=0` |
| Push-to-install | `PushToInstall\DisablePushToInstall=1` |
| OneDrive | `OneDrive\DisableFileSyncNGSC=1`, and the `OneDriveSetup` Run value removed if present |
| Reserved storage | `dism /Online /Set-ReservedStorageState /State:Disabled` |

I ran it on the installed VM and read the state back: the policy values were set, `DiagTrack` and `dmwappushservice` were stopped and disabled, the named tasks showed `Disabled`, `dism /Get-ReservedStorageState` said "Reserved storage is disabled", and QEMU-GA and WinRM stayed up.

Things the run showed:

- The HKCU values land in whichever account runs the script. The seed runs as the admin account, which is the one I use. Over WinRM it is that user's profile, not the machine default.
- There is no `Chkdsk\Proxy` task on 26100. The CEIP disk-info one is `Autochk\Proxy`, and a typo here fails silently because the lookup uses `-ErrorAction SilentlyContinue`. `ProgramDataUpdater` does not exist on this build either.
- For reserved storage I used `dism.exe` because it gives a plain exit code to log and `/Get-ReservedStorageState` reads the result back. I did not test the PowerShell cmdlet.
- Take a `qm snapshot` before testing a change like this, and delete it afterwards.

## Rebuilding

The rebuild path stops the VM, recreates the disk and EFI vars, attaches both ISOs and sends the boot key. After the install passes 12 GiB the watch script detaches the installer, attaches `virtio-win.iso` and the tools ISO, and the seed task does the rest. Editing the seed script means rebuilding the tools ISO and remounting it, which is what the role's `windows-iot-seed` tag does.
