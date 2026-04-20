---
name: apply-standard
description: Audit an existing GitHub repository against the gold standard and apply all missing pieces — scaffold files, CLAUDE.md rule imports, issue templates, linter config, branch ruleset, labels, topics, and Projects v2 board.
---

# /apply-standard — Apply Gold Standard to an Existing Repository

You are retrofitting an existing GitHub repository to meet the gold standard. Audit
first, then apply only what is missing or incorrect. Never overwrite files that already
contain project-specific content without user confirmation. Show each action before
taking it.

---

## Step 1: Gather Information

### 1a. Confirm Repository
Verify the current working directory is a git repository:
```
git rev-parse --show-toplevel
```
If not in a repo, stop: "Run /apply-standard from inside the repository you want to
update."

Detect the repo name from the remote URL:
```
git remote get-url origin
```

### 1b. Detect Platform
Inspect the repository structure to determine the platform:
- `*.ps1` files exist at root or in `src/` or `scripts/`: **powershell**
- `pyproject.toml` or `*.py` files exist: **python**
- `*.sh` files exist: **bash**
- `*.pl` or `cpanfile` exists: **perl**
- `*.vbs` files exist: **vbscript**
- `*.asm` files or `Makefile` with NASM references: **asm**
- `*.ino` or `platformio.ini` exists: **arduino**
- None of the above: **other**

Report the detected platform and ask the user to confirm or correct it.

### 1c. Confirm Identity
Present a numbered list:
1. personal/public — maps to ~/projects/personal/public/ (public GitHub repos)
2. personal/private — maps to ~/projects/personal/private/ (private GitHub repos)
3. personal/collaborative — maps to ~/projects/personal/collaborative/
4. client
5. arduino (custom)

Read the projects root from `~/.claude/config.json` (key: `projects_root`):
```powershell
$config = Get-Content "$HOME\.claude\config.json" -Raw | ConvertFrom-Json
$projectsRoot = $config.projects_root
```
If absent, fall back to `$HOME\projects`.

Derive the local path from `{projects_root}`:
- `personal/public` → `{projects_root}\personal\public\{repo_name}`
- `personal/private` → `{projects_root}\personal\private\{repo_name}`
- `personal/collaborative` → `{projects_root}\personal\collaborative\{repo_name}`
- `client` → `{projects_root}\client\{repo_name}`
- `arduino` → `{projects_root}\arduino\custom\{repo_name}`

Determine the GitHub username based on identity:
- `personal/*` → use `gh api user --jq .login`
- `client` → `client`
- `arduino` → use personal username

---

## Step 2: Audit — Check Each Gold Standard Item

Run all checks silently, then print a single audit table before making any changes.
For each item, report status as one of: PRESENT, MISSING, or NEEDS UPDATE.

### File Checklist

| Item | Check |
|------|-------|
| `.gitattributes` | File exists |
| `.gitignore` | File exists |
| `.editorconfig` | File exists |
| `README.md` | File exists |
| `CHANGELOG.md` | File exists |
| `CONTRIBUTING.md` | File exists |
| `SECURITY.md` | File exists |
| `CLAUDE.md` | File exists AND contains `@~/.claude/rules/core.md` |
| `.claude/rules/project.md` | File exists (any name is acceptable) |
| `.github/pull_request_template.md` | File exists |
| `.github/ISSUE_TEMPLATE/bug_report.md` | File exists |
| `.github/ISSUE_TEMPLATE/feature_request.md` | File exists |
| `.github/ISSUE_TEMPLATE/task.md` | File exists |
| Platform linter config | `.ps-scriptanalyzer.psd1` (powershell), `.shellcheckrc` (bash), `ruff` section in `pyproject.toml` (python), etc. |
| Git hooks | `.git/hooks/commit-msg` and `.git/hooks/pre-commit` exist and are executable |
### GitHub Checklist (requires `gh` CLI)

