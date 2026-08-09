---
layout: post
title: Recovering a lost Cursor chat draft with SQLite and Lexical JSON
date: '2026-04-24 12:00:00'
tags: [cursor, sqlite, debugging, productivity]
hidden: false
---

I use [Cursor](https://www.cursor.com/) as a command interface for a personal knowledge base and job search tracker: type a block of tasks or notes, send, let the agent process them.

This time I hit the wrong key and wiped the message before sending. I had been building that draft all morning. I retyped what I remembered and sent that, then asked a Cursor agent in the same repo to dig for the original.

## The search

The agent started with the obvious places. It scanned the agent transcript `.jsonl` files and the submitted chat bubble history. It found the re-typed version I'd submitted from memory - but not the original draft.

Next it went looking in Cursor's SQLite databases on disk. macOS stores Cursor's app data under `~/Library/Application Support/Cursor/`. There are several:

- `Session Storage/000003.log` - empty, not useful
- `Local Storage/leveldb/000003.log` - only DevTools and PDF viewer state
- `User/globalStorage/state.vscdb` - this is the main one; it stores submitted chat bubbles under keys like `bubbleId:<composerId>:<bubbleId>`
- `User/workspaceStorage/<workspaceId>/state.vscdb` - workspace-scoped state

The submitted bubbles were all there in `globalStorage/state.vscdb`, but that's only the sent messages. The unsent draft wasn't among them - which makes sense, since I never submitted it.

## `composerData` in the backup

I mentioned hour-old backups of the Cursor app support folder. The agent asked for two files from the backup; I restored them to `Cursor_0906/` and `Cursor_1006/` (backup times).

Those copies had a key `composerData:<composerId>` in `globalStorage/state.vscdb`. It holds the unsent rich text draft of the chat input as [Lexical](https://lexical.dev/) JSON. Cursor keeps that draft across quits, which is why an unsent message can still be there after a restart.

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

The `text` fields in the Lexical node tree held the full original message. Against what I had retyped from memory, four extra items came back that I had forgotten.

## What to check if this happens to you

If you clear an unsent Cursor message and want to recover it:

1. **Check your backups first.** Time Machine, rsync, whatever you use - the window where the draft still exists in the SQLite database is before Cursor overwrites it (which happens when you next open the composer or quit cleanly, I think).

2. **Open `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`** with any SQLite browser (`sqlite3`, [DB Browser for SQLite](https://sqlitebrowser.org/), etc.).

3. **Look for keys matching `composerData:<composerId>`** in the `ItemTable`. The composerId is a UUID - there may be one per chat window/composer.

4. **Parse the value as JSON** and look for `text` nodes in the Lexical tree. The draft content is in there.

The composerId you want corresponds to the chat composer where you were typing. If you know the chat session, you can cross-reference the submitted bubble keys (`bubbleId:<composerId>:...`) to confirm which composerId is the right one.

## Caveat

This only worked because of a recent backup. If Cursor had already overwritten `composerData` (likely when you open a new composer or send another message), the draft would be gone from disk too.

If you wipe an important unsent draft: stop using Cursor and copy `~/Library/Application Support/Cursor/` first. The text may still sit in `state.vscdb`.

Having a Cursor agent dig through its own storage files is a slightly strange loop, but it worked.