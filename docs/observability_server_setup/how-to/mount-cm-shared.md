# How to mount the head node's NFS exports

**Goal:** make the head node's `/cm/shared` and `/cluster` available at identical local paths,
persistently.

`/cm/shared` carries BCM's config and is read-only in practice. `/cluster` is the shared working
directory — it is where scripts, data, and anything you produce should live, so that every node sees
the same thing.

## Mount `/cm/shared`

The path must match exactly. `slurm.conf` and BCM's module files contain absolute paths under
`/cm/shared`, so mounting it anywhere else breaks them.

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

Verify:

```
ls /cm/shared/apps/slurm/
```

Expect `etc`, `var`, `statesave`, `prologs`, `epilogs`. A `bin` or `current` entry would mean your
site *does* export binaries — in that case skip
[install-slurm-binaries.md](install-slurm-binaries.md) and just add
`/cm/shared/apps/slurm/current/bin` to PATH.

## Mount `/cluster`

`/cluster` is a separate export from the same head node, and is the shared working directory. Mount
it at the same path everywhere, for the same reason as `/cm/shared`: a script that refers to
`/cluster/...` has to mean the same thing on every node.

```
mkdir -p /cluster
```

```
echo '192.168.10.2:/cluster  /cluster  nfs  defaults,_netdev  0 0' >> /etc/fstab
```

```
mount -a
```

Verify, and check the mode while you are there:

```
mountpoint /cluster && ls -ld /cluster
```

## Make `/cluster` writable

`/cluster` must be world-writable, or writes succeed for some users and fail for others depending on
which group the directory happens to be owned by. Set it **on the head node**, not here — NFS serves
the mode from the server, so a `chmod` on a mounted path is either useless or changes it for
everyone:

```
chmod 1777 /cluster
```

The leading `1` is the sticky bit, and is what makes `777` tolerable: it restricts deleting and
renaming a file to that file's owner. Plain `0777` lets any user remove anyone else's work. `1777`
is what `/tmp` uses, and there is no reason to use the weaker mode here.

## Work from `/cluster`

Put shared scripts and data under `/cluster` rather than in a home directory or `/cm/shared`. Home
directories are also NFS-exported, but they are per-user; `/cm/shared` belongs to BCM and its
contents are replaced on upgrade. `/cluster` is the only one of the three that is both shared and
yours.

This matters most with `clush`: a command that reads or writes a local path runs against a different
filesystem on each node, so results are per-node and easy to misread as cluster-wide. Referring to
`/cluster` gives every node the same file.

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
