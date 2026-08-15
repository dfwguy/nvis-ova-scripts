# How a client-only Slurm node works

A Slurm query client is smaller than a compute node. `sinfo`, `squeue`, and
`sacct` need four things:

| Requirement | Purpose |
|---|---|
| Slurm binaries and `libslurmfull.so` | Implement the Slurm protocol |
| `slurm.conf` | Identifies the controller and `SlurmUser` |
| The controller's munge key | Signs Slurm RPCs |
| A cluster-recognized UID | Identifies the requesting user |

It does not need `slurmd`, cgroup configuration, MPI libraries, or node
registration. It can query or submit work, but the controller cannot schedule
work onto it.

## BCM's local and shared state

BCM keeps binaries and libraries in node-local `/cm/local` so boot and job
launch do not depend on NFS. It keeps configuration and user-facing modules in
`/cm/shared` so nodes use the same cluster configuration.

A hand-built client mounts the shared configuration but bypasses BCM
provisioning, so it must obtain the local binaries separately. Some sites put
Slurm binaries on `/cm/shared`; checking there first avoids an unnecessary
local extraction.

## The maintenance cost

Files extracted with `dpkg -x` are not recorded by dpkg. Package upgrades do
not update them, and a cluster upgrade can leave the client incompatible or
missing a newly required plugin.

This approach is appropriate when BCM provisioning is unavailable. A durable
login or observability host is better provisioned through BCM so binaries,
configuration, authentication, and identity management update together.
