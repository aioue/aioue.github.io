---
layout: post
title: Manually Install XenServer 6.2.0 Service Pack 1
date: '2014-01-27 14:00:30'
---

1. [Download the file from Citrix](http://support.citrix.com/article/CTX139788)  
1. Unpack the zip and copy the files to the root home dir on your machine  
1. SSH in and type
`xe patch-upload file-name=XS62ESP1.xsupdate`
1. Wait a few mins and it'll spit out a UUID when it's done. Use this for the next command.
`xe patch-apply uuid=0850b186-4d47-11e3-a720-001b2151a503 host-uuid=5b280513-bfcf-4ce0-9d49-25aa61c110d9`

 The host-UUID which helpfully tab-completed on my system. You can also find this in the XenCenter management UI.
