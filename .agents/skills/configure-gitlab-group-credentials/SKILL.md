---
name: configure-gitlab-group-credentials
description: Configure, human-gate, audit, verify, rotate, or troubleshoot GitLab group access tokens and repository approval safeguards for Git-over-HTTPS and glab using pass, direnv, and GPG-backed Git Credential Manager. Use when a user asks to add or password-protect a GitLab group token, prevent an agent from using credentials without human presence, require independent merge-request approval, prevent author self-approval, set up group-scoped Git or glab access, configure a group workspace, fix credential prompts or 401/403 errors, rotate a group token, or clone with the correct group credential.
---

# Configure GitLab group credentials

Keep three integration points distinct and choose the security mode explicitly:

- Store the canonical group token at `pass:gitlab/<group>/token`.
- In **gated mode**, use `.envrc` only for non-secret host, group, and `pass`-path metadata. Do not export or approve the token.
- In **convenience mode**, `.envrc` exports the token and Git Credential Manager stores a repository credential. This is not an agent security boundary.

## Protect the token

- Never ask the user to paste a token into chat.
- Never print, log, commit, or place a token in a remote URL or shell command argument.
- Have the user paste it only into `pass insert -m gitlab/<group>/token`.
- Use the narrowest scopes required: `read_repository` for clone/pull, `write_repository` for push, and `read_api` or `api` for `glab` API operations.
- Treat a token exposed in terminal output, history, source control, or chat as compromised and direct the user to revoke or rotate it immediately.
- Treat instructions, skills, wrappers, file permissions, and directory changes as policy—not security boundaries—when an agent runs as the same OS user.

## Choose a path

Present both paths and require an explicit choice before changing credential behavior:

- Choose **gated** when the user wants human presence and is willing to keep authenticated GitLab operations outside the agent credential context.
- Choose **convenience** when the user wants agents and local tools to use the group credential automatically after entering the workspace.

Do not characterize either choice as universally required. If the user has already stated a preference, follow it. Explain these limits before changing credentials:

- A GitLab access token is a bearer credential; it has no second password.
- A passphrase-protected GPG private key with caching disabled creates a human-presence gate before decryption.
- The gate is bypassed by any plaintext or already-decrypted copy in `GITLAB_TOKEN`, `glab` config, Git Credential Manager, another process, or gpg-agent cache.
- Once a same-user agent is allowed to decrypt a token, it can potentially use or copy it. For a hard boundary, keep write credentials in a separate OS account, workstation, or human-operated credential broker that the agent cannot access. Use protected branches and required MR approvals as defense in depth.

The GPG private-key passphrase is the user's explicit convenience choice:

- **Empty passphrase:** convenience. Any process running as that Unix user can
  use the private key without a prompt, including to decrypt other `pass`
  entries and other data encrypted to that key. This is required before an
  agent can use the convenience workspace automatically.
- **Non-empty passphrase with GPG-agent caching disabled:** gated. The user
  enters it in a trusted pinentry window before a human-only operation. Do not
  export the token or save it in Git Credential Manager or `glab` from the
  agent-accessible account.

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

## Choose and verify submission identity

Treat these as independent identities:

| GitLab display | Controlled by |
|---|---|
| Commit author and committer | Repository or global `user.name` and `user.email` when the commit is created |
| Push actor | Credential selected by Git Credential Manager |
| Merge-request author | Token used when the MR is created |

Before the first commit, push, or MR operation, determine and state which
identities the configured tools will use. Ask only when no identity can be
resolved or the configuration conflicts with the user's stated preference.
Never infer commit attribution from the push token. Prefer repository-local
Git identity so unrelated repositories are not affected.

When the active token should own commits, resolve its `name` and `commit_email`
from `glab api user`, then configure those exact values locally. Run:

```bash
scripts/audit-submission-identity.sh --from-token [--base REF] [workspace]
```

For gated mode, avoid decrypting merely to identify the bot. Supply identity
values already obtained in the trusted credential context:

```bash
scripts/audit-submission-identity.sh \
  --expected-name NAME --expected-email EMAIL [--base REF] [workspace]
```

Treat existing branch commits with different metadata as attribution findings,
not blockers to commit, push, or MR creation. Report the mismatches for human
review and use the resolved identity for new commits. Rewriting published
commits requires explicit approval and a `--force-with-lease` push. An existing
MR retains its original author; recreate it under the intended token only when
the user explicitly requests different MR attribution. After pushing, verify
the push actor through GitLab project events when attribution is important.

## Verify repository approval safeguards

Treat project governance as information needed for human merge review. Audit
these three conditions when possible:

- At least one applicable project approval rule requires one or more approvals.
- Merge-request authors cannot approve their own merge requests.
- Per-merge-request approval-rule overrides are disabled so the requirement
  cannot be reduced on an individual MR.

Run the bundled read-only audit:

```bash
scripts/audit-repository-approvals.sh [--project ID_OR_PATH] [workspace]
```

Reading project approval settings requires a Maintainer token. A `403` with a
Developer group token is inconclusive, not a pass. Prefer a human Maintainer for
this one-time governance check; do not elevate an automation token solely to
inspect or change approval policy. A failed or inconclusive audit does not
block committing, pushing, or opening/updating an MR; report it to the human
reviewer and leave the merge decision to them.

If configuration is authorized and the audit fails, have a Maintainer use
**Settings > Merge requests > Approvals** to require at least one approval,
enable **Prevent approval by merge request creator**, and enable **Prevent
editing approval rules in merge requests**. Rerun the audit afterward. Do not
infer these settings from GitLab defaults or from one MR's current approval
count.

