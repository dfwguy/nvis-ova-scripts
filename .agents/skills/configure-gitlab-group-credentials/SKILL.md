---
name: configure-gitlab-group-credentials
description: Configure, verify, rotate, or troubleshoot GitLab group access tokens for Git-over-HTTPS and glab using pass, direnv, and GPG-backed Git Credential Manager. Use when a user asks to add a GitLab group token, set up group-scoped Git or glab access, configure a group workspace, fix credential prompts or 401/403 errors, rotate a group token, or clone a repository with the correct group credential.
---

# Configure GitLab group credentials

Keep three integration points distinct:

- Store the canonical group token at `pass:gitlab/<group>/token`.
- Use a workspace `.envrc` to expose that token as `GITLAB_TOKEN` for `glab`.
- Let GPG-backed Git Credential Manager store a separate credential for each HTTPS repository path.

## Protect the token

- Never ask the user to paste a token into chat.
- Never print, log, commit, or place a token in a remote URL or shell command argument.
- Have the user paste it only into `pass insert -m gitlab/<group>/token`.
- Use the narrowest scopes required: `read_repository` for clone/pull, `write_repository` for push, and `read_api` or `api` for `glab` API operations.
- Treat a token exposed in terminal output, history, source control, or chat as compromised and direct the user to revoke or rotate it immediately.

## Inspect before changing

Determine the group and host from the HTTPS `origin` remote when possible. Then inspect:

```bash
git remote -v
git config --global --get-all credential.helper
git config --global credential.credentialStore
git config --global credential.useHttpPath
command -v pass direnv glab git-credential-manager
direnv status
```

Do not use `credential.helper store`; it writes plaintext. Require Git Credential Manager with the `gpg` credential store and `credential.useHttpPath=true`. On a tbot workstation, also verify `systemctl is-active tbot`; Git URL rewrites may require credentials for `127.0.0.1` instead of the GitLab hostname.

## Create and configure

1. Direct a group Owner to the group's **Settings > Access Tokens** page. Have them create the bot with the needed role and scopes and copy its token immediately.
2. Tell the user to run this themselves in a terminal:

   ```bash
   pass insert -m gitlab/<group>/token
   ```

3. After they confirm the secret exists, run the bundled helper from the intended group workspace:

   ```bash
   scripts/setup-workspace.sh <group> [workspace]
   ```

   Use `--host HOST` for another GitLab instance and `--dry-run` to inspect actions first. The helper refuses mismatched existing token or host exports rather than overwriting them.

4. If this repository contains `scripts/clone-gitlab-group.sh`, prefer it for a new clone. It selects the group token before cloning and approves the exact repository credential.

## Verify

Run read-only checks first:

```bash
direnv status
glab api user
git ls-remote origin
git push --dry-run origin HEAD
```

Do not display the complete `glab api user` response when a short identity summary is enough. Older `glab` releases can return a false 404 for slash-form project paths; verify with `glab api projects/<numeric-project-id>` or the group's project listing before concluding that the token lacks access.

Interpret failures as follows:

- `401`: wrong, expired, revoked, or stale saved token.
- `403`: insufficient role or scope.
- `404` from one `glab` project lookup: first rule out old-client path resolution by querying the numeric project ID.
- Git repeatedly prompts: confirm `credential.useHttpPath=true` and approve the credential for the exact `path=<group>/<repo>.git` context.

## Rotate

Replace the existing `pass` entry, run `direnv reload`, and rerun `scripts/setup-workspace.sh` to approve the replacement for the current repository. Reject known stale Git credential entries only after resolving their exact host, path, and username; do not broadly delete a password store.
