---
name: check-slack
description: Check the configured Slack workspace for messages from a watch user (default: cofounder/coworker per repo) and surface a prioritized list of items needing a response.
---

# /check-slack, Slack Pings Digest

Surface what a designated watch user (typically a cofounder or
coworker) has posted in the Slack workspace this repo is bound to,
prioritized by what needs a response. Categorizes recent messages
into HIGH / MEDIUM / LOW buckets and detects threads where you have
already replied so they drop out of the unanswered list.

Use this on demand when resuming a session, after a stretch of focus
work, or any time you suspect there may be open asks.

When two repos bound to the same Slack workspace run /check-slack
concurrently (e.g., a product repo and an IT-infra repo), both will
independently surface overlapping items. Step 3 reads, and Step 11
writes, a small coordination state file so each run is aware of the
most recent other-repo run. The skill remains read-only against
Slack itself.

---

## Args (optional, all keyword)

- `--workspace <alias>`: override workspace selection. Default: see Step 1.
- `--from <username>`: override watch user. Default: see Step 2.
- `--days <N>`: search window (default 7).
- `--coord-window <minutes>`: how recent another repo's run must be to
  count as concurrent in Step 3 (default 30).

---

## Step 1: Discover the Slack workspace

Read `~/.claude/slack_workspaces.json`. Pick the workspace alias by:

1. `--workspace` arg if provided.
2. The current repo name (last path segment of `${cwd}`) appears in any
   workspace's `default_for_repos`. Use that.
3. Otherwise `default_workspace`.

State the chosen alias explicitly in the output, mirroring the gws
multi-account discipline.

---

## Step 2: Discover the watch user

Read `<repo>/memory/reference_credentials.md` (if present). Look for a
`Slack watch_user:` field under the `## Slack workspaces used`
section. Use it.

If absent:

- If the chosen workspace has fewer than 3 active human users, default
  to listing everyone (no `--from` filter).
- Otherwise, ask the user which `--from` to use rather than guessing.

---

## Step 3: Coordinate with concurrent runs (state file read)

The coordination state file lives at:

```
~/.cache/check-slack/<workspace>/state.json
```

(On Windows, `~` resolves to `$HOME`; the path uses forward slashes
consistently.) Schema:

```json
{
  "workspace": "<alias>",
  "watch_user": "<username>",
  "runs": [
    {
      "ts":              "<ISO-8601 UTC>",
      "repo":            "<last segment of cwd at run time>",
      "high_thread_ts":  ["<parent ts>", "..."],
      "medium_thread_ts":["<parent ts>", "..."],
      "addressed_count": <int>,
      "low_count":       <int>
    },
    ...
  ]
}
```

Read the file if present. From `runs`, find the most recent entry where:

- `repo` differs from the current repo (last path segment of `${cwd}`),
  AND
- `ts` is within the `--coord-window` (default 30 minutes).

If found, capture it as `${other_run}`; otherwise `${other_run} = $null`.

You will use `${other_run}` in Step 8 (banner) and Step 11 (re-write
the file). Do not block on missing files or parse errors, just treat
as `${other_run} = $null` and proceed.

Concurrency note: if two sessions read the same file at the same
moment, both see the same prior data. The risk is in the Step 11
write, addressed there.

---

## Step 4: Source the cc_session helpers and fetch the token

CC's PowerShell tool does not source the user profile, so dot-source
explicitly:

```powershell
. "$HOME/.claude/scripts/cc_session_helpers.ps1"
${tok} = Get-SlackToken <workspace>
${headers} = @{ Authorization = "Bearer ${tok}" }
```

Run `auth.test` once to verify the token is alive and capture the
caller's `user_id` (you'll need it in Step 6):

```powershell
${me} = Invoke-RestMethod -Uri "https://slack.com/api/auth.test" -Headers ${headers}
# ${me}.user_id is your own user_id; needed to detect already-replied threads
```