| Item | Check |
|------|-------|
| Branch ruleset on `main` | `gh api repos/{username}/{repo}/rulesets` — look for a ruleset targeting `main` |
| Standard labels present | `gh label list --repo {username}/{repo}` — check for: feat, fix, docs, chore, refactor, test, ci, breaking |
| Topics applied | `gh repo view {username}/{repo} --json repositoryTopics` — check for platform topic |
| Projects v2 board | `gh project list --owner {username} --format json --limit 100` — look for a project titled `{repo_name} Board`. Also verify its Status field has the 5 standardized options in order: Backlog, Todo, In Progress, In Review, Done |

### CLAUDE.md Rule Import Check

A gold standard CLAUDE.md must contain all of the following lines (uncommented):
```
@~/.claude/rules/core.md
@~/.claude/rules/{platform}.md
@.claude/rules/project.md
```
(Platform rules only apply if a platform-specific rules file exists:
`~/.claude/rules/powershell.md`, `~/.claude/rules/python.md`, etc.)

If any import is missing, mark CLAUDE.md as NEEDS UPDATE.

---

## Step 3: Present Audit Results and Confirm

Print the audit table in this format:

```
Gold Standard Audit — {repo_name}
──────────────────────────────────────────────────────
  .gitattributes                         PRESENT
  .gitignore                             PRESENT
  .editorconfig                          MISSING
  README.md                              MISSING
  CHANGELOG.md                           PRESENT
  CONTRIBUTING.md                        PRESENT
  SECURITY.md                            PRESENT
  CLAUDE.md (rule imports)               NEEDS UPDATE
  .claude/rules/project.md              PRESENT
  .github/pull_request_template.md       PRESENT
  .github/ISSUE_TEMPLATE/bug_report.md   MISSING
  .github/ISSUE_TEMPLATE/feature_request MISSING
  .github/ISSUE_TEMPLATE/task.md         MISSING
  Platform linter config                 MISSING
  Git hooks                              PRESENT
  Branch ruleset (main)                  MISSING
  Standard labels                        MISSING
  Platform topic                         MISSING
  Projects v2 board                      MISSING
──────────────────────────────────────────────────────
  9 present   12 need action
```

Ask: "Apply all fixes now? (yes/no)"

If the user says no, stop.

---

## Step 4: Apply Fixes

Work through every MISSING or NEEDS UPDATE item. Show each action before taking it.
If a step fails, report the error and continue to the next item — do not abort.

### 4a. .gitattributes
If missing, copy from `~/.claude/templates/project/.gitattributes`.

### 4b. .gitignore
If missing, copy the base `.gitignore` from `~/.claude/templates/project/.gitignore`.
Then, if a platform-specific `.gitignore` exists at
`~/.claude/templates/project/platforms/{platform}/.gitignore`, append its contents.

### 4c. .editorconfig
If missing, copy from `~/.claude/templates/project/.editorconfig`.

### 4d. README.md
If missing, copy from `~/.claude/templates/project/README.md` and replace placeholders:
- `{{REPO_NAME}}` → the repository name
- `{{DESCRIPTION}}` → ask the user for a one-sentence description if not already known
- `{{PLATFORM}}` → the detected platform

### 4e. CHANGELOG.md
If missing, create with this content:
```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]
```

### 4f. CONTRIBUTING.md
If missing, copy from `~/.claude/templates/project/CONTRIBUTING.md` and replace
`{{REPO_NAME}}` with the repository name.

### 4g. SECURITY.md
If missing, copy from `~/.claude/templates/project/SECURITY.md`.

### 4h. CLAUDE.md — Rule Imports
If CLAUDE.md exists but is missing rule import lines, add them at the top of the file
(before any existing content), inserting only the lines that are absent:

```
@~/.claude/rules/core.md
@~/.claude/rules/{platform}.md
@.claude/rules/project.md
```

Only add `@~/.claude/rules/{platform}.md` if:
- The platform is not `other`
- The file `~/.claude/rules/{platform}.md` actually exists

Do NOT replace or reformat any existing content in CLAUDE.md — append imports only
at the top.

If CLAUDE.md does not exist at all, copy from
`~/.claude/templates/project/CLAUDE.md`, replace placeholders, and uncomment the
correct platform rule line.

### 4i. .claude/rules/project.md
If no file exists under `.claude/rules/`, copy from
`~/.claude/templates/project/.claude/rules/project.md` and replace placeholders.

