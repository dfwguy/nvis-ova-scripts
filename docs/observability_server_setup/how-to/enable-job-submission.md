# How to make `srun` and `sbatch` work

**Goal:** get the submission tools running on a node whose Slurm binaries were extracted rather than
installed.

`sinfo`, `squeue`, and `sacct` work as soon as the binaries, config, and munge key are in place.
`srun` and `sbatch` need four more things, and they surface one at a time — each fix reveals the next
failure. Work through the layers in order.

| Layer | Symptom | Needs |
|---|---|---|
| 1. SPANK plugin | `dlopen(... spank_pyxis.so): cannot open shared object file` | `spank_pyxis.so` copied from the head node |
| 2. MPI plugin link deps | `dlopen(... mpi_pmix.so): libhwloc.so.15: cannot open shared object file` | `libhwloc15` from Ubuntu |
| 3. PMIx runtime load | `pmi/pmix: can not load PMIx library` | BCM's `cm-pmix4` tree plus an `ld.so.conf.d` entry |
| 4. PMIx's own deps | `libevent_pthreads-2.1.so.7 => not found` | `libevent-pthreads-2.1-7t64` from Ubuntu |

**Done looks like this** — the plugin stack initialised and the job reached the scheduler:

```
srun: job 146093 queued and waiting for resources
```

Sitting in the queue is a scheduling outcome, not an error. Anything that fails does so before this
line appears.

## Before starting: a workaround

If you only need to submit non-MPI work, layers 2–4 are avoidable. `--mpi=none` skips the MPI plugin
entirely:

```
srun --mpi=none -N1 --time=1 hostname
```

Layer 1 is not avoidable — pyxis is `required` in the shared config and blocks every invocation,
including `srun --version`.

## Layer 1: the pyxis SPANK plugin

```
srun: error: plugin_load_from_file: dlopen(/cm/local/apps/slurm/current/lib64/slurm/spank_pyxis.so): cannot open shared object file: No such file or directory
srun: error: spank: /cm/shared/apps/slurm/etc/slurm/plugstack.conf.d/pyxis.conf:1: Failed to load plugin
srun: error: Plug-in initialization failed
```

This happens before argument parsing, so even `srun --version` fails.

The plugin list lives on `/cm/shared`, so this node inherits the cluster's the moment the export is
mounted. The plugins themselves live under `/cm/local` and arrive only by provisioning. At this site
the list has one entry:

```
required /cm/local/apps/slurm/current/lib64/slurm/spank_pyxis.so execute_entrypoint=0 container_scope=global sbatch_support=1
```

`required` makes a failed load fatal; `sbatch_support=1` applies it to `sbatch` as well as `srun`.

Pyxis ships in its own package, installed on the cluster separately from Slurm — at this site the
`.so` is dated two months after the Slurm tree around it, so extracting the Slurm `.deb` could never
have delivered it.

Confirm the diagnosis, then copy the file:

```
cat /cm/shared/apps/slurm/etc/slurm/plugstack.conf.d/*.conf
```

```
ls -l /cm/local/apps/slurm/current/lib64/slurm/ | grep -i pyxis
```

```
scp <headnode>:/cm/local/apps/slurm/current/lib64/slurm/spank_pyxis.so /tmp/
```

Install into the versioned directory, not through `current`, so a version bump does not strand the
file:

```
install -m 0644 -o root -g root /tmp/spank_pyxis.so /cm/local/apps/slurm/25.05/lib64/slurm/spank_pyxis.so
```

Do **not** edit `plugstack.conf.d` to avoid this. It is on `/cm/shared` and shared with every node in
the cluster, so marking the line `optional` would also downgrade a fatal error to a warning on the
compute nodes where the plugin genuinely is required.

## Layer 2: hwloc for the MPI plugin

```
srun: error: plugin_load_from_file: dlopen(/cm/local/apps/slurm/25.05/lib64/slurm/mpi_pmix.so): libhwloc.so.15: cannot open shared object file
srun: error: MPI: Unable to load any plugin
```

This is the first of the `cm-*` dependencies to actually matter. They are genuinely skippable for the
query tools and not for job launch — see [explanation.md](../explanation.md).

The plugin's RUNPATH points at BCM's build, which does not exist here:

```
objdump -p /cm/local/apps/slurm/current/lib64/slurm/mpi_pmix_v4.so | grep -Ei 'RPATH|RUNPATH'
```

```
RUNPATH              /cm/local/apps/hwloc2/2.8.0/lib
```

Because that directory is absent, the loader falls through to the default search path, so Ubuntu's
build satisfies it. Same soname, compatible ABI:

```
apt-get install -y libhwloc15
```

Copying BCM's `hwloc2` tree to the RUNPATH instead would be the more faithful match if you want this
node to mirror the cluster exactly. Ubuntu's is simpler and has worked here.

## Layer 3: the PMIx library

```
srun: error:  mpi/pmix_v4: init: (null) [0]: mpi_pmix.c:200: pmi/pmix: can not load PMIx library
srun: error: MPI: Cannot create context for mpi/pmix
```

