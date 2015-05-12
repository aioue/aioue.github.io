---
layout: post
title: Turn off Synology LEDs
date: '2013-10-16 17:33:19'
---

<pre># Power LED off  
 echo \\6 &gt;/dev/ttyS1  
# Status LED off  
 echo \\7 &gt; /dev/ttysS1  
# Copy LED off  
 echo \\B &gt; /dev/ttyS1</pre>