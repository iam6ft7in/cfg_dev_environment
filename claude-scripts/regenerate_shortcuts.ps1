# Regenerate Claude-launcher shortcuts for each repo under {projects_root}/.
# Each .lnk opens Windows Terminal -> pwsh (profile loads) -> claude, with the
# WT tab titled after the repo.
#
# Discovery: finds every directory containing a .git under the projects root
# (depth 4, i.e. up to 5 levels deep). Also adds a top-level "projects"
# shortcut for the root itself. Re-run any time a repo is added or moved.
#
# Projects root resolution:
#   1. ~/.claude/config.json (key: projects_root), written by phase_04
#   2. Fallback: %USERPROFILE%\projects

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
${shortcutsDir} = Join-Path ${projectsRoot} 'shortcuts'

# Icon source. Claude's exe ships a real icon, so the shortcuts carry Claude
# branding rather than the generic WT glyph. Swap to the pwsh line if you'd
# rather see the PowerShell icon in the taskbar / Start menu.
${iconSrc} = "${env:USERPROFILE}\.local\bin\claude.exe,0"
# ${iconSrc} = 'C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.0.0_x64__8wekyb3d8bbwe\pwsh.exe,0'

if (-not (Test-Path ${shortcutsDir})) {
    New-Item -ItemType Directory -Path ${shortcutsDir} | Out-Null
}

# Build the repo list: ~/projects itself, plus every directory holding a .git
${repos} = @(
    [pscustomobject]@{ Name = 'projects'; Path = ${projectsRoot} }
)

Get-ChildItem -Path ${projectsRoot} -Recurse -Force -Depth 4 `
              -Directory -Filter '.git' -ErrorAction SilentlyContinue |
    ForEach-Object {
        ${repoPath} = ${_}.Parent.FullName
        ${repos} += [pscustomobject]@{
            Name = ${_}.Parent.Name
            Path = ${repoPath}
        }
    }

${shell} = New-Object -ComObject WScript.Shell

# Remove stale .lnk files so repos that were renamed/deleted don't linger.
Get-ChildItem -Path ${shortcutsDir} -Filter '*.lnk' -ErrorAction SilentlyContinue |
    Remove-Item -Force

foreach (${r} in ${repos}) {
    ${lnkPath} = Join-Path ${shortcutsDir} "$(${r}.Name).lnk"
    ${sc} = ${shell}.CreateShortcut(${lnkPath})

    ${sc}.TargetPath       = ${wt}
    # wt args: set tab title, starting dir, then launch pwsh which stays open
    # after claude exits so the user can see any final output.
    # claude -n sets the in-app session name (prompt box, /resume picker,
    # terminal title) to match the tab label.
    ${sc}.Arguments        = "new-tab --title `"$(${r}.Name)`" --startingDirectory `"$(${r}.Path)`" pwsh.exe -NoExit -Command claude -n $(${r}.Name)"
    ${sc}.WorkingDirectory = ${r}.Path
    ${sc}.IconLocation     = ${iconSrc}
    ${sc}.Description      = "Claude Code session in $(${r}.Name)"
    ${sc}.Save()

    Write-Host "Created: $(${r}.Name).lnk  ->  $(${r}.Path)"
}

Write-Host ""
Write-Host "Done. ${shortcutsDir} contains $(${repos}.Count) shortcut(s)."
