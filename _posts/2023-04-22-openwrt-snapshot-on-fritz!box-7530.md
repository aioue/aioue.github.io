---
layout: post
title: OpenWrt Snapshot on FRITZ!Box 7530
date: '2023-04-22 21:45:00'
---

**Install OpenWrt 22.03.4 release on FRITZ!Box 7530, then sysupgrade to SNAPSHOT to enable the VRX518 VDSL modem.**

**Client machine:** Mac OS X, 12.5.1, Monterey
**Snapshot target:** (r22618-21be2c26d5) @ 2023-04-22

## Install OpenWrt Release build

[Follow standard install guide](https://openwrt.org/toh/avm/avm_fritz_box_7530) for the latest supported release version, including DSL modem firmware commands.<br/>

Prepare the files on your client, following the TFTP process.

At the TFTP section, follow [TFTP on OS X](https://rick.cogley.info/post/run-a-tftp-server-on-mac-osx/) guide.<br/>
```
sudo launchctl load -F /System/Library/LaunchDaemons/tftp.plist
sudo cp FRITZ7530.bin /private/tftpboot
```

## Once OWRT installed successfully, install latest SNAPSHOT build

Use the OpenWrt [Firmware Selector](https://firmware-selector.openwrt.org/), picking your model and `SNAPSHOT` build

Snapshots, don't come with LUCI GUI, so expand `Customize installed packages`, adding `luci luci-ssl` to the end of the list of `Installed Packages`.

Click `Request Build`, and when complete, download the `SYSUPGRADE` image. Make a note of the sha256sum on the download page.

Follow the [LuCI upgrade process](https://openwrt.org/toh/avm/avm_fritz_box_7530), or SCP the sysupgrade file to `/tmp/` and run a sysupgrade. **ALL CONFIG SETTINGS WILL BE LOST WITH THIS METHOD**
```
sysupgrade -n openwrt-<foo>.bin
```

## Zen Internet UK FTTC, PPPoE IPv4 & IPv6, and Cloudflare DNS settings

1. Create a new VLAN (802.1q) device on base device of `dsl0`

    - `VLAN ID` of `101`
    - `MTU` of `1500`
    - Enable IPv6

1. Configure `DSL` tab

    - `Annex B (all)`
    - Tone `auto`
    - Encapsulation `PTM`
    - DSL line mode `VDSL`

1. Edit the `wan` interface

    - Protocol `PPPoE`
    - Device `dsl0.101`
    - Add username and password
    - Add DNS servers in `Advanced Settings` tab

## Raw Config Output

```
root@OpenWrt:~# cat /etc/config/network

config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config globals 'globals'
	option ula_prefix 'foo::/48'

config dsl 'dsl'
	option annex 'b'
	option line_mode 'vdsl'
	option ds_snr_offset '0'
	option xfer_mode 'ptm'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'lan1'
	list ports 'lan2'
	list ports 'lan3'
	list ports 'lan4'

config interface 'lan'
	option device 'br-lan'
	option proto 'static'
	option ipaddr '192.168.1.1'
	option netmask '255.255.255.0'
	option ip6assign '60'

config device
	option name 'dsl0'
	option macaddr 'foo'
	option mtu '1500'

config interface 'wan'
	option device 'dsl0.101'
	option proto 'pppoe'
	option username 'foo'
	option password 'bar'
	option ipv6 'auto'
	option peerdns '0'
	list dns '1.1.1.1'
	list dns '1.0.0.1'

config interface 'wan6'
	option device '@wan'
	option proto 'dhcpv6'
	option reqaddress 'try'
	option reqprefix 'auto'
	list dns '2606:4700:4700::1111'
	list dns '2606:4700:4700::1001'
	list dns '2001:4860:4860::8888'
	list dns '2001:4860:4860::8844'

config device
	option type '8021q'
	option ifname 'dsl0'
	option vid '101'
	option name 'dsl0.101'

config device
	option name 'pppoe-wan'
	option mtu '1500'
	option mtu6 '1280'
```


## Enable Smart Queue Management (SQM) to eliminate bufferbloat
 
[Bufferbloat mitigation](https://openwrt.org/docs/guide-user/network/traffic-shaping/sqm)


   
