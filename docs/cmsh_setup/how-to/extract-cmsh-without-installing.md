# How to extract cmsh without installing it

**Goal:** place the `cmsh` binary and its BCM-side files on a non-BCM host
without running any package maintainer scripts.

Use this when `apt install ./*.deb` leaves `cmdaemon` and `cmdaemon-cmsh`
uninstalled, or when you want a guarantee that nothing on the host is
reconfigured.

## Procedure

First make sure the dependencies are properly installed and configured:

```
sudo dpkg --configure -a
```

Then unpack the two remaining packages into the filesystem root:

```
sudo dpkg -x /tmp/cmsh-pkgs/cmdaemon-cmsh_11.0-164771-cm11.0-f6695c2d2a_amd64.deb /
```

```
sudo dpkg -x /tmp/cmsh-pkgs/cmdaemon_11.0-164771-cm11.0-f6695c2d2a_amd64.deb /
```

Confirm the binary landed:

```
ls -l /cm/local/apps/cmd/bin/cmsh
```

Confirm nothing is missing at link time:

```
ldd /cm/local/apps/cmd/bin/cmsh | grep 'not found'
```

No output means you are done. Any line listed is a library to source — extract
the matching `cm-*` deb the same way, most likely `cm-openssl`, `cm-boost`, or
`cm-curl`.

Record the extracted BCM version and repeat this procedure after a head-node
upgrade. Dpkg does not track, upgrade, or remove files placed by `dpkg -x`.

For the reasons and maintenance trade-offs, see
[Why `dpkg -x` instead of `apt install`](../explanation/why-dpkg-x.md).
