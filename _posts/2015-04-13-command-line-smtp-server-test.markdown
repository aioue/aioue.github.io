---
layout: post
title: Command line SMTP server test
date: '2015-04-13 10:41:32'
---

[Swaks - Swiss Army Knife for SMTP](http://www.jetmore.org/john/code/swaks/)  

`swaks --to foo@bar --from acme@roadrunner --server mailserver.com`

Supports TLS

`swaks --to foo@bar.com --from acme@roadrunner --auth-user someusername --auth-password somepassword --server mailserver.com --tls`
