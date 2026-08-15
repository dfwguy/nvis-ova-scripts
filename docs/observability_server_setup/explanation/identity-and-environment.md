# Munge, UIDs, and non-interactive environments

Slurm authentication and local configuration fail in different ways because
they use identity at different stages.

## Why the munge key is local

Only the key contents must match the controller. The local `munge` account does
not need the cluster's UID.

Keeping `/etc/munge/munge.key` local avoids NFS permissions, boot-order, and
availability dependencies. The trade-off is manual key rotation: when the
cluster key changes, this copy must be replaced.

## Why two UIDs matter

`SlurmUser` is a name in `slurm.conf`. Client commands resolve it locally while
parsing configuration, so a local service account must exist even though this
node does not run Slurm daemons.

The caller's UID is carried in the munge credential. With job privacy enabled,
the controller returns jobs owned by that UID. A mismatched UID is valid but
identifies a different user, so `squeue` can return an empty result without an
authentication error.

## Why shell setup is insufficient

`/etc/profile.d` affects login shells but not every cron job, service, script,
or `sudo` command. Slurm configuration should also exist at its default path,
`/etc/slurm/slurm.conf`, and `sudo` needs a trusted path containing the Slurm
binaries.

This separation makes the client work without depending on a particular
interactive shell environment.
