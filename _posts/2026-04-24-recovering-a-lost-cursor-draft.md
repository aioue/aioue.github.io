---
layout: post
title: Recovering a lost Cursor chat draft with SQLite and Lexical JSON
date: '2026-04-24 12:00:00'
tags: [cursor, sqlite, debugging, productivity]
hidden: false
---

I use [Cursor](https://www.cursor.com/) heavily to manage a personal knowledge base and job search tracker in a [git repo](https://github.com/aioue/cambodia). Tasks, notes, checklists - the Cursor chat box acts like a command interface. I type a block of items, hit send, the agent processes them.

Except this time I hit the wrong key and wiped the message before sending.

I'd been adding to that draft over the course of the morning. I knew some of what was in it, but not all of it. I retyped what I could remember and submitted that, but I had a nagging feeling I'd lost something. So I asked a Cursor agent in the same repo to try to recover the original.

What followed was a pretty good piece of detective work through Cursor's internals.

## The search

The agent started with the obvious places. It scanned the agent transcript `.jsonl` files and the submitted chat bubble history. It found the re-typed version I'd submitted from memory - but not the original draft.

Next it went looking in Cursor's SQLite databases on disk. macOS stores Cursor's app data under `~/Library/Application Support/Cursor/`. There are several:

- `Session Storage/000003.log` - empty, not useful
- `Local Storage/leveldb/000003.log` - only DevTools and PDF viewer state
- `User/globalStorage/state.vscdb` - this is the main one; it stores submitted chat bubbles under keys like `bubbleId:<composerId>:<bubbleId>`
- `User/workspaceStorage/<workspaceId>/state.vscdb` - workspace-scoped state

The submitted bubbles were all there in `globalStorage/state.vscdb`, but that's only the sent messages. The unsent draft wasn't among them - which makes sense, since I never submitted it.

## The key insight

At this point I mentioned I had hour-old backups of the Cursor app support folder. The agent asked for two specific files from the backup. I restored them to `/Users/tom/Desktop/cursor-restore/Cursor_0906/` and `Cursor_1006/` (the timestamps refer to when the backups were taken).

That's when it found something interesting: a key called `composerData:<composerId>` in `globalStorage/state.vscdb`.

This key stores the **unsent rich text draft** of the Cursor chat input box as a [Lexical](https://lexical.dev/) editor JSON blob. Lexical is the rich text framework Cursor uses for the chat input. It persists the draft state across quits and restarts - so if you close Cursor mid-thought and reopen it, your unsent message is still there.

The structure looks roughly like this:

```json
{
  "composerData": {
    "richText": {
      "root": {
        "children": [
          {
            "type": "paragraph",
            "children": [
              { "type": "text", "text": "your unsent message here" }
            ]
          }
        ]
      }
    }
  }
}
```

The `text` fields in the Lexical node tree contained the full original message. Compared to what I'd retyped from memory, there were four extra items I'd completely forgotten about:

- A [Container Solutions](https://www.container-solutions.com/) job listing URL
- "Join NorDev Discord"
- "Go over LinkedIn job emails"
- "Email old Klarytee boss Nithin about work - only need 30 hours a month contracting, happy to lower price"

That last one I definitely would not have remembered. A meaningful thing to have back.

## What to check if this happens to you

If you clear an unsent Cursor message and want to recover it:

1. **Check your backups first.** Time Machine, rsync, whatever you use - the window where the draft still exists in the SQLite database is before Cursor overwrites it (which happens when you next open the composer or quit cleanly, I think).

2. **Open `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`** with any SQLite browser (`sqlite3`, [DB Browser for SQLite](https://sqlitebrowser.org/), etc.).

3. **Look for keys matching `composerData:<composerId>`** in the `ItemTable`. The composerId is a UUID - there may be one per chat window/composer.

4. **Parse the value as JSON** and look for `text` nodes in the Lexical tree. The draft content is in there.

The composerId you want corresponds to the chat composer where you were typing. If you know the chat session, you can cross-reference the submitted bubble keys (`bubbleId:<composerId>:...`) to confirm which composerId is the right one.

## Luck required

This only worked because I had a recent backup. If Cursor had already overwritten the `composerData` key - which presumably happens once you open a new composer or send a new message - the draft would be gone from disk too.

The lesson: if you accidentally wipe an important Cursor draft, **stop using Cursor immediately** and back up `~/Library/Application Support/Cursor/` before doing anything else. The draft might still be in `state.vscdb`.

The recovery session happened in the [cambodia](https://github.com/aioue/cambodia) repo. Cursor agent doing forensics on its own app's storage files is a slightly strange loop, but it worked.
