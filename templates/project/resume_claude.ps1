# Resume the {{REPO_NAME}} Claude Code session.
# Run this from anywhere — it changes to the repo directory automatically.
# Session name convention: use the repo name exactly (set with /rename {{REPO_NAME}}).
Set-Location -Path "{{REPO_PATH}}"
claude --resume {{REPO_NAME}}
