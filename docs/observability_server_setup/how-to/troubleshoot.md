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

## Getting more detail

Raise Slurm's client verbosity:

```
sinfo -vvv
```

Check munged's own logging:

```
journalctl -u munge -n 50
```
