---
name: sync-upstream
description: Sync an ArduPilot fork with the upstream ArduPilot repository by fetching upstream commits and rebasing the local branch.
---

# /sync-upstream — Sync ArduPilot Fork With Upstream

You are syncing a forked ArduPilot repository with the canonical upstream source. This operation rewrites history via rebase. Follow every step carefully. Show each command before running it.

---

## Step 1: Verify This Is an ArduPilot-Related Repository

Check the following indicators:
- Current directory path contains `arduino/upstream` or `ardupilot`
- A `params/` directory exists at the repo root
- A `Tools/` or `ArduCopter/` directory exists at the repo root
- The existing remote URL references `ArduPilot/ardupilot`

Run:
```
git remote -v
pwd
ls
```

If none of these indicators are present, ask the user: "This does not appear to be an ArduPilot repository. Are you sure you want to run sync-upstream here? (yes/no)"
- If no: stop.
- If yes: continue with caution.

---

## Step 2: Check for Uncommitted Changes

Run:
```
git status --porcelain
```

If there are uncommitted changes, stop: "You have uncommitted changes. Please commit or stash them before syncing with upstream."

Suggest:
```
git stash push -m "WIP before upstream sync"
```
Then run /sync-upstream again after stashing.

---

## Step 3: Verify or Add the Upstream Remote

Run:
```
git remote -v
```

Look for a remote named `upstream`.

If `upstream` is NOT listed:
- Ask the user: "No upstream remote found. What is the upstream URL?"
- For ArduPilot Copter, suggest: `https://github.com/ArduPilot/ardupilot.git`
- Wait for the user to confirm or provide the URL.
- Add the remote:
  ```
  git remote add upstream {upstream_url}
  ```

If `upstream` IS listed, show the user its URL and ask them to confirm it is correct before proceeding.

---

## Step 4: Fetch Upstream

Run:
```
git fetch upstream
```

Report any errors. If the fetch fails (e.g., network error), stop and ask the user to check their internet connection and try again.

---

## Step 5: Report Ahead/Behind Status

Determine how many commits this branch is ahead of and behind upstream/master:
```
git rev-list --left-right --count upstream/master...HEAD
```

The output is `{behind}\t{ahead}`. Report to the user:
```
Sync status:
  Behind upstream/master: {behind} commit(s)
  Ahead of upstream/master: {ahead} commit(s) (your local changes)
```

If behind count is 0, tell the user: "Already up to date with upstream. No sync needed." and stop.

---

## Step 6: Confirm Before Rebasing

This is a high-impact operation. Rebase rewrites commit history.

Ask the user:
```
Proceeding will rebase your {ahead} local commit(s) on top of {behind} new upstream commit(s).
This rewrites your local commit history.

Are you sure you want to proceed? (yes/no)
```

- If no: stop. "Sync cancelled. Your branch is unchanged."
- If yes: continue.

---

## Step 7: Rebase Onto Upstream Master

Run:
```
git rebase upstream/master
```

**If the rebase succeeds:** continue to Step 8.

**If the rebase encounters conflicts:**
- Stop immediately. Do NOT attempt to auto-resolve conflicts.
- Run:
  ```
  git diff --name-only --diff-filter=U
  ```
- List every conflicting file clearly.
- Instruct the user:
  1. Open each conflicting file in your editor.
  2. Resolve the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
  3. After resolving each file: `git add {filename}`
  4. Once all files are resolved: `git rebase --continue`
  5. If you want to abort and return to the previous state: `git rebase --abort`
- Stop and wait. Do not run further commands.

---

## Step 8: Push Updated Branch

Use `--force-with-lease` (safer than `--force` — it will refuse to push if someone else has pushed in the meantime):
```
git push --force-with-lease origin main
```

If the push fails because the remote has changed since the last fetch, report the error and ask the user how to proceed.

---

## Step 9: Report Completion

Run:
```
git log -1 --oneline
```

Print a summary:
```
Upstream sync complete.

  New HEAD:             {git log -1 --oneline output}
  Commits applied:      {ahead} local commit(s) rebased
  Upstream commits:     {behind} new commit(s) integrated
  Remote:               origin main updated
```
