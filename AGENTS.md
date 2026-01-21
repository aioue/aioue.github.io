# AGENTS.md

This is a Jekyll blog hosted on GitHub Pages at **aioue.net**.

## Stack

- **Jekyll** with `github-pages` gem (~228)
- **Theme:** Minima (remote theme, auto skin)
- **Hosting:** GitHub Pages with custom domain via CNAME
- **Plugins:** jekyll-feed, jekyll-seo-tag
- **Syntax highlighting:** Rouge with Monokai theme

## Local Development

```bash
bundle install
bundle exec jekyll serve
```

Site will be available at `http://localhost:4000`

## File Structure

```
_posts/           # Blog posts (markdown)
_includes/        # Custom includes (head.html for GA4, favicon, SEO)
assets/css/       # Custom CSS (syntax.css for Monokai highlighting)
_config.yml       # Site configuration
ext/              # External assets (images, files)
about.markdown    # About page
index.markdown    # Homepage (uses home layout)
```

## Creating New Posts

Posts go in `_posts/` with filename format: `YYYY-MM-DD-slug.md` or `.markdown`

### Front Matter Template

```yaml
---
layout: post
title: Your Post Title
date: 'YYYY-MM-DD HH:MM:SS'
categories: [category1, category2]
tags: [tag1, tag2, tag3]
---
```

Categories and tags are optional but encouraged for new posts.

### Content Style

This blog contains **technical notes** — short, practical how-to guides and reference documentation. Posts are typically:

- Concise and direct — get to the commands fast
- Command-line focused with fenced code blocks (not `<pre>` tags)
- No "Overview" sections or numbered headers
- No fluff or lengthy explanations
- Double-space line breaks (`  `) are intentional — keep them
- Written for the author's future self (and others searching for solutions)

### Example Topics

Looking at existing posts, common themes include:
- Linux/Unix sysadmin (OSSEC, RAID, firmware updates)
- Windows administration (BIOS, domain, firewall)
- Networking (Cisco, VPN, OpenWrt, VDSL)
- Cloud/DevOps (AWS, VMware, Ansible)
- Development tools (Git, Ruby gems, Python)

## External Assets

Store images and files in `ext/` directory, organized by source domain if applicable:
- `ext/geocaching.com/`
- `ext/forums.teamphoenixrising.net/`

## Configuration Notes

- `show_excerpts: true` — Homepage shows post excerpts
- Google Analytics: GA4 (G-QXZ0K52W9G) via custom `_includes/head.html`
- Comments: Utterances (GitHub issues-based) via custom `_layouts/post.html`
- Social link: GitHub profile (aioue)
- URL: https://aioue.net
