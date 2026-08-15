# Why submission needs more than query tools

BCM packages Slurm query tools, launch tools, daemons, and plugins together.
Package dependencies therefore describe the whole package, not the smaller set
needed by `sinfo`, `squeue`, and `sacct`.

The query tools link directly to `libslurmfull.so` and base system libraries.
That is why extracting the Slurm package is enough for a read-only client.

`srun` and `sbatch` load additional components at runtime:

1. Slurm reads the shared `plugstack.conf.d` and loads required SPANK plugins.
2. The PMIx MPI plugin loads and resolves its linked dependencies, including
   hwloc.
3. The plugin loads PMIx with `dlopen`, so PMIx does not appear in the plugin's
   `ldd` output.
4. PMIx then resolves its own dependencies, including libevent.

Each failure hides the next because a layer is reached only after the previous
one loads. This is why a clean `ldd` on `srun` does not prove that job launch
will work.

The shared plugin configuration should not be weakened to accommodate an
unmanaged client. A plugin marked `required` expresses cluster policy; changing
it affects managed compute nodes too. The client must supply the matching
plugin and libraries instead.

Copied and extracted plugins are unmanaged local state. Record their source
and version, and revalidate submission after cluster upgrades.
