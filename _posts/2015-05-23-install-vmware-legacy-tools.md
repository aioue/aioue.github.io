---
layout: post
title: Install VMware legacy tools
date: '2015-05-23 00:58:09'
---

VMware are moving away from the classic VMware tooling to `open-vm-tools`, available in most distros as standard. This is a Good Thing (tm).

If you need the legacy tools, attach the ISO in the UI, and then:

```shell
sudo mkdir /mnt/cdrom
sudo mount /dev/cdrom /mnt/cdrom
cp /mnt/cdrom/VMwareTools-* /tmp
tar xvf /tmp/VMwareTools-*
cd vmware-tools-distrib
sudo ./vmware-install.pl
```
