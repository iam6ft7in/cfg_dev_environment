---
name: session-save
description: Write or update SESSION_STATE.md, what was accomplished, blockers, key paths touched, and exact next steps.
---

# /session-save, Save Session State

Write or overwrite `SESSION_STATE.md` in the current working directory with a
snapshot of this session. Optimize for usefulness to a future session reading
the file cold. There is no length limit; include enough detail that the next
session can resume without re-reading the conversation, and no more.

---

## Step 1: Gather Context

Do NOT ask the user any questions. Derive everything from the conversation history
and the current repo state:

- **Accomplished**, actions completed in this session (commits, PRs, files
  created, config applied, decisions made).
- **Open items**, anything started but not finished, blocked, or deferred.
  Include PR URLs, issue numbers, and manual steps that cannot be automated.
- **Key paths**, files and directories that were created or meaningfully
  changed. Repo-relative paths are preferred; absolute paths for out-of-repo
  locations (OneDrive scripts, ~/.claude/, etc.).
- **Next steps**, ordered, concrete actions the user should take to resume.
  Each step must be actionable without re-reading the full conversation.
  Include exact commands, PR URLs, or skill names (e.g., `/merge-complete`)
  where relevant.

---

## Step 2: Read Existing File

Read `SESSION_STATE.md` before writing. The Write tool requires the file to be
read before it can be overwritten. If the file does not exist yet, skip this step.

---

## Step 3: Write SESSION_STATE.md

Write the file using this exact structure. Omit any section that has nothing to
report (e.g., no blockers means omit Open Items).

If the current session has a name (not a default placeholder like "New Session"
or an auto-generated timestamp), include it as a `Session` metadata line
immediately after the heading.

```markdown
# Session State, {YYYY-MM-DD}
Session: {session name}

## Accomplished
- {bullet per completed action}

## Open Items
- **{item}**, {why it is blocked or pending}
  -> {URL or command to resume}

## Key Paths
| Item | Path |
|------|------|
| {label} | `{path}` |

## Next Steps
1. {first action, most urgent or blocking}
2. {second action}
...
```

Rules:
- Date must be today's date in `YYYY-MM-DD` format.
- Omit the `Session:` line entirely if the session is unnamed.
- Bullets are past-tense for Accomplished, imperative for Next Steps.
- Do not include meta-commentary, pleasantries, or filler.
- Length is whatever the work requires. Compress when nothing more needs
  to be said; expand when the next session needs commit hashes, PR
  numbers, per-repo state, or decision rationale to resume cleanly.
- No em dashes anywhere. Use commas, parentheses, colons, periods, or
  semicolons. See `~/.claude/rules/core.md`.

---

## Step 4: Confirm

After writing the file, print a single line:

```
SESSION_STATE.md written, {N} lines.
```

Do not summarize the contents, the user can read the file.
