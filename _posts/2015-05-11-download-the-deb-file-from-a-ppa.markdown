---
layout: post
title: Download a deb file from a PPA
date: '2015-05-11 19:05:50'
---

haproxy example  
<pre>add-apt-repository ppa:vbernat/haproxy-1.5  
apt-get update  
apt-get clean  
apt-get --download-only install haproxy</pre>  
File is available at  
<pre>/var/cache/apt/archives/haproxy_1.5.11-1ppa1~trusty_amd64.deb</pre>