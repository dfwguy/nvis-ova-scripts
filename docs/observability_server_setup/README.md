# Slurm Client-Only Node (BCM Cluster)

How to turn a standalone Ubuntu host into a **read-only Slurm client** for a Base Command Manager
(BCM) cluster — able to run `sinfo`, `squeue`, and `sacct` against the head node without being a
managed compute node and without running `slurmd`.

This documentation follows the [Diátaxis](https://diataxis.fr/) framework.

| Document | Type | Use it when |
|---|---|---|
| [tutorial.md](tutorial.md) | Tutorial | You've never done this and want a guided start-to-finish run |
| [how-to/](how-to/) | How-to guides | You know the goal and want the steps for one specific task |
| [reference.md](reference.md) | Reference | You need a path, UID, port, or config value |
| [explanation.md](explanation.md) | Explanation | You want to know *why* it's built this way |

## How-to guides

| Guide | Goal |
|---|---|
| [mount-cm-shared.md](how-to/mount-cm-shared.md) | Persistently mount the BCM `/cm/shared` NFS export |
| [set-up-munge.md](how-to/set-up-munge.md) | Install munge and install the cluster's key locally |
| [install-slurm-binaries.md](how-to/install-slurm-binaries.md) | Get Slurm client binaries on without BCM repo access |
| [align-uids.md](how-to/align-uids.md) | Match local UIDs to cluster UIDs so `squeue` returns data |
| [persist-environment.md](how-to/persist-environment.md) | Make `sinfo` work after reboot, under `sudo`, and in cron |
| [troubleshoot.md](how-to/troubleshoot.md) | Diagnose a failing `sinfo` / `squeue` |

## Scope and assumptions

- **Client only.** This node does not join the cluster, does not run `slurmd`, and cannot be
  scheduled work. It is an observability / submission-adjacent host.
- **Not BCM-managed.** The node is not in BCM's node categories and receives no image updates,
  so everything here is manual and will drift when the cluster's Slurm is upgraded.
- Values throughout (`nscale-hn1`, `192.168.10.2`, Slurm `25.05`, UID `450`/`1001`) are from one
  specific site. Substitute your own — see [reference.md](reference.md) for how to discover each one.
