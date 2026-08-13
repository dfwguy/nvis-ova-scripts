# Reference

Site-specific values below are from one deployment. The "How to discover" column tells you how to
find your own.

## Paths

| Item | Path (this site) | How to discover |
|---|---|---|
| NFS export | `192.168.10.2:/cm/shared` | Head node `/etc/exports` |
| Local mount point | `/cm/shared` | Must match the export path exactly |
| Slurm binaries | `/cm/local/apps/slurm/25.05/bin` | `ssh <hn> 'readlink -f $(which sinfo)'` |
| Slurm libraries | `/cm/local/apps/slurm/25.05/lib64/slurm` | `ldd $(which sinfo)` |
| Slurm plugins (SPANK, MPI) | `/cm/local/apps/slurm/25.05/lib64/slurm/` | Path named in `plugstack.conf.d`; `current -> 25.05` |
| SPANK plugin list | `/cm/shared/apps/slurm/etc/slurm/plugstack.conf.d/*.conf` | `cat` it — shared, so this node inherits the cluster's |
| PMIx (BCM build) | `/cm/local/apps/cm-pmix4/4.1.3/lib`, `current -> 4.1.3` | `ssh <hn> 'ls -d /cm/local/apps/*pmix*'` |
| hwloc (BCM build) | `/cm/local/apps/hwloc2/2.8.0/lib` | RUNPATH in `mpi_pmix_v4.so`; absent locally, Ubuntu's is used instead |
| `slurm.conf` (source) | `/cm/shared/apps/slurm/etc/slurm/slurm.conf` | `ls /cm/shared/apps/slurm/etc/slurm/` |
| `slurm.conf` (local default) | `/etc/slurm/slurm.conf` | Symlink to the source |
| `slurmdbd.conf` | `/cm/shared/apps/slurm/etc/slurmdbd.conf` | Same directory |
| Munge key (cluster) | `/cm/shared/apps/slurm/var/munge/keys/munge.key` | `ssh <hn> 'systemctl cat munge \| grep -i key'` |
| Munge key (local) | `/etc/munge/munge.key` | munged's compiled-in default |
| Shared working directory | `/cluster`, mode `1777` | Exported by the slogin or observability node |

`/cluster` is the default place to keep scripts and data — shared across nodes, and unlike
`/cm/shared` not owned by BCM. It is exported by the slogin or observability node, not the head
node: the head node serves only what BCM provisions. It must be world-writable or writes succeed for
some users and fail for others. Use `1777` rather than `0777` — the sticky bit stops one user
deleting another's files — and set it on the exporting host, since NFS serves the mode from the
server.

## Accounts

| Account | UID:GID (this site) | Must match cluster? | How to discover |
|---|---|---|---|
| `slurm` | `450:450` | Yes | `ssh <hn> 'id slurm'` |
| End user (`nvis`) | `1001:1001` | Yes, for `squeue` output | `ssh <hn> 'id <user>'` |
| `munge` | Package-assigned | No — only key bytes matter | n/a |

## Network

| Item | Value | Source |
|---|---|---|
| `SlurmctldHost` | `nscale-hn1` | `slurm.conf` |
| `SlurmctldPort` | `6817` | `slurm.conf` |
| `AccountingStorageHost` | `master` (BCM alias for head node) | `slurm.conf` |
| Head node IP (management) | `192.168.10.2` | Site network |
| Head node IP (bonded) | `10.40.112.2` | Site network |

Both head node addresses answer DNS. The bonded interface measured ~1 ms against ~22 ms on the
management interface at this site, so it is the one configured as the resolver — time your own with
`dig @<ip> google.com`.

## DNS

| Item | Value (this site) | How to discover |
|---|---|---|
| Upstream resolver | `10.40.112.2` | Head node bonded interface |
| Routing domain | `~cluster` | Covers every BCM `<network>.cluster` domain |
| Search domains | `dgxnet01.cluster` – `dgxnet28.cluster`, `eth.cluster` | `cmsh -c "network; list"` |
| Cache | `Cache=yes` | Drop-in setting |

BCM names each network's domain as `<network>.cluster`. The full set at this site:

```
dgxnet01.cluster dgxnet02.cluster dgxnet03.cluster dgxnet04.cluster dgxnet05.cluster
dgxnet06.cluster dgxnet07.cluster dgxnet08.cluster dgxnet09.cluster dgxnet10.cluster
dgxnet11.cluster dgxnet12.cluster dgxnet13.cluster dgxnet14.cluster dgxnet15.cluster
dgxnet16.cluster dgxnet17.cluster dgxnet18.cluster dgxnet19.cluster dgxnet20.cluster
dgxnet21.cluster dgxnet22.cluster dgxnet23.cluster dgxnet24.cluster dgxnet25.cluster
dgxnet26.cluster dgxnet27.cluster dgxnet28.cluster eth.cluster
```

