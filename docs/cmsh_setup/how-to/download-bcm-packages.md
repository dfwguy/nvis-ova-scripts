# How to download BCM packages for an offline install

**Goal:** get `cmdaemon-cmsh` and every dependency onto a host that has no
access to the NVIDIA BCM repository.

## Procedure

On the headnode:

```
mkdir -p /tmp/cmsh-pkgs && cd /tmp/cmsh-pkgs
```

```
apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances cmdaemon-cmsh | grep '^\w' | sort -u)
```

```
cd /tmp && tar czf cmsh-pkgs.tgz cmsh-pkgs
```

Copy to the client:

```
scp /tmp/cmsh-pkgs.tgz <client>:/tmp/
```

## Verify before copying

```
ls /tmp/cmsh-pkgs/cmdaemon-cmsh_*.deb /tmp/cmsh-pkgs/cmdaemon_*.deb
```

If either is absent, the download failed and the rest of the process cannot
succeed.

Keep the tarball as the record of the downloaded BCM build. The recursive
bundle includes packages for mutually exclusive node roles, so follow
[Extract cmsh without installing it](extract-cmsh-without-installing.md) rather
than deleting dependencies from the bundle.

For why the repository stays on the managed node and why extraction is used,
see [Why `dpkg -x` instead of `apt install`](../explanation/why-dpkg-x.md).
