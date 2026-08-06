# How to troubleshoot a cmsh connection

Work down the table; each row is independent of the ones below it.

## Symptoms and causes

| Symptom | Cause | Fix |
|---|---|---|
| `Command 'cmsh' not found` | Binary never landed — the package did not install | `ls /cm/local/apps/cmd/bin`; if only `include` and `lib` exist, re-run the [extraction](extract-cmsh-without-installing.md) |
| `dpkg -l` shows `iU` for cm packages | Unpacked but unconfigured; a transaction aborted | `sudo dpkg --configure -a` |
| `cmdaemon` absent from `dpkg -l` entirely | apt refused the transaction (conflicting packages in the bundle) | Extract with `dpkg -x` rather than installing |
| `error while loading shared libraries` | A `cm-*` library dependency is missing | `ldd /cm/local/apps/cmd/bin/cmsh \| grep 'not found'`, then extract the matching deb |
| `Cannot connect` | Port 8081 unreachable, or wrong hostname | Test with `nc`, below |
| Connects then hangs and times out | CMDaemon is bound to the internal cluster interface only | Connect over that network / use the internal address |
| `Certificate verify failed` | The client does not trust the headnode CA | Place `cacert.pem` — see [credentials](set-up-cmsh-credentials.md) |
| `Permission denied` on the cert | Wrong owner, or run via `sudo` (which changes `$HOME`) | `chmod 600 ~/.cm/*`; run as your own user |
| Rejected on version grounds | Client build differs from CMDaemon build | Re-download the debs matching the headnode; see [version parity](../explanation/version-parity.md) |

## Diagnostics

Reachability:

```
nc -zv nscale-hn1 8081
```

What is installed:

```
dpkg -l | grep -E 'cmdaemon|cm-config'
```

Whether the binary can actually run:

```
ldd /cm/local/apps/cmd/bin/cmsh | grep 'not found'
```

End-to-end proof, from inside a cmsh session:

```
device list
```

If nodes are listed, the client, the certificate, and CMDaemon are all working.