If `.claude/rules/` already has files (e.g., powershell.md, security.md), it is
already serving the project.md role — mark as PRESENT and skip.

### 4j. .github/pull_request_template.md
If missing, copy from
`~/.claude/templates/project/.github/pull_request_template.md`.

### 4k. .github/ISSUE_TEMPLATE/ files
If any issue template is missing, create the `.github/ISSUE_TEMPLATE/` directory
if needed and copy the missing files from
`~/.claude/templates/project/.github/ISSUE_TEMPLATE/`.

### 4l. Platform Linter Config
Copy the appropriate file from the platform template if missing:

| Platform | File | Source |
|----------|------|--------|
| powershell | `.ps-scriptanalyzer.psd1` | `~/.claude/templates/project/platforms/powershell/.ps-scriptanalyzer.psd1` |
| bash | `.shellcheckrc` | `~/.claude/templates/project/platforms/bash/.shellcheckrc` |
| python | n/a — ruff config lives in `pyproject.toml` | Remind user to add `[tool.ruff]` section if absent |
| perl | `cpanfile` | `~/.claude/templates/project/platforms/perl/cpanfile` |
| asm | `.gitignore` additions | Apply asm `.gitignore` from platform template |
| other | skip | — |

### 4m. Git Hooks
If `.git/hooks/commit-msg` or `.git/hooks/pre-commit` is missing or not executable:

For `commit-msg`, write this hook:
```bash
#!/usr/bin/env bash
# Enforce Conventional Commits format on every commit message.
# Pattern allows: type(scope): description  OR  type: description
# Valid types: feat fix docs style refactor perf test chore ci revert
set -euo pipefail

commit_msg=$(cat "${1}")
pattern='^(feat|fix|docs|style|refactor|perf|test|chore|ci|revert)(\([a-z0-9_-]+\))?: .{1,88}$'

if ! echo "${commit_msg}" | grep -qE "${pattern}"; then
  echo "ERROR: Commit message does not follow Conventional Commits format."
  echo "  Expected: type(scope): description"
  echo "  Example:  feat(parser): add NMEA sentence support"
  echo "  Types:    feat fix docs style refactor perf test chore ci revert"
  exit 1
fi
```

For `pre-commit`, write this hook:
```bash
#!/usr/bin/env bash
# Run gitleaks to block commits that contain secrets.
set -euo pipefail

if command -v gitleaks &>/dev/null; then
  gitleaks protect --staged --redact --verbose
fi
```

Make both hooks executable:
```
chmod +x .git/hooks/commit-msg
chmod +x .git/hooks/pre-commit
```

### 4p. Branch Ruleset on main
Apply via GitHub API:
```
gh api repos/{username}/{repo}/branches/main/protection \
  --method PUT \
  --field required_status_checks=null \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1}' \
  --field restrictions=null
```

If this fails (e.g., the repo does not yet have a `main` branch on GitHub), report
the error and instruct the user to push to GitHub first, then re-run `/apply-standard`.

Note: For full squash-only enforcement and signed-commit requirements, instruct the
user to verify in the browser under Settings → Rules → Rulesets that:
- Allowed merge methods: Squash only
- Require signed commits: enabled
- Automatically delete head branches: enabled

These settings require GitHub Pro or higher and are not fully configurable via the
REST API — they must be set through the UI or GitHub's GraphQL API.

### 4q. Standard Issue Labels
First check which labels already exist:
```
gh label list --repo {username}/{repo} --limit 100
```

Create only the labels that are absent:

```
gh label create feat       --repo {username}/{repo} --color "0075ca" --description "New feature"
gh label create fix        --repo {username}/{repo} --color "d73a4a" --description "Bug fix"
gh label create docs       --repo {username}/{repo} --color "0052cc" --description "Documentation"
gh label create chore      --repo {username}/{repo} --color "e4e669" --description "Maintenance"
gh label create refactor   --repo {username}/{repo} --color "6f42c1" --description "Code refactoring"
gh label create test       --repo {username}/{repo} --color "2ea44f" --description "Tests"
gh label create ci         --repo {username}/{repo} --color "f9d0c4" --description "CI/CD"
gh label create breaking   --repo {username}/{repo} --color "b60205" --description "Breaking change"
```

