---
layout: post
title: Update/upgrade Dell PowerEdge Server firmware under XenServer 6.2
date: '2013-09-18 17:10:46'
---

Run these command on all of your host machines. Don't reboot the pool master if using pools - change it to a machine that has already rebooted and settled before rebooting the original master.  
<pre>wget -q -O - http://linux.dell.com/repo/hardware/latest/bootstrap.cgi | bash    
yum install -y dell_ft_install    
yum install -y $(bootstrap_firmware)    
update_firmware --yes</pre>  
  
[Source](http://neil.spellings.net/2012/03/03/updating-dell-firmware-from-within-xenserver-dom0/ "Source")  
  
[Source](http://linux.dell.com/wiki/index.php/Repository/firmware#Downloading_firmware "Source")