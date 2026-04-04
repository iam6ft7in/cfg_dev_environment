---
name: check-notifications
description: Terminal digest of GitHub notifications — unread notifications grouped by type, plus assigned PRs/issues and review requests.
---

# /check-notifications — GitHub Notification Digest

You are fetching and presenting a structured digest of the user's GitHub activity. Run all data-fetching commands, then format and display the results grouped by priority. Show progress as you fetch ("Fetching notifications...", "Fetching assigned items...").

---

## Step 1: Fetch Unread Notifications

Run:
```
gh api notifications
```

This returns a JSON array of notification objects. Each has:
- `subject.title` — the title
- `subject.type` — PullRequest, Issue, Release, CheckSuite, etc.
- `repository.full_name` — the repo (e.g., `{username}/lib_sensor_utils`)
- `updated_at` — ISO timestamp of last update
- `reason` — why you were notified (assign, mention, review_requested, subscribed, etc.)

Parse the JSON and group by `subject.type`.

For display, convert `updated_at` to a human-readable relative time (e.g., "2 hours ago", "3 days ago").

---

## Step 2: Fetch Assigned Items

Run these three commands:

**PRs assigned to you:**
```
gh pr list --assignee @me --state open --json number,title,repository,createdAt,reviewDecision
```

**Issues assigned to you:**
```
gh issue list --assignee @me --state open --json number,title,repository,createdAt,labels
```

**PRs awaiting your review:**
```
gh pr list --reviewer @me --state open --json number,title,repository,createdAt,headRefName
```

---

## Step 3: Format and Display

Organize output into two priority groups:

### Priority 1: Needs Your Action

Include items where:
- A PR or issue is assigned to you
- A PR is awaiting your review
- Notification reason is `assign` or `review_requested`

Format:
```
NEEDS YOUR ACTION
=================

  Assigned PRs:
    personal/tool_deploy_helper  #5  feat: add retry logic  [Pending review]  (2 days ago)

  Assigned Issues:
    personal/lib_sensor_utils    #12 feat: add temperature calibration  (3 days ago)

  Review Requested:
    client/app_dashboard        #3  fix: dashboard crash on null data  (5 hours ago)
```

If a category has no items, show: `(none)`

---

### Priority 2: FYI

Include items where:
- Notification reason is `mention`, `subscribed`, `comment`, or other
- Releases
- CI check results

Group by notification type:

```
FYI NOTIFICATIONS
=================

  Pull Requests (3):
    personal/lib_sensor_utils    #9  chore: update dependencies  [updated 1 hour ago]
    ...

  Issues (2):
    arduino/custom/fw_flight_ctrl  #2  fix: IMU drift correction  [updated 4 hours ago]
    ...

  Releases (1):
    ArduPilot/ardupilot  ArduCopter-4.5.3  [1 day ago]

  Other (0):
    (none)
```

---

## Step 4: Summary Line

Print a one-line summary at the top of the output (before the sections):

```
GitHub Notifications — {current date/time}
{total unread} unread  |  {assigned PRs} assigned PRs  |  {assigned issues} assigned issues  |  {review requests} review requests
```

---

## Step 5: Hint

At the bottom, print:
```
To mark all notifications as read: gh api -X PUT notifications
To open a specific PR or issue: gh pr view {number} --web  /  gh issue view {number} --web
```
