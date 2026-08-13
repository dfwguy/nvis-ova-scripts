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

## Why `apt-get install` fails

```
apt-get install -y /cluster/dpkg/slurm25.05_25.05.8-101099-cm11.0-a3a58b4841_amd64.deb
```

This reports unmet dependencies on `cm-pmix4-local`, `cm-ucx-local`, `cm-hwloc2-local`, and
`cm-config-cm`. Those exist only in BCM's repository. Do **not** force with `--force-depends` — that
leaves a broken package that blocks future apt operations.

## Extract instead of install

On the observability node as root:

```
dpkg -x /cluster/dpkg/slurm25.05_25.05.8-101099-cm11.0-a3a58b4841_amd64.deb /
```

Files land in `/cm/local/apps/slurm/<version>/`, the same place the real package would put them.

## Verify

Check the linker resolves everything:

```
ldd /cm/local/apps/slurm/25.05/bin/sinfo | grep 'not found'
```

Empty output means you are done. The client tools link only against `libslurmfull.so` (found via
RPATH inside the package) and base glibc — the MPI, UCX, and hwloc dependencies apply to `slurmd`
and MPI launch paths, not to read-only query tools.

If libraries *are* missing, install Ubuntu equivalents:

```
apt-get install -y libhwloc15 libpmix2 libucx0
```

## Trade-offs of extraction

| Consequence | Detail |
|---|---|
| Query tools only | `srun` and `sbatch` still abort — they load SPANK plugins that ship in separate packages. See [enable-job-submission.md](enable-job-submission.md) |
| No dpkg record | `apt list --installed` won't show it; nothing tracks or removes these files |
| No upgrade path | A cluster Slurm upgrade requires repeating this by hand with a new `.deb` |
| Version skew risk | Client and controller must stay within Slurm's supported version window |
| Uninstall is manual | `rm -rf /cm/local/apps/slurm/<version>` |

Record the version and `.deb` filename somewhere durable, since nothing on the system will.

## Related

- [persist-environment.md](persist-environment.md) — putting this `bin` on PATH permanently.
- [explanation.md](../explanation.md) — why the `cm-*` dependencies are not actually required.
