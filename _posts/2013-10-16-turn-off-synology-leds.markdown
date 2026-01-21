---
layout: post
title: Turn off Synology LEDs
date: '2013-10-16 17:33:19'
---

```bash
# Power LED off
echo \\6 >/dev/ttyS1
# Status LED off
echo \\7 > /dev/ttyS1
# Copy LED off
echo \\B > /dev/ttyS1
```
