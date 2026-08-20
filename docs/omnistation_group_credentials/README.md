# Omnistation group credentials with GitLab

Use separate GitLab **group access tokens** safely from an Ubuntu workstation.
This guide covers both Git-over-HTTPS (`git`) and GitLab API commands (`glab`)
for Omnistation group workspaces.

It follows the [Diátaxis](https://diataxis.fr/) framework: tutorials teach,
how-to guides solve a specific task, reference describes the configuration, and
explanation provides the reasoning behind it.

## Contents

| Type | Document | Use it when |
|---|---|---|
| Tutorial | [Set up group credentials with the Codex skill](tutorial.md) | First-time setup; this is the recommended path |
| How-to | [Use the Codex skill](how-to/use-the-codex-skill.md) | You want the concise invocation, installation, and verification reference |
| How-to | [Configure group credentials manually](how-to/configure-manually.md) | You cannot use Codex or need to inspect every command yourself |
| How-to | [Gate credentials from agents](how-to/gate-credentials-from-agents.md) | You need human presence before a same-user agent can obtain a write token |
| How-to | [Clone a repository with its group token](how-to/clone-a-group-repository.md) | You want a new checkout without using a broad main credential |
| How-to | [Rotate or replace a group token](how-to/rotate-or-replace-a-group-token.md) | A token expires, is rotated, or might have been exposed |
| Reference | [Configuration reference](reference.md) | You need the exact paths, variables, commands, and required scopes |
| Explanation | [Why credentials are split by client and workspace](explanation.md) | You need to understand the security and routing model |

## Scope

The examples use `gitlab-master.nvidia.com`; substitute your approved GitLab
hostname if Omnistation uses a different instance. The token value never
belongs in Git configuration, a remote URL, shell history, or a committed file.

This guide assumes Ubuntu with Git Credential Manager installed. The
[skill-first tutorial](tutorial.md) guides installation of `pass`, GnuPG, and
`direnv`, then asks Codex to configure and verify the selected mode. It does
not create, grant, or revoke GitLab tokens; group owners manage those in GitLab.
