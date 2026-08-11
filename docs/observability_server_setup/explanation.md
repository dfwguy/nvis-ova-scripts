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

The boundary is exactly the query tools, though, and it is worth stating precisely: `sinfo`,
`squeue`, and `sacct` need none of it; `srun` and `sbatch` need most of it. The moment `srun` builds
an MPI context it loads `mpi_pmix_v4.so`, which wants hwloc, and PMIx, which wants libevent. Those
are the `cm-pmix4-local` and `cm-hwloc2-local` dependencies the extraction skipped, arriving late and
one at a time. "Safe to skip" is a statement about a read-only client, not about the package.

The cost is real, though. There is no dpkg record, so nothing tracks the files, nothing upgrades
them, and nothing warns you when the cluster moves to a new Slurm version. Slurm supports clients
within roughly two minor versions of the controller; beyond that, RPC changes break things. That
maintenance burden is the price of avoiding repository access, and it is why LDAP/SSSD plus proper BCM
provisioning is the better answer for anything long-lived.

## Why the query tools worked and the submission tools did not

The `ldd` argument above covers `sinfo` and `squeue` completely, because everything they need is
something the linker can see. `srun` and `sbatch` have a requirement `ldd` cannot show: a list of
SPANK plugins, read from `plugstack.conf.d` at startup and loaded with `dlopen`. A missing entry
there is invisible to every check you would run on the binary, and fatal the first time you run the
command.

What makes it land specifically on a hand-built node is where the two halves live. The list is
configuration, so BCM keeps it on `/cm/shared`, and mounting the export hands it to you
automatically. The plugins are binaries, so they sit under `/cm/local` and arrive only by
provisioning. That is the same split as everything else here, with the sign flipped: usually the NFS
mount supplies something you would otherwise have to fetch, and here it supplies an obligation you
cannot meet. A node with no `/cm/shared` mount would find no plugin list and load nothing.

The extraction misses the plugin for a second, compounding reason. Pyxis is packaged separately from
Slurm and installed on its own schedule — at this site the `.so` is dated two months after the Slurm
tree around it. Even a perfect extraction of the Slurm `.deb` could not have contained it, which is
why this surfaces as a surprise rather than as an obvious omission at install time.

Slurm's refusal is correct, and worth not fighting. A plugin marked `required` that cannot be loaded
is fatal because the alternative is silently launching jobs without the isolation, accounting, or
credential handling the site expects it to enforce. Softening that is a cluster-wide decision, and
`plugstack.conf.d` living on the shared filesystem is precisely what makes it one: there is no way to
relax it for this node without also detaching from the shared `slurm.conf` and taking on a private
copy that will drift.

So the fix is to satisfy the requirement rather than remove it — copy the plugin in, as with the
munge key, and inherit the same weakness. Both are unmanaged local copies of cluster state, and both
break silently when the cluster's version moves. That is the recurring price of this whole approach,
and it shows up once more here.

## Why each fix reveals another failure

Getting submission working takes four rounds, and the reason is that the dependencies are discovered
by *running* rather than declared anywhere readable. Each layer is loaded only once the layer above
succeeds, so the second problem is unobservable until the first is solved. There is no way to see the
whole list up front, which is why the work feels like whack-a-mole rather than a checklist.

Two mechanisms hide the chain. The first is `dlopen`: `ldd` reports what the linker recorded, and
Slurm's pmix plugin loads PMIx by name at runtime, so PMIx does not appear in the plugin's
dependencies at all. A clean `ldd` proves nothing about whether the plugin will load. The second is
RUNPATH — `mpi_pmix_v4.so` carries `/cm/local/apps/hwloc2/2.8.0/lib`, which does not exist on this
node, so the loader silently falls through to the system path and finds Ubuntu's hwloc. That
fall-through is why hwloc could be solved with an apt install while PMIx could not: a missing RUNPATH
directory degrades to the default search, but a library nothing searches for is simply absent.

The error messages compound it by being nearly identical. "cannot open shared object file" means the
loader could not find something; "can not load PMIx library" means the plugin loaded, ran its
`init()`, and failed one level deeper. Both read as "it cannot load," and only the distinction
between them tells you whether to go looking for a file or for a dependency of a file.

The general lesson is that a provisioned node's dependency graph is satisfied by its environment —
modules setting `LD_LIBRARY_PATH`, packages installed in a known order — and none of that context
travels with a copied binary. Reproducing it means rediscovering it at runtime, one failure at a
time, which is precisely why the how-to guide records the sequence: the next person should not have
to derive it again.

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

## Why DNS is configured rather than replaced

Ubuntu 24.04 resolves names through `systemd-resolved`, and the reflex on a server is to remove it —
point `/etc/resolv.conf` at the head node and be done. That works until the next reboot, because
`/etc/resolv.conf` is a symlink into `/run` that `resolved` regenerates. Fighting the stub resolver
means fighting NetworkManager and netplan too, both of which expect to own name resolution.

A drop-in under `/etc/systemd/resolved.conf.d/` takes the opposite approach: leave the mechanism
alone and supply it with the site's answer. It survives package upgrades, which edits to
`/etc/systemd/resolved.conf` do not, and it keeps the local cache and the per-link routing logic that
a hand-written `resolv.conf` throws away.

The cache is not incidental. A `clush` fan-out resolves every target name at once, and BCM serves
cluster records with short TTLs. Answering repeats locally keeps a broadcast across hundreds of nodes
from turning into hundreds of simultaneous queries at the head node — which is already the busiest
machine in the cluster and is also serving Slurm RPCs, NFS, and CMDaemon to the same nodes.

## Why routing domains beat a long search list

