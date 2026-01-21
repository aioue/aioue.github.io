---
layout: post
title: Jekyll Minima remote_theme CSS not loading on GitHub Pages
date: '2026-01-21 16:00:00'
tags: [jekyll, github-pages, minima, css]
---

Fix for Jekyll sites using `remote_theme: jekyll/minima` where CSS loads on the homepage but not on post pages.

## The Problem

Homepage styled correctly. Post pages completely bare — no CSS at all. The `<head>` section was empty except for Utterances styles injected by JavaScript.

## The Cause

Custom `_includes/head.html` wasn't being included because the remote theme's `default.html` layout wasn't being overridden locally.

When you use `remote_theme`, Jekyll pulls the theme files from GitHub. But if you have a custom `_includes/head.html`, you also need a local `_layouts/default.html` that explicitly includes it.

## The Fix

Create `_layouts/default.html`:

{% raw %}
```html
<!DOCTYPE html>
<html lang="{{ page.lang | default: site.lang | default: "en" }}">
  {%- include head.html -%}
  <body>
    {%- include header.html -%}
    <main class="page-content" aria-label="Content">
      <div class="wrapper">
        {{ content }}
      </div>
    </main>
    {%- include footer.html -%}
  </body>
</html>
```
{% endraw %}

Create `assets/main.scss`:

{% raw %}
```scss
---
---

@import
  "minima/skins/{{ site.minima.skin | default: 'classic' }}",
  "minima/initialize"
;
```
{% endraw %}

Your `_includes/head.html` should link to `/assets/main.css`:

{% raw %}
```html
<link rel="stylesheet" href="{{ "/assets/main.css" | relative_url }}">
```
{% endraw %}

## What NOT to Do

Don't create `assets/css/style.scss` with `@import "minima"` — this causes build failures because `minima` isn't in the Sass load path when using `remote_theme`.

## Debugging Tips

- Check GitHub Actions for build failures
- Add `?nocache=123` to URLs to bypass browser cache
- View page source to verify `<head>` contains stylesheet links
- Check `/assets/main.css` returns actual CSS, not a 404 page
