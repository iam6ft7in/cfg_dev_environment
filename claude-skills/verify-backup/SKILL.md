---
name: verify-backup
description: Check all local repos across ~/projects/ for unpushed commits, uncommitted changes, and stashes. Returns CLEAN or NEEDS ATTENTION.
---

# /verify-backup — Verify All Repos Are Backed Up

You are checking every Git repository under the user's projects directories to ensure nothing is at risk of being lost. This skill is also called by /pr-create and /merge-complete. Follow every step in order.

---

## Step 1: Locate All Git Repositories

Walk the following root directories and find every Git repository:
- `~/projects/personal/`
- `~/projects/client/`
- `~/projects/arduino/upstream/`
- `~/projects/arduino/custom/`

Resolve `~` to the actual home directory path (use `$HOME` in PowerShell or `~` in Git Bash).

To detect whether a directory is a Git repo, test for the presence of a `.git` directory or file. In PowerShell:
```powershell
Get-ChildItem -Path "$HOME\projects" -Recurse -Depth 2 -Filter ".git" -Force | ForEach-Object { $_.Parent.FullName }
```

Or in bash:
```bash
find ~/projects -maxdepth 3 -name ".git" -type d | sed 's/\/.git$//'
```

If any of the root directories does not exist, note it in the report as "directory not found" and skip it.

Store the list of found repo paths as `{repos}`.

---

## Step 2: Check Each Repository

For each repo path `{repo}` in `{repos}`, run the following three checks. Use `git -C {repo}` to run git commands in that directory without changing the working directory.

### 2a. Uncommitted Changes
```
git -C {repo} status --porcelain
```
If output is non-empty, this repo has uncommitted changes. Note the count of changed files.

### 2b. Unpushed Commits on Current Branch
```
git -C {repo} log @{u}..HEAD --oneline
```
If this command errors (e.g., no upstream configured), try:
```
git -C {repo} log origin/main..HEAD --oneline
```
If output is non-empty, count the unpushed commits.

If there is no upstream at all (newly initialized repo), mark as "no remote configured."

### 2c. Stashed Changes
```
git -C {repo} stash list
```
If output is non-empty, count the stash entries.

### 2d. Last Commit Date (for context)
```
git -C {repo} log -1 --format="%cr" 2>/dev/null || echo "no commits"
```

---

## Step 3: Build the Report Table

Format results as a markdown table:

```
| Repo                              | Uncommitted | Unpushed | Stashes | Last Commit | Status         |
|-----------------------------------|-------------|----------|---------|-------------|----------------|
| personal/lib_sensor_utils         | 0           | 0        | 0       | 2 hours ago | CLEAN          |
| personal/tool_deploy_helper       | 3 files     | 2        | 1       | 5 days ago  | NEEDS ATTENTION|
| client/app_dashboard             | 0           | 0        | 0       | 1 week ago  | CLEAN          |
| arduino/custom/fw_flight_ctrl     | 0           | 1        | 0       | 3 days ago  | NEEDS ATTENTION|
```

Rules for the Status column:
- CLEAN: uncommitted = 0, unpushed = 0, stashes = 0
- NEEDS ATTENTION: any value is non-zero, OR no remote configured

Use short repo names (strip the `~/projects/` prefix for readability).

---

## Step 4: Flag Issues

After the table, list every repo that NEEDS ATTENTION with specific details:

```
Issues found:

  personal/tool_deploy_helper
    - 3 files with uncommitted changes
    - 2 unpushed commits on current branch
    - 1 stash entry (may contain lost work)
    Suggested action: git -C ~/projects/personal/tool_deploy_helper status

  arduino/custom/fw_flight_ctrl
    - 1 unpushed commit
    Suggested action: git -C ~/projects/arduino/custom/fw_flight_ctrl push
```

---

## Step 5: Return Overall Status

Print one of the following as the final line, clearly formatted:

```
Overall status: CLEAN
```
or
```
Overall status: NEEDS ATTENTION — {count} repo(s) require action
```

This return value is used by other skills (/pr-create, /merge-complete) to decide whether to proceed. When called from another skill, if the status is NEEDS ATTENTION, those skills should stop and direct the user here first.
