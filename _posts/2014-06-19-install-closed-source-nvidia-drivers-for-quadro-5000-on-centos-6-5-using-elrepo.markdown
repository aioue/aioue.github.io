---
layout: post
title: Install closed source nVidia drivers for Quadro 5000 on CentOS 6.5 using ELRepo
date: '2014-06-19 19:14:19'
---

<pre>rpm --import http://elrepo.org/RPM-GPG-KEY-elrepo.org    
rpm -Uvh http://elrepo.org/elrepo-release-6-6.el6.elrepo.noarch.rpm    
yum install kmod-nvidia    
reboot</pre>  
  
That's it. nVidia settings will be in the admin menu and glxgears (simple 3D test) will run nice and smooth.