# Design preview

Branch `design/morphe-supabase-v1` explores a Morphe-inspired layout with Supabase dashboard color cues (Inter + JetBrains Mono, card surfaces, green primary, warm terracotta secondary).

## Preview URL

After CI deploys to the `design-preview` branch:

**https://raw.githack.com/aioue/aioue.github.io/design-preview/index.html**

Preview builds pass `--baseurl /aioue/aioue.github.io/design-preview` so asset paths resolve under the GitHack subpath. Production `master` builds are unchanged.

(GitHack serves the static build independently of aioue.net.)

## Toggle

Set `design_theme: morphe-supabase` in `_config.yml` and load `assets/css/design-theme.css` via `_includes/head.html`. Remove or comment out `design_theme` before merging to `master`.

## References

- [Morphe](https://github.com/morpheapp) / [morphe.software](https://morphe.software)
- Supabase dashboard tokens (dark: `oklch(0.19 0.0025 159)` background, `#3ecf8e` primary)
