---
name: new-repo
description: Create a complete gold standard GitHub repository from scratch, including scaffold, resume PowerShell script, branch protection, GitHub Projects board, topics, and labels.
---

# /new-repo — Create a Gold Standard GitHub Repository

You are setting up a new GitHub repository for the user. Follow every step in order. Do not skip steps. Show each shell command before running it.

---

## Step 1: Gather Information Interactively

Ask the user for each of the following, one at a time (or present as a single form and validate all answers before proceeding):

### 1a. Repository Name
- Must be in `snake_case` with a type prefix.
- Valid type prefixes: `lib_`, `tool_`, `bot_`, `api_`, `app_`, `cfg_`, `docs_`, `hw_`, `fw_`
- Example: `lib_sensor_utils`, `tool_deploy_helper`, `docs_architecture`
- If the name does not match this pattern, explain the requirement and suggest a corrected name. Ask the user to confirm or modify before continuing.

### 1b. Platform
Present a numbered list and ask the user to choose:
1. python
2. powershell
3. bash
4. perl
5. vbscript
6. asm
7. arduino
8. docs
9. other

### 1c. Identity
Present a numbered list:
1. personal — maps to ~/projects/personal/
2. client — maps to ~/projects/client/
3. arduino — maps to ~/projects/arduino/custom/

### 1d. Short Description
- One sentence describing what the repository does.
- Will be used as the GitHub repo description.

### 1e. License
Ask explicitly. Do NOT choose a default. Present:
1. MIT
2. Apache-2.0
3. GPL-3.0
4. None

The user MUST choose one. If they do not answer clearly, ask again.

### 1f. Visibility
- Default: **private**
- Ask: "Should this repo be public or private? (default: private)"
- If the user chooses **public**, ask them to confirm: "You chose public. This means the repository will be visible to everyone. Confirm? (yes/no)"
- Only proceed with public if they confirm.

---

## Step 2: Determine Local Path

Read the projects root from `~/.claude/config.json` (key: `projects_root`):
```powershell
$config = Get-Content "$HOME\.claude\config.json" -Raw | ConvertFrom-Json
$projectsRoot = $config.projects_root
```
If the file does not exist or the key is absent, fall back to `$HOME\projects` and
warn: "~/.claude/config.json not found — run phase_04_directories.ps1 to configure
your projects root. Falling back to %USERPROFILE%\projects."

Based on identity, construct the local path from `{projects_root}`:
- `personal` → `{projects_root}\personal\{repo_name}`
- `client` → `{projects_root}\client\{repo_name}`
- `arduino` → `{projects_root}\arduino\custom\{repo_name}`

Determine the GitHub username based on identity:
- `personal` → use the username from `gh api user --jq .login` under the personal account
- `client` → `client`
- `arduino` → use personal username (arduino repos live under the personal GitHub account)

Determine the SSH host alias based on identity:
- `personal` → `github-personal`
- `client` → `github-client`
- `arduino` → `github-personal`

---

## Step 3: Execute Commands in Sequence

Show each command to the user before running it. If a command fails, stop and report the error — do not continue to the next step.

### 3a. Create GitHub Repository
```
gh repo create {repo_name} --{visibility} --description "{description}"
```

### 3b. Create Local Directory
```
mkdir -p {local_path}
```

### 3c. Initialize Git
```
git -C {local_path} init
git -C {local_path} checkout -b main
```

### 3d. Copy Base Scaffold
Copy all files from `~/.claude/templates/project/` into `{local_path}/`.
This includes CLAUDE.md, .gitignore, .github/PULL_REQUEST_TEMPLATE.md, and other base files.

Use PowerShell:
```powershell
Copy-Item -Path "$HOME\.claude\templates\project\*" -Destination "{local_path}" -Recurse -Force
```

### 3e. Copy Platform-Specific Files
Copy files from `~/.claude/templates/project/platforms/{platform}/` into `{local_path}/`, merging with the base scaffold. Platform files take precedence.

```powershell
Copy-Item -Path "$HOME\.claude\templates\project\platforms\{platform}\*" -Destination "{local_path}" -Recurse -Force
```

### 3f. Replace Placeholders
In all files under `{local_path}`, replace these placeholders:
- `{{REPO_NAME}}` → the repository name
- `{{DESCRIPTION}}` → the short description
- `{{PLATFORM}}` → the chosen platform
- `{{YEAR}}` → the current year (4 digits)
- `{{REPO_PATH}}` → the full local path resolved in Step 2 (e.g., `{projects_root}\personal\{repo_name}`)

Use PowerShell to do this recursively:
```powershell
Get-ChildItem -Path "{local_path}" -Recurse -File | ForEach-Object {
    $content = Get-Content $_.FullName -Raw -Encoding UTF8
    $content = $content -replace '\{\{REPO_NAME\}\}', '{repo_name}'
    $content = $content -replace '\{\{DESCRIPTION\}\}', '{description}'
    $content = $content -replace '\{\{PLATFORM\}\}', '{platform}'
    $content = $content -replace '\{\{YEAR\}\}', (Get-Date).Year
    $content = $content -replace '\{\{REPO_PATH\}\}', '{local_path}'
    Set-Content $_.FullName $content -Encoding UTF8
}
```

