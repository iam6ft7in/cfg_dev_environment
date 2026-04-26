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

- **Accomplished**, actions completed in THIS session only (commits, PRs,
  files created, config applied, decisions made). This section is
  transient: it captures what just shipped for at-a-glance handoff.
  Prior `Accomplished` entries from earlier sessions are dropped on the
  next save; their content already lives in git, GitHub, and memory.
  If a prior accomplishment is still load-bearing context for an Open
  Item or Next Step, fold the relevant detail INTO that item rather
  than keeping it under Accomplished.
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

When the file already exists, treat its prior `Accomplished` section as
stale history. Replace it entirely with this session's accomplishments;
do not append. The only reason to carry forward a prior entry is if it
remains load-bearing context for a current Open Item or Next Step, and
in that case fold the detail into that item.

`Open Items`, `Key Paths`, and `Next Steps` follow the normal rules:
keep what is still applicable, drop what is resolved.

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
- `Accomplished` is replaced, not appended. Prior entries are stale by
  default; only carry detail forward by folding it into the Open Item
  or Next Step it supports. `/session-resume` skips this section by
  design, so it has no value as a long-running log.
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
