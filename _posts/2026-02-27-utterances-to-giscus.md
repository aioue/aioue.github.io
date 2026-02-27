---
layout: post
title: Moving blog comments from Utterances to Giscus
date: '2026-02-27 21:00:00'
tags: [github-pages, giscus, utterances, security]
---

This blog used [Utterances](https://utteranc.es/) for comments, which stores them as GitHub Issues. It worked well, but I've switched to [Giscus](https://giscus.app/), which uses GitHub Discussions instead. The main reason is security.

## The permission problem

Utterances is a GitHub OAuth App. When you sign in to leave a comment, it requests the `public_repo` scope. That's a broad permission — it grants read and write access to **all** of your public repositories, not just the one you're commenting on. If the Utterances token were ever compromised, an attacker could create, modify, or delete issues and code across any of your public repos.

Giscus is a GitHub App, which uses a fundamentally different permission model. It can only access repositories where the owner has explicitly installed it. When you sign in to comment on this blog, Giscus can only interact with this blog's repository. It has no access to your personal repositories unless you've specifically installed Giscus there yourself.

In short: Utterances gets keys to every public room in the building. Giscus only gets keys to the rooms it's been invited into.

## The migration

Straightforward. Enable GitHub Discussions on the repository, install the Giscus app, swap the script tag in the page template, and convert the existing comment threads from Issues to Discussions. Existing comments carried over without any trouble.
