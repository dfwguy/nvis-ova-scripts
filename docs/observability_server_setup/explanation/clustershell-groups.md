# Why clush groups come from Slurm

A static ClusterShell group file duplicates scheduler state and becomes stale.
A command-backed group source asks `sinfo` for the current nodes in each Slurm
state whenever the group is used.

This removes local membership data but inherits Slurm's failure modes. If
`sinfo` returns nothing because authentication or configuration is broken, a
group can appear empty. Expand and inspect a group before consequential work.

Group membership is also a snapshot. A node can change state after the group is
resolved, so destructive operations should use an explicitly reviewed node
list.

## State flags require normalization

Slurm decorates states with flags such as `idle*` and `idle~`. ClusterShell
group names do not accept those characters, so the group source removes the
decoration from the group name. Filtering by the base state still includes the
flagged nodes.

## The configuration directories serve different formats

- `groups.conf.d/` contains INI files that define command-backed sources with
  `list`, `map`, and `all` directives.
- `groups.d/` contains YAML files with static group membership.

The `sinfo` source belongs in `groups.conf.d/`. A `.conf` file in `groups.d/`
is ignored because it matches neither the expected directory nor format.
