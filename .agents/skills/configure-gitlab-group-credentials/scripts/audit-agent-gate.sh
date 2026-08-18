#!/usr/bin/env bash
# Report credential paths that let a same-user agent bypass human presence.

set -euo pipefail

default_host='gitlab-master.nvidia.com'

usage() {
    cat <<'EOF'
Usage: audit-agent-gate.sh [--host HOST] GROUP [WORKSPACE]

Audit whether a GitLab group token is gated from an agent running as the
current user. This command never decrypts or prints a token. It exits nonzero
when it finds a bypass.
EOF
}

host="$default_host"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            [[ $# -ge 2 ]] || { usage >&2; exit 2; }
            host="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

[[ $# -ge 1 && $# -le 2 ]] || { usage >&2; exit 2; }
group="$1"
workspace="${2:-$PWD}"
workspace="$(cd "$workspace" && pwd -P)"
failures=0

pass_store_dir="${PASSWORD_STORE_DIR:-${HOME}/.password-store}"
recipient_file="${pass_store_dir}/.gpg-id"
if [[ ! -f "$recipient_file" ]]; then
    printf '%s\n' 'FAIL pass has no .gpg-id recipient file'
    failures=$((failures + 1))
else
    recipient="$(sed -n '/^[[:space:]]*#/d; /^[[:space:]]*$/d; 1p' "$recipient_file")"
    keygrip_found=false
    while IFS= read -r keygrip; do
        keygrip_found=true
        key_file="${HOME}/.gnupg/private-keys-v1.d/${keygrip}.key"
        if [[ ! -f "$key_file" ]] || ! grep -aEq '(protected|shadowed)-private-key' "$key_file"; then
            printf '%s\n' 'FAIL pass private key is not passphrase-protected'
            failures=$((failures + 1))
            break
        fi
    done < <(gpg --batch --with-colons --with-keygrip --list-secret-keys "$recipient" 2>/dev/null | awk -F: '$1 == "grp" {print $10}')
    if [[ "$keygrip_found" == false ]]; then
        printf '%s\n' 'FAIL pass private key is unavailable'
        failures=$((failures + 1))
    fi
fi

agent_config="${HOME}/.gnupg/gpg-agent.conf"
if [[ -f "$agent_config" ]] \
    && grep -Eq '^[[:space:]]*default-cache-ttl[[:space:]]+0([[:space:]]|$)' "$agent_config" \
    && grep -Eq '^[[:space:]]*max-cache-ttl[[:space:]]+0([[:space:]]|$)' "$agent_config" \
    && grep -Eq '^[[:space:]]*no-allow-external-cache([[:space:]]|$)' "$agent_config"; then
    printf '%s\n' 'PASS gpg-agent cache is configured for prompt-on-use'
else
    printf '%s\n' 'FAIL gpg-agent may cache the passphrase'
    failures=$((failures + 1))
fi

if [[ -n "${GITLAB_TOKEN-}" ]]; then
    printf '%s\n' 'FAIL GITLAB_TOKEN is present in this process environment'
    failures=$((failures + 1))
else
    printf '%s\n' 'PASS GITLAB_TOKEN is absent from this process environment'
fi

envrc="${workspace}/.envrc"
if [[ -f "$envrc" ]] && grep -q '^export GITLAB_TOKEN=' "$envrc"; then
    printf '%s\n' 'FAIL workspace .envrc exports GITLAB_TOKEN'
    failures=$((failures + 1))
else
    printf '%s\n' 'PASS workspace .envrc does not export GITLAB_TOKEN'
fi

saved_glab_token="$(env -u GITLAB_TOKEN glab config get token --global --host "$host" 2>/dev/null || true)"
if [[ -n "$saved_glab_token" ]]; then
    printf 'FAIL glab config contains a saved token for %s\n' "$host"
    failures=$((failures + 1))
else
    printf 'PASS glab config contains no saved token for %s\n' "$host"
fi
unset saved_glab_token

repository_path=''
if git -C "$workspace" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    remote_url="$(git -C "$workspace" remote get-url origin 2>/dev/null || true)"
    url_prefix="https://${host}/"
    [[ "$remote_url" == "$url_prefix"* ]] && repository_path="${remote_url#"$url_prefix"}"
fi

credential_root="${pass_store_dir}/git/https/${host}"
if [[ -n "$repository_path" ]]; then
    credential_root="${credential_root}/${repository_path}"
else
    credential_root="${credential_root}/${group}"
fi
if [[ -d "$credential_root" ]] && find "$credential_root" -type f -name '*.gpg' -print -quit | grep -q .; then
    printf '%s\n' 'FAIL Git Credential Manager has a saved credential for this context'
    failures=$((failures + 1))
else
    printf '%s\n' 'PASS Git Credential Manager has no saved credential for this context'
fi

if [[ "$failures" -eq 0 ]]; then
    printf '%s\n' 'PASS no same-user credential bypass was detected'
    exit 0
fi

printf 'FAIL %d gate bypass(es) detected\n' "$failures"
exit 1
