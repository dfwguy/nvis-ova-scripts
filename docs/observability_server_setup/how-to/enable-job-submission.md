# How to make `srun` and `sbatch` work

Use this procedure after the Slurm query tools work but `srun` or `sbatch`
fails while loading Pyxis or PMIx. Complete the sections in order because each
dependency is loaded by the one before it.

For non-MPI work, `srun --mpi=none` avoids the MPI dependencies. The required
Pyxis plugin is still needed.

## 1. Install the Pyxis SPANK plugin

Confirm the shared configuration requires Pyxis:

```console
cat /cm/shared/apps/slurm/etc/slurm/plugstack.conf.d/*.conf
```

Copy the plugin from the head node and install it in the versioned Slurm
directory:

```console
scp <headnode>:/cm/local/apps/slurm/current/lib64/slurm/spank_pyxis.so /tmp/
sudo install -m 0644 -o root -g root /tmp/spank_pyxis.so \
    /cm/local/apps/slurm/25.05/lib64/slurm/spank_pyxis.so
```

Do not make the shared plugin entry optional; that changes policy for the
managed compute nodes too.

## 2. Install hwloc

If the MPI plugin reports that `libhwloc.so.15` is missing, install it from
Ubuntu:

```console
sudo apt-get install -y libhwloc15
```

Confirm that the plugin has no unresolved linked libraries:

```console
ldd /cm/local/apps/slurm/current/lib64/slurm/mpi_pmix_v4.so |
    grep 'not found'
```

No output is expected.

## 3. Install BCM's PMIx

On the head node, download the matching package:

```console
cd /cluster/dpkg
apt-get download cm-pmix4-local
```

On the client node, extract it and register its library directory:

```console
sudo dpkg -x /cluster/dpkg/cm-pmix4-local_4.1.3-100026-cm11.0-61feac3379_amd64.deb /
printf '/cm/local/apps/cm-pmix4/current/lib\n' |
    sudo tee /etc/ld.so.conf.d/cm-pmix4.conf
sudo ldconfig
ldconfig -p | grep libpmix
```

Use the BCM PMIx version that matches the cluster rather than Ubuntu's PMIx.

If the package is unavailable, copy the installed tree instead:

```console
rsync -a <headnode>:/cm/local/apps/cm-pmix4 /tmp/
sudo cp -a /tmp/cm-pmix4 /cm/local/apps/
```

Then create the loader configuration and run `ldconfig` as shown above.

## 4. Install PMIx dependencies

Find unresolved dependencies:

```console
ldd /cm/local/apps/cm-pmix4/current/lib/libpmix.so.2 | grep 'not found'
```

On Ubuntu 24.04, install the expected libevent package:

```console
sudo apt-get install -y libevent-pthreads-2.1-7t64
```

Run the `ldd` check again. No output is expected.

## 5. Verify submission

```console
srun --version
sbatch --version
srun -N1 --time=1 hostname
```

A hostname or `job NNNNN queued and waiting for resources` confirms that the
request reached the scheduler.

For the runtime-loading model behind these dependencies, see
[Why submission needs more than query tools](../explanation/submission-dependencies.md).
For other failures, see [Troubleshoot a failing Slurm client](troubleshoot.md).
