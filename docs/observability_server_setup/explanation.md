# Explanations

These documents describe why the client-only node is built this way. Use the
[tutorial](tutorial.md) or a [how-to guide](how-to/) when you need steps.

| Topic | Explanation |
|---|---|
| Client architecture | [How a client-only Slurm node works](explanation/client-only-slurm-node.md) |
| Job submission | [Why submission needs more than query tools](explanation/submission-dependencies.md) |
| Authentication and identity | [Munge, UIDs, and non-interactive environments](explanation/identity-and-environment.md) |
| Name resolution | [Why cluster DNS uses systemd-resolved](explanation/dns-design.md) |
| ClusterShell | [Why clush groups come from Slurm](explanation/clustershell-groups.md) |
