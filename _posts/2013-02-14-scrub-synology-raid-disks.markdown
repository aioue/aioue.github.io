---
layout: post
title: Scrub Synology RAID disks
date: '2013-02-14 11:23:47'
---

_UPDATE 2014-09-25:_ fsck command updated for Synology DSM 5.  

### Scrub  

Unlike many modern storage devices, Synology DiskStation/RackStation NAS boxes never run fsck or scrub their disks. Not regularly scrubbing (reading all sectors) of your disks could allow data to be written to failing areas and eventually cause data corruption. You can see if there have been inconsistent writes by running the following after logging in as admin via SSH:  

    echo check > /sys/block/md[x]/md/sync_action

where _[x]_ is the array you want to check (the first array on an RS3412xs is md2). This may take a few hours depending on the size of your array and disk speed and the progress can be checked in the disk manager in the web UI. After, check the mismatched block count (where data on 1 or more of the disks doesn't match its counterparts).

    cat /sys/block/md[x]/md/mismatch_cnt

To fix these errors (in a naive way, md isn't clever about which block it decides is correct from a disk group), run  

    echo repair > /sys/block/md[x]/md/sync_action

A further check afterwards will reset the mismatch count to zero if no more errors have crept in in the meanwhile. Running a repair regularly will cause all blocks to be read, potentially catching failing disk areas and causing them to be safely remapped before they become a problem. The scrub has the added benefit (vs fsck) of allowing your Synology to remain online and the services available while it happens. Errors for the all the individual disks can been displayed with  

    cat /sys/block/md[x]/md/rd?/errors

If these regularly rise after a sync, consider replacing the disk.  

### Fsck  

Commands for performing an offline fsck (SSH as root):  
```
syno_poweroff_task -d  

# if you have volume group devices use these 2 lines:
vgchange -ay
fsck.ext4 -yvf -C0 /dev/vg1000/lv  

# OR  

# if you have simple software raid devices:
fsck.ext4 -pvf -C0 /dev/md[x]  

reboot
```
The poweroff task (with debug switch to keep it from shutting down SSH) performs some unmounts (volume 1 etc.). Then you perform the usual Linux fsck.  

I have a simple setup with 'mount' run before syno_poweroff_task showing '/dev/md2 on /volume1 type ext4'. People with volume groups will need to enable the volume with vgchange and then run the second commented command against whatever device their Synology is mounting.  

If you have questions or corrections please comment.

[Source](http://www.cyberciti.biz/faq/synology-complete-fsck-file-system-check-command/)  
[Source - Synology forums: fsck with debug](http://forum.synology.com/enu/viewtopic.php?f=39&amp;t=83186#p339475)  
[Source - fsck from Synology support](http://forum.synology.com/enu/viewtopic.php?f=7&amp;t=88997)
