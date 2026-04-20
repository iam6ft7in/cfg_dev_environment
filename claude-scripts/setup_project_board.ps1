<#
.SYNOPSIS
    Create and standardize a GitHub Projects v2 kanban board for a repo.

.DESCRIPTION
    Idempotently ensures a Projects v2 board titled "{RepoName} Board" exists
    under {Owner}, then normalizes its Status field to the 5 standardized
    columns: Backlog (GRAY), Todo (GREEN), In Progress (YELLOW),
    In Review (ORANGE), Done (PURPLE).

    Safe to re-run. Skips creation if the board already exists and skips the
    GraphQL mutation if the Status options already match in order. Designed
    to be called from /new-repo, /migrate-repo, and /apply-standard.

    Requires: gh CLI authenticated with the 'project' scope. If that scope
    is missing, every gh call below will hit the scope-error path and the
    script will tell the caller exactly which command to run to fix it.

.PARAMETER Owner
    GitHub login (user or org) that will own the Projects board.

.PARAMETER RepoName
    Repository name. Board title will be "{RepoName} Board" to match the
    convention set by /new-repo.

.PARAMETER Force
    Proceed with the Status-field mutation even when the board already has
    items assigned to the current Status options. The GitHub API
    `updateProjectV2Field` replaces the entire singleSelectOptions list and
    generates new option IDs, so items previously assigned to a Status value
    become orphaned (Status = unset). Without -Force the script aborts and
    lists the at-risk items.

.EXAMPLE
    pwsh -File setup_project_board.ps1 -Owner {github_username} -RepoName tool_cv_resume

.EXAMPLE
    # Apply standardization to an existing board that has items assigned:
    pwsh -File setup_project_board.ps1 -Owner {github_username} -RepoName foo -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]${Owner},
    [Parameter(Mandatory)][string]${RepoName},
    [switch]${Force}
)

Set-StrictMode -Version Latest
${ErrorActionPreference} = 'Stop'

${title} = "${RepoName} Board"

function Invoke-GhProject {
    <#
    .SYNOPSIS
        Run a gh CLI command, capturing stderr and turning scope errors into
        an actionable 'run gh auth refresh -s project' message.

    .DESCRIPTION
        External commands don't raise PS errors on nonzero exit, so every
        gh call has to check ${LASTEXITCODE}. Doing that inline at four call
        sites duplicates the scope-detection regex and the hint text. This
        wrapper centralizes both so all four paths emit the same guidance.

        Stdout and stderr are merged via 2>&1 so the caller sees everything
        on failure, but on success stderr is typically empty for the gh
        subcommands used here (project list/create/field-list with JSON,
        and api graphql).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]${Description},
        [Parameter(Mandatory)][string[]]${GhArgs}
    )

    ${output} = & gh @GhArgs 2>&1
    if (${LASTEXITCODE} -eq 0) {
        return ${output}
    }

    ${msg} = (${output} | Out-String).Trim()

    # gh surfaces missing scopes in a few different phrasings depending on
    # whether the failure comes from the REST API, the GraphQL layer, or
    # gh's own pre-flight check. Matching any of these triggers the
    # actionable hint instead of the generic failure throw.
    ${scopePattern} = '(?i)required scope|not been granted|missing.*scope|scope.*missing|insufficient.*scope|requires.*scope'

    if (${msg} -match ${scopePattern}) {
        throw @"
${Description} failed (exit ${LASTEXITCODE}).

The gh CLI token is missing the 'project' scope required for
GitHub Projects v2. Run:

    gh auth refresh -s project

Then re-run this script. Underlying gh output:
${msg}
"@
    }

    throw "${Description} failed (exit ${LASTEXITCODE}):`n${msg}"
}

function Get-StatusAssignedItems {
    <#
    .SYNOPSIS
        Return items on the given board that currently have a value assigned
        to the Status single-select field.

    .DESCRIPTION
        Used to warn before running updateProjectV2Field, which replaces all
        singleSelectOptions and regenerates their IDs. Any item previously
        assigned to a Status value will be orphaned (Status becomes unset)
        because its stored optionId no longer resolves.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]${Owner},
        [Parameter(Mandatory)][int]${Number}
    )

    ${query} = @'
query($login: String!, $num: Int!) {
  user(login: $login) {
    projectV2(number: $num) {
      items(first: 100) {
        nodes {
          content {
            __typename
            ... on Issue       { title }
            ... on PullRequest { title }
            ... on DraftIssue  { title }
          }
          fieldValues(first: 30) {
            nodes {
              __typename
              ... on ProjectV2ItemFieldSingleSelectValue {
                field { ... on ProjectV2SingleSelectField { name } }
                name
              }
            }
          }
        }
      }
    }
  }
}
'@

    ${raw} = Invoke-GhProject -Description 'gh api graphql (list items)' -GhArgs @(
        'api', 'graphql', '-f', "query=${query}",
        '-F', "login=${Owner}", '-F', "num=${Number}"
    )
    ${response} = ${raw} | ConvertFrom-Json
    ${items} = ${response}.data.user.projectV2.items.nodes

    ${assigned} = @()
    foreach (${item} in ${items}) {
        ${statusValue} = ${item}.fieldValues.nodes |
            Where-Object {
                ${_}.__typename -eq 'ProjectV2ItemFieldSingleSelectValue' -and
                ${_}.field -and
                ${_}.field.name -eq 'Status'
            } |
            Select-Object -First 1
        if (${statusValue}) {
            ${title} = if (${item}.content -and
                           ${item}.content.PSObject.Properties['title']) {
                ${item}.content.title
            } else { '(untitled)' }
            ${assigned} += [pscustomobject]@{
                Title  = ${title}
                Status = ${statusValue}.name
            }
        }
    }
    return ,${assigned}
}

