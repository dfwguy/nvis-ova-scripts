# Repository instructions

## GitLab group credentials

Use the repository skill at
`.agents/skills/configure-gitlab-group-credentials/SKILL.md` whenever a user
asks to create, configure, rotate, verify, or troubleshoot a GitLab group
access token for `git` or `glab`.

Present the skill's two paths and require an explicit choice. Gated mode keeps
the canonical token in passphrase-protected `pass`, uses `direnv` only for non-
secret routing metadata, and does not export or approve the token. Convenience
mode exports it through `direnv` and stores the exact Git credential for agent
and tool access. Explain that convenience mode is not a same-user agent
security boundary. Never request a token in chat or print, log, commit, or
embed it in a URL.

Before committing, pushing, or creating a merge request, explicitly resolve
the desired commit, push, and MR identities. They are independent: Git commit
metadata comes from `user.name`/`user.email`, the push actor comes from the Git
credential, and the MR author comes from the API token used at creation. Run
the skill's submission-identity audit and stop on mismatches.

Before relying on a write credential, run the skill's repository-approval
audit. Require at least one approval, prevent merge-request author
self-approval, and disable per-MR approval-rule overrides. The sensitive
settings require Maintainer access to inspect; treat a Developer-token `403`
as inconclusive and have a human Maintainer perform the check.
