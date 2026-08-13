# How to install enroot for container job submission

**Goal:** install enroot on the observability node so that `srun --container-image=...` and
`sbatch --container-image=...` can launch Pyxis container jobs.

Without enroot, Pyxis loads and `srun` queues the job, but the job fails at launch on the compute
node — or on this node if it were a compute node. Enroot is what Pyxis calls to unpack and mount
the container image.

## Before starting

- Root on this node.
- Root on the head node (needed to download BCM packages — see [Downloading BCM packages](#downloading-bcm-packages) below).
- `srun` already working — see [enable-job-submission.md](enable-job-submission.md).
- `/cluster` mounted and writable — it is the staging area for the packages.

## Downloading BCM packages

BCM's package repository requires credentials. `apt-get download` works only as root on a managed
node. The pattern for any BCM package is: download as root on the head node into `/cluster/dpkg/`,
then install from there on the observability node.

On the head node as root:

```
mkdir -p /cluster/dpkg
cd /cluster/dpkg && apt-get download enroot enroot+caps
```

Check what you got:

```
ls -lh /cluster/dpkg/enroot*.deb
```

## Install on the observability node

Enroot depends on `parallel`. A plain `apt-get install -y parallel` fails on this node because the
package conflicts with a file already installed by `moreutils` (both ship a `parallel` man page).
Force the overwrite:

```
sudo apt-get -o Dpkg::Options::="--force-overwrite" install -y parallel
```

Then, on the observability node as root:

```
cd /cluster/dpkg && dpkg -i enroot*.deb
```

`dpkg` resolves install order automatically, so passing both at once works. Unlike the Slurm and
pyxis packages, enroot has no BCM-specific dependencies, so `dpkg -i` works without `dpkg -x`. The
`+caps` package sets Linux file capabilities on the enroot binary, which is what allows unprivileged
users to launch containers.

## Verify

```
enroot version
```

You should see `4.1.2` (or whichever version was downloaded) with no permission errors.

```
srun -N1 --time=1 --container-image=ubuntu bash -c 'cat /etc/os-release | head -3'
```

A result printed inside a container means enroot and Pyxis are cooperating correctly.

## Why two packages

`enroot` contains the binaries and runtime files. `enroot+caps` is a thin wrapper that sets
`CAP_SYS_ADMIN` and `CAP_DAC_OVERRIDE` file capabilities on the enroot binary using `setcap`.
These capabilities allow enroot to mount filesystems and access paths as any user without being
setuid-root. Install order matters: `+caps` must come after `enroot` since it modifies a file the
base package installs.

## Trade-offs

| Consequence | Detail |
|---|---|
| No upgrade path | A cluster enroot upgrade requires repeating this by hand; nothing here tracks the BCM version |
| Version must match | Pyxis and enroot negotiate at job launch; a major version skew between this node's enroot and the compute nodes' can fail in ways that are hard to trace |
| `/cluster/dpkg/` is unversioned | Nothing stops old `.deb` files from accumulating; record what version each was downloaded for |

## Related

- [enable-job-submission.md](enable-job-submission.md) — the SPANK plugin and MPI layers this builds on.
- [mount-cm-shared.md](mount-cm-shared.md) — `/cluster` must be mounted for the staging area to exist.
