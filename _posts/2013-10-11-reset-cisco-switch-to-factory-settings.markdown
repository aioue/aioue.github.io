---
layout: post
title: Reset Cisco switch to factory settings
date: '2013-10-11 18:51:41'
---

###### Reset Cisco switch to factory settings
```
enable  
config  
config factory-settings  
copy run start  
reload
```
###### show IOS version  
    show version
###### show all file systems  
    show file system
###### show files on file system  
    show (flash0|disk0 etc):