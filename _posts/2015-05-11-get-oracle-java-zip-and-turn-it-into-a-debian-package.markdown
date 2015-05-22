---
layout: post
title: Get Oracle Java zip and turn it into a debian package
date: '2015-05-11 18:48:28'
---

* get JRE/JDK from Oracle's site  
*  rename its extension to 'tar.gz'  
* install java-package  
  `sudo apt-get install java-package`
* build a .deb file
  `fakeroot make-jpkg server-jre-8u40-linux-x64.tar.gz`
