---
layout: post
title: Add second NIC with DHCP interface to VMware vCenter Server Appliance
date: '2014-09-24 16:25:05'
---

1.  Add the NIC to the box in the vCenter client  
2.  Reboot the box  
3.  SSH in  
4.  In [/etc/sysconfig/network/dhcp] change _DHCLIENT_HOSTNAME_OPTION_ from _AUTO_ to _*hostname*_ (e.g. foo.domain)  
5.  Copy [/etc/sysconfig/network/ifcfg-eth0] to ifcfg-eth1  
6.  Run ‘sudo /opt/vmware/share/vami/vami_config_net’. Set config for eth1 to DHCP  
7.  Run ‘service network restart’