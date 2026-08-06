# How to set up cmsh credentials

**Goal:** give a user on the client host the certificate pair that CMDaemon will
accept.

cmsh does not use a password. It presents an X.509 client certificate over TLS,
and CMDaemon maps that certificate to a management profile.

## Quick path (administrator certificate)

On the headnode:

```
tar czf /tmp/cm-certs.tgz -C /root/.cm admin.pem admin.key
```

On the client, as the user who will run cmsh:

```
mkdir -p ~/.cm && scp nscale-hn1:/tmp/cm-certs.tgz . && tar xzf cm-certs.tgz -C ~/.cm && chmod 600 ~/.cm/*
```

Verify:

```
ls -l ~/.cm/
```

You should see `admin.pem` and `admin.key`, mode `600`, owned by you. cmsh reads
`$HOME/.cm/` by default, so no flags are needed after this.

Remove the tarball from `/tmp` on both hosts when finished — it contains a
private key.

## Preferred path for shared hosts

Copying the root administrator certificate gives every holder full cluster
control, and all actions appear in the CMDaemon log as the same identity. On a
host with more than one user, issue a per-user certificate from a cmsh session on
the headnode instead, under `cert` mode, bound to a suitable profile (for example
a read-only profile for monitoring users).

> **VERIFY** — record the exact `cert` mode commands used for your site, or note
> that only the shared admin cert is in use today.

## Server verification

The client also needs to trust the headnode's CA:

```
scp nscale-hn1:/cm/local/apps/cmd/etc/cacert.pem /tmp/
```

```
sudo mkdir -p /cm/local/apps/cmd/etc && sudo cp /tmp/cacert.pem /cm/local/apps/cmd/etc/cacert.pem
```

> **VERIFY** — on this build, connection succeeded without a separately placed
> `cacert.pem` (the `dpkg -x` of `cmdaemon` may have supplied it). Confirm
> whether the file exists at that path on `network-server`, so the docs state
> whether this step is required or optional.

## Per-user checklist

- Each user needs their own `~/.cm/` pair; the shared `/usr/local/bin/cmsh`
  wrapper does not provide credentials.
- Do not run cmsh with `sudo` unless the certs are in root's home — `sudo`
  changes `$HOME` and cmsh will not find them.
