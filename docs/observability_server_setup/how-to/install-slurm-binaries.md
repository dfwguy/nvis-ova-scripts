# How to install Slurm client binaries without BCM repository access

**Goal:** get `sinfo`, `squeue`, and `sacct` onto a node that cannot resolve BCM's `cm-*` packages.

## First, check whether you need the package at all

Some sites export Slurm binaries on `/cm/shared`. Look before installing:

```
ls /cm/shared/apps/slurm/
```

| What you see | What to do |
|---|---|
| `bin`, `current`, or a version dir like `25.05` | Skip this guide — add that `bin` to PATH |
| Only `etc`, `var`, `statesave`, `prologs`, `epilogs` | Binaries are node-local; continue below |

You can also confirm where the head node's binaries live:

```
ssh <headnode> 'readlink -f $(which sinfo)'
```

A result under `/cm/local/` means node-local by design and not shareable.

## Get the package

BCM's repository requires credentials. Download as root on the head node into the shared staging
area, then extract on the observability node:

On the head node as root:

```
cd /cluster/dpkg && apt-get download slurm25.05
```

## Extract instead of install

On the observability node as root:

```
dpkg -x /cluster/dpkg/slurm25.05_25.05.8-101099-cm11.0-a3a58b4841_amd64.deb /
```

Files land in `/cm/local/apps/slurm/<version>/`, the same place the real package would put them.
Do not install with `--force-depends`; extract the package so apt is not left
with an unsatisfied package record.

## Verify

Check the linker resolves everything:

```
ldd /cm/local/apps/slurm/25.05/bin/sinfo | grep 'not found'
```

Empty output means the query binaries are ready.

If libraries *are* missing, install Ubuntu equivalents:

```
apt-get install -y libhwloc15 libpmix2 libucx0
```

Record the extracted package version. Dpkg will not track or upgrade these
files. To enable `srun` and `sbatch`, continue with
[Make job submission work](enable-job-submission.md).

## Related

- [persist-environment.md](persist-environment.md) — putting this `bin` on PATH permanently.
- [client-only-slurm-node.md](../explanation/client-only-slurm-node.md) — why extraction is sufficient for query tools.
- [submission-dependencies.md](../explanation/submission-dependencies.md) — why submission needs additional files.
