---
name: migrate-repo
description: Interactively migrate an existing project from outside GitHub into the gold standard environment — prompts for all parameters, runs migrate_to_github.ps1, and confirms the result.
---

# /migrate-repo — Migrate a Project to GitHub

You are migrating an existing project into the gold standard GitHub environment.
Gather all required information interactively, preview the migration, confirm with
the user, then execute. Show every command before running it.

---

## Step 1: Gather Information

Ask the user for each of the following. Validate each answer before moving on.

### 1a. Source Path
The full path to the existing project directory on disk.
- Must exist on the local filesystem.
- Verify with: `Test-Path "{source_path}"` — if false, ask the user to correct it.
- Example: `%USERPROFILE%\OneDrive\AI\Projects\my_project`

### 1b. Repository Name
The GitHub repo name and local directory name.
- Lowercase, snake_case or hyphen-separated. No spaces.
- Examples: `tool_deploy_helper`, `windows-automation`, `lib_sensor_utils`
- If the name contains uppercase or spaces, suggest a corrected form and confirm
  with the user before proceeding.

### 1c. Description
A one-sentence description of what the project does.
- Will be used as the GitHub repo description.
- Keep it under 100 characters.

### 1d. Topics
GitHub topics for discoverability. Comma-separated, lowercase, no spaces.
- Examples: `powershell,automation,windows` or `python,data-analysis`
- Optional — press Enter to skip.

### 1e. Identity
Present a numbered list:
1. personal — migrates to `{projects_root}\personal\{repo_name}`
2. client — migrates to `{projects_root}\client\{repo_name}`
3. arduino — migrates to `{projects_root}\arduino\custom\{repo_name}`

Read `{projects_root}` from `~/.claude/config.json` (key: `projects_root`).
Fall back to `%USERPROFILE%\projects` if absent.

Determine the GitHub SSH alias based on identity:
- `personal` → `github-personal`
- `client` → `github-client`
- `arduino` → `github-personal`

### 1f. Dry Run?
Ask: "Preview all actions without making any changes? (yes/no, default: yes)"
Default to yes — always show a dry run first.

---

## Step 2: Preview

Show the user a summary of what will happen:

```
Migration Preview
─────────────────────────────────────────────────────
  Source:      {source_path}
  Repo name:   {repo_name}
  Description: {description}
  Topics:      {topics}
  Identity:    {identity}
  Target:      {projects_root}\{identity_subpath}\{repo_name}
  GitHub:      git@{ssh_alias}:{github_username}/{repo_name}.git
  Mode:        DRY RUN (no changes will be made)
─────────────────────────────────────────────────────
```

Ask: "Proceed with dry run? (yes/no)"
If no, stop.

---

## Step 3: Dry Run

Run `migrate_to_github.ps1` with `-WhatIf` to preview all actions:

```powershell
pwsh -File scripts\migrate_to_github.ps1 `
    -SourcePath "{source_path}" `
    -RepoName "{repo_name}" `
    -Description "{description}" `
    -Topics {topics_bare} `
    -TargetRoot "{projects_root}\{identity_subpath}" `
    -GitHubAlias "{ssh_alias}" `
    -WhatIf
```

Where `{topics_bare}` is the topics as bare comma-separated strings:
`"powershell","automation","windows"` (not `@(...)`).

Show the full output. Ask: "Everything look correct? Proceed with the actual
migration? (yes/no)"

If no, ask what needs to change and return to Step 1.

---

## Step 4: Execute Migration

Run without `-WhatIf`:

```powershell
pwsh -File scripts\migrate_to_github.ps1 `
    -SourcePath "{source_path}" `
    -RepoName "{repo_name}" `
    -Description "{description}" `
    -Topics {topics_bare} `
    -TargetRoot "{projects_root}\{identity_subpath}" `
    -GitHubAlias "{ssh_alias}"
```

If the script exits with a non-zero code, report the error and stop. Do not
attempt to retry automatically — describe what failed and what the user should do.

---

## Step 5: Apply Gold Standard

After a successful migration, run `/apply-standard` to ensure the migrated repo
has all gold standard files (issue templates, CLAUDE.md rule imports, resume bat,
linter config, branch ruleset, labels, topics).

Prompt: "Run /apply-standard now to complete the gold standard setup? (yes/no)"

If yes, invoke the `/apply-standard` skill in the context of the newly migrated
repo directory.

---

## Step 6: Final Report

```
Migration Complete
─────────────────────────────────────────────────────
  Repo:    {repo_name}
  GitHub:  https://github.com/{github_username}/{repo_name}
  Local:   {projects_root}\{identity_subpath}\{repo_name}

Next steps:
  1. Open Claude in the new repo directory
  2. Run /rename {repo_name} to name the session
  3. The resume bat is at: OneDrive\scripts\resume-{repo_name}.bat
─────────────────────────────────────────────────────
```
