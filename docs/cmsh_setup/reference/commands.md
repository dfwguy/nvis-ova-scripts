# Reference: commands used

Command catalog for the procedures in this guide. Substitute your own hostnames
and version strings. For the ordered first-time workflow, use the
[tutorial](../tutorial.md); this page is intentionally grouped by context rather
than sequence.

## On the headnode

Identify the package owning cmsh:

```
dpkg -S /cm/local/apps/cmd/bin/cmsh
```

Inspect version and dependencies:

```
apt show cmdaemon-cmsh | grep -E 'Version|Depends'
```

Download the recursive dependency set:

```
mkdir -p /tmp/cmsh-pkgs && cd /tmp/cmsh-pkgs
```

```
apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances cmdaemon-cmsh | grep '^\w' | sort -u)
```

Bundle the packages:

```
cd /tmp && tar czf cmsh-pkgs.tgz cmsh-pkgs
```

## On the client

Fetch and unpack the bundles:

```
scp nscale-hn1:/tmp/cmsh-pkgs.tgz /tmp/ && cd /tmp && tar xzf cmsh-pkgs.tgz
```

Install the dependency tree:

```
cd /tmp/cmsh-pkgs && sudo apt install ./*.deb
```

Configure anything left half-installed:

```
sudo dpkg --configure -a
```

Check what registered:

```
dpkg -l | grep -E 'cmdaemon|cm-config'
```

Place cmsh and cmdaemon files without running maintainer scripts:

```
sudo dpkg -x /tmp/cmsh-pkgs/cmdaemon-cmsh_11.0-164771-cm11.0-f6695c2d2a_amd64.deb / && sudo dpkg -x /tmp/cmsh-pkgs/cmdaemon_11.0-164771-cm11.0-f6695c2d2a_amd64.deb /
```

Verify reachability:

```
nc -zv nscale-hn1 8081
```

Verify library linkage:

```
ldd /cm/local/apps/cmd/bin/cmsh | grep 'not found'
```

Connect:

```
/cm/local/apps/cmd/bin/cmsh nscale-hn1
```

Install the convenience wrapper:

```
sudo tee /usr/local/bin/cmsh >/dev/null <<'EOF'
#!/bin/bash
exec /cm/local/apps/cmd/bin/cmsh "${@:-nscale-hn1}"
EOF
```

```
sudo chmod +x /usr/local/bin/cmsh
```

## Inside cmsh

Confirm the connection is live:

```
device list
```

## Credential files

cmsh reads a certificate and key from `~/.cm/`. Use the secure transfer and
per-user certificate guidance in [set up cmsh credentials](../how-to/set-up-cmsh-credentials.md)
instead of creating a `/tmp` archive containing a private key.
