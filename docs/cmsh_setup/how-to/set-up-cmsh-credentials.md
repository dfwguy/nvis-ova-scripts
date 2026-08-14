# How to set up cmsh credentials

**Goal:** give a user on the client host the certificate pair that CMDaemon will
accept.

cmsh does not use a password. It presents an X.509 client certificate over TLS,
and CMDaemon maps that certificate to a management profile.

## Transfer a certificate securely

Create the receiving directory as the user who will run `cmsh`:

```
mkdir -m 700 -p ~/.cm
```

Use your site's approved certificate-issuance process to provide a certificate
and key. If direct SSH transfer is permitted, an administrator on the headnode
can copy a pair directly to that account:

```
scp /root/.cm/<user>.pem /root/.cm/<user>.key <client-user>@network-server:.cm/
```

On the client, restrict and verify the files:

```
chmod 600 ~/.cm/*.pem ~/.cm/*.key
ls -ld ~/.cm && ls -l ~/.cm/
```

The directory should be mode `0700`; the certificate and key should be mode
`0600`, owned by the intended user. cmsh reads `$HOME/.cm/` by default, so no
flags are needed after this. Do not place a private key in `/tmp`, including in
a tarball: a typical `/tmp` archive is readable by other local users.

## Preferred path for shared hosts

Copying the root administrator certificate gives every holder full cluster
control, and all actions appear in the CMDaemon log as the same identity. Issue
a per-user certificate from `cmsh`'s `cert` mode on the headnode, bound to the
smallest suitable profile (for example, a read-only monitoring profile). Keep
the site-specific issuance commands with the cluster's access-control runbook;
they depend on its configured profiles and CA.

## Server verification

The client also needs to trust the headnode's CA:

First check whether extracting `cmdaemon` already installed it:

```
test -r /cm/local/apps/cmd/etc/cacert.pem && echo 'CA certificate present'
```

If it is absent, copy the public CA certificate from the headnode and install it
at that path. The CA certificate is not secret, but copy it with `sudo install`
so ownership and permissions are explicit:

```
scp nscale-hn1:/cm/local/apps/cmd/etc/cacert.pem /tmp/cacert.pem
sudo install -D -o root -g root -m 0644 /tmp/cacert.pem /cm/local/apps/cmd/etc/cacert.pem
rm -f /tmp/cacert.pem
```

## Per-user checklist

- Each user needs their own `~/.cm/` pair; the shared `/usr/local/bin/cmsh`
  wrapper does not provide credentials.
- Do not run cmsh with `sudo` unless the certs are in root's home — `sudo`
  changes `$HOME` and cmsh will not find them.
