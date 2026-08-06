# Reference: commands used

Copy-pasteable, in order. Substitute your own hostnames and version strings.

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

Bundle the administrator certificate:

```
tar czf /tmp/cm-certs.tgz -C /root/.cm admin.pem admin.key
```

## On the client

Fetch and unpack the bundles:

```
scp nscale-hn1:/tmp/cmsh-pkgs.tgz /tmp/ && cd /tmp && tar xzf cmsh-pkgs.tgz
```

```
mkdir -p ~/.cm && scp nscale-hn1:/tmp/cm-certs.tgz . && tar xzf cm-certs.tgz -C ~/.cm && chmod 600 ~/.cm/*
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
