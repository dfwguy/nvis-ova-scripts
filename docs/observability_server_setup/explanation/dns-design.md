# Why cluster DNS uses systemd-resolved

Ubuntu manages `/etc/resolv.conf` through `systemd-resolved`, netplan, and often
DHCP. A drop-in under `/etc/systemd/resolved.conf.d` works with that ownership
model and survives reboot and package upgrades.

## Routing domains and search domains

A routing domain such as `~cluster` selects the DNS server for fully qualified
names below `.cluster`. It does not alter a bare hostname.

A search domain such as `dgxnet01.cluster` is appended to bare hostnames. Long
search lists create sequential failed queries and must be updated as BCM adds
networks. Use `~cluster` for coverage and add only the search domains needed for
short names.

## Keep the head node in `/etc/hosts`

The head node provides cluster DNS. Resolving the DNS server through its own
service creates a bootstrap dependency, so the head node's controller aliases
should remain locally resolvable through `/etc/hosts`.

Local caching is useful for `clush`, which can resolve hundreds of targets at
once. It also means renamed or re-addressed nodes may require a cache flush
before the change is visible.
