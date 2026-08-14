# Tutorial: connect `cmsh` from a non-BCM host

By the end of this tutorial you will have a working `cmsh` prompt on a plain
Ubuntu server, connected to the BCM headnode, without that server being managed
by BCM.

**You will need**

- A plain Ubuntu 24.04 host (here: `network-server`) with `sudo`
- SSH access to the BCM 11.0 headnode (here: `nscale-hn1`)
- Network reachability to the headnode on TCP 8081
- About 15 minutes

**What you will not do:** turn this host into a BCM-managed node. Nothing is
registered, no daemon is started, no BCM provisioning takes place.

---

## Step 1 — Confirm which package owns cmsh

On the headnode:

```
dpkg -S /cm/local/apps/cmd/bin/cmsh
```

You should see `cmdaemon-cmsh`. Note the path is `bin`, not `sbin`.

Now look at what it needs:

```
apt show cmdaemon-cmsh | grep -E 'Version|Depends'
```

The version string (e.g. `11.0-164771-cm11.0-f6695c2d2a`) matters — the client
must match the headnode. The dependency list includes the full `cmdaemon`
package and `cm-config-cm`, which is why the next steps are careful.

## Step 2 — Download the packages on the headnode

The client has no BCM repo entitlement, so fetch everything where the repo works:

```
mkdir -p /tmp/cmsh-pkgs && cd /tmp/cmsh-pkgs
```

```
apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances cmdaemon-cmsh | grep '^\w' | sort -u)
```

```
cd /tmp && tar czf cmsh-pkgs.tgz cmsh-pkgs
```

## Step 3 — Copy packages and credentials to the client

On the client, prepare a private credentials directory:

```
mkdir -m 700 -p ~/.cm
```

Copy the package bundle from the headnode:

```
scp nscale-hn1:/tmp/cmsh-pkgs.tgz /tmp/ && cd /tmp && tar xzf cmsh-pkgs.tgz
```

Use your approved credential-issuance process to place a certificate and key in
this directory. Do not create an archive containing a private key under `/tmp`.
If direct SSH transfer is permitted, an administrator on the headnode can copy
the pair directly to the intended client account over the encrypted connection:

```
scp /root/.cm/<user>.pem /root/.cm/<user>.key <client-user>@network-server:.cm/
```

On the client, restrict the files:

```
chmod 600 ~/.cm/*.pem ~/.cm/*.key
```

For a shared host, use a scoped per-user certificate rather than copying the
headnode administrator certificate. See [set up cmsh credentials](how-to/set-up-cmsh-credentials.md).

## Step 4 — Install the dependencies

```
cd /tmp/cmsh-pkgs && sudo apt install ./*.deb
```

This installs most of the tree and then stops short of `cmdaemon` and
`cmdaemon-cmsh`. That is expected — the bundle contains packages that conflict
with each other, so apt refuses the final part of the transaction. Finish
configuring what did unpack:

```
sudo dpkg --configure -a
```

Check the result:

```
dpkg -l | grep -E 'cmdaemon|cm-config'
```

`cmdaemon` and `cmdaemon-cmsh` will be absent. The rest should show `ii`.

## Step 5 — Unpack cmsh itself

Rather than fight the packaging, place the files directly:

```
sudo dpkg -x /tmp/cmsh-pkgs/cmdaemon-cmsh_11.0-164771-cm11.0-f6695c2d2a_amd64.deb / && sudo dpkg -x /tmp/cmsh-pkgs/cmdaemon_11.0-164771-cm11.0-f6695c2d2a_amd64.deb /
```

`dpkg -x` copies files and runs no maintainer scripts, so no daemon is started
and no system config is rewritten. See
[why dpkg -x](explanation/why-dpkg-x.md) for the reasoning.

## Step 6 — Verify the link and connect

```
nc -zv nscale-hn1 8081
```

You should see `succeeded!`. Then:

```
/cm/local/apps/cmd/bin/cmsh nscale-hn1
```

At the prompt, prove you are really talking to the cluster:

```
device list
```

Seeing the cluster's nodes means the client is fully working.

## Step 7 — Make it convenient

```
sudo tee /usr/local/bin/cmsh >/dev/null <<'EOF'
#!/bin/bash
exec /cm/local/apps/cmd/bin/cmsh "${@:-nscale-hn1}"
EOF
```

```
sudo chmod +x /usr/local/bin/cmsh
```

Now a bare `cmsh` connects to the headnode, and `cmsh <other-host>` still works.

## What you built

A file-level install of the cmsh binary plus a properly packaged dependency
tree, authenticating to CMDaemon over TLS on port 8081 with a copied
administrator certificate. Next: read
[version parity](explanation/version-parity.md), because a BCM upgrade on the
headnode will break this until you repeat steps 2–5.
