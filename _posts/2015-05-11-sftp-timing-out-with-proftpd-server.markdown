---
layout: post
title: SFTP timing out with ProFTPD server
date: '2015-05-11 18:48:04'
---

Old version of ProFTPD doesn't support the default key exchange set so sftp was timing out.  
  
```Couldn't read packet: Connection reset by peer```  
  
On the proftpd logs:  
mod_sftp/0.9.8[6628]: message format error: unable to write 1025 bytes of mpint (buflen = 1023)  
mod_sftp/0.9.8[6628]: disconnecting (Application error)  
  
Client running verbose:  
debug1: SSH2_MSG_KEX_DH_GEX_REQUEST(1024&lt;8192&lt;8192) sent  
debug1: expecting SSH2_MSG_KEX_DH_GEX_GROUP  
Received disconnect from [...]: 11: Application error  
  
Server:  
debug1: SSH2_MSG_KEX_DH_GEX_REQUEST(1024&lt;7680&lt;8192) sent  
debug1: expecting SSH2_MSG_KEX_DH_GEX_GROUP  
  
Fix by changing the key exchange algorithm to something supported:  
sftp -oKexAlgorithms=diffie-hellman-group1-sha1 