### 3g. Activate Platform Rules in CLAUDE.md
In `{local_path}/CLAUDE.md`, find the line that contains `@~/.claude/rules/{platform}.md` and uncomment it (remove the leading `# ` if present).

### 3h. Write LICENSE File
Based on the user's choice, write the appropriate license text to `{local_path}/LICENSE`.

- **MIT**: Standard MIT License text with the current year and author name.
- **Apache-2.0**: Standard Apache 2.0 License text.
- **GPL-3.0**: Standard GPL 3.0 License text.
- **None**: Do not create a LICENSE file.

For MIT, get the author name from `git config user.name` (run in the local path after setting the remote, or use the global config).

### 3i. Add Git Remote
```
git -C {local_path} remote add origin git@{ssh_host}:{username}/{repo_name}.git
```

### 3j. Stage and Commit
```
git -C {local_path} add .
git -C {local_path} commit -m "chore: initial project scaffold"
```

### 3k. Push to GitHub
```
git -C {local_path} push -u origin main
```

### 3l. Apply Branch Protection
Apply standard branch protection to `main` using the GitHub API:
```
gh api repos/{username}/{repo_name}/branches/main/protection \
  --method PUT \
  --field required_status_checks=null \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1}' \
  --field restrictions=null
```

### 3m. Create GitHub Projects Kanban Board
Create a Projects (v2) board with 5 columns:
- Backlog
- Todo
- In Progress
- In Review
- Done

Use the GitHub CLI Projects API. First create the project:
```
gh project create --owner {username} --title "{repo_name} Board"
```
Note the project number. Then add the status field options. If the Projects v2 API is not directly available via `gh project`, instruct the user to create the board manually at github.com/{username}/{repo_name}/projects and provide the column names.

### 3n. Apply Platform Topics
Add topics to the repository based on the platform:
```
gh repo edit {username}/{repo_name} --add-topic {platform}
```

Also add a standard `automated-setup` topic:
```
gh repo edit {username}/{repo_name} --add-topic automated-setup
```

### 3o. Create Resume PowerShell Scripts
The `resume_claude.ps1` is already in the repo (copied from the scaffold in 3d and
placeholders replaced in 3f). Now copy it to the OneDrive scripts folder so it is
available system-wide:

```powershell
Copy-Item -Path "{local_path}\resume_claude.ps1" `
          -Destination "$HOME\OneDrive\scripts\resume-{repo_name}.ps1" -Force
```

Instruct the user:
"When you first open Claude in this repo, run `/rename {repo_name}` to name the
session. This is what the resume script uses — keep the session name and script in sync."

### 3p. Apply Standard Issue Labels
Create the following labels (delete defaults first if needed):

| Label | Color |
|-------|-------|
| feat | #0075ca |
| fix | #d73a4a |
| docs | #0052cc |
| chore | #e4e669 |
| refactor | #6f42c1 |
| test | #2ea44f |
| ci | #f9d0c4 |
| breaking | #b60205 |

Use `gh label create` for each:
```
gh label create feat     --repo {username}/{repo_name} --color "0075ca" --description "New feature"
gh label create fix      --repo {username}/{repo_name} --color "d73a4a" --description "Bug fix"
gh label create docs     --repo {username}/{repo_name} --color "0052cc" --description "Documentation"
gh label create chore    --repo {username}/{repo_name} --color "e4e669" --description "Maintenance"
gh label create refactor --repo {username}/{repo_name} --color "6f42c1" --description "Code refactoring"
gh label create test     --repo {username}/{repo_name} --color "2ea44f" --description "Tests"
gh label create ci       --repo {username}/{repo_name} --color "f9d0c4" --description "CI/CD"
gh label create breaking --repo {username}/{repo_name} --color "b60205" --description "Breaking change"
```

---

## Step 4: Final Report

After all steps complete successfully, print a summary:

```
Repository created successfully.

  Name:       {repo_name}
  Platform:   {platform}
  Identity:   {identity}
  Visibility: {visibility}
  License:    {license}

  GitHub:     https://github.com/{username}/{repo_name}
  Local:      {local_path}

  Branch protection applied to: main
  Labels created: feat, fix, docs, chore, refactor, test, ci, breaking
  Topics applied: {platform}, automated-setup
  Resume script: {local_path}\resume_claude.ps1
              + %USERPROFILE%\OneDrive\scripts\resume-{repo_name}.ps1

Next step: open Claude in this repo and run /rename {repo_name}
```

If any step failed, report which step failed, what the error was, and what the user should do to recover.

---

## Normal Workflow — Skills to Use From Here

Now that the repo exists, these skills support day-to-day work:

| When | Skill |
|------|-------|
| Starting a new feature or bug fix | `/new-feature` — creates a linked GitHub issue and feature branch |
| Ready to open a pull request | `/pr-create` — pre-flight checks, template population, issue linking |
| PR has been merged on GitHub | `/merge-complete` — pulls main, cleans branches, closes issue |
| Ending a work session | `/session-save` — writes `SESSION_STATE.md` with accomplishments, blockers, and next steps |
| Starting a new session | `/session-resume` — reads `SESSION_STATE.md` and tells you exactly what is next |
| Checking repo backup health | `/verify-backup` — scans all repos for unpushed commits or uncommitted changes |
