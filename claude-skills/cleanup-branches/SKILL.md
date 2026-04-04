---
name: cleanup-branches
description: Remove local branches that have been merged into main and prune stale remote-tracking refs.
---

# /cleanup-branches — Clean Up Merged Branches

You are removing local branches that have already been merged into main. This is a safe, non-destructive cleanup. Follow every step in order. Show each command before running it.

---

## Step 1: List Branches Merged Into Main

Run:
```
git branch --merged main
```

This shows all local branches whose commits are fully contained in main — meaning they are safe to delete.

---

## Step 2: Filter the List

From the output of Step 1, remove the following branches — these must never be deleted:
- `main`
- `master`
- Any branch the user explicitly tells you to keep (ask: "Are there any branches from this list you want to keep? Enter names separated by commas, or press Enter to skip.")

The remaining branches are candidates for deletion. Store as `{branches_to_delete}`.

---

## Step 3: Confirm With the User

If `{branches_to_delete}` is empty:
- Print: "No merged branches found to clean up. Nothing to do."
- Skip to Step 5.

If there are branches to delete, show them:
```
The following merged branches will be deleted:
  {list each branch on its own line}
```

Ask: "Delete these branches? (yes/no)"
- If no: print "Cleanup cancelled. No branches were deleted." and stop.
- If yes: continue.

---

## Step 4: Delete Each Branch

For each branch in `{branches_to_delete}`, run:
```
git branch -d {branch}
```

Use `-d` (safe delete), not `-D` (force delete). The `-d` flag will refuse to delete a branch that has unmerged changes, which is a safety net.

If any deletion fails with an error, report it and continue with the rest of the list. Do not stop the entire cleanup for one failure.

Keep a count of:
- Successfully deleted branches
- Failed deletions (with reasons)

---

## Step 5: Prune Remote-Tracking Refs

Fetch and prune stale remote-tracking references (refs to remote branches that no longer exist on GitHub):
```
git fetch --prune
```

This cleans up entries like `origin/feat/old_branch` that remain locally after the remote branch is deleted on GitHub.

---

## Step 6: Report

Print a summary:

```
Branch cleanup complete.

  Deleted:   {count} branch(es)
  Pruned:    remote-tracking refs updated
```

If any branches failed to delete:
```
  Skipped:   {count} branch(es) (see details above)
```

List the successfully deleted branch names and any that were skipped with their reasons.
