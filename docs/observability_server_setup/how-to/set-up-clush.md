# How to run commands across Slurm node groups with `clush`

Use this procedure to target nodes by Slurm state without maintaining a static
node list.

## Prerequisites

- `sinfo` works on this host.
- Compute-node names resolve.
- Passwordless SSH works from this host to the target nodes.

## 1. Install ClusterShell

```console
sudo apt install clustershell
```

## 2. Define the Slurm group source

```console
sudo tee /etc/clustershell/groups.conf.d/sinfo.conf >/dev/null <<'EOF'
[sinfo]
map: sinfo -h -o "%N" -t $GROUP
list: sinfo -h -o "%T" | tr -d '*~#%@+' | sort -u
all: sinfo -h -o "%N"
EOF
```

In `/etc/clustershell/groups.conf`, set the default source under `[Main]`:

```ini
default: sinfo
```

If the host already uses another default source, leave it unchanged and refer
to groups explicitly as `sinfo:idle`.

## 3. Set fanout

In `/etc/clustershell/clush.conf`, set an initial fanout under `[Main]`:

```ini
fanout: 512
```

Do not set fanout above the host's open-file limit. Use a lower per-command
value when needed:

```console
clush -f 128 -g idle uptime
```

## 4. Verify the groups

```console
nodeset -ll
nodeset -g idle
nodeset -c -g idle
sinfo -h -o "%D %T" -t idle
```

The group names must have no Slurm state flag suffix. Compare the two counts
before relying on the group.

Run a harmless remote command:

```console
clush -b -g idle hostname
```

Before a consequential command, expand the group and review its current
members. Node state can change after ClusterShell resolves the group.

For the group-source design and configuration-directory distinction, see
[Why clush groups come from Slurm](../explanation/clustershell-groups.md). For
group-resolution failures, see
[Troubleshoot a failing Slurm client](troubleshoot.md).
