---
name: session-resume
description: Read SESSION_STATE.md and report what is next — the immediate next action, open blockers, and a brief re-orientation to where the session left off.
---

# /session-resume — Resume from Session State

Read `SESSION_STATE.md` in the current working directory and orient the user for
the next work session. This skill is the counterpart to `/session-save`.

---

## Step 1: Read the File

Read `SESSION_STATE.md`. If the file does not exist, say:

```
No SESSION_STATE.md found in {cwd}.
Run /session-save at the end of a session to create one.
```

Then stop.

---

## Step 2: Report

Print a concise re-orientation using only what is in the file. Use this structure:

```
Session state from {date in file}

NEXT UP
  {Step 1 from Next Steps — the single most urgent action}

FULL NEXT STEPS
  1. {step 1}
  2. {step 2}
  ...

OPEN ITEMS
  - {item} → {URL or command}

KEY PATHS
  {Item}: {path}
  ...
```

Rules:
- Do not reproduce the Accomplished section — it is history, not forward work.
- If Next Steps is empty, say: "No next steps recorded — session may be complete."
- If Open Items is empty, omit that section.
- Keep the output concise. Do not pad or editorialize.

---

## Step 3: Prompt

After the report, add one line:

```
Run /session-save to update this file before ending the session.
```
