---
layout: post
title: Backing up Any.do tasks with any.down
date: '2026-03-22 18:00:00'
tags: [python, any.do, backup, docker]
hidden: false
---

I've used [Any.do](https://www.any.do/) for task management for years. It is simple and stays out of the way. It also has no export or backup ([their support page confirms it](https://support.any.do/en/articles/8635961-printing-and-exporting-items)), so a deleted list or a dead service would take the data with it.

[any.down](https://github.com/aioue/any.down) is a small Python CLI that logs into Any.do's web API, pulls tasks, and writes timestamped JSON and Markdown. Run it on a schedule (or via Docker) and you keep a local copy.

## How it works

First run, any.down asks for your Any.do email and password, then sends a 2FA code to your inbox. After that it saves the session so you don't have to re-authenticate each time. It only writes new files when your tasks have actually changed, so you don't end up with hundreds of identical exports.

```bash
git clone https://github.com/aioue/any.down.git
cd any.down
uv sync
uv run anydown
```

The output lands in `outputs/` - raw JSON for archival and Markdown tables that are easy to read or grep through.

## Unattended backups with Docker

The main reason I built this was to run it on a schedule without thinking about it. A `docker compose up -d` gives you hourly syncs via [supercronic](https://github.com/aptible/supercronic), with session state in a Docker volume so it survives container rebuilds:

```bash
docker compose up -d
```

There's also a `--watch` flag if you'd rather run the process directly without Docker - it syncs every 90 minutes or so with some random jitter.

## Duplicate cleaner

Any.do occasionally creates duplicate tasks (sync conflicts or API oddities). `anydown-dupes` finds exact duplicates (same title, list, note, and subtasks) and can delete them:

```bash
uv run anydown-dupes               # dry run
uv run anydown-dupes --delete      # prompt before deleting
```

I keep the local exports because plain JSON/Markdown survives vendor churn and is easy to move to another system later.

Source: [aioue/any.down](https://github.com/aioue/any.down)
