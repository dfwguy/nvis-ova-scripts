# How to make cmsh permanent and convenient

**Goal:** type `cmsh` with no path and no hostname.

## Option A — wrapper with a default headnode (recommended)

```
sudo tee /usr/local/bin/cmsh >/dev/null <<'EOF'
#!/bin/bash
exec /cm/local/apps/cmd/bin/cmsh "${@:-nscale-hn1}"
EOF
```

```
sudo chmod +x /usr/local/bin/cmsh
```

`/usr/local/bin` is already on the default PATH, so this takes effect
immediately for all users with no re-login. `${@:-nscale-hn1}` means a bare
`cmsh` targets the headnode while `cmsh <other-host>` still passes through.

## Option B — PATH only

Use this if you want no default hostname:

```
echo 'export PATH=$PATH:/cm/local/apps/cmd/bin' | sudo tee /etc/profile.d/cmsh.sh
```

Takes effect on next login shell. You must still supply the hostname each time.

## Name resolution

If the client does not use cluster DNS, add the headnode so the wrapper works for
everyone:

```
echo '192.168.10.2 nscale-hn1' | sudo tee -a /etc/hosts
```

Check before adding a static entry:

```
getent hosts nscale-hn1
```

If this returns an address, DNS already provides the name and no `/etc/hosts`
entry is needed.

## Optional: auto-run commands on connect

Commands placed in `~/.cm/cmsh/.cmshrc` run at the start of every session — for
example setting a default mode or disabling colour.

## Limits of this setup

| Item | Note |
|---|---|
| Credentials | Not covered by the wrapper; see [set up cmsh credentials](set-up-cmsh-credentials.md) |
| Upgrades | The binary came from `dpkg -x`, so apt will not update it |
| Other users | Works for anyone on the host who has their own `~/.cm/` pair |
