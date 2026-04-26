---
name: verify-backup
description: Check all local repos under {projects_root} for unpushed commits, uncommitted changes, and stashes. Returns CLEAN or NEEDS ATTENTION.
---

# /verify-backup, Verify All Repos Are Backed Up

You are checking every Git repository under the user's projects directories to ensure nothing is at risk of being lost. This skill is also called by /pr-create and /merge-complete. Follow every step in order.

---

## Step 1: Resolve `{projects_root}` and `{github_username}`

Read `~/.claude/config.json` (written by Phase 3 of `cfg_dev_environment`). Use its `projects_root` and `github_username` keys to build the list of root directories to walk. Do NOT hard-code `~/projects` or any specific username; the values vary per machine.

PowerShell:
```powershell
$cfg = Get-Content "$HOME/.claude/config.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$projectsRoot   = $cfg.projects_root
$githubUsername = $cfg.github_username
```

Bash:
```bash
projects_root=$(jq -r '.projects_root'   ~/.claude/config.json)
github_username=$(jq -r '.github_username' ~/.claude/config.json)
```

If either value is missing or `~/.claude/config.json` does not exist, abort with a single line: `verify-backup: ~/.claude/config.json missing projects_root or github_username; run Phase 3 of cfg_dev_environment first.`

## Step 2: Locate All Git Repositories

Walk the following root directories (built from the resolved values) and find every Git repository:
- `{projects_root}/{github_username}/`     (personal repos)
- `{projects_root}/client/`                 (client repos)
- `{projects_root}/arduino/upstream/`       (Arduino upstream forks)
- `{projects_root}/arduino/custom/`         (Arduino custom work)

To detect whether a directory is a Git repo, test for the presence of a `.git` directory or file. In PowerShell:
```powershell
Get-ChildItem -Path $projectsRoot -Recurse -Depth 4 -Filter ".git" -Force |
    ForEach-Object { $_.Parent.FullName }
```

Or in bash:
```bash
find "${projects_root}" -maxdepth 5 -name ".git" -type d | sed 's/\/.git$//'
```

If any of the root directories does not exist, note it in the report as "directory not found" and skip it.

Store the list of found repo paths as `{repos}`.

---

## Step 3: Check Each Repository

For each repo path `{repo}` in `{repos}`, run the following three checks. Use `git -C {repo}` to run git commands in that directory without changing the working directory.

### 3a. Uncommitted Changes
```
git -C {repo} status --porcelain
```
If output is non-empty, this repo has uncommitted changes. Note the count of changed files.

### 3b. Unpushed Commits on Current Branch
```
git -C {repo} log @{u}..HEAD --oneline
```
If this command errors (e.g., no upstream configured), try:
```
git -C {repo} log origin/main..HEAD --oneline
```
If output is non-empty, count the unpushed commits.

If there is no upstream at all (newly initialized repo), mark as "no remote configured."

### 3c. Stashed Changes
```
git -C {repo} stash list
```
If output is non-empty, count the stash entries.

### 3d. Last Commit Date (for context)
```
git -C {repo} log -1 --format="%cr" 2>/dev/null || echo "no commits"
```

---

## Step 4: Build the Report Table

Format results as a markdown table:

```
| Repo                              | Uncommitted | Unpushed | Stashes | Last Commit | Status         |
|-----------------------------------|-------------|----------|---------|-------------|----------------|
| {github_username}/lib_sensor_utils| 0           | 0        | 0       | 2 hours ago | CLEAN          |
| {github_username}/tool_deploy     | 3 files     | 2        | 1       | 5 days ago  | NEEDS ATTENTION|
| client/app_dashboard              | 0           | 0        | 0       | 1 week ago  | CLEAN          |
| arduino/custom/fw_flight_ctrl     | 0           | 1        | 0       | 3 days ago  | NEEDS ATTENTION|
```

Rules for the Status column:
- CLEAN: uncommitted = 0, unpushed = 0, stashes = 0
- NEEDS ATTENTION: any value is non-zero, OR no remote configured

Use short repo names (strip the `{projects_root}/` prefix for readability).

---

## Step 5: Flag Issues

After the table, list every repo that NEEDS ATTENTION with specific details. Use the resolved `{projects_root}` value in the Suggested action commands so the path is copy-paste-correct on this machine:

```
Issues found:

  {github_username}/tool_deploy_helper
    - 3 files with uncommitted changes
    - 2 unpushed commits on current branch
    - 1 stash entry (may contain lost work)
    Suggested action: git -C {projects_root}/{github_username}/tool_deploy_helper status

  arduino/custom/fw_flight_ctrl
    - 1 unpushed commit
    Suggested action: git -C {projects_root}/arduino/custom/fw_flight_ctrl push
```

---

## Step 6: Return Overall Status

Print one of the following as the final line, clearly formatted:

```
Overall status: CLEAN
```
or
```
Overall status: NEEDS ATTENTION, {count} repo(s) require action
```

This return value is used by other skills (/pr-create, /merge-complete) to decide whether to proceed. When called from another skill, if the status is NEEDS ATTENTION, those skills should stop and direct the user here first.
