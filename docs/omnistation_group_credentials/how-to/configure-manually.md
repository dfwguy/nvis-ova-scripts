# How to configure group credentials manually

Use this fallback only when you cannot use the [Codex skill](use-the-codex-skill.md).
The intended end state is one encrypted token at
`pass:gitlab/<group>/token`, a group-workspace `.envrc`, and verification that
Git and `glab` select that group credential. Choose one of these outcomes first:

- **Convenience:** leave the GPG private-key passphrase empty. The workspace
  exports the token so `git`, `glab`, and same-user agents work automatically.
  That same user can also decrypt every secret or file protected with this GPG
  private key.
- **Gated:** use a non-empty GPG passphrase and do not export or save the
  token. The workspace contains only routing metadata; authenticated work stays
  in a trusted human context.

## Commands to run

Substitute `omnistation-platform` and `~/git/omnistation-platform` with the
actual group and workspace. Run the following in order. The key-generation
command is interactive; make the choice described above at its passphrase
prompt.

```bash
sudo apt update
sudo apt install -y pass gnupg direnv
gpg --full-generate-key
gpg --list-secret-keys --fingerprint --keyid-format long
pass init <full-GPG-fingerprint>
git-credential-manager configure
git config --global credential.useHttpPath true
git config --global credential.credentialStore gpg
grep -qxF 'eval "$(direnv hook bash)"' ~/.bashrc || echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
eval "$(direnv hook bash)"
mkdir -p ~/git/omnistation-platform
pass insert -m gitlab/omnistation-platform/token
.agents/skills/configure-gitlab-group-credentials/scripts/setup-workspace.sh --mode convenience omnistation-platform ~/git/omnistation-platform
```

For gated mode, replace only the final command:

```bash
.agents/skills/configure-gitlab-group-credentials/scripts/setup-workspace.sh --mode gated omnistation-platform ~/git/omnistation-platform
```

## What the commands do

`gpg --full-generate-key` creates the private key used by `pass`. Choose a key
that can **sign and encrypt** (normally the `ECC (sign and encrypt)` default),
accept the default curve, and use `0` for no expiration. An empty passphrase is
the convenience choice; a non-empty passphrase is required for gated mode.
Never put the passphrase in a command, file, or chat.

Use the full fingerprint printed by the next command in `pass init`. If
`${PASSWORD_STORE_DIR:-$HOME/.password-store}/.gpg-id` already exists, reuse
that recipient instead; do not reinitialize a populated password store with a
different key.

`pass insert -m` opens an editor-like terminal input. Paste the group token
there, press Ctrl-D, and nowhere else. It directly creates the encrypted entry
at `pass:gitlab/omnistation-platform/token`.

The setup helper directly creates or updates
`~/git/omnistation-platform/.envrc`, adds it to the checkout's local Git
exclude file, and calls `direnv allow`. In convenience mode it also exports the
token and saves the exact HTTPS repository credential when the workspace is an
existing checkout. It refuses plaintext Git credential storage.

For gated mode, set the GPG-agent cache to prompt on every use before relying
on the boundary. Follow [Gate credentials from agents](gate-credentials-from-agents.md).

## Verify the setup

From a repository below the group workspace, use these checks for convenience
mode:

```bash
direnv status
glab api user --hostname "$GITLAB_HOST"
git ls-remote origin
git push --dry-run origin HEAD
.agents/skills/configure-gitlab-group-credentials/scripts/audit-repository-approvals.sh
```

The `glab` command should identify the group bot. `git ls-remote` and the dry
run should use only the repository's group credential. A `403` from the
approval audit means a Maintainer must perform that governance check; it is
not proof that the policy is safe.

For gated mode, do not decrypt merely to test the token. Start a fresh agent
process and run:

```bash
.agents/skills/configure-gitlab-group-credentials/scripts/audit-agent-gate.sh \
  omnistation-platform ~/git/omnistation-platform
```

The audit must report no bypasses before treating the setup as gated. Perform
authenticated checks only in the separate trusted human context.