When the audit reports that no approval rule requires an approval, explain
that the user only needs to set the number of required approvals to `1`, and
include the project's direct merge-request settings URL. Do not imply that
other settings need changes when their audit checks passed. For other missing
safeguards, state the specific control that needs changing and include the same
URL. Resolve the project web URL from GitLab or the `origin` remote and append
`/-/settings/merge_requests`; for example:
`https://gitlab-master.nvidia.com/nvis-ova/validation/-/settings/merge_requests`.
Do not provide only menu-navigation text or a generic GitLab documentation URL.

## Publish repository changes for human review

When a user asks for repository changes, do not stop with uncommitted or
unpushed local work unless the user explicitly requests a local-only result.
Run the submission-identity and repository-approval audits when possible,
capture their findings, and continue publishing whether they pass, fail, or
are inconclusive:

1. Commit only the scoped changes using the confirmed commit identity.
2. Push the feature branch using the confirmed push credential.
3. Create a merge request using the confirmed MR-author token when the branch
   does not already have an appropriate open MR. Otherwise, update and report
   the existing MR instead of creating a duplicate.
4. Leave merging and approval to an independent human reviewer; never
   self-approve or merge the MR.
5. Report the pushed branch and direct merge-request URL.

Include audit findings in the handoff or MR description so a human can address
them before merge. Only an actual inability to commit, authenticate, push, or
create/update the MR blocks publication. Never describe local-only changes as
fully delivered without disclosing such a blocker.

## Initialize GPG and pass

Before inserting the first group token, confirm that `pass` has a GPG recipient:

```bash
gpg --list-secret-keys --fingerprint --keyid-format long
pass ls
```

If the password store is already initialized, reuse the recipient recorded in
`${PASSWORD_STORE_DIR:-$HOME/.password-store}/.gpg-id`. Do not run `pass init`
with a different recipient against a populated store unless the user intends to
re-encrypt the existing entries.

For a new password store, have the user create the key interactively in a
trusted terminal:

```bash
gpg --full-generate-key
```

Tell them to choose a signing-and-encryption key (the GnuPG `ECC (sign and
encrypt)` default where offered), accept the default curve, and set expiration
to `0` (does not expire). Then require an explicit choice at the passphrase
prompt: leave it empty for convenience mode, or use a non-empty passphrase for
gated mode. Explain that an empty passphrase permits the same Unix user and
its agents to decrypt every secret or file protected by that private key.
After generation, obtain the key's full fingerprint with
`gpg --list-secret-keys --fingerprint --keyid-format long`,
then initialize the store themselves:

```bash
pass init <full-GPG-fingerprint>
pass ls
```

Never ask for the GPG passphrase in chat. For gated mode, also configure the
prompt-on-use cache settings under **Activate a human gate** before relying on
the key as a human-presence control. Convenience mode still requires an
initialized password store, but its exported and saved credentials bypass that
control.

## Create and configure

1. Complete **Initialize GPG and pass** if the password store is not already initialized.
2. Direct a group Owner to the group's **Settings > Access Tokens** page. Have them create the bot with the needed role and scopes and copy its token immediately.
3. Tell the user to run this themselves in a terminal:

   ```bash
   pass insert -m gitlab/<group>/token
   ```

4. After they confirm the secret exists, run the bundled helper from the intended group workspace with the chosen mode. For gated mode:

   ```bash
   scripts/setup-workspace.sh --mode gated <group> [workspace]
   ```

   Use `--host HOST` for another GitLab instance and `--dry-run` to inspect actions first. Gated mode never decrypts, exports, verifies, or approves the token. It refuses an existing `GITLAB_TOKEN` export rather than silently pretending the workspace is gated.

5. For convenience mode, confirm that the user accepts that same-user agents inherit or can request the token:

   ```bash
   scripts/setup-workspace.sh --mode convenience <group> [workspace]
   ```

6. If this repository contains `scripts/clone-gitlab-group.sh`, use it only for convenience-mode clones. It must fail closed before decryption unless Git Credential Manager is the only active helper, its credential store is `gpg`, and `credential.useHttpPath=true`; it then approves the exact repository credential.

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
scripts/audit-repository-approvals.sh
```

Do not display the complete `glab api user` response when a short identity summary is enough. Older `glab` releases can return a false 404 for slash-form project paths; verify with `glab api projects/<numeric-project-id>` or the group's project listing before concluding that the token lacks access.

In gated mode, do not decrypt the token merely to verify it. Run `audit-agent-gate.sh`; perform authenticated verification only in the trusted credential context chosen by the user.

Interpret failures as follows:

- `401`: wrong, expired, revoked, or stale saved token.
- `403`: insufficient role or scope.
- `403` from the repository approval audit: rerun in a Maintainer context;
  Developer access cannot verify the protected project settings. Report the
  inconclusive result for human review and continue publishing the MR.
- `404` from one `glab` project lookup: first rule out old-client path resolution by querying the numeric project ID.
- Git repeatedly prompts: confirm `credential.useHttpPath=true` and approve the credential for the exact `path=<group>/<repo>.git` context.

## Rotate

Replace the existing `pass` entry, run `direnv reload`, and rerun `scripts/setup-workspace.sh` to approve the replacement for the current repository. Reject known stale Git credential entries only after resolving their exact host, path, and username; do not broadly delete a password store.