Listing these as search suffixes is only needed for hostnames typed without a domain; `~cluster`
alone routes all fully qualified `*.cluster` lookups. See
[how-to/set-up-dns.md](how-to/set-up-dns.md).

| `resolved` command | Does |
|---|---|
| `resolvectl status` | Global and per-link resolver config — the first thing to check |
| `resolvectl query <name>` | Resolve one name, showing which route answered |
| `resolvectl statistics` | Cache hit/miss counters |
| `resolvectl flush-caches` | Drop cached answers after a BCM change |

**Limitation:** `systemd-resolved` has no option to suppress `AAAA` queries. `dnsmasq` with
`no-aaaa` is the alternative if that becomes necessary.

## Relevant config settings

| Setting | Value | Effect on a client |
|---|---|---|
| `SlurmUser` | `slurm` | Name must resolve locally or config parsing fails |
| `PrivateData` | `accounts,users,jobs,reservations` | `squeue`/`sacct` filter by caller UID; mismatch returns empty, not an error |
| `SlurmctldHost` | `nscale-hn1` | Must be resolvable and reachable on 6817 |
| `plugstack.conf.d` pyxis line | `required ... spank_pyxis.so ... sbatch_support=1` | `required` makes a failed load fatal; `sbatch_support=1` applies it to `sbatch` as well as `srun` |

## Files this setup creates or modifies

| File | Purpose | Action |
|---|---|---|
| `/etc/fstab` | Persistent NFS mount | Append one line |
| `/etc/hosts` | Resolve `nscale-hn1` and `master` | Append one line |
| `/etc/munge/munge.key` | Auth credential, `munge:munge`, `0400` | Create |
| `/etc/slurm/slurm.conf` | Symlink to shared config | Create |
| `/etc/profile.d/slurm.sh` | PATH and `SLURM_CONF` for login shells | Create, `0644` |
| `/etc/sudoers.d/slurm-path` | `secure_path` including Slurm bin | Create, `0440` |
| `/etc/passwd`, `/etc/group` | `slurm` account; renumbered end user | Modify |
| `/cm/local/apps/slurm/25.05/` | Extracted binaries and libraries | Create |
| `/cm/local/apps/slurm/25.05/lib64/slurm/spank_pyxis.so` | SPANK plugin `srun`/`sbatch` require, `root:root`, `0644` | Copy from head node |
| `/cm/local/apps/cm-pmix4/` | BCM PMIx tree, loaded by the MPI plugin at runtime | Copy from head node |
| `/etc/ld.so.conf.d/cm-pmix4.conf` | Makes `libpmix.so.2` findable without `LD_LIBRARY_PATH` | Create, then `ldconfig` |
| `/etc/clustershell/groups.conf.d/sinfo.conf` | `clush` group source backed by `sinfo` | Create |
| `/etc/clustershell/groups.conf` | `default: sinfo` under `[Main]` | Modify |
| `/etc/clustershell/clush.conf` | `fanout: 512` under `[Main]` | Modify |
| `/etc/systemd/resolved.conf.d/bcm.conf` | Forward cluster DNS to the head node | Create |

## Packages

| Package | Source | Notes |
|---|---|---|
| `munge`, `libmunge2` | Ubuntu `noble-updates/universe` | Normal apt install |
| `clustershell` | Ubuntu `noble/universe` | Normal apt install; provides `clush`, `nodeset`, `clubak` |
| `pdsh` | Ubuntu `noble/universe` | Installed for `dshbak`; `pdsh` itself is unused |
| `nfs-common` | Ubuntu | Only if `mount.nfs` is missing |
| `slurm25.05_25.05.8-101099-cm11.0-a3a58b4841_amd64.deb` | BCM head node | Extract with `dpkg -x`, do not apt install |
| `spank_pyxis.so` | BCM head node, separate pyxis package | Copy the file; not in the Slurm `.deb` |
| `enroot` | BCM head node, `/cluster/dpkg/` staging | `dpkg -i`; no BCM-specific deps |
| `enroot+caps` | BCM head node, `/cluster/dpkg/` staging | `dpkg -i` after `enroot`; sets file capabilities |
| `libhwloc15` | Ubuntu `noble/universe` | Satisfies `mpi_pmix_v4.so`; BCM's RUNPATH dir is absent, so the default path is used |
| `libevent-pthreads-2.1-7t64` | Ubuntu `noble/main` | PMIx dependency; the `t64` suffix is noble's, the soname is not |
| `cm-pmix4-local` (4.1.3) | BCM head node, `/cluster/dpkg/` staging | `dpkg -x`; `cm-config-cm` dep is metadata-only, not a runtime requirement. Do not substitute Ubuntu's `libpmix2t64` — wire-protocol skew |

