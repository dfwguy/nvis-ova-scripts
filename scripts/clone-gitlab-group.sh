#!/usr/bin/env bash
# Clone an HTTPS GitLab repository using the access token assigned to its group.
# The token is read from pass, recorded by Git Credential Manager's GPG store,
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

is_git_credential_manager_helper() {
    case "$1" in
        manager|manager-core|*/git-credential-manager|*/git-credential-manager-core)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

verify_git_credential_configuration() {
    local entry key section helper resolved_helper credential_store use_http_path
    local -a active_helpers=()

    # credential.helper is multi-valued. An empty value resets helpers declared
    # earlier, so retain only the helper chain after the final reset.
    while IFS= read -r helper; do
        if [[ -z "$helper" ]]; then
            active_helpers=()
        else
            active_helpers+=("$helper")
        fi
    done < <(git config --get-all credential.helper || true)

    [[ ${#active_helpers[@]} -gt 0 ]] || \
        die 'Git Credential Manager must be configured as credential.helper before approving a token'
    for helper in "${active_helpers[@]}"; do
        is_git_credential_manager_helper "$helper" || \
            die "unsafe credential helper configured: $helper; only Git Credential Manager may be active"
    done

    # Git invokes matching URL-specific helpers in addition to generic helpers.
    # Inspect every HTTPS helper scoped to this host because --get-urlmatch
    # reports only the final value of a multi-valued helper chain.
    while IFS= read -r -d '' entry; do
        key="${entry%%$'\n'*}"
        helper="${entry#*$'\n'}"
        section="${key#credential.}"
        section="${section%.helper}"
        case "$section" in
            https://"$host"|https://"$host"/*|https://*@"$host"|https://*@"$host"/*)
                [[ -z "$helper" ]] || is_git_credential_manager_helper "$helper" || \
                    die "unsafe credential helper configured for $host: $helper"
                ;;
        esac
    done < <(git config --null --get-regexp '^credential\..*\.helper$' || true)

    resolved_helper="$(git config --get-urlmatch credential.helper "$repository_url" || true)"
    is_git_credential_manager_helper "$resolved_helper" || \
        die 'Git Credential Manager is not the credential helper selected for this repository URL'

    credential_store="$(git config --get-urlmatch credential.credentialStore "$repository_url" || true)"
    [[ "$credential_store" == 'gpg' ]] || \
        die 'credential.credentialStore must be gpg before approving a token'

    use_http_path="$(git config --type=bool --get-urlmatch credential.useHttpPath "$repository_url" || true)"
    [[ "$use_http_path" == 'true' ]] || \
        die 'credential.useHttpPath must be true before approving a repository-scoped token'
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
if ! command -v git-credential-manager >/dev/null 2>&1 && \
   ! command -v git-credential-manager-core >/dev/null 2>&1; then
    die 'required command not found: git-credential-manager'
fi

# Fail before decrypting the token or invoking `git credential approve`. This
# prevents a missing or plaintext helper configuration from receiving it.
verify_git_credential_configuration

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