function Get-Board {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]${Owner},
        [Parameter(Mandatory)][string]${Title}
    )
    # --limit 100 is a safety margin; a single user rarely has > 100 boards.
    ${json} = Invoke-GhProject -Description 'gh project list' -GhArgs @(
        'project', 'list', '--owner', ${Owner}, '--format', 'json', '--limit', '100'
    )
    ${all} = ${json} | ConvertFrom-Json
    return ${all}.projects |
        Where-Object { ${_}.title -eq ${Title} } |
        Select-Object -First 1
}

${board} = Get-Board -Owner ${Owner} -Title ${title}

if (-not ${board}) {
    Write-Host "Creating Projects board: ${title}"
    Invoke-GhProject -Description 'gh project create' -GhArgs @(
        'project', 'create', '--owner', ${Owner}, '--title', ${title}
    ) | Out-Null
    ${board} = Get-Board -Owner ${Owner} -Title ${title}
    if (-not ${board}) {
        throw "Board creation reported success but '${title}' not found afterwards"
    }
    Write-Host "  Created board #$(${board}.number): $(${board}.url)"
} else {
    Write-Host "Projects board already exists: ${title} (#$(${board}.number))"
}

${boardNumber} = ${board}.number

# Fetch the Status single-select field so we can inspect its options.
${fieldsJson} = Invoke-GhProject -Description 'gh project field-list' -GhArgs @(
    'project', 'field-list', "${boardNumber}", '--owner', ${Owner},
    '--format', 'json', '--limit', '50'
)
${fields} = ${fieldsJson} | ConvertFrom-Json
${statusField} = ${fields}.fields |
    Where-Object { ${_}.name -eq 'Status' } |
    Select-Object -First 1
if (-not ${statusField}) {
    throw "Status field not found on board #${boardNumber}"
}

# GitHub's Projects UI renders options in definition order, so we care about
# both names and order. Colors are set by the mutation and not re-checked
# here: if someone manually recolors, we don't stomp on it.
${expected} = @('Backlog', 'Todo', 'In Progress', 'In Review', 'Done')
${current}  = @(${statusField}.options | ForEach-Object { ${_}.name })

${inSync} = ${current}.Count -eq ${expected}.Count
if (${inSync}) {
    for (${i} = 0; ${i} -lt ${expected}.Count; ${i}++) {
        if (${current}[${i}] -ne ${expected}[${i}]) {
            ${inSync} = $false
            break
        }
    }
}

if (${inSync}) {
    Write-Host "Status field already standardized: $(${expected} -join ', ')"
} else {
    ${fromLabel} = if (${current}.Count -eq 0) { '(empty)' } else { ${current} -join ', ' }
    Write-Host "Standardizing Status field: ${fromLabel} -> $(${expected} -join ', ')"

    # Check for items that would be orphaned. The mutation below replaces the
    # entire singleSelectOptions list and regenerates option IDs, so any item
    # assigned to a current Status value loses that assignment.
    ${atRisk} = Get-StatusAssignedItems -Owner ${Owner} -Number ${boardNumber}
    if (${atRisk}.Count -gt 0) {
        Write-Warning "This mutation will orphan Status assignments on $(${atRisk}.Count) item(s):"
        foreach (${a} in ${atRisk}) {
            Write-Host "  [$(${a}.Status)] $(${a}.Title)"
        }
        Write-Host ""
        Write-Host "updateProjectV2Field regenerates all option IDs; the listed items"
        Write-Host "will show Status = unset after this runs. Reassign them afterwards."
        Write-Host ""

        if (-not ${Force}) {
            Write-Host "Aborted. Re-run with -Force to proceed and orphan these items."
            exit 2
        }
        Write-Host "Proceeding due to -Force."
        Write-Host ""
    }

    # Single-quoted here-string: $fieldId stays literal as a GraphQL variable
    # reference. We pass it in via gh api -f fieldId=... below.
    ${mutation} = @'
mutation($fieldId: ID!) {
  updateProjectV2Field(input: {
    fieldId: $fieldId
    singleSelectOptions: [
      {name: "Backlog",     color: GRAY,   description: ""},
      {name: "Todo",        color: GREEN,  description: ""},
      {name: "In Progress", color: YELLOW, description: ""},
      {name: "In Review",   color: ORANGE, description: ""},
      {name: "Done",        color: PURPLE, description: ""}
    ]
  }) {
    projectV2Field {
      ... on ProjectV2SingleSelectField {
        id
        name
        options { name color }
      }
    }
  }
}
'@

    ${fieldId} = ${statusField}.id
    Invoke-GhProject -Description 'gh api graphql (updateProjectV2Field)' -GhArgs @(
        'api', 'graphql', '-f', "query=${mutation}", '-f', "fieldId=${fieldId}"
    ) | Out-Null
    Write-Host "Status field standardized"
}

Write-Host ""
Write-Host "Board: $(${board}.url)"
