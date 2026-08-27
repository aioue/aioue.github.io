---
layout: post
title: Sharing a devcontainer without extends
date: '2026-08-27 12:05:00'
tags: [devcontainers, docker, opennebula, ansible]
hidden: false
---

I keep two Ansible trees that talk to OpenNebula. They share a CLI gem, a PyONE pin, Cursor rules, and bind-mounts for `~/.one` and `~/.ssh`. Copying `.devcontainer/` between them lasted until the first non-trivial fix landed in only one copy.

[pocket-nebula](https://github.com/aioue/pocket-nebula) is the shared layer those trees consume. `devcontainer.json` has no `extends` ([spec#22](https://github.com/devcontainers/spec/issues/22), 2022). The substitute is a Docker image, a vendored script directory, and a host-side sync that runs before `docker build`. That still cannot rewrite `devcontainer.json` after the tool has parsed it.

## Consumer Dockerfile

Each Ansible repo has a thin Dockerfile:

```dockerfile
FROM ghcr.io/aioue/pocket-nebula-base:v1
```

The major tag moves when pocket-nebula publishes a fix. Shared mounts, extensions, settings, and lifecycle hooks sit on the image as a `devcontainer.metadata` label. The spec already merges that label with the repo's `devcontainer.json`, and the repo file wins on conflict. Lifecycle commands concatenate, so a project can add `ssh-add` without replacing `setup.sh`.

The label cannot carry `build`, `runArgs`, `features`, or `name`. Those stay in the consumer: DNS, the Python feature, the per-project history volume.

Scripts (`setup.sh`, git hooks, the server version probe) cannot live only in the image, because `postCreateCommand` needs them in the workspace. They are vendored at `.devcontainer/common/` and committed, so a clone still builds offline.

The one file copied by hand is `sync-common.sh`. It is `initializeCommand`, which the spec runs on the host before the image is built:

{% include github-embed.html repo="aioue/pocket-nebula" file=".devcontainer-shared/scripts/sync-common.sh" start="1" end="23" %}

`common.ref` in the consumer is a git ref. A branch is re-fetched on every create; a tag or SHA is treated as immutable. If git is missing or the network is down, the committed copy stays.

Because `devcontainer.json` is already parsed by then, the sync cannot patch it. A drift script warns if a consumer re-declares an extension or a `containerEnv` key the image already set. `containerEnv` is last-value-wins, so a duplicate stops tracking the image with no error from the tool.

## PATH and remoteUser

`containerEnv` is passed as `docker run -e`. Docker does not expand `${PATH}` there. An earlier base image set PATH to `/usr/local/ansible-venv/bin:${PATH}` in metadata. The keep-alive loop is `while sleep 1000; do :; done`. `sleep` lives in `/usr/bin`. The container exited on start.

The working arrangement is to leave PATH alone in the label and symlink Ansible onto a directory the Python feature already puts on PATH. CI rejects a published image that puts PATH back:

{% include github-embed.html repo="aioue/pocket-nebula" file=".devcontainer-shared/image/verify-metadata-label.py" start="21" end="28" %}

{% include github-embed.html repo="aioue/pocket-nebula" file=".devcontainer-shared/image/Dockerfile" start="135" end="151" %}

Docker `LABEL` also replaces rather than merges. The base image has to restate `remoteUser: vscode` from `mcr.microsoft.com/devcontainers/base`. Omit that and every lifecycle command runs as root, credentials land in `/root`, and `ONE_AUTH` points at a file the `vscode` user cannot read.

XML-RPC URLs are committed in `.devcontainer/site.env`. `user:password` stays in `~/.one/one_auth_<suffix>` on the host, bind-mounted read-only. `setup.sh` copies the selected file to `~/.one_auth` because that mount cannot be written. If `~/.one/` has several auth files and the project did not pin a suffix, `postCreate` fails rather than guessing.

## Extends

[spec#22](https://github.com/devcontainers/spec/issues/22) is a same-repo file. That would not, by itself, share a config across two git trees. [spec#716](https://github.com/devcontainers/spec/issues/716) is closer: a versioned package other repos can consume. Image `devcontainer.metadata` is the stand-in that already exists, and it cannot express `runArgs` or `features`, cannot change `devcontainer.json` after parse, and inherits Docker's "LABEL replaces the key" behaviour.

A first-class `extends` of a published config would retire `sync-common.sh` and the drift checker. spec#22 is still open. This is what I run in the meantime.
