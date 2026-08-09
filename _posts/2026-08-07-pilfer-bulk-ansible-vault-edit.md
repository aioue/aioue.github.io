---
layout: post
title: Bulk edit Ansible vault files with pilfer
date: '2026-08-07 17:00:00'
tags: [ansible, vault, secrets, python, cli]
hidden: false
---

If you run Ansible at any scale, you eventually want to search across vaulted files or edit several secrets in one sitting. `ansible-vault edit` is one file at a time. Grep is useless on ciphertext. Decrypting by hand makes it easy to leave a file open.

[pilfer](https://github.com/aioue/pilfer) is the CLI I wanted for that: `pilfer open` decrypts every vault file in the tree (and optionally inline `!vault` values), you edit or search in plaintext, then `pilfer close` re-encrypts only what changed. Unchanged files keep their original ciphertext byte-for-byte.

It uses Ansible's own vault implementation (no custom crypto).

## Install

Requires **Python 3.10+** and **Ansible** on your PATH.

```bash
pipx install pilfer
pilfer --help
```

Or from source:

```bash
git clone https://github.com/aioue/pilfer.git
cd pilfer
pip install -e .
```

## Basic workflow

From your Ansible project root:

```bash
pilfer open
rg 'old-token' roles/ inventory/
# edit secrets.yml, group_vars, whatever you opened
pilfer close
```

pilfer reads `vault_password_file` from `ansible.cfg` if you have one:

```ini
[defaults]
vault_password_file = ~/.ansible-vault/.vault-file
```

Otherwise pass `-p /path/to/password-file`. It also checks a few common locations (`~/.ansible-vault/.vault-file`, `.vault_password`, and similar).

While a session is open, pilfer writes session metadata locally:

```gitignore
vaultedFileList.json
.vault/
**/*.pilfer-open
```

Add those to `.gitignore`. Do not commit while a session is open.

## Inline `encrypt_string` values

Whole-file vaults are opened by default. Inline `!vault` scalars are opt-in:

```bash
pilfer open --include-encrypted-vars
```

pilfer rewrites each opened value with a marker comment:

```yaml
db_password: "the-secret"  # pilfer:vault:0
```

Leave the marker in place until you run `pilfer close`. `close` does not need the flag - it re-encrypts whatever the session opened.

## Re-keying (not the same as close)

`pilfer close` is **not** password rotation. It refuses a different password than the one used for `open`.

To rotate the vault password across a tree:

```bash
pilfer rekey \
  --old-vault-password-file ~/.ansible-vault/.vault-file \
  --new-vault-password-file /tmp/new-vault-pass \
  --dry-run
```

Drop `--dry-run` when the plan looks right. It prompts before mutating files.

## Fail closed

pilfer prefers leaving secrets visible over silently corrupting them:

- refuses a second `open` while a session exists
- refuses `close` with the wrong password (no accidental re-key)
- keeps `.vault/` backups if `close` fails partway; fix the issue and run `close` again
- refuses ambiguous edits (for example stripping a `# pilfer:vault:N` marker but leaving plaintext)

That is fussy when you are in a hurry, on purpose.

## When I use it

Ansible repos with vault files under `inventory/`, `group_vars/`, and role `vars/`:

- bulk find/replace after a token rotation
- editing several role secrets in one pass
- checking what is still referenced before deleting a key

For a single vault file, `ansible-vault edit` is enough. For decrypt-the-whole-tree editing, use pilfer.

Source: [aioue/pilfer](https://github.com/aioue/pilfer) · PyPI: [pilfer](https://pypi.org/project/pilfer/)
