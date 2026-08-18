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
