# How to rotate or replace an Omnistation group token

Use this procedure when a GitLab group access token expires, is rotated, loses
the required scope, or may have been exposed.

## 1. Rotate or create the replacement in GitLab

As a group Owner, open the group's **Settings > Access Tokens** page. Rotate
the existing token, or create a replacement with the required role and scopes.
Copy the new value immediately; GitLab does not display it again.

Rotation invalidates the old token straight away. Plan the update of local
workspaces before rotating a widely used token.

## 2. Replace the value in `pass`

Use the existing secret path; the workspace `.envrc` does not change:

```bash
pass insert -m gitlab/omnistation-platform/token
```

Paste the new token at the `pass` prompt and press Ctrl-D.

## 3. Reload the workspace environment

From the workspace root:

```bash
direnv reload
```

Confirm that `glab` can authenticate from a repository in that workspace:

```bash
glab auth status
```

## 4. Replace the Git Credential Manager entry

Git has a separate saved credential. The next Git operation can reject a stale
token and prompt for the replacement. To deliberately remove the old entry,
run the following and enter the exact GitLab host and repository path:

```bash
git credential reject
protocol=https
host=gitlab-master.nvidia.com
path=omnistation-platform/example-repository.git
username=group-omnistation-platform

```

Run `git fetch` or `git push` afterwards and supply the replacement token when
Git Credential Manager prompts. Repeat the reject step for every repository
path that retained the old credential. `clone-gitlab-group.sh` uses the
`group-<group-path-with-slashes-replaced-by-hyphens>` username shown above. If
you entered a different username manually, use that value instead.

## 5. If the token was exposed

Revoke it in GitLab immediately, then complete steps 1–4. Treat a token in a
shell history, Git remote URL, committed file, terminal recording, or chat as
exposed. Review GitLab's access-token usage information for unexpected use.
