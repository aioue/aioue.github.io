---
layout: post
title: Upgrade Cisco IOS and ASDM from Ubuntu Linux
date: '2013-10-11 18:54:06'
---

Make sure PC can ping (or contact) ASA.
Install tftpd-hpa (defaults work fine, but conf is /etc/default/tftpd-hpa)
Run it:

```bash
/usr/sbin/in.tftpd --listen --user tftp --address 0.0.0.0:69 --secure /var/lib/tftpboot
```

Copy files to /var/lib/tftpboot directory (asa831-k8.bin, adsm-631.bin etc)

Add IP of ASA to iptables.conf and run it to let traffic from the ASA through.
Example IP tables line:

```bash
$IPTABLES -A INPUT -s 192.168.1.1 -j ACCEPT
```

Optionally test by installing tftp and tftp localhost.

On ASA:

```
copy tftp: flash:
```

enter IP, source and destination file name and wait for copy
repeat for second file (IOS or ASDM)

optional verify:

```
verify flash:/<file>
```

To install, go to global configure:

```
adsm image disk0:/adsm<version>
boot system disk0:/asa<version>
copy run start
reload
```
