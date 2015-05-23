---
layout: post
title: Install aptly with Ansible
date: '2015-05-23 01:13:21'
---

[aptly](http://www.aptly.info/) is the best thing to happen to debian repository management since sliced bread.

Plently of apps are not good enough in repo management land - they are often badly documented and difficult to set up. Repositories need to be simple and straightforward - they are a often a critical but lightweight component in a much larger infrastructure.

* [reprepro](https://mirrorer.alioth.debian.org/)
* [mini-dinstall](https://github.com/shartge/mini-dinstall)
* ftpsync
* debmirror

I wanted something that installed quickly, and was easy to install. aptly was halfway there with an available package and some **very** good documentation.

Want to spin it up on a box without having to fuss with gpg and trawl the API docs?

Use [this role](https://galaxy.ansible.com/list#/roles/3898) availble on [ansible-galaxy](https://galaxy.ansible.com/) and you'll be setup within in minutes. A suite of tests use simple curl requests to add packages to the repo, list existing packages and remove indiviual files to demonstrate the shniy new API.

It's [open source](https://github.com/smira/aptly). Thank [Andrey Smirnov](https://twitter.com/smira) for his excellent work.
