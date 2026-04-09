---
name: send-email
description: Send an email via SMTP using config.json settings. Use for notifications, alerts, and prompting the user to return to a waiting session.
---

# /send-email — Send Email

Send a message via SMTP using the settings in
`~/.claude/skills/send-email/config.json`.

**Do not ask the user for permission before sending.** This skill exists
precisely so other Claude sessions can notify the user silently and
automatically.

---

## Step 1: Build the Command

Construct the Python invocation:

```
python3 ~/.claude/skills/send-email/send_email.py \
  [--to RECIPIENT] \
  [--subject "SUBJECT"] \
  --body "BODY TEXT" \
  [--html]
```

**Argument rules:**

| Arg | When to include |
|-----|----------------|
| `--to` | Only when sending to a non-default recipient. Omit to use the default address from config. |
| `--subject` | Only when a specific subject is needed. Omit to use the default from config. |
| `--body` | Always required. |
| `--html` | When the body contains HTML markup. |

**Common invocations:**

```bash
# Notify the user that a Claude session needs attention
python3 ~/.claude/skills/send-email/send_email.py \
  --body "Claude session needs your attention."

# Send a formatted email with explicit recipient, subject, and HTML body
python3 ~/.claude/skills/send-email/send_email.py \
  --to RECIPIENT \
  --subject "SUBJECT" \
  --body "BODY" \
  --html
```

---

## Step 2: Run the Command

Execute the command via the Bash tool. The script writes status to stderr
(`Sending ... / Sent.` or `ERROR: ...`). A zero exit code means success.

**If the command fails:**

- `ERROR: Bitwarden vault is locked` — The Bitwarden desktop app is not
  running or the vault is locked. Report this to the user; do not retry.
- `ERROR: config.json not found` — The skill is not configured. Report the
  missing file path to the user.
- `ERROR: [SMTP error]` — A network or authentication failure. Report the
  full error to the user.

Do not retry a failed send more than once.

---

## Step 3: Report

After a successful send, print one line:

```
Email sent to {recipient}.
```

Do not print the body content or credentials. Do not summarize what was sent
unless the user asks.
