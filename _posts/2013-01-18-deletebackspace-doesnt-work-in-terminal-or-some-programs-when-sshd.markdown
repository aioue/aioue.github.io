---
layout: post
title: Delete/backspace doesn't work in terminal or some programs when SSH'd
date: '2013-01-18 19:39:38'
---

Encountered during an [OSSEC](http://www.ossec.net) install - when pressing delete, `^H` is printed instead.  
  
Fix:  
  
1. Press CTRL-v and then hit backspace. You'll see what code is sent as "erase". `^H` 
2. Type `stty erase ^H` to change the key setup.  
  
That's it.  
  
Source: [Macworld](http://hints.macworld.com/article.php?story=20040930002324870).