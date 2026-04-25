---
name: new-repo
description: Create a complete gold standard GitHub repository from scratch, including scaffold, branch protection, GitHub Projects board, topics, and labels.
---

# /new-repo, Create a Gold Standard GitHub Repository

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

Each choice must have a matching overlay at
`~/.claude/templates/project/platforms/{platform}/` and a rules file at
`~/.claude/rules/{platform}.md`. If either is missing, abort with a clear
error so the gap is fixed here in `cfg_dev_environment` rather than papered
over in a generated repo.

### 1c. Identity
Present a numbered list:
1. personal/public, maps to ~/projects/{username}/public/ (public GitHub repos)
2. personal/private, maps to ~/projects/{username}/private/ (private GitHub repos)
3. personal/collaborative, maps to ~/projects/{username}/collaborative/
4. client, maps to ~/projects/client/
5. arduino, maps to ~/projects/arduino/custom/

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
warn: "~/.claude/config.json not found, run phase_04_directories.ps1 to configure
your projects root. Falling back to %USERPROFILE%\projects."

Determine the GitHub username based on identity (resolve before constructing
the path so `{username}` is substituted correctly):
- `personal` → use the username from `gh api user --jq .login` under the personal account
- `client` → `client`
- `arduino` → use personal username (arduino repos live under the personal GitHub account)

Based on identity, construct the local path from `{projects_root}` and the
resolved `{username}`:
- `personal/public` → `{projects_root}\{username}\public\{repo_name}`
- `personal/private` → `{projects_root}\{username}\private\{repo_name}`
- `personal/collaborative` → `{projects_root}\{username}\collaborative\{repo_name}`
- `client` → `{projects_root}\client\{repo_name}`
- `arduino` → `{projects_root}\arduino\custom\{repo_name}`

Determine the SSH host alias based on identity:
- `personal` → `github-personal`
- `client` → `github-client`
- `arduino` → `github-personal`

---

## Step 3: Execute Commands in Sequence

Show each command to the user before running it. If a command fails, stop and report the error, do not continue to the next step.

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
Copy files from `~/.claude/templates/project/` into `{local_path}/`, excluding:
- `platforms/` (platform overlays are handled by Step 3e; the directory itself
  must not land in the new repo)
- `.code-workspace` (conditionally copied by Step 3d2 below based on user
  preference)
- `CLAUDE.md` (legacy old-schema template; Step 3g generates the new CLAUDE.md
  from `CLAUDE.template.md`)
- `CLAUDE.template.md` (template, not a per-repo file; Step 3g consumes it)
- `MEMORY.template.md` (template; Step 3g scaffolds `memory/MEMORY.md` from it)
- `settings.local.template.json` (template; Step 3g scaffolds
  `.claude/settings.local.json` from it)

`SESSION_STATE.template.md` is intentionally NOT in the exclusion list, it
gets copied verbatim into the new repo root as a committed example of the
session-state shape.

Use PowerShell:
```powershell
Get-ChildItem -Path "$HOME\.claude\templates\project" -Force `
    -Exclude 'platforms', '.code-workspace',
              'CLAUDE.md', 'CLAUDE.template.md',
              'MEMORY.template.md', 'settings.local.template.json' |
    Copy-Item -Destination "{local_path}" -Recurse -Force
