# How to align local UIDs with the cluster

**Goal:** make local accounts numerically match the cluster's, so config parses and `squeue`
returns data.

Two accounts matter, for different reasons:

| Account | Why it must match |
|---|---|
| `slurm` (`SlurmUser`) | The name must resolve locally or config parsing fails outright |
| Your end user | `PrivateData=jobs` filters `squeue` output by UID; a mismatch returns an empty list with no error |

## Create the `slurm` service account

Read the cluster's numbers:

```
ssh <headnode> 'id slurm'
```

Confirm they are free locally — if either returns a row, stop and resolve the conflict first:

```
getent passwd 450; getent group 450
```

Create it, substituting your numbers:

```
groupadd -g 450 slurm
```

```
useradd -u 450 -g 450 -d /cm/local/apps/slurm -s /sbin/nologin slurm
```

For read-only client use the account only needs to exist. It needs no home directory contents, no
shell, and no password.

## Renumber an existing end user

Compare both sides:

```
ssh <headnode> 'id nvis'
```

```
id nvis
```

`usermod` refuses while the user owns running processes, so you cannot do this from that user's own
session — including via `sudo -s` from it. If you have no other route in, create a temporary admin
account first:

```
useradd -m -s /bin/bash -G sudo fixuser && passwd fixuser
```

If password login is disabled, copy the key over:

```
install -D -o fixuser -g fixuser -m 600 /home/nvis/.ssh/authorized_keys /home/fixuser/.ssh/authorized_keys
```

Open a **new SSH session as `fixuser`**, then renumber, substituting the cluster's numbers:

```
sudo pkill -KILL -u nvis
```

```
sudo groupmod -g 1001 nvis
```

```
sudo usermod -u 1001 -g 1001 nvis
```

```
sudo chown -R 1001:1001 /home/nvis
```

## Verify

Log back in as the user and check both the ID and the query:

```
id nvis && squeue
```

Then remove the temporary account:

```
userdel -r fixuser
```

## Notes

- `chown -R /home/nvis` fixes only the home directory. Files owned by the old UID elsewhere —
  `/var/tmp`, Docker volumes, mounted data dirs — keep the stale number and need the same treatment.
  Find them with `find / -xdev -uid 1000 2>/dev/null`.
- **Alternative to renumbering:** create a *second* local account at the cluster's UID. Slurm matches
  on UID, not username, so this satisfies `PrivateData` without disturbing the existing account.
- **Durable alternative:** join the node to BCM's LDAP/SSSD. Hand-matched UIDs drift as users are
  added to the cluster, and the failure mode is a silently empty `squeue` rather than an error.

## Related

- [add-cmods-user.md](add-cmods-user.md) — creating an account UID-aligned from the start, rather
  than renumbering it after the fact.
- [troubleshoot.md](troubleshoot.md) — `Invalid user for SlurmUser` and empty-`squeue` symptoms.
- [identity-and-environment.md](../explanation/identity-and-environment.md) — how `PrivateData` filtering works.
