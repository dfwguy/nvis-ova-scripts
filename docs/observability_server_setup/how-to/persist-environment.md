# How to make the Slurm client work permanently

**Goal:** `sinfo` and `squeue` work after reboot, under `sudo`, and from cron or scripts.

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

The version number `25.05` appears in both files. To avoid changing both after
an upgrade, create a stable local symlink and use `current/bin` in their paths:

```
ln -sfn /cm/local/apps/slurm/25.05 /cm/local/apps/slurm/current
```

## Related

- [install-slurm-binaries.md](install-slurm-binaries.md) — where the version path comes from.
- [reference.md](../reference.md) — full list of files this setup touches.
- [identity-and-environment.md](../explanation/identity-and-environment.md) — why login shells and `sudo` need separate configuration.
