#!/usr/bin/env bash
# Clone an HTTPS GitLab repository using the access token assigned to its group.
# The token is read from pass, recorded by the configured Git credential helper,
# and never written to the remote URL or the workspace .envrc.

set -euo pipefail

default_host='gitlab-master.nvidia.com'
workspace_base="${HOME}/git"

usage() {
    cat <<'EOF'
Usage: clone-gitlab-group.sh [--host HOST] GROUP HTTPS_REPOSITORY_URL [DESTINATION]

Clone a repository into ~/git/GROUP and configure that group workspace for
direnv and glab. GROUP must be the GitLab group path that owns the group access
token, for example omnistation-platform or parent/subgroup.

The token must already exist in pass at gitlab/GROUP/token. The repository URL
must use HTTPS and be within GROUP or one of its subgroups.

Examples:
  clone-gitlab-group.sh omnistation-platform \
    https://gitlab-master.nvidia.com/omnistation-platform/project-a.git
  clone-gitlab-group.sh --host gitlab.example.com parent/subgroup \
    https://gitlab.example.com/parent/subgroup/project-a.git project-a
EOF
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

host="$default_host"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            [[ $# -ge 2 ]] || die '--host requires a hostname'
            host="$2"
            shift 2
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

[[ $# -ge 2 && $# -le 3 ]] || {
    usage >&2
    exit 2
}

group="$1"
repository_url="$2"
destination="${3:-}"

[[ "$group" != /* && "$group" != *'..'* ]] || die 'GROUP must be a relative group path without ..'
[[ "$group" =~ ^[A-Za-z0-9._/-]+$ ]] || die 'GROUP contains unsupported characters'

url_prefix="https://${host}/"
[[ "$repository_url" == "$url_prefix"* ]] || die "repository URL must begin with $url_prefix"
repository_path="${repository_url#"$url_prefix"}"
[[ -n "$repository_path" && "$repository_path" != */ ]] || die 'repository URL must include a repository path'
[[ "$repository_path" == "$group/"* ]] || die "repository path must be in group $group or one of its subgroups"

if [[ -z "$destination" ]]; then
    destination="${repository_path##*/}"
    destination="${destination%.git}"
fi
[[ "$destination" != /* && "$destination" != *'..'* ]] || die 'DESTINATION must be relative and must not contain ..'

for command in pass direnv git; do
    command -v "$command" >/dev/null 2>&1 || die "required command not found: $command"
done

secret_path="gitlab/${group}/token"
if ! token="$(pass show "$secret_path" 2>/dev/null | sed -n '1p')" || [[ -z "$token" ]]; then
    die "no token found at pass:$secret_path; store it with: pass insert -m $secret_path"
fi

workspace="${workspace_base}/${group}"
envrc="${workspace}/.envrc"
target="${workspace}/${destination}"
[[ ! -e "$target" ]] || die "destination already exists: $target"

mkdir -p "$workspace"
if [[ ! -e "$envrc" ]]; then
    {
        printf '%s\n' '# Local group workspace configuration. Do not commit this file.'
        # shellcheck disable=SC2016 # The command substitution is for direnv to evaluate later.
        printf 'export GITLAB_TOKEN="$(pass show %q)"\n' "$secret_path"
        printf 'export GITLAB_HOST=%q\n' "$host"
    } > "$envrc"
    printf 'created %s\n' "$envrc"
else
    printf 'using existing %s\n' "$envrc"
fi

direnv allow "$workspace"

# With credential.useHttpPath=true, this exact path is the credential context.
# GitLab accepts any non-blank username for a group access token; a stable
# group-derived username makes the keychain entry understandable.
credential_username="group-${group//\//-}"
printf 'protocol=https\nhost=%s\npath=%s\nusername=%s\npassword=%s\n\n' \
    "$host" "$repository_path" "$credential_username" "$token" | git credential approve
unset token

git clone "$repository_url" "$target"
printf '\nCloned into %s\n' "$target"
printf 'Enter it with: cd %q\n' "$target"
printf 'Its group token will be selected by %s, not by a parent workspace credential.\n' "$envrc"
