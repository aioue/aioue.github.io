---
layout: post
title: Upgrade Cisco IOS and ASDM from Ubuntu Linux
date: '2013-10-11 18:54:06'
---

Make sure PC can ping (or contact) ASA.  
Install tftpd-hpa (defaults work fine, but conf is /etc/default/tftpd-hpa)  
Run it:  
<pre># /usr/sbin/in.tftpd --listen --user tftp --address 0.0.0.0:69 --secure /var/lib/tftpboot</pre>  
Copy files to /var/lib/tftpboot directory (asa831-k8.bin, adsm-631.bin etc)  
  
Add IP of ASA to iptables.conf and run it to let traffic from the ASA through.  
Example IP tables line:  
<pre>$IPTABLES -A INPUT -s 192.168.1.1 -j ACCEPT</pre>  
Optionally test by installing tftp and tftp localhost.  
  
On ASA:  
<pre># copy tftp: flash:</pre>  
enter IP, source and destination file name and wait for copy  
repeat for second file (IOS or ASDM)  
  
optional verify:  
<pre># verify flash:/&lt;file&gt;</pre>  
To install, go to global configure:  
<pre># adsm image disk0:/adsm&lt;version&gt;  
# boot system disk0:/asa&lt;version&gt;  
# copy run start  
# reload</pre>