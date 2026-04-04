---
name: pr-create
description: Create a pull request with full automation — pre-flight checks, linting, PR template population, issue linking, and Projects board update.
---

# /pr-create — Create a Pull Request

You are creating a pull request for the current branch. Follow every step in order. Do not skip pre-flight checks. Show each command before running it.

---

## Step 1: Pre-Flight Checks

Run all checks in this section before doing anything else. If any check fails, stop and report the issue clearly. Do not create the PR until all checks pass.

### 1a. Verify Backup Status
Run the /verify-backup skill. If it returns NEEDS ATTENTION, stop and report:
"There are unpushed commits or uncommitted changes in one or more repos. Resolve these before creating a PR."

If /verify-backup is not available, run the following manually for the current repo:
```
git status --porcelain
git log @{u}..HEAD --oneline
```
If either returns output, stop and ask the user to commit and push their changes first.

### 1b. Verify Not on Main
Run:
```
git branch --show-current
```
If the output is `main`, stop: "You cannot create a PR from main. Switch to your feature branch first."

### 1c. Verify Branch Has Commits Beyond Main
Run:
```
git log main..HEAD --oneline
```
If the output is empty, stop: "This branch has no commits beyond main. There is nothing to PR."

### 1d. Detect Platform and Run Linter
Detect the platform by inspecting the repository structure:
- If `pyproject.toml` or `*.py` files exist at root: **Python**
- If `*.ps1` files exist at root or in a `scripts/` folder: **PowerShell**
- If `*.sh` files exist: **Bash**
- If `*.ino` or `*.cpp` files and a `platformio.ini` or similar: **Arduino/C++**
- Otherwise: skip linting

Run the appropriate linter:

**Python:**
```
uv run ruff check .
```
If ruff reports errors, stop: "Ruff found linting errors. Fix them before creating a PR." Show the errors.

**PowerShell:**
Check if PSScriptAnalyzer is available:
```powershell
Get-Module -ListAvailable PSScriptAnalyzer
```
If available:
```powershell
Invoke-ScriptAnalyzer -Path . -Recurse
```
Report any warnings or errors. Ask the user if they want to continue despite warnings (errors are blocking).

**Bash:**
Check if shellcheck is available:
```
shellcheck --version
```
If available, find and check all .sh files:
```
find . -name "*.sh" | xargs shellcheck
```
Report findings. Ask user if they want to continue despite warnings.

**Other/Arduino:** Skip linting.

---

## Step 2: Extract Branch Information

### 2a. Branch Name
```
git branch --show-current
```
Store as `{branch_name}`.

### 2b. Branch Type Prefix
Extract the prefix before the first `/`:
- Examples: `feat/add_login` → `feat`, `fix/null_pointer` → `fix`
- Valid prefixes: feat, fix, docs, chore, refactor, test
- If no valid prefix found, default to `feat`

Store as `{branch_type}`.

### 2c. Branch Description
Extract the part after the first `/`. Replace underscores with spaces for display.
Store as `{branch_description}`.

### 2d. Related Issue Number
Search recent commit messages for a pattern like `#123` or `closes #123`:
```
git log main..HEAD --pretty=format:"%s %b"
```
Look for `#\d+` pattern. If found, use that number as `{issue_number}`.

If not found, ask the user: "Is this branch related to a GitHub issue? Enter the issue number or press Enter to skip."

---

## Step 3: Build the PR Title

Use the most recent commit message as the default PR title:
```
git log main..HEAD --oneline | head -1
```
Strip the commit hash. Show the title to the user and ask: "PR title: `{title}`. Press Enter to accept or type a new title."

---

## Step 4: Build the PR Body

### 4a. Collect Commits
```
git log main..HEAD --oneline
```
Format each line as a markdown bullet: `- {hash} {message}`

### 4b. Populate PR Template
Use the repository's PR template at `.github/PULL_REQUEST_TEMPLATE.md` if it exists.

Fill in the template:
- **Summary section**: Insert the bullet list of commits from 4a.
- **Type of Change checkboxes**: Check the box that matches `{branch_type}`:
  - feat → `[x] New feature`
  - fix → `[x] Bug fix`
  - docs → `[x] Documentation update`
  - chore → `[x] Maintenance / chore`
  - refactor → `[x] Refactoring`
  - test → `[x] Test addition or update`
  All other checkboxes remain `[ ]`.
- **Closes line**: If `{issue_number}` was found, add: `Closes #{issue_number}`

If no template exists, build a minimal body:
```
## Summary

{bullet list of commits}

## Type of Change

- [x] {branch_type}

{Closes #{issue_number} if applicable}
```

---

## Step 5: Create the Pull Request

Run:
```
gh pr create --title "{pr_title}" --body "{pr_body}"
```

Note the PR URL from the output.

---

## Step 6: Update Projects Board

If `{issue_number}` was found and a Projects board is linked, move the issue to "In Review":
```
gh issue edit {issue_number} --add-project "{project_name}"
```
Or use the Projects v2 API to set the status to "In Review". If this is not possible via CLI, tell the user: "Please manually move issue #{issue_number} to In Review on the Projects board."

---

## Step 7: Show Result

```
Pull request created.

  PR:     {pr_url}
  Branch: {branch_name}
  Issue:  #{issue_number} — now In Review
```

If no issue was linked:
```
Pull request created.

  PR:     {pr_url}
  Branch: {branch_name}
```
