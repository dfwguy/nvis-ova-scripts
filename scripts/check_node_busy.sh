#!/bin/bash
# Return success only when scontrol reports no Slurm-managed PIDs locally.
# Any command or output-format failure is treated as busy (fail closed).

set -o nounset

if (( $# != 1 )) || [[ $1 != /* ]] || [[ ! -x $1 ]]; then
    exit 1
fi

readonly scontrol=$1

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
