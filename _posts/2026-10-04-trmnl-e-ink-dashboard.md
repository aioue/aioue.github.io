---
layout: post
title: TRMNL e-ink dashboard
date: '2026-10-04 01:00:00'
tags: [homelab, gadgets]
hidden: false
---

I have a TRMNL OG and a TRMNL X on my desk. Both are e-paper dashboards from [usetrmnl.com](https://usetrmnl.com). They refresh on a schedule and do not ping me like a phone. I wanted a screen I could read without another notification surface in the room.

TRMNL has a plugin marketplace and a private-plugin webhook. You POST JSON, they render it on the device. I already run small pollers on the homelab for similar jobs. Battery and firmware show up in Home Assistant through their integration.

For todos I run [anydown](https://aioue.net/2026/03/22/anydown-backup-any-do-tasks/) on Proxmox to back up Any.do. A Python sidecar polls that backup and POSTs a short task list to a TRMNL private plugin. The OG cycles through due items while I am at the desk.

If you want one, my referral link: https://trmnl.com?ref=tom10 (disclosure: I get credit if you buy through it).
