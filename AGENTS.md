# Repository instructions

## GitLab group credentials

Use the repository skill at
`.agents/skills/configure-gitlab-group-credentials/SKILL.md` whenever a user
asks to create, configure, rotate, verify, or troubleshoot a GitLab group
access token for `git` or `glab`.

Keep the canonical token in `pass`, select it per workspace with `direnv`, and
store Git's exact repository-path credential through GPG-backed Git Credential
Manager. Never request a token in chat or print, log, commit, or embed it in a
URL. Prefer the skill's helper for existing workspaces and
`scripts/clone-gitlab-group.sh` for new clones.
