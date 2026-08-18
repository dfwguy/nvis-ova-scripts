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

Choose convenience mode when you deliberately want `direnv`, `glab`, and Git
Credential Manager to access the token. Convenience mode is not a security
boundary against an agent running as your Unix user. See [gate credentials
from agents](gate-credentials-from-agents.md) before relying on a passphrase as
a human-presence control.

The token must already exist at `pass:gitlab/nvis-ova/token`. Never paste it
or its GPG passphrase into a Codex conversation.

## Keep the installed copy current

The repository copy is canonical. After changing it, validate it and replace
the user-scoped copy with the updated directory. Begin a new Codex turn if the
updated skill metadata is not yet visible.