If `auth.test` returns `ok: false`, surface the error and stop.

---

## Step 5: Search for the watch user's recent messages

```powershell
${query} = "from:@<username>"
${url}   = "https://slack.com/api/search.messages?query=$([uri]::EscapeDataString(${query}))&sort=timestamp&sort_dir=desc&count=100"
${r}     = Invoke-RestMethod -Uri ${url} -Headers ${headers}
```

Apply the `--days` filter client-side (search.messages does not
accept date filters reliably). Drop matches older than
`(Get-Date).AddDays(-${days})`.

PowerShell strict-mode gotcha: `thread_ts`, `reply_count`,
`reply_users`, and (sometimes) `permalink` are NOT returned by
`search.messages` on user tokens. Treat each match as a flat record;
only `ts`, `channel`, `user`, `text`, and `permalink` (when present)
are reliable. Thread metadata must come from `conversations.history`
in Step 6.

---

## Step 6: Detect already-answered threads

Because `search.messages` strips thread metadata, the answered
signal has to come from `conversations.history`. Collect the unique
channel ids from the Step 5 results, then fetch one history page per
channel filtered to the search window:

```powershell
${cutoffTs} = [int][double]::Parse((Get-Date (Get-Date).AddDays(-${days}).ToUniversalTime() -UFormat %s))
${chIds}    = ${r}.messages.matches | ForEach-Object { $_.channel.id } | Sort-Object -Unique
${parents}  = @{}
foreach (${ch} in ${chIds}) {
    ${url} = "https://slack.com/api/conversations.history?channel=${ch}&oldest=${cutoffTs}&limit=200"
    ${h}   = Invoke-RestMethod -Uri ${url} -Headers ${headers}
    foreach (${m} in ${h}.messages) {
        ${ru} = if (${m}.PSObject.Properties.Name -contains 'reply_users') { ${m}.reply_users } else { @() }
        ${rc} = if (${m}.PSObject.Properties.Name -contains 'reply_count') { ${m}.reply_count } else { 0 }
        ${parents}["${ch}|$(${m}.ts)"] = [pscustomobject]@{ reply_users=${ru}; reply_count=${rc} }
    }
}
```

For each watch-user match:

- Compose the key as `${match.channel.id}|${match.ts}`.
- If `${parents}` contains the key AND `${parents[key]}.reply_users`
  contains your `user_id`, mark the match **answered**.
- Otherwise mark **unanswered**. Watch-user messages that are
  themselves thread replies (in a thread the watch user did not
  start) will NOT appear in `conversations.history` (which returns
  parents only) and will fall through as unanswered. This is the
  safe default: a false negative in the answered bucket is worse
  than a false positive in the unanswered bucket.

If precision matters for an orphan match, fan out one
`conversations.replies?channel=<ch>&ts=<parent_ts>` call per parent
in the same channel and look for both user ids in the reply list.
Skip this fan-out by default to keep API usage bounded.

Items marked answered go to the "already addressed" bucket; all
others remain candidates for HIGH/MEDIUM/LOW classification in
Step 7.

Why this is reliable: `conversations.history` returns `reply_users`
(set-membership of everyone who replied) and `reply_count` for each
parent, which `search.messages` omits entirely. One history call
per channel keeps the run within Slack's tier-2 budget for any
realistic watch-user activity volume.

---

## Step 7: Categorize unanswered items

Sort each remaining message into one bucket using these heuristics:

### HIGH (decisions, blockers, explicit asks)

- Contains an `@<your-username>` mention (lookup via Slack user-id
  format `<@U...>` matching your `user_id`).
- Contains phrases like "this is all you", "your call", "let me know",
  "decision", "blocker", "blocking", "before we can", "need you to",
  ending in a question mark.
- Posted in a channel matching `^bus-`, `^law-`, or `^hr-` (the repo's
  `memory/reference_credentials.md` may list additional decision
  channels under `## Slack workspaces used`; respect those).

