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

### Scope filter: this repo's state only

`SESSION_STATE.md` tracks the CURRENT repo's own state. It is not a
catalog of bookmarks for other repos. Before adding any Open Item, Key
Path, or Next Step, ask: "does this entry belong to a different repo?"

- **Track here:** files owned by this repo, user-level `~/.claude/`
  paths that don't belong to a single repo, paths currently in motion
  this session pending a follow-up that will land in their proper
  home, and cross-cutting work that genuinely spans multiple repos
  with no single home.
- **Don't track here:** files owned by other repos (those repos have
  their own `SESSION_STATE.md`), bug lists for other repos (file as
  GitHub issues on the target repo), reference docs for delegated
  work, PRs and deferred work clearly owned by a single other repo.
- **Cross-ref instead of mirroring:** if a one-line pointer is needed,
  use the repo name (e.g., "AWS migration: see `tool_aws_vdc`"). Do
  NOT pin paths inside another repo, they go silently stale on
  rename.

Why: mirroring other repos' state creates drift risk and bloats the
file with entries the next session does not need. Each repo's own
session-save discipline is the right home for its own state.

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
- Fresh `Accomplished` entries from THIS session are fine; they age out
  on the next `/session-save` once the work has a real home (commit,
  PR, issue, memory file).
- Length is whatever the work requires. Compress when nothing more needs
  to be said; expand when the next session needs commit hashes, PR
  numbers, per-repo state, or decision rationale to resume cleanly.
- Pruning signal: if the file passes ~100 to 150 lines and `Next Steps`
  is short, that is a cue to prune `Accomplished` aggressively and
  audit `Open Items` / `Key Paths` for stale cross-repo entries.
  Forward-work density should dominate, not backstory.
- No em dashes anywhere. Use commas, parentheses, colons, periods, or
  semicolons. See `~/.claude/rules/core.md`.

---

## Step 4: Confirm

After writing the file, print a single line:

```
SESSION_STATE.md written, {N} lines.
```

Do not summarize the contents, the user can read the file.
