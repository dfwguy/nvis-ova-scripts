# Gate compute-node SSH access on Slurm activity

This policy gives SSH access in this order:

1. `root`, or a user whose connection `pam_slurm_adopt` can adopt into a local
   job, is admitted immediately.
2. Everyone else is denied while `scontrol listpids` reports any
   Slurm-managed process on the node.
3. When the node has no Slurm-managed processes, the existing
   `/etc/security/access.conf` policy decides whether the user is admitted.

This is useful when selected users may log in normally on an idle compute node,
but new unmanaged SSH sessions must not start while a workload is active.

## Important limitation

PAM evaluates this policy only when a login starts. A user admitted while the
node is idle can remain logged in when a job starts later. This configuration
therefore gates **new logins**; it does not provide exclusive workload
isolation or terminate pre-existing sessions. Use scheduler reservations,
draining, or another session-lifecycle control if jobs must never overlap an
unmanaged login.

Also, `scontrol listpids` reports processes in local Slurm steps. An allocation
with no current step processes is treated as idle. If the intended policy is
based on allocated node state rather than running processes, use a
scheduler-state check instead.

## Prerequisites

- `pam_slurm_adopt.so` is installed on every compute node.
- Slurm job containment is configured as required by
  `pam_slurm_adopt` (`PrologFlags=contain`, `task/cgroup`, and
  `proctrack/cgroup`).
- `sshd_config` has `UsePAM yes` and uses a supported SSH authentication
  method.
- `pam_systemd.so` is disabled in PAM files included by `sshd`, as required by
  `pam_slurm_adopt`.
- `/etc/security/access.conf` contains the intended idle-node access rules.

Review the upstream
[`pam_slurm_adopt` documentation](https://slurm.schedmd.com/pam_slurm_adopt.html)
before rollout, especially its containment prerequisites and production failure
options.

## Install the busy-node helper

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

## Configure the PAM account stack

Keep the distribution's existing `account` entries. After its normal account
includes, add these entries to `/etc/pam.d/sshd`, replacing the `scontrol` path
with the value found above:

```pam
account [success=done ignore=ignore default=die] pam_slurm_adopt.so action_no_jobs=ignore action_adopt_failure=deny action_generic_failure=deny
account requisite pam_exec.so quiet /usr/local/sbin/check_node_busy.sh /cm/local/apps/slurm/current/bin/scontrol
account required  pam_access.so
```

Ordering and control flags are part of the policy:

- A successful `pam_slurm_adopt` returns immediately, so an adopted job owner
  (and `root`, which the module always permits) skips the remaining checks.
  `action_no_jobs=ignore` is the one result that continues; adoption and
  internal failures stop the stack instead of being mistaken for an idle-node
  fallback.
- `requisite` stops the account stack immediately when the node is busy or its
  state cannot be determined.
- `pam_access` is `required`, so its denial is enforced on an idle node. Do not
  mark this entry `sufficient`: failure of a `sufficient` module is ignored.

The `account` stack performs account authorization, not password or key
authentication. The existing PAM `auth` stack and SSH configuration still
validate the user's credentials before this policy admits the account.

Audit included PAM files for earlier `account sufficient` entries, such as
`pam_localuser.so`; an earlier success can return before these three entries
run.

## Validate without locking out the node

Keep an existing root session open and test on one drained compute node first.
Before changing PAM, verify the helper directly:

```console
sudo /usr/local/sbin/check_node_busy.sh \
    /cm/local/apps/slurm/current/bin/scontrol
echo $?
```

An idle node returns `0`; a node with Slurm-managed PIDs returns `1`. A broken
or incorrect `scontrol` path must also return `1`.

Then test all policy branches from a second terminal:

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
