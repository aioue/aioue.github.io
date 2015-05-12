---
layout: post
title: XenServer 6.2 iSCSI won't connect to Synology 4.3
date: '2013-09-24 17:38:27'
---

When attaching an iSCSI LUN to a XenServer pool - only the master connects and the rest remain unplugged.  
  
Make sure your iSCSI target is set up to accept multiple connections on the Synology settings page.  
  
If the storage fails to attatch following that, turn off chap discovery:  
  
[http://1bitatatime.blogspot.de/2011/08/initiator-error-0201-and-xenserver.html?m=1](http://1bitatatime.blogspot.de/2011/08/initiator-error-0201-and-xenserver.html?m=1)  
  
This will work until reboot.