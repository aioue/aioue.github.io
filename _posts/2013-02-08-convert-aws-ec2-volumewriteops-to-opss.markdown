---
layout: post
title: Convert AWS EC2 VolumeWriteOps to Ops/s
date: '2013-02-08 18:57:41'
---

When looking at the volume monitoring tab in EC2 you'll see write throughput measured in ops/s. In CloudWatch however you are given VolumeWriteOps, and it's not immediately obvious that this is per minute.    
  
To convert to average per second ops, divide by 60.  
  
![AWS dashboard interface showing Ops/s graph](/content/images/2015/05/cloudwatch-management-console-google-chrome_2013-02-08_15-11-02-1.png)