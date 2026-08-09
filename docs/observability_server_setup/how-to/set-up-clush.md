# How to run commands across the cluster with `clush`

**Goal:** run a command on every node in a Slurm state — `idle`, `down`, `drain` — without
maintaining a node list by hand.

ClusterShell reads its node groups from a *group source*: a small config block that tells it how to
list groups and map a group to nodes. Pointing that source at `sinfo` means the groups are always
whatever Slurm currently reports.

## Prerequisites

- `sinfo` already works on this host — see [../tutorial.md](../tutorial.md).
- Node names resolve — see [set-up-dns.md](set-up-dns.md). `sinfo` returns short names that must
  resolve before SSH can connect.
- Passwordless SSH from this host to the nodes you intend to target — see
  [distribute-ssh-keys.md](distribute-ssh-keys.md). `clush` is only a fan-out wrapper around `ssh`;
  it adds no authentication of its own.

## Install

```
sudo apt install clustershell
```

## Define the `sinfo` group source

The file must go in `groups.conf.d/`, not `groups.d/` — see [Notes](#notes):

```
sudo tee /etc/clustershell/groups.conf.d/sinfo.conf > /dev/null << 'EOF'
[sinfo]
map: sinfo -h -o "%N" -t $GROUP
list: sinfo -h -o "%T" | tr -d '*~#%@+' | sort -u
all: sinfo -h -o "%N"
EOF
```

| Directive | Answers |
|---|---|
| `list` | Which groups exist — here, the set of node states Slurm reports |
| `map` | Which nodes are in group `$GROUP` — the state name is substituted in |
| `all` | Which nodes exist at all, used when no group is given |

The `tr` is not optional. Slurm appends a flag character to the state for nodes in a special
condition — `idle*` for unreachable, `idle~` for powered down — and those characters are illegal in a
ClusterShell group name. Leaving them in makes `nodeset -ll` fail outright:

```
nodeset: Illegal group character: "*"
```

Stripping the flag in `list` costs nothing, because `map` filters on the base state: `sinfo -t idle`
returns `idle*` nodes too. The flagged nodes stay in the group; only the decoration goes.

## Make it the default source

In `/etc/clustershell/groups.conf`, under `[Main]`:

```ini
default: sinfo
```

Without this, `clush -g idle` looks in whatever source is currently default (`local` on a stock
install) and reports the group as unknown. You can skip the change and qualify the group explicitly
instead — `clush -g sinfo:idle` — which is worth doing if the host has other group sources in use.

## Verify

List the groups, then expand one, before running anything remotely:

```
nodeset -ll
```

```
nodeset -g idle
```

The group names must match the states in `sinfo` output, with no trailing flag character. Compare a
group against `sinfo` directly before trusting it — this is also the check that confirms flagged
nodes were not dropped:

```
nodeset -c -g idle && sinfo -h -o "%D %T" -t idle
```

`nodeset -c` prints a count; `%D` is Slurm's own node count. If the two disagree, `map` is filtering
differently than you expect.

Then a harmless fan-out:

```
clush -g idle hostname
```

## Notes

- **`groups.d/` will not work for this.** The `autodir` directive loads `/etc/clustershell/groups.d/`
  but reads only `*.yaml` files there; a `.cfg` or `.conf` file in that directory is silently ignored,
  and `clush` then fails with `Group resolver error: Default group source not found: "sinfo"`.
  Source definitions in this INI format belong under `confdir` — `/etc/clustershell/groups.conf.d/`
  — where `*.conf` is the expected extension.
- **Groups are a snapshot.** `map` runs `sinfo` at the moment you invoke `clush`, so a node that
  drains between listing and execution is still targeted. For anything destructive, expand with
  `nodeset -g` first and pass the resulting list explicitly.
- **State flags must be stripped, and `$` cannot be.** The `tr` above removes `* ~ # % @ +`. Slurm
  also uses `$` (node in a maintenance reservation), which is deliberately absent from that list:
  ClusterShell treats `$` as the start of a substitution like `$GROUP`, so a literal one must be
  written `$$` in `groups.conf.d`. If a node ever appears as `idle$`, add `$$` to the `tr` set rather
  than a bare `$`.
- **A flagged node is not a lost node.** `map` filters with `sinfo -t <state>`, which matches the base
  state, so `idle*` and `idle~` nodes remain in the `idle` group. Stripping the flag changes the group
  *name* only — an unreachable node stays in the target set and will simply fail its SSH connection
  when `clush` runs. `clush -b` makes those failures easy to spot.
- Group membership is only as visible as `sinfo` is. If the munge key or UID alignment breaks, `list`
  returns nothing and every group silently becomes empty — the same failure mode described in
  [troubleshoot.md](troubleshoot.md).

## Related

- [../reference.md](../reference.md) — `clush` and `nodeset` command quick reference.
- [../explanation.md](../explanation.md) — why the group source lives where it does.
- [troubleshoot.md](troubleshoot.md) — when `sinfo` itself is the thing that is broken.
