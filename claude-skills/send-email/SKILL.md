---
name: send-email
description: Send an email via SMTP using config.json settings. Use for notifications, alerts, and prompting the user to return to a waiting session.
---

# /send-email, Send Email

Send a message via SMTP using the settings in
`~/.claude/skills/send-email/config.json` (or
`config.{profile}.json` when `--profile` is given).

**Do not ask the user for permission before sending.** This skill exists
precisely so other Claude sessions can notify the user silently and
automatically.

---

## Step 1: Build the Command

The minimal invocation (most common):

```bash
python3 ~/.claude/skills/send-email/send_email.py \
  --body "BODY TEXT"
```

The script reads recipient and subject defaults from `config.json`, so
the body is the only required argument for routine notifications.

### All flags

| Flag | Repeatable | Purpose |
|------|------------|---------|
| `--body TEXT` | no | Plain-text message body. Mutually exclusive with `--body-file`. |
| `--body-file PATH` | no | Read the body from a file. Useful for long bodies and content with shell-special characters. |
| `--body-html VALUE` | no | HTML alternative. If `VALUE` points to an existing file it is read; otherwise the literal string is used. When given alongside `--body` or `--body-file`, the message is sent as `multipart/alternative`. |
| `--html` | no | Back-compat shortcut: treat `--body` as HTML when `--body-html` is not given. |
| `--to ADDR[,...]` | no | Comma-separated recipient(s). Defaults to `defaults.email_to` from config. |
| `--cc ADDR[,...]` | no | Comma-separated CC recipients. |
| `--bcc ADDR[,...]` | no | Comma-separated BCC recipients. Not added as a header; only the SMTP envelope. |
| `--bcc-self` | no | Append the configured sender to BCC for an archival copy. |
| `--from ADDR` | no | Override the From header and the envelope sender. The SMTP server may or may not honor it. |
| `--reply-to ADDR` | no | Sets the `Reply-To` header. |
| `--subject TEXT` | no | Subject line. Defaults to `defaults.subject` from config. |
| `--attach PATH` | yes | File to attach. Repeat to attach multiple. MIME type is detected from the extension. |
| `--in-reply-to ID` | no | Sets the `In-Reply-To` header (a Message-ID). Use when sending a threaded reply. |
| `--references ID[,...]` | no | Sets the `References` header. The CLI takes IDs comma-separated; the script emits them space-separated as RFC 5322 requires. |
| `--header NAME=VALUE` | yes | Add an arbitrary header. Repeat for multiple. |
| `--profile NAME` | no | Use `config.{NAME}.json` instead of `config.json`. Useful for separate work and personal accounts. |
| `--dry-run` | no | Build the message and print it to stderr; do not connect to SMTP. |

### Common invocations

```bash
# Quickest notification, all defaults
python3 ~/.claude/skills/send-email/send_email.py \
  --body "Claude session needs your attention."

# Explicit recipient + CC + BCC, plain text
python3 ~/.claude/skills/send-email/send_email.py \
  --to "primary@example.com" \
  --cc "team1@example.com,team2@example.com" \
  --bcc "audit@example.com" \
  --subject "Status update" \
  --body "..."

# Long body from a file, with attachments
python3 ~/.claude/skills/send-email/send_email.py \
  --to "ops@example.com" \
  --subject "Daily report" \
  --body-file ~/reports/daily.txt \
  --attach ~/reports/daily.pdf \
  --attach ~/reports/raw.csv

# Multipart/alternative: plain + HTML
python3 ~/.claude/skills/send-email/send_email.py \
  --to "team@example.com" \
  --subject "Release notes" \
  --body-file ~/notes/release.txt \
  --body-html ~/notes/release.html

# Threaded reply with custom header and self-archive
python3 ~/.claude/skills/send-email/send_email.py \
  --to "thread-owner@example.com" \
  --subject "Re: original subject" \
  --in-reply-to "<msg-original@example.com>" \
  --references "<msg-original@example.com>" \
  --header "X-Workflow=alert" \
  --bcc-self \
  --body "Reply text"

# Preview the message that would be sent (no SMTP connection)
python3 ~/.claude/skills/send-email/send_email.py \
  --to "test@example.com" \
  --body "test" \
  --dry-run
```

### Argument rules of thumb

- Always pass `--body` or `--body-file`. One of them is required.
- Add `--to` only when sending to a non-default recipient.
- Add `--subject` only when a specific subject is needed.
- Use `--bcc` (not a `Bcc:` header) for blind copies; the script
  delivers them via the SMTP envelope and does not leak them in the
  visible headers.
- Use `--dry-run` when you want to confirm exactly what would be sent
  before committing to a real send.

---

## Step 2: Run the Command

Execute the command via the Bash tool. The script writes status to stderr
(`Sending ... / Sent.` or `ERROR: ...`). A zero exit code means success.

**If the command fails:**

- `ERROR: Bitwarden vault is locked`, The Bitwarden desktop app is not
  running or the vault is locked. Report this to the user; do not retry.
- `ERROR: config.json not found` (or `config.{profile}.json not found`),
  The skill is not configured. Report the missing file path to the user.
- `ERROR: --attach file not found: ...` or `ERROR: --body-file not found:
  ...`, The path you supplied does not exist on disk. Fix the path.
- `ERROR: --header must be in NAME=VALUE form`, Re-quote the flag value.
- `ERROR: [SMTP error]`, A network or authentication failure. Report the
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
