# How to use the Codex group-credential skill

Use the repository's `configure-gitlab-group-credentials` skill when you want
Codex to create, verify, rotate, or troubleshoot a group-scoped GitLab setup.
It implements the same `pass` + `direnv` + Git Credential Manager model as this
guide.

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
anything. After you create the group access token in GitLab and insert it into
`pass`, its helper:

1. Creates or validates the workspace `.envrc` without storing the token in it.
2. Adds `.envrc` to the checkout's local Git exclude file.
3. Approves the group token for the exact HTTPS repository path through
   GPG-backed Git Credential Manager.
4. Verifies the group bot through the GitLab API without displaying the token.

Run the helper directly when useful:

```bash
.agents/skills/configure-gitlab-group-credentials/scripts/setup-workspace.sh \
  --dry-run nvis-ova

.agents/skills/configure-gitlab-group-credentials/scripts/setup-workspace.sh \
  nvis-ova
```

The token must already exist at `pass:gitlab/nvis-ova/token`. Never paste it
into a Codex conversation.

## Keep the installed copy current

The repository copy is canonical. After changing it, validate it and replace
the user-scoped copy with the updated directory. Begin a new Codex turn if the
updated skill metadata is not yet visible.
