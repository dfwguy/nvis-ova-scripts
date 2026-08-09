# How to set up SSH access to managed nodes

**Goal:** passwordless SSH from this host to every managed node, which is what `clush` needs to fan
out.

Home directories are exported over NFS from the head node, so a public key appended to
`~/.ssh/authorized_keys` there appears on every managed node at once. One key authorises the whole
cluster; there is nothing to copy per node.

## Generate a keypair on this host

Generate the key where it will be used, as the user who will use it. The private key then never
crosses the network and is never owned by anyone but its user:

```
ssh-keygen -t ed25519 -f ~/.ssh/id_bcm -N ""
```

Do not generate it on the head node. A key made there and read back over NFS has travelled the
network for no reason, and one made by root under a user's home is left root-owned — unreadable by
that user, failing silently at login.

## Authorise it on the cluster

Append the public key to the user's `authorized_keys` in the NFS-exported home. `ssh-copy-id` does
this and fixes permissions itself:

```
ssh-copy-id -i ~/.ssh/id_bcm.pub nvis@192.168.10.2
```

If password login to the head node is disabled, add the key to `~/.ssh/authorized_keys` there by
whatever route you do have, then confirm permissions — `sshd` ignores the file if it is group- or
world-writable:

```
ssh nvis@192.168.10.2 'chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys'
```

That single append is what reaches every managed node.

## Configure the client

In `~/.ssh/config` on this host:

```
Host bcm-hn bcm
  HostName 192.168.10.2
  User nvis
  IdentityFile ~/.ssh/id_bcm
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new

Host ink50-*
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
```

The two blocks deliberately differ, because the two kinds of host differ.

**The head node** has a stable identity worth verifying. `accept-new` records its key on first
connect without prompting, then keeps checking it — so a *changed* key still fails loudly, which is
the case that matters. `IdentitiesOnly yes` stops SSH offering every key the agent holds, which can
exhaust `MaxAuthTries` and fail before the right key is tried.

**Managed nodes** are reprovisioned and regenerate their host keys under the same name. To
`accept-new` that is indistinguishable from an impersonation attempt, so it would refuse to connect
and need a manual `known_hosts` edit after every reprovision. Discarding the record instead keeps
fan-out working:

| Option | Effect |
|---|---|
| `StrictHostKeyChecking no` | Accepts any host key without prompting |
| `UserKnownHostsFile /dev/null` | Records nothing, so a reprovisioned node never conflicts |
| `LogLevel ERROR` | Suppresses the "Permanently added" notices that would otherwise flood a fan-out |

This is a real trade: nothing detects a node being impersonated on that pattern. It is defensible on
a private management network and not elsewhere. Keep the `Host` pattern narrow — a bare `Host *`
would disable checking for every SSH connection from this account.

## Verify

Confirm the key reached a managed node by comparing the file it arrived in:

```
ssh bcm md5sum .ssh/authorized_keys
```

```
ssh <managed-node> md5sum .ssh/authorized_keys
```

The hashes must match. Then the fan-out itself:

```
clush -b -g idle hostname
```

## Related

- [set-up-clush.md](set-up-clush.md) — the consumer of this; `clush` is a wrapper around `ssh`.
- [set-up-dns.md](set-up-dns.md) — node names must resolve before any of this connects.
