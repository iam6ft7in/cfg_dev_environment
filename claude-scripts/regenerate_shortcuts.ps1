<#
.SYNOPSIS
    Regenerate Claude-launcher shortcuts for each repo under {projects_root}/.

.DESCRIPTION
    Script Name : regenerate_shortcuts.ps1
    Source repo : iam6ft7in/public/cfg_dev_environment
                  https://github.com/iam6ft7in/cfg_dev_environment
    Last update : 2026-04-25

    DO NOT EDIT THE DEPLOYED COPY.
    This script is deployed by Phase 07b
    (phase_07b_claude_skills_and_scripts.ps1) from the source repo
    above. Edit the upstream copy in
    iam6ft7in/public/cfg_dev_environment and re-run Phase 07b. Local
    edits to the deployed copy at ~/.claude/shortcuts/regenerate.ps1
    will be overwritten on the next sync.

    Behavior:
      - Discovers every .git-bearing directory under {projects_root}
        to depth 4 (up to 5 levels deep). The {projects_root} folder
        itself is no longer launched as its own session.
      - Shortcuts (.lnk) are written to ~/.claude/shortcuts/, not
        under {projects_root}. The script wipes any stale .lnk files
        in that directory before re-creating them.
      - Each repo's .lnk filename and the session name passed to
        claude (--name) both default to the repo basename. Examples
        (no collisions):
          iam6ft7in/private/ltvdc -> ltvdc.lnk     (--name ltvdc)
          JobChron/JobChron       -> JobChron.lnk  (--name JobChron)
      - When two or more repos share a basename anywhere under
        {projects_root}, every colliding entry is promoted to its
        path-joined name (separators replaced by '_'). Both the .lnk
        filename and the session name use the promoted form so
        /resume, the prompt header, and the per-repo auto-memory
        bucket stay unambiguous. Example with three lua repos:
          pegapod/drone/lua     -> pegapod_drone_lua.lnk
          JobChron/lua          -> JobChron_lua.lnk
          iam6ft7in/private/lua -> iam6ft7in_private_lua.lnk
      - The Windows Terminal tab title is left to claude itself: WT
        honors the OSC title sequence claude emits when launched with
        --name, so passing --title is unnecessary.

.NOTES
    Projects root resolution:
      1. ~/.claude/config.json (key: projects_root), written by Phase 04.
      2. Fallback: %USERPROFILE%\projects.

    Re-run any time a repo is added, moved, or removed.
#>

${ErrorActionPreference} = 'Stop'

${wt} = "${env:LOCALAPPDATA}\Microsoft\WindowsApps\wt.exe"

${configPath} = Join-Path ${env:USERPROFILE} '.claude\config.json'
if (Test-Path ${configPath}) {
    ${cfg} = Get-Content ${configPath} -Raw -Encoding UTF8 | ConvertFrom-Json
    if (${cfg}.PSObject.Properties.Name -contains 'projects_root' `
            -and ${cfg}.projects_root) {
        ${projectsRoot} = ${cfg}.projects_root
    } else {
        ${projectsRoot} = Join-Path ${env:USERPROFILE} 'projects'
    }
} else {
    ${projectsRoot} = Join-Path ${env:USERPROFILE} 'projects'
}
${shortcutsDir} = Join-Path ${env:USERPROFILE} '.claude\shortcuts'

# Icon source. Claude's exe ships a real icon, so the shortcuts carry Claude
# branding rather than the generic WT glyph. Swap to the pwsh line if you'd
# rather see the PowerShell icon in the taskbar / Start menu.
${iconSrc} = "${env:USERPROFILE}\.local\bin\claude.exe,0"
# ${iconSrc} = 'C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.0.0_x64__8wekyb3d8bbwe\pwsh.exe,0'

if (-not (Test-Path ${shortcutsDir})) {
    New-Item -ItemType Directory -Path ${shortcutsDir} | Out-Null
}

# Discover every .git-bearing directory under projectsRoot. The synthetic
# 'projects' entry is intentionally not created; the projects folder is no
# longer launched as its own session.
${repos} = @()

Get-ChildItem -Path ${projectsRoot} -Recurse -Force -Depth 4 `
              -Directory -Filter '.git' -ErrorAction SilentlyContinue |
    ForEach-Object {
        ${repoPath}  = ${_}.Parent.FullName
        ${rel}       = [System.IO.Path]::GetRelativePath(${projectsRoot}, ${repoPath})
        # Normalize separators: the shortcut filename and the collision-promoted
        # session name both use '_' between path components.
        ${relJoined} = ${rel} -replace '[\\/]+', '_'
        ${repos} += [pscustomobject]@{
            BaseName    = ${_}.Parent.Name
            RelJoined   = ${relJoined}
            Path        = ${repoPath}
            SessionName = ${_}.Parent.Name   # provisional; resolved below
        }
    }

# Resolve basename collisions. When two or more repos share a basename
# anywhere under projectsRoot, every colliding entry gets promoted to its
# path-joined name so claude --name stays unambiguous (/resume picker,
# prompt header, and the per-repo auto-memory bucket).
${baseNameCounts} = @{}
foreach (${r} in ${repos}) {
    if (${baseNameCounts}.ContainsKey(${r}.BaseName)) {
        ${baseNameCounts}[${r}.BaseName]++
    } else {
        ${baseNameCounts}[${r}.BaseName] = 1
    }
}
foreach (${r} in ${repos}) {
    if (${baseNameCounts}[${r}.BaseName] -gt 1) {
        ${r}.SessionName = ${r}.RelJoined
    }
}

${shell} = New-Object -ComObject WScript.Shell

# Remove stale .lnk files so repos that were renamed/deleted don't linger.
Get-ChildItem -Path ${shortcutsDir} -Filter '*.lnk' -ErrorAction SilentlyContinue |
    Remove-Item -Force

foreach (${r} in ${repos}) {
    ${lnkPath} = Join-Path ${shortcutsDir} "$(${r}.SessionName).lnk"
    ${sc} = ${shell}.CreateShortcut(${lnkPath})

    ${sc}.TargetPath       = ${wt}
    # No --title is passed: Windows Terminal honors the OSC title sequence
    # claude emits when launched with --name, so the tab adopts the session
    # name automatically. pwsh -NoExit keeps the tab open after claude exits
    # so any final output remains visible.
    ${sc}.Arguments        = "new-tab --startingDirectory `"$(${r}.Path)`" pwsh.exe -NoExit -Command claude --name $(${r}.SessionName)"
    ${sc}.WorkingDirectory = ${r}.Path
    ${sc}.IconLocation     = ${iconSrc}
    ${sc}.Description      = "Claude Code session: $(${r}.SessionName)"
    ${sc}.Save()

    Write-Host "Created: $(${r}.SessionName).lnk  ->  $(${r}.Path)"
}

Write-Host ""
Write-Host "Done. ${shortcutsDir} contains $(${repos}.Count) shortcut(s)."
