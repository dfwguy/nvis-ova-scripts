# How to resolve cluster hostnames via the BCM head node

**Goal:** resolve BCM-provisioned node names — both fully qualified (`ink50-dh01-d22-36.dgxnet01.cluster`)
and bare (`ink50-dh01-d22-36`) — by forwarding queries to the head node's DNS.

Without this, `/etc/hosts` is the only name source on the host, which covers the head node and
nothing else. `clush` in particular becomes unusable, since `sinfo` returns node names that must
resolve before SSH can reach them.

## Choose which head node interface to use

BCM head nodes are typically multi-homed and answer DNS on more than one address. Both work; they do
not perform the same. Time each before committing:

```
dig @192.168.10.2 google.com | grep 'Query time'
```

```
dig @10.40.112.2 google.com | grep 'Query time'
```

At this site the bonded interface answered in ~1 ms against ~22 ms for the management interface, so
the bonded address is the one configured below. Use whichever is faster on your network, and confirm
it answers for cluster names as well as external ones.

## Write the drop-in

Ubuntu 24.04 resolves through `systemd-resolved`. Configure it with a drop-in rather than by editing
`/etc/systemd/resolved.conf` or `/etc/resolv.conf` — see [Notes](#notes):

```
sudo mkdir -p /etc/systemd/resolved.conf.d
```

```
sudo tee /etc/systemd/resolved.conf.d/bcm.conf > /dev/null << 'EOF'
[Resolve]
DNS=10.40.112.2
Domains=~cluster dgxnet01.cluster eth.cluster
Cache=yes
EOF
```

| Key | Effect |
|---|---|
| `DNS` | Where queries go |
| `~cluster` | *Routing* domain — sends every `*.cluster` lookup to this server, without adding a search suffix |
| `dgxnet01.cluster eth.cluster` | *Search* domains — suffixes appended to bare hostnames, tried in order |
| `Cache=yes` | Answers served locally on repeat |

Apply it:

```
sudo systemctl restart systemd-resolved
```

## Decide how many search domains you need

The distinction above is what keeps this file maintainable. A leading `~` makes a domain
routing-only: it tells the resolver *where to ask* for names under `.cluster`, and one such entry
covers every network BCM will ever provision. A plain entry additionally makes the domain a search
suffix, which is only useful for names you type without a suffix.

Listing all 29 `dgxnetNN.cluster` domains as search suffixes works, and is what this site started
with. The costs are that the list must be updated whenever BCM gains a network, and that a bare
hostname triggers up to 29 sequential queries before failing. Add a plain entry only for the networks
whose nodes you actually address by short name; leave the rest to `~cluster`.

If you do want every domain listed, generate the list rather than transcribing it — see below.

## Regenerate the domain list from BCM

The authoritative list is BCM's own network objects, each of which carries a domain name. From a host
with `cmsh` ([../../cmsh_setup/](../../cmsh_setup/)):

```
cmsh -c "network; list"
```

Confirm which column holds the domain name in your BCM version before scripting against it, then
extract it. On the version used here the domain is the fifth column:

```
cmsh -c "network; list" | awk 'NR>2 && $5 ~ /\./ {printf "%s ", $5}'
```

Paste the result into `Domains=`, keeping `~cluster` first.

## Verify

Check that the drop-in took effect and note which link the server is attached to:

```
resolvectl status
```

Resolve a fully qualified name, which exercises the `~cluster` route:

```
resolvectl query ink50-dh01-d22-36.dgxnet01.cluster
```

Resolve a bare name, which exercises the search list:

```
resolvectl query ink50-dh01-d22-36
```

Confirm the cache is being used — run the same query twice and watch the hit counter:

```
resolvectl statistics | grep -A3 Cache
```

Finally, the end-to-end test that matters, once `clush` is set up:

```
clush -b -g idle hostname
```

## Notes

- **Do not edit `/etc/resolv.conf`.** On Ubuntu 24.04 it is a symlink into `/run/systemd/resolve/`
  and is regenerated; edits vanish on restart. Drop-ins under `/etc/systemd/resolved.conf.d/` also
  survive package upgrades, which edits to `/etc/systemd/resolved.conf` do not.
- **Link-specific DNS wins over global DNS.** The `DNS=` above is a *global* setting. If netplan or
  DHCP supplies a nameserver on the active interface, that per-link server is preferred for ordinary
  queries and the head node may never be consulted. `resolvectl status` shows both; if the link has
  its own `DNS Servers` entry and lookups still fail, move the configuration into netplan for that
  interface instead. The `~cluster` routing domain is unaffected — routing domains are honoured
  regardless — which is another reason to prefer it over a bare search list.
- **`/etc/hosts` still wins over DNS**, and still needs its entry for the head node. Resolving the
  head node must not depend on the head node. Leave those lines in place.
- **No AAAA suppression.** `systemd-resolved` cannot be told to skip IPv6 lookups. If duplicate AAAA
  queries against BCM become a problem, the workaround is `dnsmasq` with `no-aaaa` in front of it —
  a larger change than it sounds, since it means taking `resolved` out of the resolution path.
- **Caching hides changes.** A node renamed or re-addressed in BCM stays wrong locally until the TTL
  expires. Force it:

```
resolvectl flush-caches
```

## Related

- [set-up-clush.md](set-up-clush.md) — the main consumer of this; `clush` cannot reach a node whose
  name does not resolve.
- [../reference.md](../reference.md) — the DNS values used at this site.
- [../explanation.md](../explanation.md) — why the resolver is configured rather than replaced.
- [troubleshoot.md](troubleshoot.md) — resolution failures and the link-versus-global trap.
