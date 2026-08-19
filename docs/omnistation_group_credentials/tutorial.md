# Tutorial: set up Omnistation group credentials

By the end of this tutorial, Git uses the right secure credential for each
repository and `glab` uses the group token for the workspace you are in.

This is for an Ubuntu workstation with multiple GitLab group access tokens on
the same GitLab host. It does not put a token in a repository or remote URL.

This tutorial describes **convenience mode**: `direnv` decrypts the token into
the workspace environment. It is not a security boundary against an agent
running as the same Unix user. If you need human presence before an agent can
obtain a token, follow [gate credentials from agents](how-to/gate-credentials-from-agents.md)
instead.

**You will need**

- Git Credential Manager, `pass`, and GnuPG
- `direnv` and Bash
- One existing group access token for each Omnistation group
- A group workspace per group, for example `~/git/omnistation-platform`

For `git`, use a token with `read_repository` or `write_repository` as needed.
For `glab`, use `read_api` for read-only API work or `api` for commands that
create or change GitLab objects. See the [reference](reference.md#token-scopes).

## Step 1 — install and initialize `pass`

Install the standard Ubuntu package:

```bash
sudo apt update
sudo apt install -y pass gnupg
```

Confirm that it is available before continuing:

```bash
pass --version
gpg --version
```

`pass` encrypts secrets to a GnuPG key. First check whether this password store
is already initialized and list the secret keys available to you:

```bash
pass ls
gpg --list-secret-keys --fingerprint --keyid-format long
```

If `${PASSWORD_STORE_DIR:-$HOME/.password-store}/.gpg-id` already exists, reuse
the recipient recorded there. Do not run `pass init` with a different recipient
against a populated store unless you intend to re-encrypt its existing entries.

For a new password store with no suitable key, create one interactively in a
trusted terminal:

```bash
gpg --full-generate-key
```

Use a non-empty passphrase when GnuPG's pinentry window prompts. Never paste the
passphrase into a command, document, or chat. When key generation finishes,
display the full fingerprint:

```bash
gpg --list-secret-keys --fingerprint --keyid-format long
```

Initialize `pass` with that full fingerprint, then verify the store:

```bash
pass init <full-GPG-fingerprint>
pass ls
```

The password store is now ready for the group token in step 4. If you need the
passphrase to act as a human-presence gate, use the gated-mode guide instead of
relying on this convenience-mode tutorial.

## Step 2 — configure Git to distinguish repositories

Run once:

```bash
git-credential-manager configure
git config --global credential.useHttpPath true
git config --global credential.credentialStore gpg
```

The first command registers Git Credential Manager as Git's credential helper.
Git normally treats all HTTPS repositories on one host as the same credential
context. `credential.useHttpPath=true` makes the repository path part of that
context, so a token for one group/project is not silently offered to another.
The clone helper verifies all three settings before it decrypts or approves a
token.

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

## Step 5 — attach the token to the group workspace in convenience mode

At the root of that group workspace, allow `direnv` before creating `.envrc`:

```bash
direnv allow
```

Then create `.envrc` with `echo`:

```bash
echo 'export GITLAB_TOKEN="$(pass show gitlab/omnistation-platform/token)"' > .envrc
```

If this directory is a Git repository, add `.envrc` to that repository's local
`.gitignore`. Never commit `.envrc`, even though it contains only a secret
lookup: it identifies the secret-store layout and becomes executable when
trusted by `direnv`.

After creating or changing `.envrc`, approve its new contents:

```bash
direnv allow
```

When you enter the workspace or any repository below it, `direnv` loads this
group's `GITLAB_TOKEN`; when you leave, it removes the variable. Repeat steps
4–5 for each group workspace, using a different `pass` path.

### Require the GnuPG passphrase on each workspace entry

`pass` encrypts the token with your GnuPG key. By default, `gpg-agent` caches
the key passphrase, so re-entering a workspace may not prompt. To require the
passphrase whenever `direnv` loads the workspace credential, add these lines to
`~/.gnupg/gpg-agent.conf`:

```text
default-cache-ttl 0
max-cache-ttl 0
no-allow-external-cache
```

Then flush and reload the agent configuration:

```bash
gpgconf --reload gpg-agent
```

With this setting, leaving the workspace and entering it again causes the
`.envrc` lookup to prompt for the GnuPG passphrase. `direnv` does not re-run an
unchanged `.envrc` while moving between subdirectories that remain under the
same workspace, so it does not prompt for every `cd` there.

This protects decryption on workspace entry; it does not protect the token
after `direnv` exports it. Every process started in that environment can use
the token.

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
workspace has no Git remote, append the GitLab host to `.envrc` with `echo`:

```bash
echo 'export GITLAB_HOST=gitlab-master.nvidia.com' >> .envrc
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

## Step 9 — check merge-request approval policy

Run the repository approval audit for the human merge reviewer, preferably
from a Maintainer credential context:

```bash
.agents/skills/configure-gitlab-group-credentials/scripts/audit-repository-approvals.sh
```

If the audit says no approval rule requires an approval and the other checks
pass, the only change needed is to set the number of required approvals to
`1`. Open the direct settings URL printed by the audit. For the validation
project, it is [the merge-request settings page](https://gitlab-master.nvidia.com/nvis-ova/validation/-/settings/merge_requests).
For another project, use:

```text
https://gitlab-master.nvidia.com/<group>/<project>/-/settings/merge_requests
```

Save the change and rerun the audit. If the author-approval or per-MR override
checks also fail, correct those specific controls as described in the
[configuration reference](reference.md#repository-approval-safeguards).
Audit failures or a Maintainer-only `403` should be reported in the MR, but do
not prevent committing, pushing, or opening the MR for human review.

## What you built

- `pass` holds each group token once, encrypted with GnuPG.
- `.envrc` selects exactly one token for `glab` based on the current workspace.
- Git Credential Manager retains credentials independently by HTTPS repository
  path, either through the helper or a normal Git prompt.
- GitLab requires an independent approval before repository changes can merge.

Next, read [why this is split by client and workspace](explanation.md), and
use [the rotation how-to](how-to/rotate-or-replace-a-group-token.md) when a
token changes.
