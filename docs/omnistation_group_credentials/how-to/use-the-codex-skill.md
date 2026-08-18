# How to use the Codex group-credential skill

Use the repository's `configure-gitlab-group-credentials` skill when you want
Codex to create, human-gate, audit, verify, rotate, or troubleshoot a group-
scoped GitLab setup. The skill presents gated and convenience paths and
requires an explicit choice.

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

## Keep the installed copy current

The repository copy is canonical. After changing it, validate it and replace
the user-scoped copy with the updated directory before publishing the branch.
Begin a new Codex turn if the updated skill metadata is not yet visible.
