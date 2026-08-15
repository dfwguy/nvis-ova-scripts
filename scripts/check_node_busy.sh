#!/bin/bash
# Return success only when scontrol reports no Slurm-managed PIDs locally.
# Any command or output-format failure is treated as busy (fail closed).

set -o nounset

if (( $# > 1 )); then
    exit 1
fi

# Do not search a caller-controlled PATH from the PAM environment. A trusted
# module initialization script may extend this baseline below.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
unset MODULEPATH MODULESHOME LOADEDMODULES _LMFILES_ \
    LMOD_DEFAULT_MODULES LMOD_SYSTEM_DEFAULT_MODULES

readonly requested_module_init=${1:-}
readonly -a module_init_files=(
    "$requested_module_init"
    /etc/profile.d/modules.sh
    /etc/profile.d/lmod.sh
    /usr/share/Modules/init/bash
)

unset -f module 2>/dev/null || true

for module_init in "${module_init_files[@]}"; do
    if [[ -n $module_init && $module_init == /* && -r $module_init ]]; then
        # shellcheck source=/dev/null
        source "$module_init" >/dev/null 2>&1 || true
    fi

    if command -v module >/dev/null 2>&1; then
        break
    fi
done

# Loading is best effort: scontrol may already be available, and some module
# implementations return failure when the requested module is already loaded.
if command -v module >/dev/null 2>&1; then
    module load slurm >/dev/null 2>&1 || true
fi

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
