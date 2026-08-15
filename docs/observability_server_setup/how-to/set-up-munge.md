# How to set up munge with the cluster's key

**Goal:** run a local munged that holds the same key as the cluster controller.

Slurm signs every RPC with munge. Without a matching key the controller rejects the client with
`Invalid credential`.

## Steps

Install munge from Ubuntu's repository — do not use a BCM munge package:

```
apt-get install -y munge
```

Find where the head node's munged reads its key. BCM overrides the default:

```
ssh <headnode> 'systemctl cat munge | grep -i key'
```

Copy that key to the local default path, with local ownership and strict permissions:

```
install -o munge -g munge -m 0400 /cm/shared/apps/slurm/var/munge/keys/munge.key /etc/munge/munge.key
```

Restart and test:

```
systemctl restart munge
```

```
munge -n | unmunge
```

`STATUS: Success (0)` means munged can read and use the key. `systemctl enable` is not needed —
the Ubuntu package enables the unit at install time.

## If the copy is denied

The key is typically mode `0400` owned by a non-root UID (often `1`/`daemon`). Root can only read
it if the export allows root. If `install` fails with permission denied, read it as the owning user:

```
runuser -u daemon -- cat /cm/shared/apps/slurm/var/munge/keys/munge.key > /etc/munge/munge.key
```

```
chown munge:munge /etc/munge/munge.key && chmod 0400 /etc/munge/munge.key
```

If that also fails, the export uses `root_squash` and has no route for that UID — copy from the head
node instead:

```
scp root@<headnode>:/cm/shared/apps/slurm/var/munge/keys/munge.key /tmp/munge.key
```

```
install -o munge -g munge -m 0400 /tmp/munge.key /etc/munge/munge.key && shred -u /tmp/munge.key
```

## Verify integrity

The key must be byte-identical. Compare hashes across nodes:

```
md5sum /etc/munge/munge.key
```

## Notes

| Point | Detail |
|---|---|
| Local `munge` UID | Does **not** need to match the head node's — only key bytes matter |
| Key size | Typically 1024 bytes; a truncated copy fails with confusing errors |
| Do not point `--key-file` at NFS | A `0400` file plus a mismatched local UID makes munged unable to read it at boot |
| Key is a credential | Anyone holding it can impersonate any user to the controller — treat the copy accordingly |

## Related

- [troubleshoot.md](troubleshoot.md) — distinguishing key mismatch from connectivity failure.
- [identity-and-environment.md](../explanation/identity-and-environment.md) — why the key is copied locally rather than read from NFS.
