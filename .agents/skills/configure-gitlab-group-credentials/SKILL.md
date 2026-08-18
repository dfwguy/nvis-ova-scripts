---
name: configure-gitlab-group-credentials
description: Configure, human-gate, audit, verify, rotate, or troubleshoot GitLab group access tokens for Git-over-HTTPS and glab using pass, direnv, and GPG-backed Git Credential Manager. Use when a user asks to add or password-protect a GitLab group token, prevent an agent from using credentials without human presence, set up group-scoped Git or glab access, configure a group workspace, fix credential prompts or 401/403 errors, rotate a group token, or clone with the correct group credential.
---

# Configure GitLab group credentials

Keep three integration points distinct and choose the security mode explicitly:

- Store the canonical group token at `pass:gitlab/<group>/token`.
- In **gated mode**, use `.envrc` only for non-secret host, group, and `pass`-path metadata. Do not export or approve the token.
- In opt-in **convenience mode**, `.envrc` exports the token and Git Credential Manager stores a repository credential. This is not an agent security boundary.

## Protect the token

- Never ask the user to paste a token into chat.
- Never print, log, commit, or place a token in a remote URL or shell command argument.
- Have the user paste it only into `pass insert -m gitlab/<group>/token`.
- Use the narrowest scopes required: `read_repository` for clone/pull, `write_repository` for push, and `read_api` or `api` for `glab` API operations.
- Treat a token exposed in terminal output, history, source control, or chat as compromised and direct the user to revoke or rotate it immediately.
- Treat instructions, skills, wrappers, file permissions, and directory changes as policy—not security boundaries—when an agent runs as the same OS user.

## Choose the gate

Default to gated mode when the user wants human control. Explain these limits before changing credentials:

- A GitLab access token is a bearer credential; it has no second password.
- A passphrase-protected GPG private key with caching disabled creates a human-presence gate before decryption.
- The gate is bypassed by any plaintext or already-decrypted copy in `GITLAB_TOKEN`, `glab` config, Git Credential Manager, another process, or gpg-agent cache.
- Once a same-user agent is allowed to decrypt a token, it can potentially use or copy it. For a hard boundary, keep write credentials in a separate OS account, workstation, or human-operated credential broker that the agent cannot access. Use protected branches and required MR approvals as defense in depth.

Run the bundled read-only audit without decrypting the token:

```bash
scripts/audit-agent-gate.sh <group> [workspace]
```

Do not claim the gate is active until the audit passes in a newly started agent process.

## Inspect before changing

Determine the group and host from the HTTPS `origin` remote when possible. Then inspect:

```bash
git remote -v
git config --global --get-all credential.helper
git config --global credential.credentialStore
git config --global credential.useHttpPath
command -v pass direnv glab git-credential-manager
direnv status
scripts/audit-agent-gate.sh <group> [workspace]
```

Do not use `credential.helper store`; it writes plaintext. Require Git Credential Manager with the `gpg` credential store and `credential.useHttpPath=true`. On a tbot workstation, also verify `systemctl is-active tbot`; Git URL rewrites may require credentials for `127.0.0.1` instead of the GitLab hostname.

## Create and configure

1. Direct a group Owner to the group's **Settings > Access Tokens** page. Have them create the bot with the needed role and scopes and copy its token immediately.
2. Tell the user to run this themselves in a terminal:

   ```bash
   pass insert -m gitlab/<group>/token
   ```

3. After they confirm the secret exists, run the bundled helper from the intended group workspace. Gated mode is the default:

   ```bash
   scripts/setup-workspace.sh <group> [workspace]
   ```

   Use `--host HOST` for another GitLab instance and `--dry-run` to inspect actions first. Gated mode never decrypts, exports, verifies, or approves the token. It refuses an existing `GITLAB_TOKEN` export rather than silently pretending the workspace is gated.

4. Use `--mode convenience` only after the user explicitly accepts that same-user agents inherit or can request the token:

   ```bash
   scripts/setup-workspace.sh --mode convenience <group> [workspace]
   ```

5. If this repository contains `scripts/clone-gitlab-group.sh`, use it only for convenience-mode clones. It decrypts the group token and approves the exact repository credential.

## Activate a human gate

Require the user to perform passphrase entry and token rotation in a trusted terminal, outside the agent process:

1. Password-protect the private GPG key used by `pass` with `gpg --passwd <fingerprint>`.
2. Configure `default-cache-ttl 0`, `max-cache-ttl 0`, and `no-allow-external-cache` in `~/.gnupg/gpg-agent.conf`, then reload gpg-agent.
3. Remove the token export from `.envrc`, host-level tokens from `glab` config, and exact saved Git credentials. Resolve exact targets before removal; never delete the password store broadly.
4. Rotate a token that was previously available to an agent and insert the replacement into `pass` only from the trusted terminal.
5. Stop all agent processes that inherited the old environment, start a fresh process, and rerun `audit-agent-gate.sh`.

Read `docs/omnistation_group_credentials/how-to/gate-credentials-from-agents.md` when it is available in the current repository. Do not perform destructive cleanup or token rotation without confirming the exact target and warning that active sessions will lose access.

## Verify

In convenience mode, run read-only checks first:

```bash
direnv status
glab api user
git ls-remote origin
git push --dry-run origin HEAD
```

Do not display the complete `glab api user` response when a short identity summary is enough. Older `glab` releases can return a false 404 for slash-form project paths; verify with `glab api projects/<numeric-project-id>` or the group's project listing before concluding that the token lacks access.

In gated mode, do not decrypt the token merely to verify it. Run `audit-agent-gate.sh`; perform authenticated verification only in the trusted credential context chosen by the user.

Interpret failures as follows:

- `401`: wrong, expired, revoked, or stale saved token.
- `403`: insufficient role or scope.
- `404` from one `glab` project lookup: first rule out old-client path resolution by querying the numeric project ID.
- Git repeatedly prompts: confirm `credential.useHttpPath=true` and approve the credential for the exact `path=<group>/<repo>.git` context.

## Rotate

Replace the existing `pass` entry, run `direnv reload`, and rerun `scripts/setup-workspace.sh` to approve the replacement for the current repository. Reject known stale Git credential entries only after resolving their exact host, path, and username; do not broadly delete a password store.
