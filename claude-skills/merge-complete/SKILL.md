---
name: merge-complete
description: Full post-merge cleanup after a PR has been merged on GitHub, switch to main, pull, clean branches, close linked issue, and verify backup.
---

# /merge-complete, Post-Merge Cleanup

You are performing post-merge cleanup after a PR has been merged on GitHub. Follow every step in order. Show each command before running it.

---

## Step 1: Verify the PR Was Merged

Show the user the 5 most recently merged PRs so they can confirm which one was merged:
```
gh pr list --state merged --limit 5
```

Ask the user: "Has your PR been merged on GitHub? (yes/no)"
- If no: stop. "Complete the merge on GitHub first, then run /merge-complete."
- If yes: ask them to confirm the PR number or title so you know which PR was merged. Store as `{pr_title}`.

---

## Step 2: Identify the Linked Issue

Check the current branch name for a type prefix pattern (e.g., `feat/add_login`).

Look for a linked issue:
1. Check the current branch name, if it was created with /new-feature, the issue may be trackable.
2. Run:
   ```
   git log --oneline -10
   ```
   Look for `#\d+` in commit messages.
3. Ask the user: "What GitHub issue number is linked to this PR? Enter a number or press Enter if none."

Store as `{issue_number}` (may be empty).

---

## Step 3: Switch to Main

Run:
```
git checkout main
```

Confirm the switch succeeded:
```
git branch --show-current
```
Output must be `main`. If not, stop and report the error.

---

## Step 4: Pull Latest Changes

Run:
```
git pull
```

This pulls the squash-merged commit from GitHub. Confirm there are no merge conflicts or errors before continuing.

---

## Step 5: Clean Up Merged Branches

Run the /cleanup-branches skill now.

If /cleanup-branches is not available, perform the steps manually:

```
git branch --merged main
```

Show the list to the user, filtered to exclude `main`. Ask: "Delete these branches? (yes/no)"

If yes, delete each one:
```
git branch -d {branch}
```

Then prune remote refs:
```
git fetch --prune
```

---

## Step 6: Move Issue to "Done" on Projects Board

If `{issue_number}` is set and a Projects board is linked to this repo, update the issue status to "Done" using the Projects v2 API via `gh`.

If the CLI does not support this directly, tell the user: "Please manually move issue #{issue_number} to Done on the Projects board."

---

## Step 7: Close the Linked GitHub Issue

If `{issue_number}` is set, run:
```
gh issue close {issue_number} --comment "Resolved in merged PR: {pr_title}"
```

Confirm the issue is now closed.

---

## Step 8: Verify Backup

Run the /verify-backup skill. Confirm it returns CLEAN for all repos (or at least for the current repo).

If /verify-backup is not available, manually check:
```
git status --porcelain
git log @{u}..HEAD --oneline
```
Both should return empty output.

---

## Step 9: Final Summary

Print a clean summary:

```
Merge complete.

  Merged PR:    {pr_title}
  Issue closed: #{issue_number}, moved to Done
  Current HEAD: {output of git log -1 --oneline}
  Backup:       CLEAN

You are now on main with a clean working tree.
```

If no issue was linked:
```
Merge complete.

  Merged PR:    {pr_title}
  Issue:        (none linked)
  Current HEAD: {output of git log -1 --oneline}
  Backup:       CLEAN

You are now on main with a clean working tree.
```