### 4r. Platform Topic
Add platform topic if absent:
```
gh repo edit {username}/{repo} --add-topic {platform}
gh repo edit {username}/{repo} --add-topic automated-setup
```

### 4s. GitHub Projects v2 Board
Ensure a board titled `{repo_name} Board` exists under `{username}` and that
its Status field has the 5 standardized options in order: Backlog (GRAY),
Todo (GREEN), In Progress (YELLOW), In Review (ORANGE), Done (PURPLE).

The helper script handles both creation and standardization, and is idempotent
(skips the GraphQL mutation when options already match):
```powershell
pwsh -File "$HOME\.claude\scripts\setup_project_board.ps1" `
    -Owner {username} -RepoName {repo_name}
```

If the helper fails with a scope error (`INSUFFICIENT_SCOPES` or similar),
run `gh auth refresh -s project` and re-run the helper. If the helper script
is missing, note it in the final report and instruct the user to create the
board manually — do not fail the rest of /apply-standard.

---

## Step 5: Commit Changes

If any files were added or modified, stage and commit:
```
git add .gitattributes .gitignore .editorconfig README.md CHANGELOG.md \
        CONTRIBUTING.md SECURITY.md CLAUDE.md \
        .claude/rules/ .github/
git commit -m "chore: apply gold standard scaffold"
git push
```

Only include files that actually exist after the fixes. Do not stage files that
were not changed.

---

## Step 6: Regenerate Project Shortcuts

Re-run the launcher-shortcut generator so a `.lnk` for this repo appears in
`{projects_root}\shortcuts\` (auto-discovers repos via `.git` dirs and clears
stale `.lnk`s):
```powershell
pwsh -File "{projects_root}\shortcuts\regenerate.ps1"
```
If the script is missing, note it in the final report but do not fail the run.

---

## Step 7: Final Report

Print a summary of what was done:

```
Gold Standard Applied — {repo_name}
──────────────────────────────────────────────────
Files added/updated:
  + .editorconfig
  + README.md
  ~ CLAUDE.md (added rule imports)
  + .github/ISSUE_TEMPLATE/bug_report.md
  + .github/ISSUE_TEMPLATE/feature_request.md
  + .github/ISSUE_TEMPLATE/task.md
  + .ps-scriptanalyzer.psd1

GitHub settings:
  + Branch ruleset applied to: main
  + Labels created: feat, fix, docs, chore, refactor, test, ci, breaking
  + Topics applied: powershell, automated-setup
  + Projects board: {repo_name} Board (Backlog, Todo, In Progress, In Review, Done)

Shortcut:
  + {projects_root}\shortcuts\{repo_name}.lnk (regenerated)

Already present (unchanged):
  .gitattributes, .gitignore, CHANGELOG.md, CONTRIBUTING.md,
  SECURITY.md, .claude/rules/, .github/pull_request_template.md,
  Git hooks

Manual step required:
  Verify branch ruleset settings in GitHub UI:
  Settings → Rules → Rulesets → main
  - Squash merge only
  - Require signed commits
  - Auto-delete head branches
──────────────────────────────────────────────────
```

If any step failed, list them clearly with the error and recovery instructions.

---

## Normal Workflow — Skills to Use From Here

Now that the repo meets the gold standard, these skills support day-to-day work:

| When | Skill |
|------|-------|
| Starting a new feature or bug fix | `/new-feature` — creates a linked GitHub issue and feature branch |
| Ready to open a pull request | `/pr-create` — pre-flight checks, template population, issue linking |
| PR has been merged on GitHub | `/merge-complete` — pulls main, cleans branches, closes issue |
| Ending a work session | `/session-save` — writes `SESSION_STATE.md` with accomplishments, blockers, and next steps |
| Starting a new session | `/session-resume` — reads `SESSION_STATE.md` and tells you exactly what is next |
| Checking repo backup health | `/verify-backup` — scans all repos for unpushed commits or uncommitted changes |
