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

Before committing, pushing, or creating a merge request, determine and report
the commit, push, and MR identities. They are independent: Git commit metadata
comes from `user.name`/`user.email`, the push actor comes from the Git
credential, and the MR author comes from the API token used at creation. Run
the skill's submission-identity audit when possible. Treat mismatches as
attribution findings to disclose in the MR, not as blockers to commit, push, or
MR creation. Never rewrite published commits without explicit approval.

Run the skill's repository-approval audit and report its findings for human
review. The desired merge safeguards are at least one approval, no
merge-request author self-approval, and no per-MR approval-rule overrides. The
sensitive settings require Maintainer access to inspect; treat a
Developer-token `403` as inconclusive, but do not let a failed or inconclusive
audit prevent commit, push, or MR creation. Leave merge approval to a human
reviewer who can confirm or correct the settings.

When a user asks for repository changes, do not leave completed work only in
the local worktree unless they explicitly request local-only changes. After
running the advisory identity and repository-approval audits, commit the scoped
changes, push the feature branch, and create or update a merge request for
independent human review even when an audit reports findings. Update an
existing open MR for the branch instead of creating a duplicate. Never merge
or self-approve the merge request. Report the branch, merge-request URL, and
audit findings. Only an actual inability to commit, authenticate, push, or
create/update the MR is a publication blocker.
