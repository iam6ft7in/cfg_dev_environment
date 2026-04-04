---
name: activate-client
description: Step-by-step activation of the client GitHub account identity — SSH key generation, key upload, gitconfig setup, signing, and identity verification.
---

# /activate-client — Activate Client GitHub Identity

You are walking the user through a complete setup of the client GitHub account identity. This is a guided, interactive process. At each step, pause for user confirmation where indicated. Show every command before running it. Do not proceed to the next step until the current step is confirmed complete.

---

## Step 1: Check for Existing SSH Key

Run in PowerShell:
```powershell
Test-Path "$HOME\.ssh\id_ed25519_github_client"
```

**If `True` (key exists):**
Tell the user: "An SSH key already exists at `~\.ssh\id_ed25519_github_client`."
Ask: "Do you want to regenerate it? This will replace the existing key. (yes/no)"
- If no: skip to Step 2 (use the existing key).
- If yes: continue with key generation below.

**If `False` (key does not exist):**
Generate the key:
```powershell
ssh-keygen -t ed25519 -C "{your_name} - GitHub Client" -f "$HOME\.ssh\id_ed25519_github_client"
```
When prompted for a passphrase, let the user decide. Do not force or suggest a specific passphrase.

After generation, confirm the key files exist:
```powershell
Test-Path "$HOME\.ssh\id_ed25519_github_client"
Test-Path "$HOME\.ssh\id_ed25519_github_client.pub"
```

---

## Step 2: Display the Public Key

Run:
```powershell
Get-Content "$HOME\.ssh\id_ed25519_github_client.pub"
```

Display the full key output to the user, then instruct:

```
ACTION REQUIRED — Add this key to your client GitHub account:

1. Go to: https://github.com/settings/keys
   (Make sure you are signed in as the CLIENT account, not your personal account.)

2. Click "New SSH key"
   Title:  {your_name} Client — Authentication
   Type:   Authentication Key
   Key:    {paste the key above}
   Click "Add SSH key"

3. Click "New SSH key" again
   Title:  {your_name} Client — Signing
   Type:   Signing Key
   Key:    {paste the same key again}
   Click "Add SSH key"
```

Pause and ask: "Have you added both the Authentication Key and the Signing Key to GitHub? (yes/no)"
- Do not continue until the user confirms yes.

---

## Step 3: Get Client Noreply Email

Instruct the user:
```
ACTION REQUIRED — Find your client noreply email address:

1. Sign in to GitHub as the client account.
2. Go to: https://github.com/settings/emails
3. Find the noreply address — it looks like:
   {number}+{username}@users.noreply.github.com

Paste it here:
```

Wait for the user to paste the email address. Store it as `{client_noreply_email}`.

Validate that the input looks like a GitHub noreply address (contains `noreply.github.com`). If it does not look right, ask again.

---

## Step 4: Update gitconfig-client

The file `~/.gitconfig-client` should already exist from initial setup. Read it:
```powershell
Get-Content "$HOME\.gitconfig-client"
```

Make the following changes:
1. Replace any placeholder like `UPDATE_WITH_CLIENT_NOREPLY_EMAIL` or an empty `email =` with: `email = {client_noreply_email}`
2. Ensure `user.signingkey` is set to: `~/.ssh/id_ed25519_github_client`
3. Ensure `gpg.format = ssh` is present
4. Ensure `commit.gpgsign = true` is present

Write the updated file back.

Show the user the final content of `~/.gitconfig-client` for confirmation.

---

## Step 5: Update allowed_signers

The file `~/.ssh/allowed_signers` is used by Git to verify SSH commit signatures.

Read the current file (create it if it does not exist):
```powershell
if (-not (Test-Path "$HOME\.ssh\allowed_signers")) { New-Item "$HOME\.ssh\allowed_signers" -Force }
Get-Content "$HOME\.ssh\allowed_signers"
```

Get the client public key:
```powershell
$clientKey = Get-Content "$HOME\.ssh\id_ed25519_github_client.pub"
```

Check if the client noreply email is already in the file. If not, append a new line:
```
{client_noreply_email} {full content of id_ed25519_github_client.pub}
```

Example line format:
```
123456+client@users.noreply.github.com ssh-ed25519 AAAA... {your_name} - GitHub Client
```

Write the updated file.

---

## Step 6: Add Key to SSH Agent

Ensure the SSH agent is running and add the client key:

In Git Bash or PowerShell:
```powershell
Start-Service ssh-agent -ErrorAction SilentlyContinue
ssh-add "$HOME\.ssh\id_ed25519_github_client"
```

Or in Git Bash:
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_github_client
```

Confirm the key was added:
```
ssh-add -l
```

Look for `id_ed25519_github_client` in the output.

---

## Step 7: Verify SSH Connection

Test authentication to GitHub using the client SSH host alias:
```
ssh -T github-client
```

Expected response:
```
Hi client! You've successfully authenticated, but GitHub does not provide shell access.
```

If you see the expected message: tell the user "SSH authentication is working correctly."

If you see `Permission denied (publickey)`:
- The key may not be uploaded yet. Ask the user to re-verify Step 2.
- The SSH config may not have the `github-client` host alias. Check `~/.ssh/config` for the entry and instruct the user to add it if missing:
  ```
  Host github-client
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github_client
    IdentitiesOnly yes
  ```

Do not proceed until the SSH test succeeds.

---

## Step 8: GitHub CLI Authentication for Client

Run:
```
gh auth login --hostname github.com
```

Instruct the user:
```
Follow the prompts in the terminal:
  1. "What account do you want to log into?" — choose GitHub.com
  2. "What is your preferred protocol?" — choose SSH
  3. "Upload your SSH public key to your GitHub account?" — choose the client key if prompted, or skip if already uploaded
  4. "How would you like to authenticate?" — choose "Login with a web browser"
  5. Copy the one-time code shown, open the URL, and authenticate as the CLIENT account.
```

After completing, verify the login:
```
gh auth status
```

Confirm the client username appears in the output.

---

## Step 9: Verify Identity Routing

Create a temporary test repository to confirm commits are signed and attributed to the client identity.

```powershell
$testPath = "$HOME\projects\client\_identity_test"
New-Item -ItemType Directory -Path $testPath -Force
```

```bash
git -C ~/projects/client/_identity_test init
git -C ~/projects/client/_identity_test checkout -b main
echo "identity test" > ~/projects/client/_identity_test/test.txt
git -C ~/projects/client/_identity_test add test.txt
git -C ~/projects/client/_identity_test commit -m "chore: identity test"
```

Check the committed identity:
```
git -C ~/projects/client/_identity_test config user.email
```
This must show the client noreply email, not the personal email.

Check the commit signature:
```
git -C ~/projects/client/_identity_test log --show-signature -1
```
Look for `Good "git" signature` and confirmation the key fingerprint matches the client key.

Clean up:
```powershell
Remove-Item -Recurse -Force "$HOME\projects\client\_identity_test"
```

If the email is wrong or the signature is not verified, revisit Steps 4 and 5.

---

## Step 10: Report Activation Complete

Print a final summary:

```
Client identity activation complete.

  SSH Key:         ~/.ssh/id_ed25519_github_client
  Noreply Email:   {client_noreply_email}
  SSH Alias:       github-client
  SSH Auth:        Verified
  Commit Signing:  Verified
  GH CLI Auth:     Logged in as client

  Repos under ~/projects/client/ will automatically use this identity
  via the conditional include in ~/.gitconfig.

  To start a new client repo: run /new-repo and choose identity: client
```
