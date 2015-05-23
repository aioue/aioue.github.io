---
layout: post
title: Use the aptly REST API with curl
date: '2015-05-23 01:56:35'
---

[aptly](http://www.aptly.info/) is good. Very good. If you've [got it installed](http://aioue.net/2015/05/23/install-aptly-with-ansible.html), use the REST API to get your work done.


* add package to an aptly repo

  Given a package called `apackage.deb` and repo `arepo` that we've got on the aptly server itself for convenience, let's get that up onto our aptly repo using the API.

  * upload a local file to aptly's staging area

    `curl -v -X POST -F file=@apackage.deb http://localhost:8080/api/files/apackage`

  * import everything in that directory to a local repo

      `curl -v -X POST http://localhost:8080/api/repos/arepo/file/apackage`

  * update the published repo from the local repo

    `curl -v -X PUT -H 'Content-Type: application/json' --data '{}' http://localhot:8080/api/publish/arepo/trusty`

* remove package from an aptly repo

  * list packages named apackage with their keys in a repo (remove ?q=[..] to list all packages)

    `curl http://localhost:8080/api/repos/arepo/packages?q=apackage`

  * delete package from repo by key

    `curl -X DELETE -H 'Content-Type: application/json' --data '{"PackageRefs": ["Pall apackage 0.1.0 ebcaf7a13cb11e2e"]}' http://localhost:8080/api/repos/arepo/packages`

  * update published repo

    `curl -X PUT -H 'Content-Type: application/json' --data '{}' http://localhost:8080/api/publish/arepo/trusty`
