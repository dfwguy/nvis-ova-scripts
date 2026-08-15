# How the SSH access policy works

The policy gives a running Slurm job priority over unmanaged SSH sessions while
still allowing approved users to connect to an idle compute node.

## The account checks run in order

The PAM account stack makes three decisions:

1. `pam_slurm_adopt` admits `root` or a user whose connection can be adopted
   into a local job. A successful adoption ends the account checks.
2. If the user has no local job, `check_node_busy.sh` runs `scontrol listpids`.
   Any Slurm-managed process makes the node busy and denies the login.
3. On an idle node, `pam_access` applies the site's normal rules from
   `/etc/security/access.conf`.

The order matters. Checking `pam_access` first could admit an unmanaged session
on a busy node. Checking node activity first could reject the owner of the job
that made the node busy.

## The activity check fails closed

The helper permits the login only when `scontrol listpids` succeeds, returns the
expected output header, and reports no processes. A missing Slurm module, an
unavailable `scontrol`, a command failure, or unexpected output denies access.

Failing closed prevents a broken Slurm check from silently turning a compute
node into a general-purpose SSH host.

## What “busy” means

This policy defines a busy node as one with a process in a local Slurm step. An
allocation with no current step processes is treated as idle.

PAM evaluates the policy only when a connection starts. It does not disconnect
a user who was admitted while the node was idle and remains connected when a
job starts later.
