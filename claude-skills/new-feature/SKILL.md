---
name: new-feature
description: Start a fully tracked feature branch with a linked GitHub issue, ensuring main is clean and up to date before branching.
---

# /new-feature — Start a Tracked Feature Branch

You are preparing the repository for new work. Follow every step in order. Show each command before running it.

---

## Step 1: Verify You Are on Main

Run:
```
git branch --show-current
```

If the output is NOT `main`:
- Tell the user: "You are currently on branch `{current_branch}`, not `main`."
- Ask: "Do you want to switch to main before creating a new branch? (yes/no)"
- If yes: run `git checkout main`
- If no: stop and explain that /new-feature must be started from main.

---

## Step 2: Ensure Main Is Up to Date

Run:
```
git pull
```

If there are conflicts or errors, stop and report them. Do not continue until main is clean.

---

## Step 3: Gather Branch Information

Ask the user for each of the following:

### 3a. Branch Type
Present a numbered list:
1. feat — new feature
2. fix — bug fix
3. docs — documentation change
4. chore — maintenance, dependency updates, config
5. refactor — code restructuring without behavior change
6. test — adding or updating tests

Wait for the user to pick a number or type the prefix.

### 3b. Description
- Ask: "Enter a short description for this branch (will become the branch name suffix)."
- Automatically convert the input to `snake_case`:
  - Lowercase everything
  - Replace spaces and hyphens with underscores
  - Remove any characters that are not alphanumeric or underscores
- Show the user the converted name and ask them to confirm: "Branch will be named `{type}/{snake_case_description}`. Confirm? (yes/no)"

### 3c. Issue Title
- Default: use the description as entered (before snake_case conversion, but cleaned up).
- Ask: "Issue title will be `{type}: {description}`. Press Enter to accept or type a new title."
- Accept the user's input or use the default if they press Enter without typing.

---

## Step 4: Create GitHub Issue

Run:
```
gh issue create --title "{type}: {description}" --label "{type}" --body ""
```

Note the issue number from the output (it will appear as a URL ending in `/{number}`). Store this as `{issue_number}`.

If the label does not exist yet, `gh issue create` may warn you. In that case, create the label first:
```
gh label create {type} --color "0075ca" --description "{type}"
```
Then retry issue creation.

---

## Step 5: Move Issue to "In Progress" on Projects Board

Check if the repository has a linked GitHub Project:
```
gh project list --owner @me
```

If a project board exists that matches the repo, move the issue to "In Progress":
```
gh issue edit {issue_number} --add-project "{project_name}"
```

If the Projects v2 API is available, use it to set the status field to "In Progress". If this is not possible through the CLI, note to the user: "Please manually move issue #{issue_number} to In Progress on the Projects board."

---

## Step 6: Create and Checkout the Branch

Run:
```
git checkout -b {type}/{snake_case_description}
```

Verify the branch was created:
```
git branch --show-current
```

Confirm the output matches `{type}/{snake_case_description}`.

---

## Step 7: Show Summary

Print a clean summary:

```
Branch ready.

  Branch:  {type}/{snake_case_description}
  Issue:   #{issue_number} — {issue_title}
  Status:  In Progress

Next steps:
  1. Make your changes.
  2. Commit using Conventional Commits: git commit -m "{type}: description"
  3. When ready to open a PR, run /pr-create
```
