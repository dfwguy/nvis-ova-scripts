# Tutorial: Make a standalone host into a Slurm client

By the end of this tutorial you will run `sinfo` and `squeue` on a host that is not part of the
BCM cluster, and see the same output the head node sees.

**Time:** about 30 minutes.

## What you need before starting

- Root (or full `sudo`) on the client host, running Ubuntu 24.04.
- Network reachability to the head node on the cluster network.
- Root on the head node, to download BCM packages to `/cluster/dpkg/`.
- Shell access to the head node, to read UIDs and config.
- The head node's IP and hostname. This tutorial uses `nscale-hn1` at `192.168.10.2`.

> **A note on the shape of this problem.** Slurm clients need four things: the binaries, the
> config, a munge key shared with the controller, and matching UIDs. BCM scatters these across a
> local path, an NFS export, and its own package repository. Most of this tutorial is collecting
> them.

## Step 1: Mount the shared filesystem

The cluster's Slurm configuration lives on the head node's `/cm/shared` export. Mount it at the
same path locally, because paths inside `slurm.conf` are absolute.

Create the mount point and add a permanent entry:

```
mkdir -p /cm/shared
```

```
echo '192.168.10.2:/cm/shared  /cm/shared  nfs  defaults,_netdev  0 0' >> /etc/fstab
```

```
mount -a
```

Check that it worked:

```
ls /cm/shared/apps/slurm/
```

You should see directories including `etc` and `var`. Note what is **not** there: no `bin`, no
version directory, no `current` symlink. The binaries are not on this share — that is Step 3.

## Step 2: Install munge and the cluster's key

Slurm authenticates every RPC with munge. The client and the controller must hold a byte-identical
key. Install munge from Ubuntu's own repository:

```
apt-get install -y munge
```

Find where the head node's munged reads its key from — BCM does not use the default location:

```
ssh nscale-hn1 'systemctl cat munge | grep -i key'
```

At this site the answer is `/cm/shared/apps/slurm/var/munge/keys/munge.key`, which you already have
mounted. Copy it to the local default path with local ownership:

```
install -o munge -g munge -m 0400 /cm/shared/apps/slurm/var/munge/keys/munge.key /etc/munge/munge.key
```

Restart munged and prove the key works:

```
systemctl restart munge
```

```
munge -n | unmunge
```

A `STATUS: Success (0)` line means munge is healthy. This is a purely local test — it does not yet
prove the key matches the controller's, only that munged can read and use it.

## Step 3: Get the Slurm binaries onto the node

BCM's package repository requires credentials. Download the `.deb` as root on the head node into
the shared staging area:

```
cd /cluster/dpkg && apt-get download slurm25.05
```

Back on the observability node, the obvious install move fails — try it so you recognise the error
later:

```
apt-get install -y /cluster/dpkg/slurm25.05_25.05.8-101099-cm11.0-a3a58b4841_amd64.deb
```

apt refuses because the package depends on `cm-pmix4-local`, `cm-ucx-local`, `cm-hwloc2-local`, and
`cm-config-cm` — all of which live in BCM's repository, which this node is not subscribed to.

The client tools do not actually need those. Unpack the archive directly, bypassing dependency
resolution and the dpkg database:

```
dpkg -x /cluster/dpkg/slurm25.05_25.05.8-101099-cm11.0-a3a58b4841_amd64.deb /
```

Verify nothing is missing at the linker level:

```
ldd /cm/local/apps/slurm/25.05/bin/sinfo | grep 'not found'
```

Empty output is what you want. `sinfo` links only against `libslurmfull.so` (found via RPATH inside
the package) plus base glibc — none of the MPI or hwloc libraries the metadata demanded.

## Step 4: Create the `slurm` service account

Point your shell at the binaries and the shared config, then run `sinfo`:

```
export PATH=/cm/local/apps/slurm/25.05/bin:$PATH
```

```
export SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf
```

```
sinfo
```

It fails: `Invalid user for SlurmUser slurm`. The config names a `SlurmUser` that must resolve
locally, even for read-only commands. Get the cluster's numbers:

```
ssh nscale-hn1 'id slurm'
```

At this site, uid and gid are both `450`. Confirm they are free locally, then create the account:

```
getent passwd 450; getent group 450
```

```
groupadd -g 450 slurm
```

