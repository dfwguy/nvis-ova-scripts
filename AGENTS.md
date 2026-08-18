# Repository instructions

## GitLab group credentials

Use the repository skill at
`.agents/skills/configure-gitlab-group-credentials/SKILL.md` whenever a user
asks to create, configure, rotate, verify, or troubleshoot a GitLab group
access token for `git` or `glab`.

Default to the skill's gated mode: keep the canonical token in passphrase-
protected `pass`, use `direnv` only for non-secret routing metadata, and do not
export `GITLAB_TOKEN` or approve it into Git Credential Manager. Never request
a token in chat or print, log, commit, or embed it in a URL. Use convenience
mode or `scripts/clone-gitlab-group.sh` only after the user explicitly accepts
that these make the token available to same-user agent processes.
