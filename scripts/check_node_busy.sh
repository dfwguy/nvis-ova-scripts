#!/bin/bash
# Return success only when scontrol reports no Slurm-managed PIDs locally.
# Any command or output-format failure is treated as busy (fail closed).

set -o nounset

(( $# == 0 )) || exit 1

# Use the cluster's Slurm module rather than the SSH/PAM environment.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

# shellcheck source=/dev/null
source /etc/profile.d/modules.sh >/dev/null 2>&1 || exit 1
module load slurm >/dev/null 2>&1 || exit 1

if ! scontrol=$(type -P scontrol) || [[ ! -x $scontrol ]]; then
    exit 1
fi

readonly scontrol

if ! output=$("$scontrol" listpids 2>/dev/null); then
    exit 1
fi

mapfile -t lines <<< "$output"
read -r -a headings <<< "${lines[0]:-}"

if [[ ${headings[0]:-} != PID || ${headings[1]:-} != JOBID ]]; then
    exit 1
fi

for line in "${lines[@]:1}"; do
    if [[ -n ${line//[[:space:]]/} ]]; then
        exit 1
    fi
done

exit 0