Note what changed: the plugin now *loads*, and fails in its `init()`. Slurm's pmix plugin `dlopen`s
`libpmix.so.2` itself at init, so this is not a link-time dependency and `ldd` on the plugin will
show nothing missing. There is also no RUNPATH for it — the RUNPATH above names only hwloc — so the
loader's default search is all there is.

On the head node PMIx is not in the `ldconfig` cache either; BCM's environment modules supply the
path at runtime. An unmanaged node loads no modules, which is why it must be made visible another
way.

Copy the tree from the head node. Pull as your own user first — `sudo rsync` runs its SSH as root,
and root cannot log in to the head node:

```
rsync -a <headnode>:/cm/local/apps/cm-pmix4 /tmp/
```

```
sudo cp -a /tmp/cm-pmix4 /cm/local/apps/
```

Both steps preserve the `current -> 4.1.3` symlink, which the loader entry points through. Then make
the path visible to every process, not just login shells:

```
printf '/cm/local/apps/cm-pmix4/current/lib\n' | sudo tee /etc/ld.so.conf.d/cm-pmix4.conf
```

```
sudo ldconfig && ldconfig -p | grep libpmix
```

Expect `libpmix.so.2 => /cm/local/apps/cm-pmix4/current/lib/libpmix.so.2`.

Use BCM's PMIx rather than Ubuntu's `libpmix2t64`. Both expose `libpmix.so.2`, but PMIx negotiates a
wire protocol with the compute nodes' PMIx servers, and a 5.x-against-4.1.3 skew fails at job startup
rather than at load — a far worse failure to debug than this one.

## Layer 4: PMIx's own dependencies

`ldconfig` finding the library is not the same as it loading. The plugin's error text is identical
whether PMIx is missing or merely unloadable, so check PMIx's own dependencies:

```
ldd /cm/local/apps/cm-pmix4/current/lib/libpmix.so.2 | grep 'not found'
```

```
libevent_pthreads-2.1.so.7 => not found
```

Ubuntu noble renamed these packages in the 64-bit `time_t` transition, so the name carries a `t64`
suffix while the soname does not:

```
apt-get install -y libevent-pthreads-2.1-7t64
```

libevent is stable at this ABI, so Ubuntu's build binds to BCM's PMIx without complaint — unlike PMIx
itself.

## Verify

```
ldd /cm/local/apps/cm-pmix4/current/lib/libpmix.so.2 | grep 'not found'
```

```
srun --version && sbatch --version
```

```
srun -N1 --time=1 hostname
```

A hostname, or `job NNNNNN queued and waiting for resources` if the cluster is busy, means every
layer is satisfied. `--version` alone is a weaker test than it looks: it clears layer 1 but not the
MPI layers, which initialise only on a real launch.

## Debugging technique

The layers all report as "cannot load", so the useful skill is telling *which* thing cannot load.

| Question | Command |
|---|---|
| What link-time deps are missing? | `ldd <file> \| grep 'not found'` |
| Where will the loader search for them? | `objdump -p <file> \| grep -Ei 'RPATH\|RUNPATH'` |
| Does a library load standalone, with a real error? | `python3 -c "import ctypes; ctypes.CDLL('libpmix.so.2')"` |
| Is it visible to the loader at all? | `ldconfig -p \| grep <soname>` |
| What is Slurm actually doing? | `srun -vvvv -N1 --time=1 hostname 2>&1 \| grep -iE 'pmix\|dlopen\|undefined'` |

Two distinctions worth internalising, because they cost the most time here:

- **`ldd` cannot see `dlopen`.** Layer 3 is invisible to `ldd` on the plugin, because Slurm loads
  PMIx by name at runtime. A clean `ldd` does not mean a loadable plugin.
- **"cannot open shared object file" versus a failed `init()`.** The first means the loader could not
  find a file. The second means it found and loaded it, and the code inside then failed — usually
  because of a dependency one level further down.

An `undefined symbol` error at any layer means a build mismatch rather than a missing file, and the
fix is to copy BCM's matching tree rather than install an Ubuntu package.

## What this does not give you

| Point | Detail |
|---|---|
| `--container-image` requires enroot | Pyxis invokes enroot at launch — see [install-enroot.md](install-enroot.md) |
| MPI jobs are unproven | This verifies the plugin stack initialises. A real multi-rank job also exercises UCX and fabric access this host may lack |
| Everything here is unmanaged | A cluster pyxis or PMIx upgrade leaves stale copies here; an ABI change breaks `srun` again with no warning |
| New plugins break it again | Another `required` line in `plugstack.conf.d` fails the same way, since the list is shared and the plugins are not |
| Global PMIx | The `ld.so.conf.d` entry makes BCM's PMIx 4.1.3 visible to every binary on the node, not just Slurm's plugin |

Record the source host and date alongside the Slurm `.deb` version — nothing on the system tracks any
of it.

## Related

- [install-slurm-binaries.md](install-slurm-binaries.md) — the extraction this completes.
- [troubleshoot.md](troubleshoot.md) — other symptoms and their causes.
- [explanation.md](../explanation.md) — why the query tools work while the submission tools do not.
