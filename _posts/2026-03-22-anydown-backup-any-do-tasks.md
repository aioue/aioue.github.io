---
layout: post
title: Backing up Any.do tasks with any.down
date: '2026-03-22 18:00:00'
tags: [python, any.do, backup, docker]
hidden: false
---

I've used [Any.do](https://www.any.do/) for task management for years. It's simple and stays out of the way, which is what I want. But it has no export or backup feature - [their own support page confirms it](https://support.any.do/en/articles/8635961-printing-and-exporting-items). If the service disappeared tomorrow, or I accidentally deleted a list, everything would be gone.

[any.down](https://github.com/aioue/any.down) is a small Python CLI I wrote to fix that. It logs into Any.do's web API, pulls your tasks, and saves them as timestamped JSON and Markdown files. Run it once a day (or let Docker do it for you) and you've got a local paper trail of everything.

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

## Bonus: duplicate cleaner

Any.do occasionally creates duplicate tasks - maybe from sync conflicts across devices, maybe from the API being weird. any.down ships with a separate `anydown-dupes` command that finds exact duplicates (matching title, list, note, and subtasks) and lets you clean them up:

```bash
uv run anydown-dupes               # dry run
uv run anydown-dupes --delete      # prompt before deleting
```

## Why not just use the app?

Mostly peace of mind. I don't distrust Any.do, but I've been burned before by services that shut down or lose data. Having a local copy of my tasks - in plain text formats I can read without any special tooling - means I'm not locked in. If I ever move to a different system, the data is already there.

Source: [aioue/any.down](https://github.com/aioue/any.down)
