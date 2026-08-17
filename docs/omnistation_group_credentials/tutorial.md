# Tutorial: set up Omnistation group credentials

By the end of this tutorial, Git uses the right secure credential for each
repository and `glab` uses the group token for the workspace you are in.

This is for an Ubuntu workstation with multiple GitLab group access tokens on
the same GitLab host. It does not put a token in a repository or remote URL.

**You will need**

- Git Credential Manager, `pass`, and GnuPG
- `direnv` and Bash
- One existing group access token for each Omnistation group
- A group workspace per group, for example `~/git/omnistation-platform`

For `git`, use a token with `read_repository` or `write_repository` as needed.
For `glab`, use `read_api` for read-only API work or `api` for commands that
create or change GitLab objects. See the [reference](reference.md#token-scopes).

## Step 1 — install `pass`

Install the standard Ubuntu package:

```bash
sudo apt update
sudo apt install -y pass
```

Confirm that it is available before continuing:

```bash
pass --version
```

`pass` encrypts secrets with GnuPG. Ensure GnuPG is installed and that you have
an encryption key available before storing a token.

## Step 2 — configure Git to distinguish repositories

Run once:

```bash
git config --global credential.useHttpPath true
git config --global credential.credentialStore gpg
```

Git normally treats all HTTPS repositories on one host as the same credential
context. `credential.useHttpPath=true` makes the repository path part of that
context, so a token for one group/project is not silently offered to another.

## Step 3 — install and enable `direnv` in Bash

Install the standard Ubuntu package:

```bash
sudo apt install -y direnv
```

Confirm that it is available before configuring the shell:

```bash
direnv version
```

Run this in the current shell:

```bash
eval "$(direnv hook bash)"
```

Add the same line to `~/.bashrc` to enable it in future shells:

```bash
eval "$(direnv hook bash)"
```

Open a new terminal, or reload your Bash configuration, before continuing.

## Step 4 — store one group token in `pass`

Choose a stable secret path from the group name. For example, store the token
for the `omnistation-platform` group:

```bash
pass insert -m gitlab/omnistation-platform/token
```

Paste the token only when `pass` prompts, then press Ctrl-D. Do not paste a
token into this document, a command line, or a chat window.

## Step 5 — attach the token to the group workspace

At the root of that group workspace, create `.envrc` with this one line:

```bash
export GITLAB_TOKEN="$(pass show gitlab/omnistation-platform/token)"
```

If this directory is a Git repository, add `.envrc` to that repository's local
`.gitignore`. Never commit `.envrc`, even though it contains only a secret
lookup: it identifies the secret-store layout and becomes executable when
trusted by `direnv`.

Approve the file:

```bash
direnv allow
```

When you enter the workspace or any repository below it, `direnv` loads this
group's `GITLAB_TOKEN`; when you leave, it removes the variable. Repeat steps
4–5 for each group workspace, using a different `pass` path.

Do not put a broad main token in `~/git/.envrc` unless you deliberately want it
available in every workspace that has no nearer `.envrc`. A group workspace
`.envrc` is nearer for repositories below it, so it replaces—not combines
with—the parent context. Do not call `source_up` from a group `.envrc`.

## Step 6 — verify `glab`

From inside a repository that has the expected GitLab remote, run:

```bash
glab auth status
```

The environment token takes precedence over any global `glab` login. If the
workspace has no Git remote, set the GitLab host in `.envrc` too:

```bash
export GITLAB_HOST=gitlab-master.nvidia.com
```

Then test an API action appropriate to the token's scope, for example:

```bash
glab repo view
```

Do not use `glab auth login` to switch between group tokens on the same host:
it sets a host-level default rather than a workspace-level one.

## Step 7 — clone with the group token

Use the included helper to create the group workspace if needed, configure its
local `.envrc`, save the matching credential for this exact repository path,
and clone:

```bash
scripts/clone-gitlab-group.sh omnistation-platform \
  https://gitlab-master.nvidia.com/omnistation-platform/project-a.git
```

The helper obtains the token from `pass:gitlab/omnistation-platform/token`; it
does not read a token from an argument, write one to a remote URL, or expose a
parent workspace's credential inside the new checkout. See [the cloning
how-to](how-to/clone-a-group-repository.md) for the interface and behavior.

## Step 8 — let Git save a credential manually (optional)

From a repository in this group, run a normal operation:

```bash
git fetch
```

When Git Credential Manager prompts, enter a non-blank username (the group bot
username is clearest) and the group token as the password. It stores the
credential securely using the configured GPG-backed store. This is only needed
when you do not use the cloning helper, or when adding an existing checkout.

## What you built

- `pass` holds each group token once, encrypted with GnuPG.
- `.envrc` selects exactly one token for `glab` based on the current workspace.
- Git Credential Manager retains credentials independently by HTTPS repository
  path, either through the helper or a normal Git prompt.

Next, read [why this is split by client and workspace](explanation.md), and
use [the rotation how-to](how-to/rotate-or-replace-a-group-token.md) when a
token changes.
