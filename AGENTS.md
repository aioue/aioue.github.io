# AGENTS.md

This is a Jekyll blog hosted on GitHub Pages at **aioue.net**.

## Stack

- **Jekyll** with `github-pages` gem (~228)
- **Theme:** Minima via `remote_theme: jekyll/minima` (CRITICAL: must use `remote_theme`, not `theme:` for GitHub Pages)
- **Hosting:** GitHub Pages with custom domain via CNAME
- **Plugins:** jekyll-feed, jekyll-seo-tag, jekyll-remote-theme
- **Syntax highlighting:** Rouge with Monokai theme (custom CSS in `assets/css/syntax.css`)

## Local Development

```bash
bundle install
bundle exec jekyll serve
```

Site will be available at `http://localhost:4000`

## File Structure

```
_posts/           # Blog posts (markdown)
_layouts/         # Custom layouts (default.html, post.html with Utterances)
_includes/        # Custom includes (head.html for GA4, favicon, SEO)
assets/css/       # Custom CSS (syntax.css for Monokai highlighting)
assets/main.scss  # Theme CSS import (imports minima)
_config.yml       # Site configuration
ext/              # External assets (images, files)
about.markdown    # About page
index.markdown    # Homepage (uses home layout)
```

## Creating New Posts

Posts go in `_posts/` with filename format: `YYYY-MM-DD-slug.md` or `.markdown`

**CRITICAL:** The filename MUST use dashes (`-`) to separate the date from the slug, not underscores. Jekyll will silently ignore files like `2026-01-29_my-post.md` — they won't appear on the site.

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

For posts with timezone, use ISO 8601 format with offset:
```yaml
date: '2026-01-29T15:55:00+07:00'  # ICT (Indochina Time, UTC+7)
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

- `permalink: pretty` — Clean URLs without `.html` extension (e.g. `/2026/01/29/my-post/`)
- `show_excerpts: true` — Homepage shows post excerpts
- Google Analytics: GA4 (G-QXZ0K52W9G) via custom `_includes/head.html`
- Comments: Utterances (GitHub issues-based) via custom `_layouts/post.html`
- Social link: GitHub profile (aioue)
- URL: https://aioue.net

### Theme Configuration

**CRITICAL:** Always use `remote_theme: jekyll/minima` in `_config.yml`, NOT `theme: minima`. GitHub Pages requires `remote_theme` and the `jekyll-remote-theme` plugin.

**CRITICAL:** This site requires custom `_layouts/default.html` to properly include `head.html`. The remote theme's default layout doesn't automatically use our custom `_includes/head.html` for all pages. Without a local `default.html`, post pages will be unstyled.

Theme CSS requires `assets/main.scss` with:
```scss
---
---
@import
  "minima/skins/{{ site.minima.skin | default: 'classic' }}",
  "minima/initialize"
;
```

Custom `_includes/head.html` must link to `/assets/main.css` (generated from main.scss).

If the site appears "bare" or unstyled:
1. Verify `remote_theme: jekyll/minima` in `_config.yml`
2. Verify `_layouts/default.html` exists and includes `{%- include head.html -%}`
3. Verify `assets/main.scss` exists with the Minima imports
4. Check `_includes/head.html` links to `/assets/main.css`
5. **Do NOT create `assets/css/style.scss`** — this causes build failures with remote_theme

## Troubleshooting

### Theme Not Loading / Bare Appearance

If the site appears unstyled:
- **Check `_layouts/default.html`:** Must exist and include `{%- include head.html -%}` — this is the most common cause
- **Check `assets/main.scss`:** Must exist with proper Minima imports (see Theme Configuration above)
- **Check `_config.yml`:** Must use `remote_theme: jekyll/minima`, NOT `theme: minima`
- **Check CSS path:** `_includes/head.html` must link to `/assets/main.css`
- **Rebuild:** After changes, GitHub Pages rebuilds automatically (1-2 min), or restart local server
- **Cache busting:** Add `?nocache=123` to URL to bypass browser cache when testing

### Local Development Issues

If `bundle install` fails:
- Ensure Ruby 3.3+ is installed (check with `ruby --version`)
- Install libffi: `brew install libffi` (macOS)
- Set PATH: `export PATH="/opt/homebrew/opt/ruby@3.3/bin:$PATH"`

If Jekyll build fails:
- Clear cache: `rm -rf .jekyll-cache _site`
- Reinstall gems: `bundle install --force`
- Check Ruby version compatibility with `github-pages` gem

## Commit Message Convention

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>: <short summary>

<optional body with motivation/context>
```

**Types:**
- `feat:` — New feature or post
- `fix:` — Bug fix
- `docs:` — Documentation changes
- `style:` — Formatting, CSS changes
- `refactor:` — Code restructuring
- `chore:` — Maintenance tasks

**Examples:**
```
feat: add post on Ubuntu RDP setup

docs: update AGENTS.md with commit conventions

fix: correct syntax highlighting for bash blocks
```

## Important Notes for AI Agents

- **Post filenames MUST use dashes after the date** — `2026-01-29-slug.md` works; `2026-01-29_slug.md` silently fails (Jekyll ignores it)
- **Never use `theme:` in `_config.yml`** — always use `remote_theme:` for GitHub Pages compatibility
- **Custom `_layouts/default.html` is required** — the remote theme won't use our `head.html` without it
- **Custom `head.html` overrides theme defaults** — must include all meta tags, SEO, feed_meta, and CSS links
- **Never create `assets/css/style.scss`** — this causes build failures; use `assets/main.scss` instead
- **Double-space line breaks are intentional** — preserve `  ` in posts (author preference for mobile typing)
- **Categories create URL paths** — posts with categories appear at `/category1/category2/YYYY/MM/DD/slug.html`; use tags only for cleaner URLs
- **Tags don't affect URLs** — use tags for metadata without changing the URL structure
- **Liquid tags in code blocks need `{% raw %}` wrapper** — wrap code blocks containing `{{ }}` or `{% %}` in `{% raw %}` and `{% endraw %}` to prevent Jekyll from processing them
- **Self-improvement:** When you encounter issues, learn new patterns, or discover important gotchas, update this AGENTS.md file with the information. Add troubleshooting steps, update configuration notes, or expand the "Important Notes" section as needed.
