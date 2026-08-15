# How to gate SSH access on Slurm activity

Use this procedure to allow `root` and users with a local Slurm job to connect
to a compute node. Other users can connect only when the node is idle and
`/etc/security/access.conf` allows them.

## Prerequisites

- `pam_slurm_adopt.so` and its Slurm containment requirements are configured.
- SSH uses PAM, and `pam_systemd.so` is disabled in PAM files included by
  `sshd`.
- `/etc/profile.d/modules.sh` is installed, and `module load slurm` provides
  `scontrol`.
- `/etc/security/access.conf` contains the intended idle-node access rules.

## 1. Install the busy-node helper

Install the repository
[`check_node_busy.sh` helper](../../../scripts/check_node_busy.sh):

```console
sudo install -o root -g root -m 0755 scripts/check_node_busy.sh \
    /usr/local/sbin/check_node_busy.sh
```

## 2. Configure the PAM policy

Keep the existing `account` entries in `/etc/pam.d/sshd`. Add these entries
after the normal account includes:

```pam
account [success=done ignore=ignore default=die] pam_slurm_adopt.so action_no_jobs=ignore action_adopt_failure=deny action_generic_failure=deny
account requisite pam_exec.so quiet /usr/local/sbin/check_node_busy.sh
account required  pam_access.so
```

Keep this order and these control flags. Check included PAM files for an earlier
`account sufficient` entry, which could return before this policy runs.

## 3. Test on one compute node

Keep an existing root session open and test on one drained compute node first.
Run the helper on an idle node:

```console
sudo /usr/local/sbin/check_node_busy.sh
echo $?
```

The result must be `0`. Start a Slurm job on the node, run the helper again, and
confirm that it returns `1`.

From a second terminal, test these SSH connections:

| Situation | Expected result |
|---|---|
| `root` | Login succeeds |
| User owns a local job | Login succeeds and is adopted into the job's external step |
| User owns no local job; node has Slurm-managed PIDs | Login fails |
| User owns no local job; node has no Slurm-managed PIDs; `pam_access` allows | Login succeeds |
| User owns no local job; node has no Slurm-managed PIDs; `pam_access` denies | Login fails |

Roll out the PAM change to the remaining compute nodes only after every test
passes.
