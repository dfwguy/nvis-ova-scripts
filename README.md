# nvis-ova-scripts

Scripts and documentation for NVIS OVA infrastructure.

## Docs

The client guides cover giving a standalone (non-BCM-managed) Ubuntu host
access to a BCM cluster. The compute-node guide covers SSH access policy on
the managed cluster itself.

| Guide | Gives you | Talks to |
|---|---|---|
| [docs/observability_server_setup/](docs/observability_server_setup/) | `sinfo`, `squeue`, `sacct` — a read-only Slurm client, plus `clush` fan-out | Slurm controller, TCP 6817, munge + matching UID |
| [docs/cmsh_setup/](docs/cmsh_setup/) | `cmsh` — the interactive BCM management shell | CMDaemon, TCP 8081, X.509 client certificate |
| [docs/compute_node_ssh_access/](docs/compute_node_ssh_access/) | Job-aware SSH admission on compute nodes, with an idle-node fallback | Local PAM stack, `pam_slurm_adopt`, and `scontrol` |
| [docs/omnistation_group_credentials/](docs/omnistation_group_credentials/) | Secure, group-scoped GitLab credentials for `git` and `glab` | Git Credential Manager, `pass`, and `direnv` |

## Scripts

| Script | Description |
|---|---|
| [scripts/check_node_busy.sh](scripts/check_node_busy.sh) | PAM helper that succeeds only when the local node has no Slurm-managed processes |
| [scripts/squeue-tree-viewer.sh](scripts/squeue-tree-viewer.sh) | `nodetree`: tree view of Slurm nodes, running jobs, and node-blocked pending jobs |
| [scripts/clone-gitlab-group.sh](scripts/clone-gitlab-group.sh) | Clone an HTTPS GitLab repository with the matching group token from `pass` |

Run `scripts/squeue-tree-viewer.sh -h` to see its options. It requires Bash 4+
and Slurm's `sinfo`, `squeue`, and `scontrol` commands.

## Codex skills

| Skill | Description |
|---|---|
| [.agents/skills/configure-gitlab-group-credentials/](.agents/skills/configure-gitlab-group-credentials/) | Configure and verify group-scoped GitLab credentials with `pass`, `direnv`, and Git Credential Manager |

See [how to use the Codex group-credential skill](docs/omnistation_group_credentials/how-to/use-the-codex-skill.md)
for invocation and installation details.
