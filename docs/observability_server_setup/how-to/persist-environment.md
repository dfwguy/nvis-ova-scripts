# How to make the Slurm client work permanently

**Goal:** `sinfo` and `squeue` work after reboot, under `sudo`, and from cron or scripts.

## What is already persistent

| Item | Mechanism |
|---|---|
| NFS mount | `/etc/fstab` |
| `munge` service | Unit enabled at package install |
| Munge key | On local disk |
| `/etc/hosts` entry | On local disk |
| `slurm` and user accounts | `/etc/passwd`, `/etc/group` |
| Library resolution | RPATH inside the package — nothing needed in `/etc/ld.so.conf.d/` |

Only PATH and the config location need work.

## Set PATH for login shells

```
printf 'export PATH=/cm/local/apps/slurm/25.05/bin:$PATH\nexport SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf\n' > /etc/profile.d/slurm.sh
```

```
chmod 0644 /etc/profile.d/slurm.sh
```

## Symlink the config to the default path

Do this **as well as** the `SLURM_CONF` export. `profile.d` loads only in login shells, so cron,
`sudo`, and non-interactive scripts would otherwise have no config. `/etc/slurm/slurm.conf` is where
Slurm looks by default, making the env var redundant rather than required:

```
mkdir -p /etc/slurm
```

```
ln -sfn /cm/shared/apps/slurm/etc/slurm/slurm.conf /etc/slurm/slurm.conf
```

## Fix `sudo`

`sudo` discards the caller's PATH in favour of `secure_path`, so `sudo sinfo` reports
`command not found`. Prepend the Slurm bin directory:

```
echo 'Defaults secure_path="/cm/local/apps/slurm/25.05/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' > /etc/sudoers.d/slurm-path
```

```
chmod 0440 /etc/sudoers.d/slurm-path
```

A file in `/etc/sudoers.d/` survives `sudoers` package upgrades; editing `/etc/sudoers` directly does
not. A syntax error in `secure_path` can lock out `sudo` entirely — validate before logging out:

```
visudo -c
```

## Verify all three contexts

```
su - nvis -c 'sinfo | head -3' && sudo sinfo | head -3 && env -i /cm/local/apps/slurm/25.05/bin/sinfo | head -3
```

The third command runs with an empty environment, proving the symlink works without `SLURM_CONF`.

## Notes

- The version number `25.05` is embedded in both the profile script and `secure_path`. A cluster
  Slurm upgrade means editing both files. Alternatively, create your own stable symlink and reference
  that instead:

```
ln -sfn /cm/local/apps/slurm/25.05 /cm/local/apps/slurm/current
```

- If `/cm/shared` fails to mount, every Slurm command breaks, since the config lives there. Keeping a
  local fallback copy is an option, but it will silently go stale — usually worse than a clear failure.

## Related

- [install-slurm-binaries.md](install-slurm-binaries.md) — where the version path comes from.
- [reference.md](../reference.md) — full list of files this setup touches.
