# How to set up the shared filesystems

**Goal:** `/cm/shared` and `/cluster` available at identical paths across the cluster, persistently.

The two come from different places and are not interchangeable:

| Share | Exported by | Holds |
|---|---|---|
| `/cm/shared` | BCM head node | BCM's own config, modules, and Slurm state — mounted, not written to |
| `/cluster` | The slogin or observability node | Everything we produce: scripts, data, working files |

`/cluster` deliberately does not live on the head node. The head node runs BCM and Slurm and serves
what BCM provisions; nothing of ours belongs there, since it is upgraded and reprovisioned on BCM's
schedule rather than ours.

## Mount `/cm/shared`

The path must match exactly. `slurm.conf` and BCM's module files contain absolute paths under
`/cm/shared`, so mounting it anywhere else breaks them.

Create the mount point:

```
mkdir -p /cm/shared
```

Add a persistent entry, substituting your head node's address:

```
echo '<headnode>:/cm/shared  /cm/shared  nfs  defaults,_netdev  0 0' >> /etc/fstab
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

## Export `/cluster`

Do this on whichever host serves it — the slogin or observability node, not the head node. The mode
matters as much as the export: `/cluster` must be world-writable, or writes succeed for some users
and fail for others depending on which group the directory happens to be owned by.

```
mkdir -p /cluster && chmod 1777 /cluster
```

The leading `1` is the sticky bit, and is what makes `777` tolerable: it restricts deleting and
renaming a file to that file's owner. Plain `0777` lets any user remove anyone else's work. `1777`
is what `/tmp` uses, and there is no reason to use the weaker mode here.

Export it to the cluster's subnet, substituting your own range:

```
echo '/cluster  <subnet>/<prefix>(rw,sync,no_subtree_check)' >> /etc/exports
```

```
exportfs -ra && exportfs -v
```

`no_root_squash` is deliberately absent. Adding it would let root on any client write to `/cluster`
as root, which is a large amount of trust to extend to every node for the sake of a shared scratch
directory.

## Mount `/cluster` on the clients

On every other host, at the same path — a script that refers to `/cluster/...` has to mean the same
thing everywhere:

```
mkdir -p /cluster
```

```
echo '<slogin-or-obs-node>:/cluster  /cluster  nfs  defaults,_netdev  0 0' >> /etc/fstab
```

```
mount -a
```

Verify, and check the mode came through:

```
mountpoint /cluster && ls -ld /cluster
```

Expect `drwxrwxrwt`. If it is not world-writable here, fix it on the exporting host — NFS serves the
mode from the server, so a local `chmod` on a mounted path is either useless or changes it for
everyone.

## Work from `/cluster`

Put shared scripts and data under `/cluster` rather than in a home directory or `/cm/shared`. Home
directories are per-user, and `/cm/shared` belongs to BCM — it is replaced on upgrade, and writing
there means our files are subject to BCM's provisioning cycle. `/cluster` is the only share that is
both cluster-wide and ours.

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
- [client-only-slurm-node.md](../explanation/client-only-slurm-node.md) — why `/cm/shared` holds config but not binaries.
