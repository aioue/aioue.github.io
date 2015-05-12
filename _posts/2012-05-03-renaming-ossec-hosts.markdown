---
layout: post
title: Renaming OSSEC hosts
date: '2012-05-03 10:58:18'
---

OSSEC hosts can be centrally renamed by editing the `etc/client-keys` file.  
  
However, since the client key also contains the host name the client will use, the keys must be re-extracted using `manage-agents` and the keys imported into the existing client installs.  
  
This is only a small time-saving over removing and re-adding a client but less prone to human error.  
  
_Edit:_  
This also works for changing OSSEC host IPs. Simply update them in the keys file and restart the agent and client and they will reconnect.