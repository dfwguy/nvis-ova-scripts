# How to resolve cluster hostnames through the BCM head node

Use this procedure when fully qualified or short compute-node names do not
resolve from the client.

## 1. Choose the DNS address

Test each reachable head-node interface and use the one that answers cluster
names reliably:

```console
dig @192.168.10.2 ink50-dh01-d22-36.dgxnet01.cluster
dig @10.40.112.2 ink50-dh01-d22-36.dgxnet01.cluster
```

## 2. Configure systemd-resolved

Create a drop-in using the selected address. Keep `~cluster` as the routing
domain and list only the search domains needed for short names:

```console
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/bcm.conf >/dev/null <<'EOF'
[Resolve]
DNS=10.40.112.2
Domains=~cluster dgxnet01.cluster eth.cluster
Cache=yes
EOF
sudo systemctl restart systemd-resolved
```

If every BCM network must support short names, obtain the domain list from a
host with `cmsh`:

```console
cmsh -c "network; list"
```

Confirm the domain column for the installed BCM version before extracting it.
For the version used here:

```console
cmsh -c "network; list" |
    awk 'NR>2 && $5 ~ /\./ {printf "%s ", $5}'
```

Add the result after `~cluster` in `Domains=` and restart
`systemd-resolved`.

## 3. Verify resolution

```console
resolvectl status
resolvectl query ink50-dh01-d22-36.dgxnet01.cluster
resolvectl query ink50-dh01-d22-36
```

If an old answer remains cached:

```console
sudo resolvectl flush-caches
```

Once ClusterShell is configured, verify the complete path:

```console
clush -b -g idle hostname
```

Keep the head node's controller aliases in `/etc/hosts`; resolving the DNS
server must not depend on that server already working.

For the choice of routing and search domains, see
[Why cluster DNS uses systemd-resolved](../explanation/dns-design.md). For
resolution failures, see [Troubleshoot a failing Slurm client](troubleshoot.md).
