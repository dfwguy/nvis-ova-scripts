# How to install enroot for container job submission

**Goal:** install enroot on the observability node so that `srun --container-image=...` and
`sbatch --container-image=...` can launch Pyxis container jobs.

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

Passing both packages lets `dpkg` install them in dependency order.

## Verify

```
enroot version
```

You should see `4.1.2` (or whichever version was downloaded) with no permission errors.

```
srun -N1 --time=1 --container-image=ubuntu bash -c 'cat /etc/os-release | head -3'
```

A result printed inside a container means enroot and Pyxis are cooperating correctly.

Record the downloaded Enroot version and revalidate container submission after
cluster upgrades.

## Related

- [enable-job-submission.md](enable-job-submission.md) — the SPANK plugin and MPI layers this builds on.
- [mount-cm-shared.md](mount-cm-shared.md) — `/cluster` must be mounted for the staging area to exist.
