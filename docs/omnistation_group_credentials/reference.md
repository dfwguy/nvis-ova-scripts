# Reference: Omnistation group credential configuration

## Token scopes

| Client and action | Minimum scope |
|---|---|
| `git clone`, `fetch`, or pull | `read_repository` |
| `git push` | `write_repository` |
| Read-only `glab` API command | `read_api` |
| `glab` command that creates or modifies GitLab objects | `api` |

Scopes limit what a token can do within its owning group and its descendant
projects. A group token does not grant access to unrelated groups.

## Git configuration

```bash
git config --global credential.useHttpPath true
git config --global credential.credentialStore gpg
```

| Setting | Purpose |
|---|---|
| `credential.useHttpPath` | Makes the HTTPS repository path part of Git's credential lookup. |
| `credential.credentialStore gpg` | Tells Git Credential Manager to use its GPG-backed credential store. |

Do not use `credential.helper store`; it writes tokens as plaintext.

## Secret and workspace layout

Example for group `omnistation-platform`:

| Item | Value |
|---|---|
| Encrypted token | `pass:gitlab/omnistation-platform/token` |
| Workspace root | `~/git/omnistation-platform` |
| Workspace configuration | `~/git/omnistation-platform/.envrc` |
| Convenience-mode `glab` token variable | `GITLAB_TOKEN` |
| Optional self-managed host variable | `GITLAB_HOST=gitlab-master.nvidia.com` |

Gated-mode `.envrc` content is non-secret metadata:

```bash
export GITLAB_HOST=gitlab-master.nvidia.com
export GITLAB_GROUP=omnistation-platform
export GITLAB_TOKEN_PASS_PATH=gitlab/omnistation-platform/token
```

Convenience-mode `.envrc` additionally contains:

```bash
export GITLAB_TOKEN="$(pass show gitlab/omnistation-platform/token)"
```

Group workspace `.envrc` files supersede a `~/git/.envrc` for repositories
below that workspace. Do not use `source_up` in them, because that would
deliberately reintroduce the parent environment.

## Commands

| Purpose | Command |
|---|---|
| Store/update a token | `pass insert -m gitlab/<group>/token` |
| Trust a workspace `.envrc` | `direnv allow` |
| Reload its environment | `direnv reload` |
| Audit same-user gate bypasses | `.agents/skills/configure-gitlab-group-credentials/scripts/audit-agent-gate.sh <group>` |
| Configure gated workspace metadata | `.agents/skills/configure-gitlab-group-credentials/scripts/setup-workspace.sh --mode gated <group>` |
| Configure convenience mode | `.agents/skills/configure-gitlab-group-credentials/scripts/setup-workspace.sh --mode convenience <group>` |
| Audit commit identity against active token | `.agents/skills/configure-gitlab-group-credentials/scripts/audit-submission-identity.sh --from-token` |
| Audit required review and author restrictions | `.agents/skills/configure-gitlab-group-credentials/scripts/audit-repository-approvals.sh` |
| Check the active `glab` authentication | `glab auth status` |
| Remove a saved Git credential | `git credential reject` |
| Clone with the matching group token | `scripts/clone-gitlab-group.sh <group> <https-url>` |

## Submission identities

| Attribution | Source |
|---|---|
| Commit author and committer | Git `user.name` and `user.email` at commit creation |
| Push actor | HTTPS credential selected by Git Credential Manager |
| Merge-request author | GitLab token used when the MR is created |

Using a group token to push does not rewrite commit metadata. Configure bot
commit identity locally per repository when desired, and audit every commit on
the feature branch before merging. Existing merge-request authors cannot be
changed by updating the branch or token.

## Repository approval safeguards

A write-capable group token should be paired with GitLab-side review controls:

| Check | Required value |
|---|---|
| Applicable project approval rule | At least `1` approval |
| Author approval | Disabled |
| Per-MR approval-rule overrides | Disabled |

Run `audit-repository-approvals.sh` before relying on write access. The
approval-rule endpoint is visible to project members, but GitLab requires a
Maintainer to read the author and override settings. A Developer-token `403`
means the audit is incomplete; it does not prove that the defaults are safe.

Configure the controls under **Settings > Merge requests > Approvals**. Enable
**Prevent approval by merge request creator** and **Prevent editing approval
rules in merge requests**, then rerun the audit in the Maintainer context. Keep
the normal automation token at the lowest practical role instead of elevating
it only to administer these settings.

## Sources

- [Git credential contexts and `credential.useHttpPath`](https://git-scm.com/docs/gitcredentials.html)
- [GitLab group access tokens](https://docs.gitlab.com/user/group/settings/group_access_tokens/)
- [GitLab access-token scopes](https://docs.gitlab.com/security/tokens/access_token_scopes/)
- [GitLab protected branches](https://docs.gitlab.com/user/project/repository/branches/protected/)
- [GitLab merge-request approval rules](https://docs.gitlab.com/user/project/merge_requests/approvals/rules/)
- [GitLab merge-request approval settings](https://docs.gitlab.com/user/project/merge_requests/approvals/settings/)
- [GitLab merge-request approval settings API](https://docs.gitlab.com/api/merge_request_approval_settings/)
- [`glab auth login` credential precedence](https://docs.gitlab.com/cli/auth/login/)
- [GnuPG agent cache options](https://www.gnupg.org/documentation/manuals/gnupg/Agent-Options.html)
