# How to gate GitLab credentials from agents

Use this procedure when an agent may run commands as your Unix user and must
not use a GitLab write token without human presence.

## Understand the boundary

A GitLab access token is a bearer credential. GitLab does not add a password
prompt when the token is used. Password-protecting the GPG private key used by
`pass` can gate decryption, but only while every decrypted copy is absent.

| Credential route | Why it bypasses the gate |
|---|---|
| `GITLAB_TOKEN` in the environment | Every child process inherits the token. |
| Token in `glab` config | `glab` can authenticate without consulting `pass`. |
| Git Credential Manager entry | Git can obtain its encrypted duplicate independently of the workspace. |
| gpg-agent or desktop cache | Decryption can succeed again without human input. |
| Same-user process after unlock | It may observe or reuse the bearer token during an authorized operation. |

For a hard isolation boundary, keep write credentials in a separate OS account,
workstation, or human-operated credential broker that the agent cannot access.
Use protected branches and required merge-request approvals to limit damage if
a credential is used unexpectedly. A skill or wrapper is policy, not a security
boundary, because an agent with filesystem access can edit or bypass it.

## 1. Audit without decrypting

Run:

```bash
.agents/skills/configure-gitlab-group-credentials/scripts/audit-agent-gate.sh \
  nvis-ova
```

The audit checks private-key protection, gpg-agent caching, the current process
environment, `.envrc`, `glab` config, and the exact Git credential context. It
never decrypts or displays the token.

## 2. Protect the `pass` private key

Do this in a trusted terminal outside the agent process. Identify the GPG key
listed in `~/.password-store/.gpg-id`, then add a passphrase:

```bash
gpg --list-secret-keys --keyid-format long
gpg --passwd <full-fingerprint>
```

Only enter the passphrase in GnuPG's pinentry window. Do not paste it into a
conversation or shell command.

Configure `~/.gnupg/gpg-agent.conf` to avoid reusable passphrase caching:

```text
default-cache-ttl 0
max-cache-ttl 0
no-allow-external-cache
```

Reload the agent configuration:

```bash
gpgconf --reload gpg-agent
```

## 3. Remove persistent token routes

Stop agent processes before doing this cleanup so they cannot retain the old
environment. Resolve every target exactly before removing it.

1. Remove any `export GITLAB_TOKEN=...` line from the workspace `.envrc`.
2. Log out the matching host-level `glab` entry. On older `glab` versions that
   lack `auth logout`, clear only that host's token with `glab config set token
   '' --host <hostname> --global`.
3. Reject each Git Credential Manager entry for the exact host, repository
   path, and saved username. Do not delete the password store broadly.
4. Configure non-secret workspace routing in gated mode:

   ```bash
   .agents/skills/configure-gitlab-group-credentials/scripts/setup-workspace.sh \
     nvis-ova
   ```

Gated `.envrc` content contains only values such as:

```bash
export GITLAB_HOST=gitlab-master.nvidia.com
export GITLAB_GROUP=nvis-ova
export GITLAB_TOKEN_PASS_PATH=gitlab/nvis-ova/token
```

It does not load the token.

## 4. Rotate the previously exposed token

If an agent inherited or could decrypt the old token, treat it as exposed.
Create or rotate the group token in GitLab from the trusted terminal/browser,
then replace the encrypted `pass` entry:

```bash
pass insert -m gitlab/nvis-ova/token
```

Do not approve the replacement into Git Credential Manager or log in with it
through `glab` in the agent-accessible account.

## 5. Keep privileged operations outside the agent

Let the agent prepare local branches and commits. Perform `git push`, merge-
request creation, and other authenticated mutations in the separate trusted
credential context. If you deliberately unlock a token for a same-user agent,
the gate protects only the period before unlock; it cannot stop that process
from using the bearer credential during the authorized session.

Start a fresh agent process only after cleanup, then rerun the audit. Do not
consider the migration complete until it reports no bypasses.
