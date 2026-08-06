# How to download BCM packages for an offline install

**Goal:** get `cmdaemon-cmsh` and every dependency onto a host that has no
access to the NVIDIA BCM repository.

## Why not just add the repo

The BCM apt repo authenticates with the headnode's entitlement certificate
(`/cm/local/apps/cmd/etc/cert.pem` and `cert.key`, referenced from
`/etc/apt/apt.conf.d/`). Copying that config to another host works, but it
spreads the entitlement credential further than necessary. Downloading on the
headnode avoids that.

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

## Things to know about the result

- The recursive walk pulls in both `cm-master` and `cm-slave`, which are
  mutually exclusive roles. This is what makes the later `apt install ./*.deb`
  stop short. Do not try to fix it by deleting debs at random — see
  [why dpkg -x](../explanation/why-dpkg-x.md).
- It also pulls base packages the client already has (`dpkg`, `perl`, `passwd`).
  Harmless; apt skips same-version packages.
- `net-snmp-recent` and the `cm-*` libraries exist only in the BCM repo. If the
  bundle is missing them, nothing downstream will configure.
- The `.deb` filenames contain the exact build string
  (`11.0-164771-cm11.0-f6695c2d2a`). Keep the tarball — it is the only local
  record of that build if the repo moves on.

## Verify before copying

```
ls /tmp/cmsh-pkgs/cmdaemon-cmsh_*.deb /tmp/cmsh-pkgs/cmdaemon_*.deb
```

If either is absent, the download failed and the rest of the process cannot
succeed.
