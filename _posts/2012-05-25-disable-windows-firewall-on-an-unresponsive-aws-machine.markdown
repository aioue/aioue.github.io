---
layout: post
title: Disable Windows firewall on an unresponsive AWS machine
date: '2012-05-25 11:18:52'
---

Courtesy of AWS support  
  
**Stop Server and Detach Root Volume**  
  
In the AWS console, stop (don’t terminate!) the non-responsive server. Note that the properties for the server show that the instance has a drive attached to /dev/sda1. This is a Linux attach point but the concept should still apply.  
  
Also make note of the instance ID: _______________  
  
On the Volumes tab, detach the instance. You may need to refresh the pane after detaching in order to update the console UI. You may want to name this drive, in order to make it easy to keep track of.  
  
Attach Root Volume to the Debug Server  
  
Right click on the volume to attach it. Choose xvdg as the device name.  
  
**Fix the Problem**  
  
1.  Log in to the debug server.  
  
2.  Click on Start -&gt; Administrative Tools -&gt;Computer Management  
  
3.  Choose the Disk Management node, then right-click on Disk 1 (left-hand portion of that row) to bring the disk online. The disk will most likely appear as Drive E once you complete this step.  
  
4.  Use Windows Explorer to navigate to E:\Windows\System32\Config. (Careful! Not the C drive…) This directory contains the registry files that control, among other things, the network address. We’ll be working with the file that is named SYSTEM.  
  
5.  Click on Start -&gt; Run and start Regedit  
  
6.  To load the errant file, first click on HKEY_LOCAL_MACHINE  
  
---- if you need to adjust the firewall the registry key here is:  
  
HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\WindowsFirewall  
  
set to zero (0) for both Domain and Standard profiles  
  
7.  Next we need to load the file. Click on File -&gt; Load Hive, and then select SYSTEM in this directory  
  
8.  You’ll be asked to name the subkey to load the file into. Name it: BadDrive (or something else you choose0  
  
9.  Navigate to:  HKEY_LOCAL_MACHINE\BadDrive\ControlSet001\Services\Tcpip\Parameters\Interfaces\{9E9784DE-F79F-48BF-AF55-20DABCC88F0F} (Note that this is ControlSet001, not 002).  
  
10.  Delete all the keys that have anything to do with the static addresses. These are likely the IPAddress, DefautlGateway, and SubnetMask.  
  
11.  Also re-enable DHCP by setting the registry value to 1.  
  
12.  Save the changes by highlighting BadDrive and then choosing File -&gt;Unload Hive. Important! Your changes will not be saved unless you unload the hive.  
  
Detach the Drive  
  
We’re done with the repairs, so detach the drive from this instance. Make certain that Windows Explorer isn’t open and in the E drive, or you will not be able to detach the drive.  
  
1.  Back in Disk Manager, take the drive offline:  
  
2.  Detach the Volume in the AWS Console. You will likely need to refresh the console in order to make it recognize that you detached the volume.  
  
3.  And of course re-attach to the original instance. Enter /dev/sda1 as the device name.  
  
4.  Restart the Instance.  
  
5.  Copy the new DNS name, and log in via Remote Desktop. You may have to wait as long as 10 minutes after restart before RDP will connect. So do not panic if initial attempts time out.