Unresolvable dependencies in the BCM `.deb`: `cm-pmix4-local`, `cm-ucx-local`, `cm-hwloc2-local`,
`cm-config-cm (= 11.0)`. None are required by the client query tools.

## Command quick reference

Discover the cluster's Slurm binary location:

```
ssh <headnode> 'readlink -f $(which sinfo)'
```

Discover the munge key location:

```
ssh <headnode> 'systemctl cat munge | grep -i key'
```

Read the client-relevant config settings:

```
grep -Ei 'SlurmctldHost|SlurmctldPort|AccountingStorageHost|SlurmUser|PrivateData' /etc/slurm/slurm.conf
```

Inspect a `.deb`'s target paths before installing:

```
dpkg -c <package>.deb | awk '{print $6}' | sort -u | head -30
```

Full health check:

```
mountpoint /cm/shared && munge -n | unmunge && sinfo | head -3 && squeue | head -3
```

Submission health check — each stage fails differently, see
[how-to/enable-job-submission.md](how-to/enable-job-submission.md):

```
ls /cm/local/apps/slurm/current/lib64/slurm/spank_pyxis.so && ldd /cm/local/apps/cm-pmix4/current/lib/libpmix.so.2 | grep 'not found'; srun --version && srun -N1 --time=1 hostname
```

Find what a plugin will fail to load, and where it searches:

```
ldd <plugin>.so | grep 'not found'
```

```
objdump -p <plugin>.so | grep -Ei 'RPATH|RUNPATH'
```

Load a library standalone to see the real `dlopen` error, which Slurm's message hides:

```
python3 -c "import ctypes; ctypes.CDLL('libpmix.so.2')"
```

## ClusterShell quick reference

Assumes the `sinfo` group source from
[how-to/set-up-clush.md](how-to/set-up-clush.md), with `default: sinfo` set.

| Command | Does |
|---|---|
| `nodeset -ll` | List every group and its members |
| `nodeset -g idle` | Expand one group to a node list |
| `nodeset -c -g idle` | Count the nodes in a group |
| `clush -g idle hostname` | Run on all idle nodes |
| `clush -g down uptime` | Run on all down nodes |
| `clush -g drain "systemctl status slurmd"` | Run on all drained nodes |
| `clush -b -g idle uptime` | Same, with identical output lines folded together |
| `clush -g idle uptime \| dshbak -c` | Equivalent via `pdsh`'s formatter, as used by existing scripts |
| `clush -g idle uptime \| clubak -b` | Equivalent via ClusterShell's own formatter |
| `clush -w node[01-04] uptime` | Target an explicit node range, ignoring groups |
| `clush -f 128 -g idle uptime` | Override the configured fanout for one run |

| ClusterShell setting | File | This site | Default |
|---|---|---|---|
| `default` | `groups.conf` `[Main]` | `sinfo` | `local` |
| `fanout` | `clush.conf` `[Main]` | `512` | `64` |

`fanout` is the number of concurrent SSH connections. Each consumes file descriptors, so `ulimit -n`
bounds how high it can usefully go. Lower it behind a bastion or on a small host; raise it on a
well-resourced head node driving a large cluster.

## Slurm node state flags

Appended by `sinfo` to the state name in `%T` / `%t` output. All are illegal in a ClusterShell group
name and must be stripped by the `list` directive.

| Flag | Meaning |
|---|---|
| `*` | Node not responding to the controller |
| `~` | Node powered down |
| `#` | Node powering up or being configured |
| `%` | Node powering down |
| `@` | Node has a pending reboot |
| `+` | Node in the process of being provisioned |
| `$` | Node in a maintenance reservation — write as `$$` in `groups.conf.d`, since `$` starts a substitution |

`sinfo -t <state>` filters on the base state, so flagged nodes are still returned by `map`.

## ClusterShell config locations

| Directive in `groups.conf` | Directory | Files read |
|---|---|---|
| `confdir` | `/etc/clustershell/groups.conf.d/` | `*.conf` — INI group **source** definitions |
| `autodir` | `/etc/clustershell/groups.d/` | `*.yaml` only — static group **membership** |
