# How to use the Codex group-credential skill

Use the repository's `configure-gitlab-group-credentials` skill when you want
Codex to create, human-gate, audit, verify, rotate, or troubleshoot a group-
scoped GitLab setup. The skill presents gated and convenience paths and
requires an explicit choice.

The intended result is one encrypted token at `pass:gitlab/<group>/token`, a
group-workspace `.envrc`, and a verification result without exposing the token.
Use the [skill-first tutorial](../tutorial.md) for the complete first-time
workflow. This page is the short reference for invoking, installing, and
checking the skill.

## Select the passphrase and workspace mode

Make this choice explicitly before asking Codex to configure anything:

| Mode | GPG private-key passphrase | Consequence |
|---|---|---|
| Convenience | Empty | `direnv`, Git Credential Manager, `git`, `glab`, and same-user agents can automatically use the workspace credential. The same private key can also decrypt other data protected with it. |
| Gated | Non-empty, with GPG-agent caching disabled | Codex configures only non-secret workspace metadata. Authenticated operations remain in a trusted human context. |

Leaving the passphrase empty is a convenience feature, not isolation from a
same-user agent or another person sharing that Unix account. The full setup
and verification implications are in [the tutorial](../tutorial.md).

## Invoke it

Ask Codex directly, for example:

```text
Use $configure-gitlab-group-credentials to configure the nvis-ova token for
this workspace.
```

The skill is stored at:

```text
.agents/skills/configure-gitlab-group-credentials/
```

Codex can discover that copy while working in this repository. A user-scoped
copy at `~/.codex/skills/configure-gitlab-group-credentials/` makes it available
from other workspaces on the same machine.

Install the repository copy for the current user with:

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
cp -a .agents/skills/configure-gitlab-group-credentials \
  "${CODEX_HOME:-$HOME/.codex}/skills/"
```

## What it does

The skill checks the current remote and credential backend before changing
anything. In gated mode, its helper:

1. Creates or validates `.envrc` with non-secret routing metadata only.
2. Adds `.envrc` to the checkout's local Git exclude file.
3. Never decrypts, exports, verifies, or approves the token.
4. Refuses an existing token export instead of claiming the workspace is gated.

Run the helper directly when useful:

```bash
.agents/skills/configure-gitlab-group-credentials/scripts/setup-workspace.sh \
  --mode gated --dry-run nvis-ova

.agents/skills/configure-gitlab-group-credentials/scripts/setup-workspace.sh \
  --mode gated nvis-ova

.agents/skills/configure-gitlab-group-credentials/scripts/setup-workspace.sh \
  --mode convenience nvis-ova
```

Run the read-only gate audit with:

```bash
.agents/skills/configure-gitlab-group-credentials/scripts/audit-agent-gate.sh \
  nvis-ova
```

As part of submission, audit whether the Git commit metadata matches the active
token identity:

```bash
.agents/skills/configure-gitlab-group-credentials/scripts/audit-submission-identity.sh \
  --from-token
```

The skill checks commit author/committer, push actor, and merge-request author
separately. A bot token used for push does not automatically make existing or
future commits bot-authored. Identity differences are attribution findings to
report for human review; they do not prevent pushing or opening an MR.

Run the repository-governance audit for the human merge reviewer, preferably
from a Maintainer credential context:

```bash
.agents/skills/configure-gitlab-group-credentials/scripts/audit-repository-approvals.sh
```

It verifies that at least one approval is required, merge-request authors
cannot approve their own work, and individual merge requests cannot lower the
project approval rule. A Developer group token can usually read the rule but
receives `403` for the sensitive project settings; have a human Maintainer run
the audit rather than treating that response as success. A failed or
inconclusive result should be reported in the MR, but it does not block commit,
push, or MR creation.

If the audit reports that no approval rule requires an approval while the
other checks pass, the only change needed is to set the number of required
approvals to `1`. The audit prints the project's direct settings URL. For the
validation project, use [its merge-request settings](https://gitlab-master.nvidia.com/nvis-ova/validation/-/settings/merge_requests).
For another project, use this pattern:

```text
https://gitlab-master.nvidia.com/<group>/<project>/-/settings/merge_requests
```

Rerun the audit after saving the change.

## Publish repository changes for review

For repository-change requests, the expected completion state is a committed
feature branch pushed to GitLab with a merge request opened or updated for
independent human review. Unless you explicitly ask Codex to keep changes
local, it should:

1. Confirm the commit, push, and merge-request identities independently.
2. Run the submission-identity and repository-approval audits.
3. Commit the scoped changes and push the feature branch.
4. Create a merge request, or update the branch's existing open MR, and report
   its direct URL.

Codex must not self-approve or merge the merge request. Identity and
approval-policy findings belong in the review handoff and do not block
publication. Only an actual inability to commit, authenticate, push, or
create/update the MR is a publication blocker, and Codex should state that
blocked step clearly.

Choose convenience mode when you deliberately want `direnv`, `glab`, and Git
Credential Manager to access the token. Convenience mode is not a security
boundary against an agent running as your Unix user. See [gate credentials
from agents](gate-credentials-from-agents.md) before relying on a passphrase as
a human-presence control.

The token must already exist at `pass:gitlab/nvis-ova/token`. Never paste it
or its GPG passphrase into a Codex conversation.

## Verify the setup

Ask Codex to verify the configured workspace using the same skill. In
convenience mode it checks `direnv`, the active `glab` identity, known Git
repository access, and the approval audit. In gated mode it runs the
non-decrypting agent-gate audit; authenticated checks remain in the trusted
human context.

```text
Use $configure-gitlab-group-credentials to verify the nvis-ova workspace in
its current mode.
```

For manual verification commands and failure interpretation, use the
[manual setup how-to](configure-manually.md#verify-the-setup).

## Keep the installed copy current

The repository copy is canonical. After changing it, validate it and replace
the user-scoped copy with the updated directory before publishing the branch.
Begin a new Codex turn if the updated skill metadata is not yet visible.