`Domains=` conflates two different jobs, and the difference is what makes the config either stable or
a maintenance chore.

A **search domain** is a suffix appended to a bare name. `Domains=dgxnet01.cluster` means
`ink50-dh01-d22-36` is retried as `ink50-dh01-d22-36.dgxnet01.cluster`. Each entry is tried in order,
so 29 entries means a name that does not exist costs up to 29 sequential queries before failing.

A **routing domain**, written with a leading `~`, appends nothing. It answers a different question:
which resolver should handle names under this domain. `~cluster` sends every `*.cluster` lookup to
the head node and covers every network BCM has now or will provision later.

The site's original configuration listed all 29 domains as search suffixes, which is why it worked —
listing a domain plainly makes it a route *and* a suffix. But it encodes the cluster's current
network layout in a file on an unmanaged host, which is exactly the drift this guide keeps running
into: BCM adds `dgxnet29`, nothing here notices, and the failure is a name that will not resolve for
reasons unrelated to anything that changed locally. `~cluster` plus the handful of networks whose
nodes you address by short name has the same effect with nothing to keep in sync.

## Why the head node still needs an `/etc/hosts` entry

With cluster DNS working it is tempting to delete the `/etc/hosts` lines for `nscale-hn1` and
`master`. Don't. The resolver those names point at *is* the head node, so resolving the head node by
DNS would make every Slurm command depend on the head node already being reachable by name — a
circular dependency that is invisible while things work and total when they do not.

This is the same reasoning as copying the munge key locally instead of reading it from NFS: the
bootstrap path for reaching a service must not run through that service. `/etc/hosts` is consulted
before DNS, costs nothing, and means a DNS outage degrades cluster-wide name resolution without
taking `sinfo` with it.

## Why `clush` groups come from `sinfo` rather than a file

ClusterShell can hold static group membership in a YAML file, and for a fixed set of racks that is
the simpler answer. It is the wrong answer here for the same reason the rest of this guide avoids
local copies: this node is not managed, so anything written down by hand goes stale without warning.

A group *source* inverts that. Instead of storing which nodes are idle, it stores a command that
answers the question at the moment it is asked. `sinfo` is already the authoritative answer, already
installed, and already authenticated to the controller — so the group source is three lines and has
no state of its own to drift.

The trade is that group resolution now inherits every failure mode of `sinfo`. If munge or the NFS
mount breaks, `list` returns nothing, `clush -g idle` targets an empty set, and it exits cleanly
having done nothing. Like the empty-`squeue` symptom, success and breakage look alike — which is why
expanding with `nodeset -g` before a consequential fan-out is worth the extra keystroke.

There is also a race with no clean fix: `map` samples state once per invocation, so a node that
changes state mid-run is targeted according to what it *was*. For read-only queries that does not
matter. For anything that writes, resolve the list first and pass it explicitly.

The deeper cost of deriving groups from a command is that you inherit the command's output format,
including parts of it you did not ask for. `sinfo` decorates a state name with a flag character —
`idle*` for an unreachable node — because it is designed for a human reading a terminal, where the
flag is useful and unambiguous. ClusterShell reads the same string as an identifier, and identifiers
do not permit `*`. Nothing is wrong on either side; the two tools simply disagree about what the
string is *for*.

That disagreement produces a disproportionate failure. `nodeset -ll` does not skip the malformed
name and carry on — it aborts, so a single unreachable node makes the entire group listing
unavailable. Normalising in `list` is what reconciles the two views, and it is worth understanding as
the general shape of the problem rather than a one-off: any command-backed source needs its output
sanitised into the namespace the consumer expects, and the failures show up only when the underlying
command starts emitting a case you did not see on the day you wrote the config.

## Why the two ClusterShell config directories are not interchangeable

ClusterShell reads group configuration from two directories that look similar and are not:

- **`confdir`** (`groups.conf.d/`) holds `*.conf` files in INI format, each defining a *source* — a
  named set of `list`/`map`/`all` commands. This is where `[sinfo]` belongs.
- **`autodir`** (`groups.d/`) holds `*.yaml` files listing *membership* directly — group names mapped
  to node sets, no commands involved.

The distinction is definition-by-command versus definition-by-data, and the file extension is how
ClusterShell tells them apart. A `.conf` dropped in `groups.d/` matches neither the YAML loader's
glob nor the INI parser's directory, so it is not read and no warning is emitted. The only visible
consequence appears later, when `default: sinfo` in `groups.conf` refers to a source that was never
loaded:

```
clush: Group resolver error: Default group source not found: "sinfo"
```

The error names the symptom, not the cause — it says the source is missing, not that the file
defining it was ignored. Reading it as "my config is wrong" rather than "my config is in the wrong
directory" is the natural mistake, and it costs time.

## What this node is not

Being explicit, since the distinction matters when someone else inherits the host:

- It is **not BCM-managed**. It receives no image updates and appears in no node category. Every step
  here is manual and will drift on the next cluster upgrade.
- It **cannot run jobs**. No `slurmd`, so the controller has no way to schedule work onto it.
- It **can** submit jobs, but only after the pyxis SPANK plugin is copied in by hand — see
  [how-to/enable-job-submission.md](how-to/enable-job-submission.md). Jobs then land on real compute
  nodes, and anything depending on shared paths or MPI libraries this node lacks will behave
  differently here than on a login node. Container launch (`--container-image`) still does not work,
  since there is no enroot.
- Its user accounts are **local**, not LDAP. New cluster users will not exist here, and UID collisions
  become more likely over time.

For a durable login or observability host, the supported path is provisioning it through BCM as a
login-category node, which delivers binaries, config, munge key, and LDAP integration as part of the
image. This guide describes what to do when that is not available to you.
