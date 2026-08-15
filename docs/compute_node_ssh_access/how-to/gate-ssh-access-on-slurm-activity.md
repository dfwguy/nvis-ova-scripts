# How to gate SSH access on Slurm activity

**Goal:** admit `root` and users whose SSH connections can be adopted into a
local Slurm job; deny other new logins while the node has Slurm-managed
processes; and apply `/etc/security/access.conf` normally when the node is idle.

## Prerequisites

- `pam_slurm_adopt.so` is installed on every target compute node.
- Slurm job containment is configured as required by `pam_slurm_adopt`:
  `PrologFlags=contain`, `task/cgroup`, and `proctrack/cgroup`.
- `sshd_config` has `UsePAM yes` and uses a supported SSH authentication
  method.
- `pam_systemd.so` is disabled in PAM files included by `sshd`, as required by
  `pam_slurm_adopt`.
- `/etc/security/access.conf` contains the intended idle-node access rules.

Review the upstream
[`pam_slurm_adopt` documentation](https://slurm.schedmd.com/pam_slurm_adopt.html)
before rollout, especially its containment prerequisites and production failure
options.

## 1. Install the busy-node helper

Find the compute node's real `scontrol` path:

```console
command -v scontrol
```

Install the repository helper:

```console
sudo install -o root -g root -m 0755 scripts/check_node_busy.sh \
    /usr/local/sbin/check_node_busy.sh
```

The helper requires the absolute `scontrol` path as its only argument. It exits
successfully only when `scontrol listpids` succeeds, has the expected header,
and returns no process rows. Missing binaries, Slurm errors, and unexpected
output all deny access.

## 2. Configure the PAM account stack

Keep the distribution's existing `account` entries. After its normal account
includes, add these entries to `/etc/pam.d/sshd`, replacing the `scontrol` path
with the value found above:

```pam
account [success=done ignore=ignore default=die] pam_slurm_adopt.so action_no_jobs=ignore action_adopt_failure=deny action_generic_failure=deny
account requisite pam_exec.so quiet /usr/local/sbin/check_node_busy.sh /cm/local/apps/slurm/current/bin/scontrol
account required  pam_access.so
```

The order and control flags are required:

- A successful `pam_slurm_adopt` returns immediately, so an adopted job owner
  and `root` skip the remaining checks.
- `action_no_jobs=ignore` continues to the busy-node helper. Adoption and
  internal failures stop the stack instead of becoming an idle-node fallback.
- `pam_exec` is `requisite`, so a busy node or an indeterminate Slurm state
  stops the account stack immediately.
- `pam_access` is `required`, so its denial is enforced on an idle node. Do not
  mark it `sufficient`; failure of a `sufficient` module is ignored.

The `account` stack performs account authorization, not password or key
authentication. The existing PAM `auth` stack and SSH configuration still
validate credentials.

Audit included PAM files for earlier `account sufficient` entries, such as
`pam_localuser.so`; an earlier success can return before these entries run.

## 3. Validate the helper

Keep an existing root session open and test on one drained compute node first.
Run the helper directly:

```console
sudo /usr/local/sbin/check_node_busy.sh \
    /cm/local/apps/slurm/current/bin/scontrol
echo $?
```

An idle node returns `0`; a node with Slurm-managed PIDs returns `1`. A broken
or incorrect `scontrol` path must also return `1`.

## 4. Test every login path

Use a second terminal to verify each branch:

| Situation | Expected result |
|---|---|
| `root` | Login succeeds |
| User owns a local job | Login succeeds and is adopted into the job's external step |
| User owns no local job; node has Slurm-managed PIDs | Login fails |
| User owns no local job; node has no Slurm-managed PIDs; `pam_access` allows | Login succeeds |
| User owns no local job; node has no Slurm-managed PIDs; `pam_access` denies | Login fails |
| `scontrol` fails | Login fails unless `pam_slurm_adopt` already succeeded |

Confirm adoption for the job-owner case with the site's normal cgroup or Slurm
step inspection procedure. Roll out to additional nodes only after every branch
behaves as expected.

## Limitations

PAM evaluates the policy only when a login starts. A user admitted while the
node is idle can remain logged in when a job starts later. Use scheduler
reservations, draining, or session-lifecycle controls if jobs must never overlap
an unmanaged login.

`scontrol listpids` reports processes in local Slurm steps. If the policy must
consider an allocated node busy even when it has no current step processes,
replace the helper with a fail-closed scheduler-state check.
