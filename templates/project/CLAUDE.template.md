# {{repo_name}}

{{one_line_purpose}}

- **Owner:** {{owner}}              (iam6ft7in | pegapod | ...)
- **Visibility:** {{visibility}}    (public | private | collaborative)
- **Primary languages:** {{languages}}
- **Session name:** `{{session_name}}`  (used by the shortcut's
  `--name`)

## Global Rules
Every rule in `~/.claude/CLAUDE.md` applies here. Not restated.

## Stack-Specific Rules
`~/.claude/rules/*.md` auto-load (universal or extension-triggered).
`~/.claude/stacks/*.md` do NOT auto-load; @-import them here when needed.

{{rule_imports}}
Examples:
  @~/.claude/rules/python.md
  @~/.claude/rules/shell.md
  @~/.claude/stacks/vmware.md

## Repo Memory
Durable repo-level memory lives in `memory/MEMORY.md`. Read it when
relevant; update it when you learn something that belongs there.

## Key Paths (repo-local)
{{key_paths}}
Table form; include things like build output, test targets, config
directories. Host-specific paths (e.g., remote hosts) go in
`memory/reference_command_paths.md`, not here.

## Credentials (if any)
{{credentials_note}}
- Default: Bitwarden CLI for ambient secrets.
- If this repo uses git-crypt, note the GPG key id(s).
- `.env.example` is the committed schema.

## Scripts
If this repo has a `scripts/` directory, scripts under it are
idempotent by convention. Re-running is safe. Delete this section if
the repo has no scripts.

## Session Handoff
- `SESSION_STATE.md`: current session's forward pointer. Gitignored
  (machine-local, transient). Written by `session-save`, read by
  `session-resume`.
- `SESSION_DIARY.md`: durable narrative log of what happened in
  each session. **Committed.** Soft limit 500 lines.
- At session end, if `SESSION_DIARY.md` exceeds 500 lines,
  `session-save` archives the current contents to
  `SESSION_DIARY.YYYY-MM-DD.md` (date of the oldest entry) and starts
  a fresh active file with a "continued from ..." header. Archives
  are committed alongside the active diary. This preserves the full
  history across rollovers; no separate `REPO_DIARY.md` is needed.
- `SESSION_STATE.template.md`: committed example of the state-file
  shape, for forkers and new repos (not live state).

## Repo-Specific Rules and Conventions
{{repo_specific}}
Only include what is truly repo-specific. Do not duplicate anything
that is already in the global rules or global CLAUDE.md.
