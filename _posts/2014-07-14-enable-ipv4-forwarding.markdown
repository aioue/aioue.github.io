---
layout: post
title: Enable ipv4 forwarding
date: '2014-07-14 13:24:43'
---

enable ipv4 forwarding (not permanent over reboots!)

`echo 1 > /proc/sys/net/ipv4/ip_forward`
