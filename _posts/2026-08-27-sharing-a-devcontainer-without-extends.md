---
layout: post
title: Sharing a devcontainer without extends
date: '2026-08-27 19:15:00'
last_modified_at: '2026-08-27'
tags: [devcontainers, docker, opennebula, ansible]
hidden: false
---

I keep two Ansible trees that talk to OpenNebula. They share a CLI gem, a PyONE pin, Cursor rules, and bind-mounts for `~/.one` and `~/.ssh`. Copying `.devcontainer/` between them lasted until the first non-trivial fix landed in only one copy.

[pocket-nebula](https://github.com/aioue/pocket-nebula) is the shared layer those trees consume. `devcontainer.json` has no `extends` ([spec#22](https://github.com/devcontainers/spec/issues/22), 2022). I simulate it with an image label, a git clone on the host, and 13 committed copies of someone else's scripts. Each of those exists for one missing merge.

## What I want the consumer to be

```jsonc
{
  "name": "automation",
  "extends": "ghcr.io/aioue/pocket-nebula-base:v1",
  "build": { "dockerfile": "Dockerfile", "args": { "vscodedevcontainer": "true" } },
  "runArgs": ["--dns=172.16.1.10", "--dns=172.16.1.11", "--dns=1.1.1.1"],
  "features": {
    "ghcr.io/devcontainers/features/python:1": {
      "toolsToInstall": "virtualenv, argcomplete"
    }
  },
  "postStartCommand": "ssh-add -q ~/.ssh/id_ed25519 2>/dev/null; true"
}
```

Plus a one-line `FROM ghcr.io/aioue/pocket-nebula-base:v1` and a `site.env` of XML-RPC URLs. That is the project-specific surface: name, DNS, extra features, one extra lifecycle line, endpoints.

Compose already merges like this. The spec issue proposes the same rules (arrays union, scalars overwrite, new keys add). The tool would load the parent as part of parsing `devcontainer.json`. There is no second channel.

## What I ship instead

A thin Dockerfile, the json above *without* `extends`, and then the glue that `extends` would make unnecessary:

- `sync-common.sh` as `initializeCommand`
- `common.ref` (a second pin, independent of the image tag)
- 13 files under `.devcontainer/common/`, committed in every consumer: `setup.sh`, git hooks, the version probe, a drift checker, Cursor rules, and so on

{% include github-embed.html repo="aioue/pocket-nebula" file=".devcontainer-shared/scripts/sync-common.sh" start="1" end="23" %}

That comment is the design. The spec runs `initializeCommand` on the host *before* `docker build`, and *after* it has already parsed `devcontainer.json`. Shared json therefore cannot travel with the scripts. It travels as a `devcontainer.metadata` LABEL on the image, which is a different merge with a different property set.

## Why each extra piece exists

**13 vendored files.** `postCreateCommand` is a path relative to the workspace, so `setup.sh` has to be in git. I cannot point at a file that only exists in the parent image, because the parent config is not a json file I extend; it is a LABEL, and the lifecycle entry it carries is `.devcontainer/common/setup.sh`. With `extends`, the parent json can say `/usr/local/lib/pocket-nebula/setup.sh` (a path in the image). The consumer tree does not need a copy.

**`sync-common.sh`.** Those 13 files are deliberately *not* baked into every image rebuild, so a hook fix can land without republishing Ubuntu. The only hook early enough to fetch them is `initializeCommand`, which means a `git clone` on the laptop, with a fallback to the committed copy when offline. With `extends` of a published config, the tool fetches the parent while it is loading json. The clone, the offline fallback, and the "ask on a TTY / apply silently in Cursor" branch all go away.

**`common.ref`.** Image tag `:v1` and script ref `main` can move separately. That is two distribution channels for one logical parent. `extends` is one parent. One pin.

**The drift checker.** Shared extensions and `containerEnv` keys live in the LABEL. If a consumer repeats one in local json, last-value-wins: the local copy is now the source of truth and will not see the next image change. The tool does not warn. I warn in a shell script, and the script is not allowed to fail the create (that was worse). With `extends`, you do not copy keys in order to inherit them. You add deltas. A repeated key is an override you wrote on purpose, which is the Compose rule.

**Restating `remoteUser: vscode`.** Docker `LABEL` replaces a key. The child image's `devcontainer.metadata` does not inherit the parent's label, so omitting `remoteUser` drops it from `mcr.microsoft.com/devcontainers/base`. Lifecycle then runs as root, credentials land in `/root`, and `ONE_AUTH` points at a 0600 file `vscode` cannot read. Config `extends` is a json merge in the tool. It does not go through `LABEL`, so it does not have replace-the-whole-key semantics for the parent image's metadata.

**Forbidding `PATH` in that LABEL.** `containerEnv` is `docker run -e`. Docker does not expand `${PATH}` there. A metadata value of `/usr/local/ansible-venv/bin:${PATH}` made `/usr/bin` disappear. The keep-alive loop is `while sleep 1000; do :; done`. The container exited on start. That bug is possible because inheritance was stuffed into `containerEnv`, which is the wrong mechanism for PATH (Dockerfile `ENV` expands; `docker run -e` does not). CI now rejects it:

{% include github-embed.html repo="aioue/pocket-nebula" file=".devcontainer-shared/image/verify-metadata-label.py" start="21" end="28" %}

{% include github-embed.html repo="aioue/pocket-nebula" file=".devcontainer-shared/image/Dockerfile" start="135" end="151" %}

With `extends`, PATH stays in the parent Dockerfile. It never needs to be a json field, so it never hits `docker run -e`.

None of this touches project secrets. XML-RPC URLs still belong in `site.env`. `user:password` still belongs in `~/.one/` on the host. Those are data, not inheritance.

## The spec gap, precisely

[spec#22](https://github.com/devcontainers/spec/issues/22) is a same-repo file, merged with Compose rules. That slice removes the LABEL-as-parent *inside* one git tree.

Two Ansible repos are two git trees. The issue lists "configuration outside the repository" as future work. [spec#716](https://github.com/devcontainers/spec/issues/716) is the versioned-package form of that. Image metadata is the stand-in that already shipped, and it cannot express `runArgs` or `features`, cannot change json after parse, and inherits `LABEL` replace.

Same-repo `extends` plus a parent that other repos can name (the future work in #22, or #716) is the whole pitch. The consumer json at the top is that combined primitive. Until it exists, the image label and the host clone are the two halves I have to keep in step by hand.
