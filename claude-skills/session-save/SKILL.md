---
name: session-save
description: Write or update SESSION_STATE.md — what was accomplished, blockers, key paths touched, and exact next steps. Keeps the file under 100 lines.
---

# /session-save — Save Session State

Write or overwrite `SESSION_STATE.md` in the current working directory with a
concise snapshot of this session. The file must stay under 100 lines.

---

## Step 1: Gather Context

Do NOT ask the user any questions. Derive everything from the conversation history
and the current repo state:

- **Accomplished** — actions completed in this session (commits, PRs, files created,
  config applied, decisions made).
- **Open items** — anything started but not finished, blocked, or deferred. Include
  PR URLs, issue numbers, and manual steps that cannot be automated.
- **Key paths** — files and directories that were created or meaningfully changed.
  Repo-relative paths are preferred; absolute paths for out-of-repo locations
  (OneDrive scripts, ~/.claude/, etc.).
- **Next steps** — ordered, concrete actions the user should take to resume. Each
  step must be actionable without re-reading the full conversation. Include exact
  commands, PR URLs, or skill names (e.g., `/merge-complete`) where relevant.

---

## Step 2: Write SESSION_STATE.md

Write the file using this exact structure. Omit any section that has nothing to
report (e.g., no blockers → omit Open Items).

```markdown
# Session State — {YYYY-MM-DD}

## Accomplished
- {bullet per completed action}

## Open Items
- **{item}** — {why it is blocked or pending}
  → {URL or command to resume}

## Key Paths
| Item | Path |
|------|------|
| {label} | `{path}` |

## Next Steps
1. {first action — most urgent or blocking}
2. {second action}
...
```

Rules:
- Date must be today's date in `YYYY-MM-DD` format.
- Bullets are past-tense for Accomplished, imperative for Next Steps.
- Keep every line under 100 characters.
- Total file must be under 100 lines.
- Do not include meta-commentary, pleasantries, or filler.

---

## Step 3: Confirm

After writing the file, print a single line:

```
SESSION_STATE.md written — {N} lines.
```

Do not summarize the contents — the user can read the file.
