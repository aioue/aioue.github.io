---
layout: post
title: Install VMware deployPkg
date: '2015-05-23 01:01:17'
---

deployPkg is sometimes needed for guest customization and is missing from `open-vm-tools` for no good reason.

[The raw files are located here.](http://packages.vmware.com/packages/ubuntu/dists/trusty/main/binary-amd64/index.html)

Import the VMware packaging public keys, add their (slow as molasses) repo to the repo list and install the package.

```shell

mkdir keys
cd keys
wget http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-DSA-KEY.pub
wget http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub
sudo apt-key add VMWARE-PACKAGING-GPG-DSA-KEY.pub
sudo apt-key add VMWARE-PACKAGING-GPG-RSA-KEY.pub
touch /etc/apt/sources.list.d/vmware-tools.list
echo deb http://packages.vmware.com/packages/ubuntu precise main > /etc/apt/sources.list.d/vmware-tools.list
sudo apt-get update
sudo apt-get install open-vm-tools-deploypkg
```
