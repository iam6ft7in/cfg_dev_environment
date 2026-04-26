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
1. personal/public — migrates to `{projects_root}\personal\public\{repo_name}`
2. personal/private — migrates to `{projects_root}\personal\private\{repo_name}`
3. personal/collaborative — migrates to `{projects_root}\personal\collaborative\{repo_name}`
4. client — migrates to `{projects_root}\client\{repo_name}`
5. arduino — migrates to `{projects_root}\arduino\custom\{repo_name}`

Read `{projects_root}` from `~/.claude/config.json` (key: `projects_root`).
Fall back to `%USERPROFILE%\projects` if absent.

Determine the GitHub SSH alias based on identity:
- `personal/*` → `github-personal`
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

## Step 5: Create GitHub Projects Board

Ensure a Projects v2 board titled `{repo_name} Board` exists under
`{github_username}` with the 5 standardized Status options: Backlog (GRAY),
Todo (GREEN), In Progress (YELLOW), In Review (ORANGE), Done (PURPLE).

The helper script is idempotent and safe to re-run:
```powershell
pwsh -File "$HOME\.claude\scripts\setup_project_board.ps1" `
    -Owner {github_username} -RepoName {repo_name}
```

If it fails with an auth/scope error, run `gh auth refresh -s project` and
retry. If the helper script is missing, report it and continue — do not fail
the migration.

This step runs unconditionally because `/apply-standard` (next step) is
user-optional; the board should exist regardless of whether the user opts
into the rest of the gold standard audit.

---

## Step 6: Apply Gold Standard

After the board is in place, invoke `/apply-standard` in the context of the
newly migrated repo directory. This is not optional, migration is incomplete
without it, and most of the gold-standard additions belong to this step:

- Missing top-level files scaffolded: `.gitattributes`, `.gitignore`,
  `.editorconfig`, `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`,
  `SECURITY.md`, `CLAUDE.md`, `SESSION_STATE.md` (machine-local),
  `SESSION_STATE.template.md` (committed), `.github/...`, platform linter
  config, git hooks.
- `memory/MEMORY.md` scaffolded as the per-repo memory index.
- `.claude/settings.local.json` scaffolded with an empty permissions
  allow-list.
- Branch ruleset, standard labels, platform topic, and Projects v2 board
  config. `/apply-standard` detects the board from Step 5 and skips its
  creation.

If the migrated source already contains any of these files,
`/apply-standard` preserves the existing content:
- `CLAUDE.md` existing content round-trips unchanged, only missing @-imports
  are prepended.
- `.gitignore` drift is reported but not auto-merged; the user re-runs
  `/apply-standard --merge` if they want the template lines appended.
- Every other file is only created if absent.

Invoke the skill and let it run to completion before proceeding to Step 7.
If the user has a reason to skip specific sub-steps, they can interrupt
the apply-standard prompts individually, but the default is a full run.

---

## Step 7: Regenerate Project Shortcuts

Re-run the launcher-shortcut generator so a `.lnk` for the migrated repo
appears in `~/.claude/shortcuts/` (auto-discovers repos via `.git` dirs
and clears stale `.lnk`s):
```powershell
pwsh -File "$HOME\.claude\shortcuts\regenerate.ps1"
```
If the script is missing, note it in the final report but do not fail the run.

---

## Step 8: Final Report

```
Migration Complete
─────────────────────────────────────────────────────
  Repo:     {repo_name}
  GitHub:   https://github.com/{github_username}/{repo_name}
  Local:    {projects_root}\{identity_subpath}\{repo_name}
  Shortcut: ~/.claude/shortcuts/{repo_name}.lnk

Next steps:
  1. Open Claude in the new repo directory
  2. Run /rename {repo_name} to name the session
─────────────────────────────────────────────────────
```
