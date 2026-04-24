---
name: notify-wait pipeline setup pending
description: notify-wait chain is armed but not operational; config files and python3 references need fixing before it can send
type: project
originSessionId: 4f652d9e-9ab5-4f61-9b45-7c8f05ce5f17
---
The `notify-wait` skill chain is armed in `~/.claude/notify_config.json`
(scope=session, mode=both) but cannot actually send — setup deferred to a
future session.

**Why:** Confirmed 2026-04-21 that running the hook command exercises the
logic but never fires an email. User wants to defer the fix.

**How to apply:** Don't claim notifications are working. If the user asks to
arm or test notify-wait before the items below are resolved, surface this
memory and the checklist rather than silently arming.

## Outstanding blockers

1. **`~/.claude/skills/send-email/config.json` missing** — only
   `config.example.json` exists. Needs Bitwarden item name (for SMTP creds),
   sender address, and default recipient. Gitignore the file.
2. **`~/.claude/skills/send-email/aliases.json` missing** —
   `notify_send.py` reads `"my phone"` from it to get the SMS-gateway
   address. Format: `{"my phone": ["<number>@<carrier-gateway>"]}`.
3. **`notify_send.py:137` hardcodes `"python3"`** in its
   `subprocess.run(["python3", SEND_SCRIPT, ...])` call. On this machine
   `python3` is a broken Microsoft Store execution alias; change to
   `"python"` (see feedback_python_command.md).
4. **`~/.claude/settings.json` hook commands** use `python3`:
   - PreToolUse(AskUserQuestion): `python3 ~/.claude/skills/notify-wait/notify_send.py --type decision || true`
   - Stop: `python3 ~/.claude/skills/notify-wait/notify_send.py --type done || true`
   Same fix: swap to `python`. Also update the two matching `permissions.allow`
   entries so the command name matches.

## Evidence captured 2026-04-21

- `python ~/.claude/skills/notify-wait/notify_send.py --type done` exited 0
  but `last_sent_at` in `notify_config.json` stayed at `1775795777.56`,
  confirming the inner `send_email()` subprocess returned False.
- `python3` in the Bash tool resolves to
  `C:\Users\antho\AppData\Local\Microsoft\WindowsApps\python3.exe`, which
  prints the "install from Microsoft Store" message and exits 49.
- Real Python is `C:\Program Files\Python312\python.exe`; no `python3.exe`
  exists alongside it.
