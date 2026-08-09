# How to troubleshoot a failing `sinfo` or `squeue`

**Goal:** map a symptom to its cause quickly.

The errors appear in a predictable order as you fix each layer: config parsing, then connectivity,
then authentication, then authorization.

## Symptom table

| Symptom | Cause | Fix |
|---|---|---|
| `command not found` | PATH missing the Slurm bin dir | [persist-environment.md](persist-environment.md) |
| `command not found` under `sudo` only | `sudo` uses `secure_path`, not your PATH | [persist-environment.md](persist-environment.md) |
| `Unable to locate config file` | No `/etc/slurm/slurm.conf` and no `SLURM_CONF` | Symlink the config |
| `Invalid user for SlurmUser slurm` | No local `slurm` account | [align-uids.md](align-uids.md) |
| `Unable to contact slurm controller (connect failure)` | `SlurmctldHost` won't resolve, or port 6817 blocked | See below |
| `Invalid credential` | Munge key differs from the controller's | [set-up-munge.md](set-up-munge.md) |
| `Zero-length credential` / auth errors | munged not running locally | `systemctl status munge` |
| Command hangs, then times out | DNS resolves to a wrong or unreachable address | Check `/etc/hosts` |
| `squeue` empty, no error, jobs visible on head node | UID mismatch under `PrivateData=jobs` | [align-uids.md](align-uids.md) |
| `sinfo` works but `sacct` fails | `AccountingStorageHost` (often `master`) unresolved | Add the alias to `/etc/hosts` |
| Everything broke after reboot | `/cm/shared` not mounted | `mount -a`, check `_netdev` in fstab |

## Diagnosing a connect failure

Find what the config is trying to reach:

```
grep -Ei 'SlurmctldHost|SlurmctldPort|AccountingStorageHost' /etc/slurm/slurm.conf
```

Check name resolution, then the port:

```
getent hosts <slurmctldhost>
```

```
nc -vz <slurmctldhost> 6817
```

| Result | Meaning |
|---|---|
| `getent` returns nothing | Add a `/etc/hosts` entry for the head node |
| `getent` works, `nc` refused or times out | Head node firewall, or you're on a subnet its rules don't allow |
| Both succeed but `sinfo` still fails | Move on to authentication — likely the munge key |

BCM commonly uses an internal alias such as `master` alongside the real hostname. Both usually point
at the same head node:

```
printf '192.168.10.2\tnscale-hn1 master\n' >> /etc/hosts
```

## Diagnosing authentication

Test munge locally first — this proves munged works but says nothing about whether the key matches
the controller:

```
munge -n | unmunge
```

Then compare key bytes across nodes:

```
md5sum /etc/munge/munge.key
```

A mismatch, wrong ownership, or wrong mode all produce `Invalid credential`. Required state is
`munge:munge` and `0400`:

```
ls -l /etc/munge/munge.key
```

## Diagnosing the silently empty `squeue`

This is the least obvious failure, because nothing errors. Confirm the config filters by UID:

```
grep -i PrivateData /etc/slurm/slurm.conf
```

If `jobs` is listed, compare your UID with the cluster's. `squeue --all` will **not** override
`PrivateData` — the UID must actually match.

## Cluster hostnames do not resolve

`clush` fails with SSH name-resolution errors, or `resolvectl query <node>` returns
`Name or service not known`.

Check what the resolver is actually configured with, per link and globally:

```
resolvectl status
```

Then work down these in order:

| Symptom in `resolvectl status` | Cause | Fix |
|---|---|---|
| No `DNS Servers` line under Global | Drop-in not applied | `systemctl restart systemd-resolved`; check the file parses |
| A link has its own `DNS Servers` | DHCP or netplan is supplying a nameserver, which is preferred over the global one | Configure DNS on that interface in netplan, or rely on the `~cluster` routing domain, which applies regardless |
| Global server present, FQDN resolves, bare name does not | The name's domain is routed by `~cluster` but is not a search suffix | Add that domain plainly to `Domains=` |
| Nothing resolves, including external names | Wrong or unreachable server address | `dig @<ip> google.com` against each head node interface |

Test the head node directly, bypassing `resolved` entirely — if this works and `resolvectl` does not,
the problem is local configuration, not the server:

```
dig @10.40.112.2 ink50-dh01-d22-36.dgxnet01.cluster
```

## A renamed or re-addressed node still resolves to the old value

`Cache=yes` is doing its job; the record has not expired yet.

```
resolvectl flush-caches
```

If it comes back stale, the head node itself is serving the old record.

## `nodeset: Illegal group character: "*"`

`nodeset -ll` aborts and lists nothing.

The `sinfo` group source is returning state names with Slurm's flag characters attached — `idle*` for
an unreachable node, `idle~` for a powered-down one. Those characters are not legal in a ClusterShell
group name, and the error stops the whole listing, not just the offending group.

Check what `list` is actually producing:

```
sinfo -h -o "%T" | sort -u
```

Strip the flags in the `list` directive — see
[set-up-clush.md](set-up-clush.md#define-the-sinfo-group-source). The nodes themselves are not
affected; only the group name is.

## `clush: Group resolver error: Default group source not found: "sinfo"`

`default: sinfo` is set in `groups.conf`, but no source by that name was loaded.

Almost always the source file is in the wrong directory. It belongs in
`/etc/clustershell/groups.conf.d/` as a `*.conf` file. `/etc/clustershell/groups.d/` is a different
mechanism and reads only `*.yaml`, ignoring anything else without warning:

```
ls /etc/clustershell/groups.conf.d/ /etc/clustershell/groups.d/
```

## `clush -g <state>` runs but targets nothing

The command exits cleanly, having done nothing.

Groups are resolved by running `sinfo`, so if `sinfo` is broken every group is empty and `clush`
reports no error. Test the underlying command before debugging ClusterShell:

```
sinfo -h -o "%N" -t idle
```

If that is empty too, the problem is Slurm, not `clush` — work through the sections above. If it
returns nodes but `nodeset -g idle` does not, the group source is misconfigured.

## Getting more detail

Raise Slurm's client verbosity:

```
sinfo -vvv
```

Check munged's own logging:

```
journalctl -u munge -n 50
```
