---
layout: post
title: Run Windows 8 from an encrypted external USB drive on your Macbook Pro
date: '2013-04-12 16:11:49'
---

I need windows for work and gaming and I didn't want to give up space to bootcamp on my internal drive so I installed Windows on an external USB drive by doing this:  
  
1.  <span style="line-height:14px;">Find or create a Windows 8 Enterprise computer.</span>  
2.  Get a desktop/laptop SSD drive (I used a 128GB Samsung 830) and plug it in via USB.  
3.  Install Windows To Go on the SSD drive from the Windows 8 Enterprise computer. Optionally select whether you would like the drive encrypted using BitLocker full disk encryption.  
4.  When installed, plug the USB cable into your MacBook and hold option down when you hear the boot noise until it shows you some boot options.  
5.  Choose the Windows partition and boot it. It will talk about preparing for the first time and you'll have to reboot again into Windows.  
6.  The screen will be totally screwed up (Late 2012 rMBP), trust yourself and log into Windows (one keypress to show the login screen, then type your user and pass as normal).  
7.  Right click in the thin sliver of screen and choose the screen resolution option.  
8.  Using the top of the window, move the visible part of the window left until you can see the resolution slider. Slide it to something much lower like 1280*1024 and apply it.  
9.  Ok, so screen is visible, now time for some drivers.  
10.  [Download the latest Boot Camp Support Software](http://www.apple.com/support/bootcamp/ "Boot Camp Support Software") from Apple. Copy it to something and then onto the Windows To Go install.  
11.  Run the installer to install all the drivers.  
12.  Activate Windows.  
13.  Reboot and set the resolution up to maximum.  
14.  Enjoy.  
Windows 8 looks terrible on the Retina display - far too small but you can adjust the text size up a bit. Gaming works fine, I've played XCOM and Portal 2 over USB2.  
  
_EDIT: _Have upgraded to an [Anker USB 3.0 to SATA Adapter Cable](http://www.amazon.co.uk/Anker%C2%AE-Uspeed-Converter-Adapter-External/dp/B006J2L0ZM/) and now get hundreds of MB/second transfer speed. As fast as an internal drive.  
  
Any questions please comment. Like if the solution worked for you.