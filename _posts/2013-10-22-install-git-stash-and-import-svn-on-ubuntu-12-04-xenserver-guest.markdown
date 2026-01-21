---
layout: post
title: Install Git, Stash and import SVN on Ubuntu 12.04 XenServer guest
date: '2013-10-22 11:02:12'
---

### Goal

Install Git and Atlassian Stash (backed by PostgreSQL) on Ubuntu 12.04 and import an SVN repo without the normal branch format (i.e. just versioned files, no branch tags etc).

### Setup machine

- Install a new linux box - Ubuntu Server 12.04.3 LTS and select OpenSSH server component during install to enable remote access
- Install XenServer tools - load ISO in XenCenter, then mount it and install the software:

```bash
mkdir /mnt/xs-tools
mount /dev/xvdd /mnt/xs-tools
/mnt/xs-tools/Linux/install.sh
```

- Reboot, then update the system packages:

```bash
sudo apt-get -y update && sudo apt-get -y upgrade
```

### Install a new version of Git

- Add a remote PPA since 12.04.3 current only ships with an older version of Git (1.7.9.5-1)

Enable add-apt-repository for Ubuntu >= 12.10

```bash
sudo apt-get install software-properties-common
```

Enable add-apt-repository for Ubuntu <= 12.04

```bash
sudo apt-get install python-software-properties
```

- Add the Git PPA

```bash
sudo add-apt-repository ppa:git-core/ppa
sudo apt-get update
sudo apt-get install git
```

### Install Java 7 (Stash pre-requisite)

- [Install Java 7 and configure environment variables](http://www.webupd8.org/2012/01/install-oracle-java-jdk-7-in-ubuntu-via.html)

```bash
sudo add-apt-repository ppa:webupd8team/java
sudo apt-get-update
sudo apt-get install oracle-java7-installer
# set this version as default (java -version)
sudo apt-get install oracle-java7-set-default
```

### Install PostgresSQL (Stash external database)


```bash
sudo apt-get install postgresql
sudo vim /etc/postgresql/9.1/main/postgresql.conf
```

Uncomment the following line so server listens for local connections

```
listen_addresses = 'localhost'
```

- If access needed remotely above should be set to '*' and then modify pg_hba.conf to allow external connections

```bash
vim /etc/postgresql/9.1/main/pg_hba.conf
# allow all hosts on this subnet to access the DB
host all all x.x.x.x/x md5
```

where x.x.x.x/x is your network range and subnet mask.

- Create PostgreSQL user

```sql
sudo -u postgres psql postgres
\password postgres
# set password
CREATE ROLE stashuser WITH LOGIN PASSWORD '<password>' VALID UNTIL 'infinity';
CREATE DATABASE stash WITH ENCODING='UTF8' OWNER=stashuser CONNECTION LIMIT=-1;
# Quit
\q
```

- [Atlassian recommend that you should not locate your Stash home directory inside the install directory](https://confluence.atlassian.com/display/STASH/Stash+home+directory).

```bash
sudo mkdir -p /var/stash/install
sudo mkdir /var/stash/home
```

- Secure stash home dir with separate user

```bash
adduser stashadmin
cd /var/stash/install
sudo wget http://www.atlassian.com/software/stash/downloads/binary/atlassian-stash-2.8.2.tar.gz
sudo tar xvf atlassian-stash-2.8.2.tar.gz
```

- Set stash home in setenv.sh to /var/stash/home.


```bash
sudo vim atlassian-stash-2.8.2/bin/setenv.sh
sudo chown -R stashadmin /var/stash
atlassian-stash-2.8.2/bin/start-stash.sh
```

- Navigate to the URL displayed and configure Stash.

### Install svn2git


```bash
sudo apt-get install git-core git-svn ruby rubygems
```

- Once you have the necessary software your system, you can install svn2git through rubygems, which will add the svn2git command to your PATH.

```bash
sudo gem install svn2git
svn2git https:/// --rootistrunk --authors ~/authors.txt --username  --verbose
```

- Output doesn't render properly on my machine - I have to accept the remote certificate once, then run the command again and and type the remote repo user's password before I can actually see the prompt.
- Wait for import to complete.
- Create project and repo in Stash.
- Follow on-screen instructions for configuring Git for the first time and pushing the converted repo to Stash (copied below).

### Configure Git for the first time


```bash
git config --global user.name "Name"
git config --global user.email "email@domain"
```

### Push code to Git (Stash repository)


```bash
git init
git add --all
git commit -m "Initial Commit"
git remote add origin http://<username>@<host>:7990/scm/<stash project>/<stash git repo>.git
git push origin master
```
