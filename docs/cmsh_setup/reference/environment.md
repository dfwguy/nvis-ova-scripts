# Reference: environment as built

Values observed on 2026-08-06. They are site-specific examples, not defaults;
confirm them on the host before applying a procedure.

## Hosts

| Role | Hostname | Address | OS |
|---|---|---|---|
| BCM headnode | `nscale-hn1` | 192.168.10.2 | Ubuntu 24.04 (confirm with `lsb_release -a`) |
| cmsh client | `network-server` | — | Ubuntu 24.04 (confirm with `lsb_release -a`) |

The client's Ubuntu release must match the headnode's, because the `.deb` files
are built per release.

## Versions

| Item | Value |
|---|---|
| BCM | 11.0 |
| `cmdaemon-cmsh` | `11.0-164771-cm11.0-f6695c2d2a` |
| `cmdaemon` | `11.0-164771-cm11.0-f6695c2d2a` |
| `cmdaemon-remotecm` | `11.0-164771-cm11.0-f6695c2d2a` |
| `cm-config-cm` | `11.0` |

## Paths

| Path | Contents |
|---|---|
| `/cm/local/apps/cmd/bin/cmsh` | The client binary (note `bin`, not `sbin`) |
| `/cm/local/apps/cmd/etc/cacert.pem` | CA used to verify the headnode |
| `/cm/local/apps/cmd/etc/cert.pem`, `cert.key` | Headnode's BCM repo entitlement credential |
| `/root/.cm/admin.pem`, `admin.key` | Administrator client certificate on the headnode |
| `~/.cm/` | Where cmsh looks for client credentials by default |
| `~/.cm/cmsh/.cmshrc` | Per-user commands run at session start |
| `/usr/local/bin/cmsh` | Wrapper supplying the default headnode |
| `/tmp/cmsh-pkgs/` | The downloaded `.deb` bundle on both hosts |

## Network

| Item | Value |
|---|---|
| Protocol | TLS |
| Port | TCP 8081 (CMDaemon) |
| Auth | X.509 client certificate; no password |

## Dependency chain of `cmdaemon-cmsh`

Direct: `cmdaemon` (=), `cmdaemon-remotecm` (=), `cm-config-cm` (= 11.0),
`net-snmp-recent`, `libyaml-0-2`, `libxml2`.

The recursive set also includes `cm-boost`, `cm-openssl`, `cm-curl`,
`cm-mariadb-libs`, `cm-mysql++`, `cm-gcc`, `cm-lua`, `cm-luajit`, `cm-modules`,
`cm-freeipmi`, `cm-lshw`, `cm-rsync`, `cm-libprometheus`, `cm-gmp`, `cm-mpfr`,
`cm-mpc`, `cm-confuse`, `openldap-servers`, `cuda-dcgm-libs`, `mailutils`,
`expect`, plus **both** `cm-master` and `cm-slave`.

## Installation state after the procedure

| Package | State | Method |
|---|---|---|
| Dependency tree (`cm-*`, `net-snmp-recent`, Ubuntu libs) | `ii` | `apt install ./*.deb` then `dpkg --configure -a` |
| `cmdaemon` | not registered with dpkg | `dpkg -x` |
| `cmdaemon-cmsh` | not registered with dpkg | `dpkg -x` |

## Site capture checklist

Run these on the client when adapting this guide to another environment:

```
lsb_release -a; ls -l /cm/local/apps/cmd/bin/cmsh /cm/local/apps/cmd/etc/cacert.pem; ls -l ~/.cm/; getent hosts nscale-hn1; ls -l /usr/local/bin/cmsh /etc/profile.d/cmsh.sh
```

Also useful:

- The exact error text from `sudo apt install ./*.deb` (to replace the inferred
  `cm-master`/`cm-slave` conflict explanation with the real cause).
- Whether the final working state came from `apt install` of the two debs or from
  `dpkg -x` — the docs currently assume `dpkg -x`.
- Headnode OS release, from `lsb_release -a` on `nscale-hn1`.
- The site-specific per-user certificate issuance process and profile names.
- Output of `ldd /cm/local/apps/cmd/bin/cmsh | grep 'not found'` — confirms
  whether any library gaps remain.