```

### 3d2. Conditionally Copy VS Code Workspace File
The base template ships a `.code-workspace` for VS Code users. Copy it only
when the user wants it. Decision order:

1. If `~/.claude/config.json` has `include_vscode_workspace: true`, copy it.
2. If `~/.claude/config.json` has `include_vscode_workspace: false`, skip it.
3. If the key is absent, auto-detect: include the file when `code` is on
   PATH, skip otherwise.

```powershell
${includeKey} = $null
if (Test-Path "$HOME\.claude\config.json") {
    ${cfg} = Get-Content "$HOME\.claude\config.json" -Raw | ConvertFrom-Json
    if (${cfg}.PSObject.Properties.Name -contains 'include_vscode_workspace') {
        ${includeKey} = [bool]${cfg}.include_vscode_workspace
    }
}
if (${includeKey} -eq $null) {
    ${includeKey} = [bool](Get-Command code -ErrorAction SilentlyContinue)
}
if (${includeKey}) {
    Copy-Item -Path "$HOME\.claude\templates\project\.code-workspace" `
        -Destination "{local_path}" -Force
}
```

Report which branch fired so the choice is transparent:
`VS Code workspace: included (config=true)` /
`VS Code workspace: skipped (config=false)` /
`VS Code workspace: included (auto-detect, code on PATH)` /
`VS Code workspace: skipped (auto-detect, code not on PATH)`.

### 3e. Copy Platform-Specific Files
Copy files from `~/.claude/templates/project/platforms/{platform}/` into `{local_path}/`, merging with the base scaffold. Platform files take precedence.

```powershell
Copy-Item -Path "$HOME\.claude\templates\project\platforms\{platform}\*" -Destination "{local_path}" -Recurse -Force
```

### 3f. Replace Legacy Uppercase Placeholders
Replace uppercase-schema placeholders in the bulk-copied files (README.md,
CONTRIBUTING.md, AGENTS.md, etc.). This step does NOT apply to CLAUDE.md,
memory/MEMORY.md, SESSION_STATE.md, or settings.local.json, those are
generated in Step 3g with the new lowercase schema.

Placeholders replaced here:
- `{{REPO_NAME}}` → the repository name
- `{{DESCRIPTION}}` → the short description
- `{{PLATFORM}}` → the chosen platform
- `{{YEAR}}` → the current year (4 digits)
- `{{REPO_PATH}}` → the full local path resolved in Step 2 (e.g.,
  `{projects_root}\personal\{repo_name}`)

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

### 3g. Scaffold From New-Schema Templates
Generate four files from the new-schema templates. The template files live
in `~/.claude/templates/project/` (deployed by `phase_08_scaffold_template`),
with the `CLAUDE.template.md` canonical at `~/.claude/templates/` for
cross-repo sync. Resolve each template path in this order, stopping at the
first hit:

1. `~/.claude/templates/CLAUDE.template.md` (canonical; CLAUDE template only)
2. `~/.claude/templates/project/{Template file name}` (phase_08 deploy target)

If neither is found, abort with a clear error, do not silently fall back to
the legacy `CLAUDE.md` template, because the old schema produces a file the
rest of this skill and `apply-standard` will mis-handle.

**3g.i. Generate CLAUDE.md**

Build the `{{rule_imports}}` value:
- Always include `@.claude/rules/project.md`.
- If `{platform}` is not `other` AND `~/.claude/rules/{platform}.md` exists,
  append `@~/.claude/rules/{platform}.md`.
- Stack imports (`@~/.claude/stacks/*.md`) are NOT added at creation time,
  the user adds them later when a repo actually needs a stack.

Read `CLAUDE.template.md`, substitute the new-schema tokens, and write the
result to `{local_path}/CLAUDE.md`:

| Token | Value |
|-------|-------|
| `{{repo_name}}` | `{repo_name}` |
| `{{one_line_purpose}}` | `{description}` |
| `{{owner}}` | `{username}` (resolved in Step 2) |
| `{{visibility}}` | `{visibility}` |
| `{{languages}}` | `{platform}` |
| `{{session_name}}` | `{repo_name}` |
| `{{rule_imports}}` | The import block built above, one `@`-line per row |
| `{{key_paths}}` | `\| Item \| Path \|\n\|------\|------\|\n\| \| \|` (empty table the user fills in later) |
| `{{credentials_note}}` | Leave the template's default "Bitwarden CLI for ambient secrets" line in place (the line *after* the placeholder), and replace the placeholder itself with an empty string |
| `{{repo_specific}}` | Empty string |

After substitution, delete the lines that read `Examples:` followed by the
`  @~/.claude/rules/python.md` / `shell.md` / `stacks/vmware.md` example
block (lines 19–22 of the template as of 2026-04-24). These are intentional
docstring lines in the template and must not land in the generated
CLAUDE.md.

**3g.ii. Generate memory/MEMORY.md**

Create `{local_path}/memory/` if absent. Copy `MEMORY.template.md` to
`memory/MEMORY.md` verbatim (no placeholder substitution).

**3g.iii. Generate SESSION_STATE.md**

Copy `SESSION_STATE.template.md` to `{local_path}/SESSION_STATE.md` and
substitute:
- The literal string `YYYY-MM-DD` on the first line → today's date in
  ISO format
- `{{session_name}}` → `{repo_name}`

This file is gitignored by the template-copied `.gitignore`, so it stays
in the working tree but out of the initial commit. The committed
`SESSION_STATE.template.md` copied by Step 3d serves as the example.

**3g.iv. Generate .claude/settings.local.json**

Create `{local_path}/.claude/` if absent. Copy
`settings.local.template.json` to `.claude/settings.local.json` verbatim.

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
Apply standard branch protection to `main` using the GitHub API. The
`required_pull_request_reviews` value is a nested JSON object, which
`gh --field` cannot send (magic type conversion covers bool/null/integer
only; objects become literal strings and the API rejects them). Pass the
JSON body via `--input -` instead.

PowerShell:
```powershell
@'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {"required_approving_review_count": 1},
  "restrictions": null
}
'@ | gh api --method PUT `
    "repos/{username}/{repo_name}/branches/main/protection" `
    --input -
```

Bash fallback (for non-Windows contexts):
```bash
gh api --method PUT \
    "repos/{username}/{repo_name}/branches/main/protection" \
    --input - <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {"required_approving_review_count": 1},
  "restrictions": null
}
JSON
```

### 3m. Create GitHub Projects Kanban Board
Create a Projects (v2) board titled `{repo_name} Board` and standardize its
Status field to the 5 columns: Backlog (GRAY), Todo (GREEN), In Progress
(YELLOW), In Review (ORANGE), Done (PURPLE).

The helper script does both in one call, idempotent, safe to re-run:
```powershell
pwsh -File "$HOME\.claude\scripts\setup_project_board.ps1" `
    -Owner {username} -RepoName {repo_name}
```

If the helper fails with an auth/scope error, run
`gh auth refresh -s project` and retry. If the script is missing, fall back to
`gh project create --owner {username} --title "{repo_name} Board"` and instruct
the user to set the Status options manually at
https://github.com/users/{username}/projects.

### 3n. Apply Platform Topics
Add the platform name as a topic, unless `{platform}` is `other`. The
`other` catch-all carries no semantic value as a topic, so skip it in
that case:
```
gh repo edit {username}/{repo_name} --add-topic {platform}
```

Always add the standard `automated-setup` topic:
```
gh repo edit {username}/{repo_name} --add-topic automated-setup
```

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

### 3q. Regenerate Project Shortcuts
Re-run the launcher-shortcut generator so a `.lnk` for the new repo appears in
`~/.claude/shortcuts/` (auto-discovers repos via `.git` dirs and clears
stale `.lnk`s):
```powershell
pwsh -File "$HOME\.claude\shortcuts\regenerate.ps1"
```
If the script is missing, note it in the final report but do not fail the run.

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
  Topics applied: {topics_applied}
  Shortcut regenerated: ~/.claude/shortcuts/{repo_name}.lnk

Next step: open Claude in this repo and run /rename {repo_name}
```

If any step failed, report which step failed, what the error was, and what the user should do to recover.

---

## Normal Workflow, Skills to Use From Here

Now that the repo exists, these skills support day-to-day work:

| When | Skill |
|------|-------|
| Starting a new feature or bug fix | `/new-feature`, creates a linked GitHub issue and feature branch |
| Ready to open a pull request | `/pr-create`, pre-flight checks, template population, issue linking |
| PR has been merged on GitHub | `/merge-complete`, pulls main, cleans branches, closes issue |
| Ending a work session | `/session-save`, writes `SESSION_STATE.md` with accomplishments, blockers, and next steps |
| Starting a new session | `/session-resume`, reads `SESSION_STATE.md` and tells you exactly what is next |
| Checking repo backup health | `/verify-backup`, scans all repos for unpushed commits or uncommitted changes |
