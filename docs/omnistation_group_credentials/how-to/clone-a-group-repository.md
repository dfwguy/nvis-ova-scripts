# How to clone an Omnistation repository with its group token

Use `clone-gitlab-group.sh` for a new HTTPS checkout. It is the preferred
initial-clone path because it uses the intended group token from `pass`, rather
than a broad main credential that might be available at `~/git`.

## Before you begin

The group token must already be stored in `pass` and have a suitable Git scope:

```bash
pass insert -m gitlab/omnistation-platform/token
```

Paste it only at the `pass` prompt. Configure Git Credential Manager and
`direnv` as described in [the tutorial](../tutorial.md).

## Clone the repository

From a checkout of this repository, run:

```bash
scripts/clone-gitlab-group.sh omnistation-platform \
  https://gitlab-master.nvidia.com/omnistation-platform/project-a.git
```

The default destination is:

```text
~/git/omnistation-platform/project-a
```

Pass a relative destination as the final argument to choose another name:

```bash
scripts/clone-gitlab-group.sh omnistation-platform \
  https://gitlab-master.nvidia.com/omnistation-platform/project-a.git \
  project-a-local
```

For a different self-managed GitLab hostname, use `--host` and ensure the URL
uses the same host:

```bash
scripts/clone-gitlab-group.sh --host gitlab.example.com parent/subgroup \
  https://gitlab.example.com/parent/subgroup/project-a.git
```

## What the helper does

1. Reads `pass:gitlab/<group>/token`.
2. Creates `~/git/<group>/.envrc` if absent. The file looks up the token from
   `pass`; it contains no token value.
3. Runs `direnv allow` for the group workspace.
4. Saves the token through `git credential approve` for the exact HTTPS
   repository path.
5. Runs `git clone` into the group workspace.

It refuses URLs outside the stated group or its subgroups, existing destination
paths, non-HTTPS URLs, and group/destination paths that contain `..`.

## Use a broad main credential only when necessary

`GITLAB_TOKEN` in a top-level `.envrc` is used by `glab`, not normal HTTPS
Git. If a one-off bootstrap clone genuinely must use a host-level main Git
credential, run:

```bash
git -c credential.useHttpPath=false clone \
  https://gitlab-master.nvidia.com/<group>/<project>.git
```

Then register the project's group credential before doing routine work. The
helper avoids this exception entirely.