### MEDIUM (assigned work)

- Posted in DM (channel id starts with `D`, or channel.name equals
  the watch user's user_id).
- Asks for help, review, or collaboration without a hard decision
  ask. "we can both work on this", "come up with...", "I need you to
  clean up..."

### LOW (FYI / casual)

- No mention, no question mark, no decision phrase.
- Pure tips, links, or thinking-out-loud posts.
- Reactions, emojis-only, or links with no commentary.

### SKIP (filter out of the report)

- System messages: channel renames (`has renamed the channel from
  ... to ...`), joins, leaves.
- Empty-text messages with only file attachments where the attached
  file is unrelated to a decision (judgment call: peek at the
  filename).

---

## Step 8: Format and display

Top line:

```
Slack pings digest, <workspace> workspace, <username>'s last <N> days
<H> high | <M> medium | <L> low | <A> already addressed
```

Prepend the current date/time to surfaces per
`~/.claude/rules/slack.md` rule 7: format `MM/DD/YYYY HH:MM:SS` in
24-hour. Do this once at the top of the digest.

If `${other_run}` from Step 3 is non-null, prepend a coordination
banner immediately under the top line:

```
NOTE: /check-slack ran <X> min ago in <other_run.repo> against this
workspace. That run surfaced <H'> HIGH / <M'> MEDIUM. Overlap with
this run: <O_high> HIGH, <O_medium> MEDIUM (marked [also in
<other_run.repo>] in the tables below).
```

`<X>` is `floor((now - other_run.ts) / 60s)`. `<O_high>` is the size
of `set(this_run.high_thread_ts) intersect set(other_run.high_thread_ts)`,
matched on the parent `thread_ts` (or `ts` for top-level messages).
Same for `<O_medium>`.

For each bucket (HIGH, MEDIUM, LOW), show a table with columns:

```
MM/DD HH:MM | channel | summary (truncate to ~80 chars) | permalink
```

For HIGH and MEDIUM rows whose parent `thread_ts` (or `ts` if top-level)
appears in `${other_run}.high_thread_ts` or `medium_thread_ts`, append
` [also in <other_run.repo>]` to the summary column.

Permalink format if not present in the search result:
`https://<team_domain>.slack.com/archives/<channel_id>/p<ts_no_dot>`
where `<ts_no_dot>` is the `ts` field with the period removed.

Skip the SKIP bucket entirely. Show the "already addressed" bucket
collapsed (just count + date range, e.g., "3 messages already in
threads where you replied").

---

## Step 9: Recommend next actions

After the table, propose 1 to 3 next actions like:

- "HIGH item #1 (`<channel>` <date>): <watch_user> asked for a
  decision on <topic>. Repo state suggests <option>. Want me to draft
  a thread reply?"
- "Two MEDIUM items in DM are assigned to you: <task A>, <task B>.
  Both are open-ended; pick a low-energy slot."

If the coordination banner fired, add one more recommendation:

- "Items marked [also in <other_run.repo>] are likely already in view
  in that session. Defer or coordinate before drafting to avoid
  double-replying."

Keep recommendations grounded in repo state (per the
`docs/architecture/`, `infrastructure/`, and memory files). Do NOT
fabricate context from outside the repo.

---

## Step 10: Hint

At the bottom:

```
Drafts are not auto-posted. Say "draft <item-number>" to get a
proposed reply, "post it" to send. /check-slack --days 14 for a
longer window. /check-slack --from <user> to watch a different user.
```

---

## Step 11: Persist run state (state file write)

After the digest is rendered, append the current run's record to the
state file from Step 3 and write it back atomically.

Algorithm:

1. Build `${this_run}`:
   - `ts` = current UTC ISO-8601 (`(Get-Date).ToUniversalTime().ToString('o')`)
   - `repo` = last path segment of `${cwd}`
   - `high_thread_ts` = parent `thread_ts` (or `ts` if top-level) of every
     HIGH bucket item this run surfaced
   - `medium_thread_ts` = same for MEDIUM
   - `addressed_count`, `low_count` = bucket sizes

2. Read the existing state file (if any), append `${this_run}` to
   `runs`, then trim `runs` to the most recent 10 entries (drop oldest).

3. Wrap the whole read-modify-write in a **named system mutex**. This
   is mandatory on Windows: `Move-Item -Force` is *not* atomic under
   contention (it calls `MoveFileEx` with `MOVEFILE_REPLACE_EXISTING`,
   which fails with "Cannot create a file when that file already
   exists" if another writer races between rename steps). Empirical
   stress test (20 parallel runspaces) loses ~90% of writes without
   the mutex and 0% with it.

```powershell
${dir}    = Join-Path $HOME ".cache/check-slack/${workspace}"
${path}   = Join-Path ${dir} "state.json"
New-Item -ItemType Directory -Force -Path ${dir} | Out-Null

${mtx} = [System.Threading.Mutex]::new($false, "Global\check-slack-state-${workspace}")
try {
    if (-not ${mtx}.WaitOne(5000)) {
        Write-Warning "check-slack: state-file mutex unavailable, skipping persist"
        return
    }
    # Re-read inside the critical section: the data may have changed
    # since Step 3, since Step 3's read was outside the lock.
    ${state} = @{ workspace=${workspace}; watch_user=${watch_user}; runs=@() }
    if (Test-Path ${path}) {
        try { ${state} = Get-Content ${path} -Raw | ConvertFrom-Json } catch { }
    }
    ${runs} = @()
    if (${state}.runs) { ${runs} = @(${state}.runs) }
    ${runs} += ${this_run}
    if (${runs}.Count -gt 10) { ${runs} = ${runs}[-10..-1] }
    ${out} = @{ workspace=${workspace}; watch_user=${watch_user}; runs=${runs} }

    ${tmp} = "${path}.$([guid]::NewGuid().ToString('N')).tmp"
    ${out} | ConvertTo-Json -Depth 6 | Set-Content -Path ${tmp} -Encoding utf8
    Move-Item -Path ${tmp} -Destination ${path} -Force
} finally {
    if (${mtx}) {
        try { ${mtx}.ReleaseMutex() } catch { }
        ${mtx}.Dispose()
    }
}
```

The `Global\` prefix scopes the mutex per Windows session and makes it
visible across processes, so two separate Claude Code sessions
serialize on the same lock. The 5-second `WaitOne` timeout prevents an
indefinite hang if a peer crashes mid-critical-section; if the timeout
fires, log a warning and skip the persist (the next successful run
repairs the omission).

Why re-read inside the critical section: Step 3's read is outside any
lock and is purely for the display banner. By the time Step 11 runs,
the file may have been updated by another session that ran during
Steps 4-10. Re-reading inside the mutex is what prevents lost updates.

Failures writing the state file are non-fatal. Log a single warning
and continue; the next successful run repairs the omission.

---

## Rate-limit and rule notes

- Slack tier-2 endpoints (`search.messages`, `conversations.history`)
  allow ~20 calls/min. The pattern above takes 1 `auth.test` + 1
  `search.messages` + one `conversations.history` per channel the
  watch user posted in (typically 5-15), comfortably under the limit.
- The state file at `~/.cache/check-slack/<workspace>/state.json` is
  a local cache only. It is not committed, not synced, and not a
  Slack write. The skill remains read-only against Slack.
- Per `~/.claude/rules/slack.md` rule 10 (no exfiltration): never
  POST anything to Slack from this skill. Drafting and posting are
  separate operations the user explicitly authorizes.
- Per rule 8: if the watch user has zero matches in the window, say
  so explicitly. Do not invent activity.
- Per rule 3: name the chosen workspace alias in the digest header
  even when discovery picked the obvious one.
