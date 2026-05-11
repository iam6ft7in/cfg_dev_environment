---
name: merge-complete
description: Pre-merge guard for stacked PRs plus full post-merge cleanup, switch to main, pull, retarget dependents, clean branches, close linked issue, verify backup.
---

# /merge-complete, PR Merge + Post-Merge Cleanup

You are guiding the user through merging a PR safely (especially when it has open dependent PRs in a stack) and then performing post-merge cleanup. Follow every step in order. Show each command before running it.

This skill can be invoked before OR after the merge happens on GitHub. Step 1 detects which mode applies.

---

## Why this skill exists, two stacked-PR landmines

These two facts came from a real merge that surprised the user. Trust them and do not re-litigate them inside this skill.

### Landmine 1, `--delete-branch` on a parent PR closes its dependents unrecoverably

When you squash-merge a parent PR with `--delete-branch` (CLI flag) or "Delete branch" (UI button), GitHub deletes the head branch. Any open PR whose `base` was that branch is automatically closed. The dependent PRs cannot be re-opened with their original numbers; you have to create new PRs with new numbers, losing review history and CI runs on the old numbers. Either omit `--delete-branch` on parents that have open dependents, or accept that dependents get new PR numbers.

### Landmine 2, squash-merged local branches need a force delete, but the hook blocks the literal pattern

Squash-merging creates a new commit on main whose SHA differs from the source branch's tip. The source branch's tip is therefore NOT in main's ancestry. `git branch -d` refuses with "not fully merged". `git branch -D` (force) works, but the destructive-bash hook (`~/.claude/hooks/guard-destructive-bash.ps1`) blocks the literal string `git branch -D` regardless of context. The correct tool is `/cleanup-branches`, which uses `git update-ref -d refs/heads/<branch>` and bypasses both problems. Do not fall back to `git branch -d` or `-D` inside this skill.

---

## Step 1: Identify the PR and Its State

Ask the user: "Which PR are we handling? Enter a PR number, or press Enter to use the PR associated with the current branch."

If a number was entered, use it. Otherwise resolve from the current branch:

```
gh pr view --json number,title,headRefName,baseRefName,state -q '.'
```

Store as `{pr_number}`, `{pr_title}`, `{head_branch}`, `{base_branch}`, `{pr_state}`.

Branch on `{pr_state}`:
- `OPEN`: continue to Step 2 (pre-merge guard).
- `MERGED`: jump to Step 5 (post-merge flow).
- `CLOSED`: stop. "PR was closed without merging. Nothing to clean up via this skill."

---

## Step 2: Pre-Merge Guard, Detect Open Dependents

Before merging an OPEN PR, check whether any other open PRs use this PR's head branch as their base:

```
gh pr list --state open --base {head_branch} --json number,title,headRefName
```

If the result is empty, jump to Step 4 (no stack issue, normal merge path).

If the result is non-empty, this PR has open dependents. Print them with numbers and titles, then present the three options.

---

## Step 3: Stack Detected, Three-Option Prompt

Print:

```
This PR has open dependents:
  #{n}  {title}  (head: {headRefName})
  ...

Squash-merging with --delete-branch will CLOSE these dependents.
Three options:
  a. Merge without --delete-branch; clean up branch later.
  b. Cancel.
  c. Auto-handle: retarget dependents to the new base, rebase,
     force-push. Only viable if you've authorized force-push for
     those branches.
```

Ask: "Choose a, b, or c. Press Enter for a (default)."

Store the choice as `{guard_choice}`. Store the dependents as `{dependents}` for later retargeting.

### If `{guard_choice}` is `a` (default)

Tell the user:
```
Squash-merge PR #{pr_number} on GitHub WITHOUT "Delete branch"
(or use `gh pr merge {pr_number} --squash` without --delete-branch).
After the merge lands, re-run /merge-complete and the skill will
retarget the dependents and clean up the parent branch.
```
Stop. User resumes the skill after merging.

### If `{guard_choice}` is `b`

Print: "Cancelled. No changes made." Stop.

### If `{guard_choice}` is `c`

Confirm explicitly with the user: "Force-push is authorized for these branches: {list of dependent head branches}? (yes/no)". If no, fall back to option `a` and stop.

If yes, for each dependent (in the order returned by `gh pr list`):

