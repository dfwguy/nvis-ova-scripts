# Tutorial: set up group credentials with the Codex skill

This is the recommended way to set up an Omnistation GitLab group credential.
By the end, the token is stored once at `pass:gitlab/<group>/token`, the group
workspace is configured in the selected mode, and the skill has verified the
result without displaying the token.

The skill handles the end-to-end configuration: it checks the current Git and
credential setup, asks you to select a mode, creates the workspace `.envrc`,
configures the correct Git credential context when appropriate, and runs the
relevant verification. You perform only the interactive secret and passphrase
steps in a trusted terminal.

## Choose the mode before you start

| Choice | GPG-key passphrase | Result |
|---|---|---|
| Convenience | Leave it empty | `direnv`, Git Credential Manager, `git`, and `glab` can use the group token automatically in the workspace. Any same-user process or agent can also use the private key to decrypt other data encrypted to it. |
| Gated | Use a non-empty passphrase | The workspace records only non-secret routing metadata. The agent does not decrypt, export, verify, or save the token; perform authenticated operations in a trusted human context. |

An empty GPG passphrase is a deliberate convenience choice, not a security
boundary. A GitLab token remains a bearer credential in either mode. If you
need a hard boundary from same-user agents, keep write credentials in a
separate OS account, workstation, or human-operated credential broker.

## 1. Ask Codex to run the skill

From this repository, start with one of these requests. The skill will ask for
the missing group, workspace, and explicit mode rather than assuming them.

```text
Use $configure-gitlab-group-credentials to configure the
omnistation-platform group credential in convenience mode for
~/git/omnistation-platform.
```

```text
Use $configure-gitlab-group-credentials to configure the
omnistation-platform group credential in gated mode for
~/git/omnistation-platform.
```

If you invoke Codex outside this repository, first install the repository copy
of the skill as described in [the skill how-to](how-to/use-the-codex-skill.md).

## 2. Complete the interactive setup the skill requests

For a new password store, the skill asks you to create the GPG key in your own
trusted terminal. At `gpg --full-generate-key`, choose a key that can **sign and
encrypt** (normally GnuPG's `ECC (sign and encrypt)` default), accept the
default curve, and enter `0` for no expiration. At the passphrase prompt, make
the mode choice above: empty for convenience; non-empty for gated.

The skill then has you initialize `pass` with the generated full fingerprint
and paste the GitLab token only into this terminal prompt:

```bash
pass insert -m gitlab/omnistation-platform/token
```

It never asks you to paste a token or GPG passphrase into a conversation.

## 3. Verify the end result

The skill performs verification as part of setup. For convenience mode it
checks `direnv`, the active `glab` identity, known-repository Git access, and
the GitLab approval policy. For gated mode it runs the non-decrypting gate
audit; authenticated checks stay in the trusted human context.

You can request a repeat check at any time:

```text
Use $configure-gitlab-group-credentials to verify the
omnistation-platform workspace in its current mode.
```

For the exact checks and what failures mean, see [Use the Codex
skill](how-to/use-the-codex-skill.md#verify-the-setup). For a no-Codex
alternative, see [Configure group credentials manually](how-to/configure-manually.md).
