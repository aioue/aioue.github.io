---
layout: post
title: Can't install aws-sdk gem
date: '2013-03-08 13:58:55'
---

Error:  
```user@host:~$ sudo gem install aws-sdk
Building native extensions. This could take a while...
ERROR: Error installing aws-sdk:
ERROR: Failed to build gem native extension.
/usr/bin/ruby1.8 extconf.rb
checking for libxml/parser.h... no
-----
libxml2 is missing. please visit http://nokogiri.org/tutorials/installing_nokogiri.html for help with installing dependencies.  
```

Solve by installing the required libraries  

    $ apt-get install libxml2-dev libxslt1-dev
    
[Source](https://discussion.dreamhost.com/post-119253.html)