```
useradd -u 450 -g 450 -d /cm/local/apps/slurm -s /sbin/nologin slurm
```

## Step 5: Make the controller reachable by name

Run `sinfo` again. The error changes to `Unable to contact slurm controller (connect failure)` —
progress: the config now parses. Look at what it is trying to reach:

```
grep -Ei 'SlurmctldHost|SlurmctldPort|AccountingStorageHost' /cm/shared/apps/slurm/etc/slurm/slurm.conf
```

It wants `nscale-hn1` on port 6817, and `master` for accounting. Neither name resolves here, so add
both — `master` is BCM's internal alias for the same head node:

```
printf '192.168.10.2\tnscale-hn1 master\n' >> /etc/hosts
```

Confirm resolution and reachability:

```
nc -vz nscale-hn1 6817
```

```
sinfo
```

You should now get the full partition and node listing. Munge's key matched — if it hadn't, you'd
see `Invalid credential` rather than node states.

## Step 6: Match your user's UID to the cluster's

Run `squeue` as your normal user. It returns a header and no rows, even though the head node shows
several pending jobs. There is no error, which is the confusing part.

The cause is in the config:

```
grep -i PrivateData /cm/shared/apps/slurm/etc/slurm/slurm.conf
```

`PrivateData=accounts,users,jobs,reservations` means `squeue` shows only jobs whose owner UID
matches the caller's. Your local account has a different UID than the cluster's, so it matches
nothing and the filter silently returns an empty set.

Compare the two:

```
ssh nscale-hn1 'id nvis'
```

```
id nvis
```

At this site the cluster has `1001` and the client has `1000`. Fixing this requires killing the
user's processes, so you cannot do it from that user's own session. Create a temporary account:

```
useradd -m -s /bin/bash -G sudo fixuser && passwd fixuser
```

Log in over SSH **as `fixuser`**, then renumber:

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

Log back in as `nvis` and confirm:

```
id nvis && squeue
```

You should now see the cluster's pending jobs. Remove the temporary account from a `fixuser`
session, or from root:

```
userdel -r fixuser
```

## Step 7: Make it survive a reboot and work under sudo

Your working setup so far depends on two exported variables in one shell. Fix both properly.

Write a login-shell profile script:

```
printf 'export PATH=/cm/local/apps/slurm/25.05/bin:$PATH\nexport SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf\n' > /etc/profile.d/slurm.sh
```

```
chmod 0644 /etc/profile.d/slurm.sh
```

Symlink the config to the path Slurm checks by default, so `SLURM_CONF` is not required at all:

```
mkdir -p /etc/slurm
```

```
ln -sfn /cm/shared/apps/slurm/etc/slurm/slurm.conf /etc/slurm/slurm.conf
```

Give `sudo` the binaries, since it discards your PATH in favour of its own `secure_path`:

```
echo 'Defaults secure_path="/cm/local/apps/slurm/25.05/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' > /etc/sudoers.d/slurm-path
```

```
chmod 0440 /etc/sudoers.d/slurm-path
```

Verify all three paths work — clean login shell, sudo, and non-login shell:

```
su - nvis -c 'sinfo | head -3' && sudo sinfo | head -3 && env -i /cm/local/apps/slurm/25.05/bin/sinfo | head -3
```

## What you built

- A client that reads config and the munge key from NFS, runs binaries from a locally-unpacked
  BCM package, and authenticates as a UID the controller recognises.
- No `slurmd`, no BCM management, no scheduling participation.

## Where to go next

- [How a client-only Slurm node works](explanation/client-only-slurm-node.md) — why BCM splits
  `/cm/local` from `/cm/shared`.
- [Munge, UIDs, and non-interactive environments](explanation/identity-and-environment.md) — why
  the munge key is copied rather than read in place.
- [how-to/troubleshoot.md](how-to/troubleshoot.md) — mapping each error message to its cause.
- [how-to/set-up-dns.md](how-to/set-up-dns.md) — resolve cluster node names, needed before you can
  reach any node by name.
- [how-to/set-up-clush.md](how-to/set-up-clush.md) — now that `sinfo` works, use it to drive
  `clush` fan-out across nodes grouped by Slurm state.
- Consider joining the node to BCM's LDAP/SSSD instead of hand-matching UIDs, if more than one or
  two users will need this host. Manual UID matching does not scale and drifts silently.
