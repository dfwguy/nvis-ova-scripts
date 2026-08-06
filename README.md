# nvis-ova-scripts

Scripts and documentation for NVIS OVA infrastructure.

## Docs

Two guides, both about giving a standalone (non-BCM-managed) Ubuntu host access to a BCM cluster.
They are independent — each covers a different client and a different protocol — and can be followed
in either order, or alone.

| Guide | Gives you | Talks to |
|---|---|---|
| [docs/observability_server_setup/](docs/observability_server_setup/) | `sinfo`, `squeue`, `sacct` — a read-only Slurm client | Slurm controller, TCP 6817, munge + matching UID |
| [docs/cmsh_setup/](docs/cmsh_setup/) | `cmsh` — the interactive BCM management shell | CMDaemon, TCP 8081, X.509 client certificate |

## Scripts

| Script | Description |
|---|---|
| [scripts/squeue-tree-viewer.sh](scripts/squeue-tree-viewer.sh) | Tree view of Slurm nodes: state, running jobs, and blocked pending jobs |
