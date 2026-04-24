---
description: VMware Tools / vmrun rules. Stack-specific, opt-in via @-import from a repo CLAUDE.md. Not auto-loaded.
---

# VMware Tools / vmrun Rules

## VMware Tools Guest Operations

The built-in Administrator account (SID-500) does not work reliably with vmrun
guest operations (`runProgramInGuest`, `copyFileFromHostToGuest`, etc.) even when
renamed. Use a non-SID-500 account or domain credentials instead.

If a guest script changes the password of the account used for vmrun `-gp`
authentication, all subsequent vmrun calls in the same host script will fail
authentication. Either:
- Use a separate account for vmrun that the guest script does not modify, or
- Extract and update the in-memory credential after the password change before
  making any further vmrun calls
