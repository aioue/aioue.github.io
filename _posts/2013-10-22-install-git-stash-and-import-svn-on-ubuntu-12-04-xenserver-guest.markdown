---
layout: post
title: Install Git, Stash and import SVN on Ubuntu 12.04 XenServer guest
date: '2013-10-22 11:02:12'
---

### Goal  
  
Install Git and Atlassian Stash (backed by PostgreSQL) on Ubuntu 12.04 and import an SVN repo without the normal branch format (i.e. just versioned files, no branch tags etc).  
  
### Setup machine  
  
- Install a new linux box - Ubuntu Server 12.04.3 LTS and select OpenSSH server component during install to enable remote access  
- Install XenServer tools - load ISO in XenCenter, then mount it and install the software:  
<pre>mkdir /mnt/xs-tools  
mount /dev/xvdd /mnt/xs-tools  
/mnt/xs-tools/Linux/install.sh</pre>  
- Reboot, then update the system packages:  
<pre>sudo apt-get -y update &amp;&amp; sudo apt-get -y upgrade</pre>  
  
### Install a new version of Git  
  
- Add a remote PPA since 12.04.3 current only ships with an older version of Git (1.7.9.5-1)  
  
Enable add-apt-repository for Ubuntu &gt;= 12.10  
<pre>sudo apt-get install software-properties-common</pre>  
Enable add-apt-repository for Ubuntu &lt;= 12.04  
<pre>sudo apt-get install python-software-properties</pre>  
- Add the Git PPA  
<pre>sudo add-apt-repository ppa:git-core/ppa  
sudo apt-get update  
sudo apt-get install git</pre>  
  
### Install Java 7 (Stash pre-requisite)  
  
- [Install Java 7 and configure environment variables](http://www.webupd8.org/2012/01/install-oracle-java-jdk-7-in-ubuntu-via.html)  
<pre>sudo add-apt-repository ppa:webupd8team/java  
sudo apt-get-update  
sudo apt-get install oracle-java7-installer  
# set this version as default (java -version)  
sudo apt-get install oracle-java7-set-default</pre>  
  
### Install PostgresSQL (Stash external database)  
  
<pre>sudo apt-get install postgresql  
sudo vim /etc/postgresql/9.1/main/postgresql.conf</pre>  
Uncomment the following line so server listens for local connections  
<pre>listen_addresses = 'localhost'</pre>  
- If access needed remotely above should be set to '*' and then modify pg_hba.conf to allow external connections  
<pre>vim /etc/postgresql/9.1/main/pg_hba.conf  
# allow all hosts on this subnet to access the DB  
host all all x.x.x.x/x md5</pre>  
where x.x.x.x/x is your network range and subnet mask.  
  
- Create PostgreSQL user  
<pre>sudo -u postgres psql postgres  
\password postgres  
# set password  
CREATE ROLE stashuser WITH LOGIN PASSWORD '&lt;password&gt;' VALID UNTIL 'infinity';  
CREATE DATABASE stash WITH ENCODING='UTF8' OWNER=stashuser CONNECTION LIMIT=-1;  
# Quit  
\q</pre>  
- [Atlassian recommend that you should not locate your Stash home directory inside the install directory](https://confluence.atlassian.com/display/STASH/Stash+home+directory).  
<pre>sudo mkdir -p /var/stash/install  
sudo mkdir /var/stash/home</pre>  
- Secure stash home dir with separate user  
<pre>adduser stashadmin  
cd /var/stash/install  
sudo wget http://www.atlassian.com/software/stash/downloads/binary/atlassian-stash-2.8.2.tar.gz  
sudo tar xvf atlassian-stash-2.8.2.tar.gz</pre>  
  
- Set stash home in setenv.sh to /var/stash/home.  
  
<pre>sudo vim atlassian-stash-2.8.2/bin/setenv.sh  
sudo chown -R stashadmin /var/stash  
atlassian-stash-2.8.2/bin/start-stash.sh</pre>  
  
- Navigate to the URL displayed and configure Stash.  
  
### Install svn2git  
  
<pre> sudo apt-get install git-core git-svn ruby rubygems</pre>  
  
- Once you have the necessary software your system, you can install svn2git through rubygems, which will add the svn2git command to your PATH.  
<pre>sudo gem install svn2git  
svn2git https:/// --rootistrunk --authors ~/authors.txt --username  --verbose</pre>  
- Output doesn't render properly on my machine - I have to accept the remote certificate once, then run the command again and and type the remote repo user's password before I can actually see the prompt.  
- Wait for import to complete.  
- Create project and repo in Stash.  
- Follow on-screen instructions for configuring Git for the first time and pushing the converted repo to Stash (copied below).  
  
### Configure Git for the first time  
  
<pre>git config --global user.name "Name"  
git config --global user.email "email@domain"</pre>  
  
### Push code to Git (Stash repository)  
  
<pre>git init  
git add --all  
git commit -m "Initial Commit"  
git remote add origin http://&lt;username&gt;@&lt;host&gt;:7990/scm/&lt;stash project&gt;/&lt;stash git repo&gt;.git  
git push origin master</pre>