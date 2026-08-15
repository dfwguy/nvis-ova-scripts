# Compute-node SSH access

Documentation for allowing Slurm job owners to SSH to compute nodes while
blocking new unmanaged logins on nodes that have Slurm-managed processes.

This documentation follows the [Diátaxis](https://diataxis.fr/) framework.

| Document | Type | Use it when |
|---|---|---|
| [Gate SSH access on Slurm activity](how-to/gate-ssh-access-on-slurm-activity.md) | How-to | You need to install and validate the PAM policy on compute nodes |

## Scope and assumptions

- The target is a managed compute node running `slurmd`, not a login or
  client-only node.
- `pam_slurm_adopt` and its cgroup containment prerequisites are already
  available on the compute node.
- The policy gates new SSH logins. It does not terminate sessions admitted
  before a job starts.
- Busy means that `scontrol listpids` reports a Slurm-managed process. An
  allocation with no current step processes is treated as idle.
