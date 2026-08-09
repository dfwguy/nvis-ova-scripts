# How to add the `cmods` user to another node

**Goal:** create the `cmods` admin account on a new node with the same UID/GID as the head node, the
same SSH keys, and passwordless sudo.

This is the account-provisioning counterpart to [align-uids.md](align-uids.md). That guide renumbers
accounts that already exist; this one creates the account correctly the first time, which is always
the easier path.

Values below (`nscale-hn1`, UID/GID `1002`) are from one site. Substitute your own — step 1 tells you
how to find them.

## Steps

### 1. Read the head node's numbers

```
ssh nscale-hn1 'id cmods; getent passwd cmods'
```

Note the UID, GID, home directory, and shell. Everything that follows assumes `1002:1002` and
`/home/cmods`.

### 2. Confirm the numbers are free on the target

All three must return nothing. If any returns a row, resolve the conflict before continuing — see
[align-uids.md](align-uids.md) for renumbering an existing account.

```
getent passwd 1002; getent group 1002; getent passwd cmods
```

### 3. Create the group and user

```
groupadd -g 1002 cmods
```

```
useradd -m -u 1002 -g 1002 -s /bin/bash -c "CM Ops" cmods
```

No password is set. The account is key-only by design; leaving it passwordless means there is no
password to guess and no password to rotate.

### 4. Copy `authorized_keys` from the head node

The head node's `/home/cmods/.ssh` is mode `0700` and owned by `cmods`, so you generally cannot read
it over SSH as yourself. Read it under sudo on the head node and stage it locally:

```
ssh nscale-hn1 'sudo cat /home/cmods/.ssh/authorized_keys' > /tmp/cmods_authorized_keys
```

Install it with the correct ownership and modes in one step, then remove the staging copy:

```
install -d -o cmods -g cmods -m 0700 /home/cmods/.ssh
```

```
install -o cmods -g cmods -m 0600 /tmp/cmods_authorized_keys /home/cmods/.ssh/authorized_keys
```

```
rm -f /tmp/cmods_authorized_keys
```

`sshd` silently ignores `authorized_keys` if the file or its parent directory is group- or
world-writable. `install` sets the modes atomically, so there is no window where they are wrong.

### 5. Grant passwordless sudo

Use a drop-in file, never `/etc/sudoers` directly. A syntax error in `/etc/sudoers` locks every user
out of sudo; a bad drop-in is ignored with a warning.

```
echo 'cmods ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/cmods
```

```
chmod 0440 /etc/sudoers.d/cmods
```

```
visudo -c -f /etc/sudoers.d/cmods
```

`sudo` requires mode `0440` and ignores files whose names contain a `.` or end in `~`.

Membership in the `sudo` group is **not** required — the explicit rule is sufficient. Add it only if
you want the account to match other admins on the host:

```
usermod -aG sudo cmods
```

## Verify

From your workstation, in a **new** session. Keep your existing session open until this passes.

```
ssh cmods@<target-node> 'id; sudo -n true && echo "passwordless sudo OK"'
```

The `id` output must match step 1 exactly. `sudo -n` fails rather than prompting, so a hang means
something else is wrong.

Compare the key sets across both nodes:

```
ssh nscale-hn1 'sudo md5sum /home/cmods/.ssh/authorized_keys'; ssh <target-node> 'sudo md5sum /home/cmods/.ssh/authorized_keys'
```

## Notes

| Point | Detail |
|---|---|
| Shared home | If `/home/cmods` is on an NFS export rather than local disk, skip step 4 and mount instead — two copies of `authorized_keys` drift silently |
| Key rotation | A copied `authorized_keys` is a snapshot. Adding a key on the head node does not propagate; repeat step 4 or manage it with config management |
| `NOPASSWD:ALL` scope | Anyone holding a key in that file has unrestricted root on the node. Scope the rule to specific commands if the account only needs a few |
| Existing account | If `cmods` already exists at the wrong UID, do not delete and recreate — files elsewhere keep the stale number. See [align-uids.md](align-uids.md) |
| Durable alternative | Joining the node to BCM's LDAP/SSSD removes hand-matched UIDs and key copies entirely |

## Related

- [align-uids.md](align-uids.md) — renumbering accounts that already exist at the wrong UID.
- [reference.md](../reference.md) — the account table and how to discover each value.
