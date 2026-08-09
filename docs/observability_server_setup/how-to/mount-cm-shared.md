# How to mount the BCM `/cm/shared` export

**Goal:** make the head node's `/cm/shared` available at the identical local path, persistently.

The path must match exactly. `slurm.conf` and BCM's module files contain absolute paths under
`/cm/shared`, so mounting it anywhere else breaks them.

## Steps

Create the mount point:

```
mkdir -p /cm/shared
```

Add a persistent entry, substituting your head node's IP:

```
echo '192.168.10.2:/cm/shared  /cm/shared  nfs  defaults,_netdev  0 0' >> /etc/fstab
```

Mount it:

```
mount -a
```

## Verify

```
ls /cm/shared/apps/slurm/
```

Expect `etc`, `var`, `statesave`, `prologs`, `epilogs`. A `bin` or `current` entry would mean your
site *does* export binaries — in that case skip
[install-slurm-binaries.md](install-slurm-binaries.md) and just add
`/cm/shared/apps/slurm/current/bin` to PATH.

## Shared writable space

`/cm/shared` holds BCM's own config and is not a place to put your files. For scratch shared across
nodes, sites commonly export a separate `/cluster`. It needs to be world-writable, or writes fail
for some users and not others depending on which group the directory happens to be owned by:

```
chmod 1777 /cluster
```

Set this on the exporting node, not the client — NFS serves the mode from the server, so a local
`chmod` on a mounted path either does nothing or changes it for everyone.

The leading `1` is the sticky bit, and is what makes `777` safe to live with: it restricts deleting
and renaming a file to that file's owner. Plain `0777` lets any user remove anyone else's work.
`1777` is what `/tmp` uses, and there is no reason to use the weaker mode here.

## Notes

- `_netdev` tells systemd this mount depends on the network, preventing a boot-time hang or a
  silently empty directory.
- If `mount -a` reports `access denied by server`, the export list on the head node does not include
  this client's IP. That is fixed in BCM on the head node (`/etc/exports` or via cmsh), not here.
- If `mount.nfs: No such device`, install the client package:

```
apt-get install -y nfs-common
```

## Related

- [set-up-munge.md](set-up-munge.md) — the munge key may live on this share.
- [explanation.md](../explanation.md) — why `/cm/shared` holds config but not binaries.
