---
layout: post
title: Install closed source nVidia drivers for Quadro 5000 on CentOS 6.5 using ELRepo
date: '2014-06-19 19:14:19'
---

```shell
rpm --import http://elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://elrepo.org/elrepo-release-6-6.el6.elrepo.noarch.rpm
yum install kmod-nvidia
reboot
```  

nVidia settings will be available in the admin menu and glxgears (a simple 3D test app) will run smoothly.
