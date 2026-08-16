# Explanation: why credentials are split by client and workspace

Group access tokens represent bot users scoped to a GitLab group and its
descendant projects. They are a better fit than one broad personal token when
an Omnistation workstation needs intentionally separate access boundaries.

## Git and `glab` authenticate differently

Git authenticates an HTTPS remote through Git's credential protocol. Credential
helpers can use a host, username, and—when `credential.useHttpPath` is
enabled—a repository path to select a stored credential. This supports safely
retaining different group tokens on the same GitLab host.

`glab` makes GitLab API calls. Its normal saved login is host-scoped, so a
single saved login cannot know which of several group tokens should apply just
because a command was run in a particular directory. `GITLAB_TOKEN` overrides
that saved login for the current process.

`direnv` bridges that gap: entering a trusted workspace sets one group's token
only for processes started there; leaving the workspace removes it. `pass`
keeps the token encrypted at rest instead of storing it in `.envrc` or the
shell startup file.

`direnv` selects the closest applicable `.envrc`. A group workspace such as
`~/git/omnistation-platform/.envrc` therefore shields repositories below it
from a broader `~/git/.envrc`; it must not use `source_up`, which explicitly
imports a parent environment. This supports a narrowly scoped bootstrap area
at `~/git` while routine project work sees only its group token.

## Why Git stores a second credential

Git Credential Manager and `pass` serve different integration points. `pass`
is the source used by `direnv` to make the correct `glab` token available.
Git Credential Manager is invoked by Git itself and securely caches its own
repository-specific credential. This duplicates an encrypted secret by design,
but avoids token-bearing URLs and custom credential-helper scripts.

The included `clone-gitlab-group.sh` makes the first clone follow this same
model. It reads the group token from `pass`, approves it for the exact Git
credential context, and then clones. A main Git credential is unnecessary for
the normal path and never becomes the new repository's saved credential.

The practical trade-off is that a rotated token must be updated in both places:
the `pass` entry for `glab`, and the Git Credential Manager entry for each
affected repository. The [rotation how-to](how-to/rotate-or-replace-a-group-token.md)
walks through both.

## Why `.envrc` must stay uncommitted

`direnv` executes `.envrc` after explicit approval. Even an `.envrc` that only
reads `pass` is executable configuration tied to a local security boundary.
Keeping it uncommitted prevents another checkout or contributor from silently
changing that behavior, and prevents workstation-specific secret paths from
becoming project configuration.