1. `gh pr edit {dependent_number} --base main`
2. `git fetch origin main`
3. `git checkout {dependent_head}`
4. Try `git rebase origin/main`. If it fails with conflicts that the user did not anticipate, run `git rebase --abort`, report the conflict, and ask whether to continue with the remaining dependents or stop.
5. `git push --force-with-lease origin {dependent_head}`

After all dependents are retargeted and force-pushed, tell the user:
```
Dependents retargeted to main and force-pushed. You can now squash-
merge PR #{pr_number} normally (--delete-branch is safe). Re-run
/merge-complete after the merge.
```
Stop.

---

## Step 4: Wait for Normal Merge (No Dependents Path)

No dependents detected. Tell the user:
```
No open dependents on {head_branch}. Squash-merge PR #{pr_number}
on GitHub (--delete-branch is safe). Return after the merge lands.
```
Stop. User resumes the skill after merging.

---

## Step 5: Confirm the Merge Landed

Verify the PR is actually merged before doing any cleanup:

```
gh pr view {pr_number} --json state,mergedAt -q '.'
```

`state` must be `MERGED`. If not, stop and report what you saw.

---

## Step 6: Identify the Linked Issue

Look for a linked issue from the PR's closing references first:

```
gh pr view {pr_number} --json closingIssuesReferences -q '.closingIssuesReferences[].number'
```

If empty, fall back to the original heuristics:
1. Check the head branch name pattern (e.g., `feat/add_login`).
2. `git log --oneline -10` and look for `#\d+` in commit messages.
3. Ask the user: "What GitHub issue number is linked to this PR? Enter a number or press Enter if none."

Store as `{issue_number}` (may be empty).

---

## Step 7: Switch to Main and Pull

```
git checkout main
git pull
```

Confirm `git branch --show-current` returns `main`. Confirm pull succeeded.

---

## Step 8: Retarget Stale Dependents (option `a` aftermath)

If the user picked option `a` in Step 3 (or merged without `--delete-branch` for any reason), the parent's head branch was not auto-deleted, but the parent's content is now on main. Any dependents still pointing at the parent's head branch should be retargeted to main so they become standalone PRs against the merged base.

Check for dependents still based on the merged head branch:

```
gh pr list --state open --base {head_branch} --json number,headRefName
```

For each result, retarget to main:

```
gh pr edit {n} --base main
```

Report how many were retargeted (or "none" if the list was empty).

If the parent's head branch still exists on origin and the user wants it gone, delete it explicitly so `/cleanup-branches` will see the local branch as `[gone]` on the next fetch:

```
gh api -X DELETE repos/{owner}/{repo}/git/refs/heads/{head_branch}
```

Ask before running this; deleting a remote branch is a shared-state action.

---

## Step 9: Clean Up Local Merged Branches

Run the `/cleanup-branches` skill.

Do NOT fall back to `git branch -d` or `git branch -D` inline. See Landmine 2 above for why. If `/cleanup-branches` is somehow unavailable, tell the user to run it manually rather than emulating it here with the wrong tools.

---

## Step 10: Move Issue to "Done" on Projects Board

If `{issue_number}` is set and a Projects board is linked to this repo, update the issue status to "Done" using the Projects v2 API via `gh`.

If the CLI does not support this directly, tell the user: "Please manually move issue #{issue_number} to Done on the Projects board."

---

## Step 11: Close the Linked GitHub Issue

If `{issue_number}` is set, run:

```
gh issue close {issue_number} --comment "Resolved in merged PR: {pr_title}"
```

Confirm the issue is now closed.

---

## Step 12: Verify Backup

Run the `/verify-backup` skill. Confirm CLEAN for the current repo.

If `/verify-backup` is not available, manually:

```
git status --porcelain
git log '@{u}..HEAD' --oneline
```

Both should return empty output.

---

## Step 13: Final Summary

Print:

```
Merge complete.

  Merged PR:    #{pr_number} {pr_title}
  Dependents:   {n retargeted, or "none"}
  Issue closed: #{issue_number}, moved to Done
  Current HEAD: {output of git log -1 --oneline}
  Backup:       CLEAN

You are now on main with a clean working tree.
```

If no issue was linked, replace the Issue line with:

```
  Issue:        (none linked)
```

If no dependents were retargeted, omit the Dependents line.
