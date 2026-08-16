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
| Tutorial | [Set up group credentials](tutorial.md) | First-time setup of Git Credential Manager, `pass`, and `direnv` |
| How-to | [Clone a repository with its group token](how-to/clone-a-group-repository.md) | You want a new checkout without using a broad main credential |
| How-to | [Rotate or replace a group token](how-to/rotate-or-replace-a-group-token.md) | A token expires, is rotated, or might have been exposed |
| Reference | [Configuration reference](reference.md) | You need the exact paths, variables, commands, and required scopes |
| Explanation | [Why credentials are split by client and workspace](explanation.md) | You need to understand the security and routing model |

## Scope

The examples use `gitlab-master.nvidia.com`; substitute your approved GitLab
hostname if Omnistation uses a different instance. The token value never
belongs in Git configuration, a remote URL, shell history, or a committed file.

This guide assumes Ubuntu with Git Credential Manager, `pass`, GnuPG, and
`direnv` installed. It does not create, grant, or revoke GitLab tokens; group
owners manage those in GitLab.
