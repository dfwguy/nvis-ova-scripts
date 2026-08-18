#!/usr/bin/env bash
# Configure a workspace to use one GitLab group token without exposing it.

set -euo pipefail

default_host='gitlab-master.nvidia.com'

usage() {
    cat <<'EOF'
Usage: setup-workspace.sh [--host HOST] [--dry-run] GROUP [WORKSPACE]

Configure an existing group workspace for pass, direnv, glab, and Git
Credential Manager. The group token must already be stored at
pass:gitlab/GROUP/token. WORKSPACE defaults to the current directory.

Examples:
  setup-workspace.sh nvis-ova
  setup-workspace.sh --dry-run parent/subgroup ~/git/parent/subgroup
EOF
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

host="$default_host"
dry_run=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            [[ $# -ge 2 ]] || die '--host requires a hostname'
            host="$2"
            shift 2
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            die "unknown option: $1"
            ;;
        *)
            break
            ;;
    esac
done

[[ $# -ge 1 && $# -le 2 ]] || {
    usage >&2
    exit 2
}

group="$1"
workspace="${2:-$PWD}"

[[ "$group" != /* && "$group" != *'..'* ]] || die 'GROUP must be a relative group path without ..'
[[ "$group" =~ ^[A-Za-z0-9._/-]+$ ]] || die 'GROUP contains unsupported characters'
[[ "$host" =~ ^[A-Za-z0-9.-]+$ ]] || die 'HOST contains unsupported characters'
[[ -d "$workspace" ]] || die "workspace does not exist: $workspace"
workspace="$(cd "$workspace" && pwd -P)"

secret_path="gitlab/${group}/token"
envrc="${workspace}/.envrc"
expected_token_line="export GITLAB_TOKEN=\"\$(pass show ${secret_path})\""
expected_host_line="export GITLAB_HOST=${host}"
repository_path=''

if git -C "$workspace" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    remote_url="$(git -C "$workspace" remote get-url origin 2>/dev/null || true)"
    if [[ -n "$remote_url" ]]; then
        url_prefix="https://${host}/"
        [[ "$remote_url" == "$url_prefix"* ]] || die "origin must use HTTPS on ${host}: $remote_url"
        repository_path="${remote_url#"$url_prefix"}"
        [[ "$repository_path" == "$group/"* ]] || die "origin is not within group ${group}: $repository_path"

        while read -r rewrite_key rewrite_source; do
            if [[ "$rewrite_source" == "$url_prefix" ]]; then
                die "Git rewrites ${url_prefix} through ${rewrite_key}; configure the rewritten credential context explicitly"
            fi
        done < <(git config --global --get-regexp '^url\..*\.insteadof$' 2>/dev/null || true)
    fi
fi

if [[ "$dry_run" == true ]]; then
    printf 'Would read pass:%s without displaying it.\n' "$secret_path"
    printf 'Would configure and approve %s for direnv.\n' "$envrc"
    if [[ -n "$repository_path" ]]; then
        printf 'Would approve the Git credential for https://%s/%s.\n' "$host" "$repository_path"
    else
        printf 'No origin repository credential would be approved.\n'
    fi
    printf 'Would verify the group bot identity with glab.\n'
    exit 0
fi

for required_command in pass direnv git glab git-credential-manager; do
    command -v "$required_command" >/dev/null 2>&1 || die "required command not found: $required_command"
done

manager_configured=false
while IFS= read -r credential_helper; do
    case "$credential_helper" in
        manager|manager-core|*/git-credential-manager|*/git-credential-manager-core)
            manager_configured=true
            ;;
    esac
done < <(git config --global --get-all credential.helper || true)
[[ "$manager_configured" == true ]] || die 'Git Credential Manager is not the global credential helper'

[[ "$(git config --global credential.credentialStore || true)" == 'gpg' ]] || \
    die 'credential.credentialStore must be gpg; plaintext credential storage is not allowed'
[[ "$(git config --global credential.useHttpPath || true)" == 'true' ]] || \
    die 'credential.useHttpPath must be true for per-repository group tokens'

if ! token="$(pass show "$secret_path" 2>/dev/null | sed -n '1p')" || [[ -z "$token" ]]; then
    die "no token found at pass:${secret_path}; store it with: pass insert -m ${secret_path}"
fi
trap 'unset token' EXIT

if [[ -f "$envrc" ]]; then
    if grep -q '^export GITLAB_TOKEN=' "$envrc" && ! grep -qxF "$expected_token_line" "$envrc"; then
        die "$envrc selects a different token; review it manually"
    fi
    if grep -q '^export GITLAB_HOST=' "$envrc" && ! grep -qxF "$expected_host_line" "$envrc"; then
        die "$envrc selects a different GitLab host; review it manually"
    fi
else
    printf '%s\n' '# Local group workspace configuration. Do not commit this file.' > "$envrc"
    chmod 600 "$envrc"
    printf 'created %s\n' "$envrc"
fi

grep -qxF "$expected_token_line" "$envrc" || printf '%s\n' "$expected_token_line" >> "$envrc"
grep -qxF "$expected_host_line" "$envrc" || printf '%s\n' "$expected_host_line" >> "$envrc"

if git -C "$workspace" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    exclude_file="$(git -C "$workspace" rev-parse --git-path info/exclude)"
    [[ "$exclude_file" == /* ]] || exclude_file="${workspace}/${exclude_file}"
    mkdir -p "$(dirname "$exclude_file")"
    grep -qxF '.envrc' "$exclude_file" 2>/dev/null || printf '%s\n' '.envrc' >> "$exclude_file"
fi

direnv allow "$workspace"

if [[ -n "$repository_path" ]]; then
    credential_username="group-${group//\//-}"
    printf 'protocol=https\nhost=%s\npath=%s\nusername=%s\npassword=%s\n\n' \
        "$host" "$repository_path" "$credential_username" "$token" | git credential approve
    printf 'approved Git credential for https://%s/%s\n' "$host" "$repository_path"
fi

GITLAB_TOKEN="$token" GITLAB_HOST="$host" glab api user --silent
printf 'verified the GitLab group token without displaying it\n'
printf 'workspace configured: %s\n' "$workspace"
printf 'Re-enter the workspace or run: direnv reload\n'
