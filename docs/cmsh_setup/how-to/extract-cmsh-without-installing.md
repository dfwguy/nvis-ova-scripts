# How to extract cmsh without installing it

**Goal:** place the `cmsh` binary and its BCM-side files on a non-BCM host
without running any package maintainer scripts.

Use this when `apt install ./*.deb` leaves `cmdaemon` and `cmdaemon-cmsh`
uninstalled, or when you want a guarantee that nothing on the host is
reconfigured.

## Procedure

First make sure the dependencies are properly installed and configured:

```
sudo dpkg --configure -a
```

Then unpack the two remaining packages into the filesystem root:

```
sudo dpkg -x /tmp/cmsh-pkgs/cmdaemon-cmsh_11.0-164771-cm11.0-f6695c2d2a_amd64.deb /
```

```
sudo dpkg -x /tmp/cmsh-pkgs/cmdaemon_11.0-164771-cm11.0-f6695c2d2a_amd64.deb /
```

Confirm the binary landed:

```
ls -l /cm/local/apps/cmd/bin/cmsh
```

Confirm nothing is missing at link time:

```
ldd /cm/local/apps/cmd/bin/cmsh | grep 'not found'
```

No output means you are done. Any line listed is a library to source — extract
the matching `cm-*` deb the same way, most likely `cm-openssl`, `cm-boost`, or
`cm-curl`.

## What this deliberately skips

| Skipped | Consequence |
|---|---|
| `postinst` scripts | No `cmd` service is created or started; the host never self-registers |
| `cm-config-cm` system rewriting | apt repos, PAM, and `profile.d` on this host are left alone |
| dpkg database registration | `dpkg -l` will not list `cmdaemon-cmsh`; apt cannot upgrade or remove it |

## Consequences to plan for

- Upgrades are manual. Re-run the extraction after any headnode BCM upgrade.
- `apt` may later install a conflicting file at the same path with no warning.
  In practice `/cm/` is untouched by Ubuntu packages, so this is low risk.
- To undo, delete `/cm/local/apps/cmd/bin` and the other extracted paths by
  hand; there is no `apt remove`.
