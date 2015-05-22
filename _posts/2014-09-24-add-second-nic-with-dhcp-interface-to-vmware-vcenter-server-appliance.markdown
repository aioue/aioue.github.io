---
layout: post
title: Add second NIC with DHCP interface to VMware vCenter Server Appliance
date: '2014-09-24 16:25:05'
---

1.  Add the NIC to the box in the vCenter client  
1.  Reboot the box  
1.  SSH in  
1.  In `[/etc/sysconfig/network/dhcp]` change `DHCLIENT_HOSTNAME_OPTION` from `AUTO` to `hostname` (e.g. foo.domain)  
1.  Copy `[/etc/sysconfig/network/ifcfg-eth0]` to `ifcfg-eth1`  
1.  run `sudo /opt/vmware/share/vami/vami_config_net` and set config for eth1 to DHCP  
1. `service network restart`
