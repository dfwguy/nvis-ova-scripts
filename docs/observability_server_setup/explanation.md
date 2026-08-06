# Explanation: why a BCM client node is set up this way

This document explains the reasoning behind the steps. It is not needed to complete the task, but it
makes the failure modes predictable rather than surprising.

## What a Slurm client actually needs

Slurm has no client package in the usual sense. `sinfo` and `squeue` are thin RPC clients that
require exactly four things:

| Requirement | Why |
|---|---|
| Binaries plus `libslurmfull.so` | The protocol implementation |
| `slurm.conf` | Tells the client which host and port to contact, and names `SlurmUser` |
| A munge key matching the controller's | Every RPC is signed; unsigned or wrongly-signed calls are rejected |
| A UID the controller recognises | Determines what the controller will show you |

Notably absent: `slurmd`, cgroup configuration, MPI libraries, and node registration. Those belong to
compute nodes. A client-only node is a much smaller problem than a compute node, which is why
extracting a few files works where installing the full package does not.

## Why BCM splits `/cm/local` from `/cm/shared`

BCM deliberately separates two kinds of state:

- **`/cm/local`** — binaries and libraries, node-local. Kept local so that node startup and job
  launch do not depend on NFS being healthy, and so per-node hardware variation (different MPI or
  driver builds) is possible.
- **`/cm/shared`** — configuration, state, and user-facing modules, exported over NFS. Kept shared so
  every node reads the same `slurm.conf` and the controller's state is in one place.

This is the reason the setup feels awkward: you have to gather from both. Configuration arrives
automatically once you mount the export, but binaries do not, because BCM would normally deliver them
by provisioning the node from an image. A hand-built client bypasses provisioning and therefore has
to bypass binary delivery too.

It also explains why some sites *do* have binaries under `/cm/shared/apps/slurm/current/bin` — that
is a site choice to prioritise convenience over NFS independence. Both layouts exist, so you check
rather than assume.

## Why the `cm-*` dependencies are safe to skip

BCM's Slurm package declares dependencies on `cm-pmix4-local`, `cm-ucx-local`, and `cm-hwloc2-local`
because the package ships *everything*: `slurmd`, `srun`, the MPI launch plugins, and the query tools
in one artifact. Those libraries are needed by the launch and topology-detection paths.

Package dependencies are declared per package, not per binary, so `sinfo` inherits requirements it
never uses. `ldd` reveals the truth: `sinfo` links only `libslurmfull.so`, glibc, libm, and libresolv.
Extracting with `dpkg -x` gets the files while skipping metadata that describes a use case you do not
have.

The cost is real, though. There is no dpkg record, so nothing tracks the files, nothing upgrades
them, and nothing warns you when the cluster moves to a new Slurm version. Slurm supports clients
within roughly two minor versions of the controller; beyond that, RPC changes break things. That
maintenance burden is the price of avoiding repository access, and it is why LDAP/SSSD plus proper BCM
provisioning is the better answer for anything long-lived.

## Why the munge key is copied rather than read from NFS

BCM points its munged at a key on `/cm/shared`, and it is tempting to do the same. Resist it, for
three reasons:

1. **Permissions.** Munge keys are mode `0400` owned by a single UID. On NFS with `root_squash`,
   whether your local munged can read that file depends on UID alignment and export options — a
   fragile combination.
2. **Boot ordering.** munged starts early. If NFS is not yet mounted, munged fails, and every Slurm
   command on the node breaks until someone notices.
3. **Coupling.** A read-only client should not become unusable because a network mount blipped.

Copying the bytes to `/etc/munge/munge.key` with local ownership sidesteps all three. Only the
contents matter to the protocol — the local `munge` account's UID is irrelevant, unlike the `slurm`
and end-user accounts.

The consequence is that a key rotation on the cluster silently breaks this node, producing
`Invalid credential` until you re-copy. That is a fair trade for boot-time robustness, but it is worth
writing down where someone will find it.

## Why UIDs must match, in two different ways

The two UID requirements are unrelated, which is why they fail differently.

**`SlurmUser`** is a name in `slurm.conf`. Client tools resolve it during config parsing, before any
network activity, and abort if it does not resolve. This is a local sanity check, not an
authorization step — which is why the failure is `fatal: Unable to process configuration file` rather
than an auth error, and why the account needs no shell, home directory, or password.

**Your own UID** is what munge asserts to the controller. Munge signs the credential with the caller's
real UID and GID; the controller trusts that assertion and applies authorization to it. With
`PrivateData=jobs` set, the controller returns only jobs whose owner UID matches. A mismatched local
UID is a *valid* identity — just a different person, who happens to own no jobs.

That is why the failure is an empty list rather than an error, and why `squeue --all` cannot help. The
request succeeded. The answer is honestly zero. This is the single most confusing symptom in the whole
setup, because success and misconfiguration look identical.

It also explains why `sinfo` worked while `squeue` did not: partition and node state are not
UID-scoped, so `PrivateData` never filters them.

## Why `sudo` needs separate treatment

`sudo` deliberately discards the caller's environment, including PATH, replacing it with
`secure_path` from `sudoers`. This prevents a user from placing a trojan `ls` earlier in PATH and
having root execute it. The behaviour is a security feature, not a bug, so the fix is to extend
`secure_path` rather than to make `sudo` preserve PATH.

More generally, environment variables are the weakest form of configuration: they exist only in
shells that sourced the right file. `profile.d` covers interactive login shells and misses cron,
systemd units, `sudo`, and scripts with `#!/bin/sh`. Putting the config at `/etc/slurm/slurm.conf` —
Slurm's compiled-in default — makes it work everywhere with no environment at all. `SLURM_CONF`
remains useful for overriding, but should not be the only mechanism.

## What this node is not

Being explicit, since the distinction matters when someone else inherits the host:

- It is **not BCM-managed**. It receives no image updates and appears in no node category. Every step
  here is manual and will drift on the next cluster upgrade.
- It **cannot run jobs**. No `slurmd`, so the controller has no way to schedule work onto it.
- `srun` and `sbatch` may work as submission clients, but jobs land on real compute nodes, and
  anything depending on shared paths or MPI libraries this node lacks will behave differently here
  than on a login node.
- Its user accounts are **local**, not LDAP. New cluster users will not exist here, and UID collisions
  become more likely over time.

For a durable login or observability host, the supported path is provisioning it through BCM as a
login-category node, which delivers binaries, config, munge key, and LDAP integration as part of the
image. This guide describes what to do when that is not available to you.
