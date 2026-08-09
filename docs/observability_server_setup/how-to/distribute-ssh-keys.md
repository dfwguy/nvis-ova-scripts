# How to give users SSH access to managed nodes

**Goal:** passwordless SSH from the head node to every managed node, which is what `clush` needs to
fan out.

Home directories are exported over NFS from the head node, so a key written to `~/.ssh` there appears
on every managed node automatically. One keypair per user covers the whole cluster; there is nothing
to copy per node.

## Generate a keypair

As the target user, on the head node:

```
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
```

## Authorise it

Because home is shared, the user's own public key in their own `authorized_keys` grants access to
every node. Print the append command first so you can read it before running it:

```
echo "echo '$(cat ~/.ssh/id_ed25519.pub)' >> ~/.ssh/authorized_keys"
```

Run that output, then fix permissions — `sshd` ignores the file if it is group- or world-writable:

```
chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
```

## Do it for several users at once

Run as root on the head node. The `chown` matters: files created by root under a user's home stay
root-owned, and a private key the user cannot read fails silently at login. The existence check
matters too — without it `ssh-keygen` stops to ask about overwriting and the loop hangs:

```
for u in user1 user2 user3; do
  install -d -o "$u" -g "$u" -m 700 "/home/$u/.ssh"
  [ -f "/home/$u/.ssh/id_ed25519" ] || \
    sudo -u "$u" ssh-keygen -t ed25519 -f "/home/$u/.ssh/id_ed25519" -N ""
  sudo -u "$u" sh -c "cat /home/$u/.ssh/id_ed25519.pub >> /home/$u/.ssh/authorized_keys"
  chmod 600 "/home/$u/.ssh/authorized_keys"
done
```

Running each step as the user via `sudo -u` gets the ownership right by construction rather than
repairing it afterwards.

## Skip host key prompts

A first connection to an unknown node prompts for confirmation, which blocks a `clush` fan-out.
Nodes are also reprovisioned regularly and regenerate their host keys, so tracking them is churn.
Turn it off for the cluster's nodes in `~/.ssh/config`:

```
Host ink50-*
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
```

| Option | Effect |
|---|---|
| `StrictHostKeyChecking no` | Accepts any host key without prompting |
| `UserKnownHostsFile /dev/null` | Records nothing, so a reprovisioned node never conflicts |
| `LogLevel ERROR` | Suppresses the "Permanently added" notices |

Keep the `Host` pattern narrow enough that it matches cluster nodes only — a bare `Host *` would
disable host key checking for every SSH connection from this account, including off-cluster ones.

## Verify

Confirm the key reached a managed node — the hashes must match:

```
md5sum ~/.ssh/authorized_keys && ssh <managed-node> md5sum ~/.ssh/authorized_keys
```

Then the fan-out itself:

```
clush -b -g idle hostname
```

## Related

- [set-up-clush.md](set-up-clush.md) — the consumer of this; `clush` is a wrapper around `ssh`.
- [set-up-dns.md](set-up-dns.md) — node names must resolve before any of this connects.
