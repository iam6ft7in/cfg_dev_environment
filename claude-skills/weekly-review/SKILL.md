---
name: weekly-review
description: Comprehensive weekly digest of all projects, repo health, open issues and PRs, recent activity, milestones, backup status, and last gitleaks scan.
---

# /weekly-review, Weekly Project Digest

You are generating a comprehensive weekly review of all projects. Run each section in sequence and compile everything into a single clean markdown report. Show progress as you go ("Running Section 1: Repo Health...").

---

## Section 1: Repo Health

Find all Git repositories under:
- `~/projects/personal/`
- `~/projects/client/`
- `~/projects/arduino/upstream/`
- `~/projects/arduino/custom/`

For each repo, collect:

**a. Uncommitted changes:**
```
git -C {repo} status --porcelain
```

**b. Unpushed commits:**
```
git -C {repo} log @{u}..HEAD --oneline 2>/dev/null | wc -l
```

**c. Last commit date:**
```
git -C {repo} log -1 --format="%ci %s" 2>/dev/null
```

**d. Flag inactive repos:**
If the last commit is more than 30 days ago, mark the repo as INACTIVE.

Format as a table:
```
| Repo | Last Commit | Days Ago | Uncommitted | Unpushed | Status   |
|------|-------------|----------|-------------|----------|----------|
| ...  | ...         | ...      | ...         | ...      | Active   |
| ...  | ...         | 45 days  | ...         | ...      | INACTIVE |
```

---

## Section 2: Open Issues

For each GitHub account (personal, client), run:
```
gh issue list --state open --limit 50 --json number,title,repository,createdAt,labels
```

Group results by repository. Display:
```
### personal/lib_sensor_utils
  #12 feat: add temperature calibration (opened 3 days ago)
  #8  fix: handle null sensor input (opened 10 days ago)

### client/app_dashboard
  (no open issues)
```

Show total open issue count at the end of this section.

---

## Section 3: Open Pull Requests

For each GitHub account, run:
```
gh pr list --state open --json number,title,headRefName,createdAt,reviewDecision,isDraft
```

For each open PR, show: title, branch, how many days it has been open, and review status (Approved / Changes Requested / Pending / Draft).

```
### personal/tool_deploy_helper
  #5 feat: add retry logic (feat/add_retry_logic), 2 days open, Pending review
```

Flag any PR open for more than 7 days as STALE.

---

## Section 4: Recent Activity (Last 7 Days)

For each repo, show commits from the last 7 days:
```
git -C {repo} log --since="7 days ago" --oneline --all
```

Format as:
```
| Repo | Commits (7d) | Last Author | Latest Message |
|------|-------------|-------------|----------------|
| personal/lib_sensor_utils | 5 | you | feat: add temp cal |
| personal/tool_deploy_helper | 0 |, |, |
```

Highlight any repo with 0 commits in the last 7 days if it has open issues or PRs (it may be stalled).

---

## Section 5: Upcoming Milestones

For each repo in each GitHub account, fetch milestones:
```
gh api repos/{owner}/{repo}/milestones --jq '.[] | {title, due_on, open_issues, closed_issues}'
```

Show milestones due within the next 14 days:
```
### personal/lib_sensor_utils
  "v1.0 Release", due in 5 days, 3 open issues remaining
```

If no milestones are due within 14 days, show: "(no milestones due within 14 days)"

---

## Section 6: Backup Status

Run the /verify-backup skill and include its full output verbatim in this section.

If /verify-backup is unavailable, manually run the equivalent checks (see /verify-backup for the procedure) and produce the same table and status output.

---

## Section 7: Last Gitleaks Scan

Gitleaks runs on a weekly Task Scheduler task. Check the log file at:
```
~/.claude/logs/gitleaks-scan.log
```
Or check common alternative locations:
- `~/logs/gitleaks.log`
- `C:\ProgramData\gitleaks\scan.log`

Read the last 20 lines:
```powershell
Get-Content "$HOME\.claude\logs\gitleaks-scan.log" -Tail 20
```

Report:
- Last scan date and time
- Repos scanned
- Number of findings (leaks detected)
- If findings > 0: list the affected files and secret types (do NOT print the actual secret values)

If the log file does not exist: "Gitleaks log not found. Verify Task Scheduler task is configured and has run at least once."

---

## Final Report Format

Compile all sections into a single markdown document with this header:

```markdown
# Weekly Project Review
Generated: {current date and time}

---

## 1. Repo Health
{section 1 content}

---

## 2. Open Issues
{section 2 content}

---

## 3. Open Pull Requests
{section 3 content}

---

## 4. Recent Activity (Last 7 Days)
{section 4 content}

---

## 5. Upcoming Milestones
{section 5 content}

---

## 6. Backup Status
{section 6 content}

---

## 7. Last Gitleaks Scan
{section 7 content}

---

## Summary

| Area | Status |
|------|--------|
| Repo Health | {X repos active, Y inactive} |
| Open Issues | {count} |
| Open PRs | {count} |
| Backup | CLEAN / NEEDS ATTENTION |
| Gitleaks | Clean / {N} finding(s) |
```
