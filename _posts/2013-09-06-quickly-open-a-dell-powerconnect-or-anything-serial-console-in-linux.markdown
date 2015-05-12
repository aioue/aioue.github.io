---
layout: post
title: Quickly open a Dell PowerConnect (or anything) serial console in Linux
date: '2013-09-06 00:07:55'
---

Find your serial port(s)  
<pre>dmesg | grep tty</pre>  
  
You'll see...  
<pre>[   37.531286] serial8250: ttyS0 at I/O 0x3f8 (irq = 4) is a 16550A  
[   37.531841] 00:0b: ttyS0 at I/O 0x3f8 (irq = 4) is a 16550A  
[   37.532138] 0000:04:00.3: ttyS1 at I/O 0x1020 (irq = 18) is a 16550A</pre>  
  
Looks like one at ttyS0. Access it using  
<pre>screen /dev/ttyS0</pre>  
  
...and you're in. 'screen' also takes a baud rate (such as 19200) if needed.