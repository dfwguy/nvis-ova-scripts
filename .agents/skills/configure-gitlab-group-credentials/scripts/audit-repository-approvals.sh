#!/usr/bin/env bash
# Verify that GitLab requires review and prevents author self-approval.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: audit-repository-approvals.sh [--project ID_OR_PATH] [--target-branch BRANCH] [--minimum COUNT] [WORKSPACE]

Verify that the GitLab project has an approval rule requiring at least COUNT
approvals, prevents merge-request authors from approving their own work, and
prevents per-merge-request approval-rule overrides. COUNT defaults to 1.

PROJECT defaults to the path derived from the origin remote. BRANCH defaults to
the project's default branch. A Maintainer token is required to read project
approval settings. The script is read-only.
EOF
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 2
}

project=''
target_branch=''
minimum=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        --project)
            [[ $# -ge 2 ]] || die '--project requires a numeric ID or namespace path'
            project="$2"
            shift 2
            ;;
        --minimum)
            [[ $# -ge 2 ]] || die '--minimum requires a positive integer'
            minimum="$2"
            shift 2
            ;;
        --target-branch)
            [[ $# -ge 2 ]] || die '--target-branch requires a branch name'
            target_branch="$2"
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

[[ $# -le 1 ]] || { usage >&2; exit 2; }
[[ "$minimum" =~ ^[1-9][0-9]*$ ]] || die '--minimum must be a positive integer'

for required_command in glab jq; do
    command -v "$required_command" >/dev/null 2>&1 || die "required command not found: $required_command"
done

if [[ -z "$project" ]]; then
    workspace="${1:-$PWD}"
    workspace="$(cd "$workspace" && pwd -P)"
    git -C "$workspace" rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
        die "not a Git worktree: $workspace"
    remote_url="$(git -C "$workspace" remote get-url origin 2>/dev/null || true)"
    [[ -n "$remote_url" ]] || die 'origin remote is unavailable; pass --project explicitly'
    case "$remote_url" in
        http://*/*|https://*/*|ssh://*/*)
            project="${remote_url#*://}"
            project="${project#*/}"
            ;;
        *@*:*)
            project="${remote_url#*:}"
            ;;
        *)
            die "cannot derive a GitLab project path from origin: $remote_url"
            ;;
    esac
    project="${project%.git}"
fi

resolve_project_id() {
    local requested="$1"
    local encoded project_json project_id search_name search_query matches

    if [[ "$requested" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$requested"
        return
    fi

    encoded="$(jq -rn --arg value "$requested" '$value | @uri')"
    project_json="$(glab api "projects/${encoded}" 2>/dev/null || true)"
    project_id="$(printf '%s' "$project_json" | jq -r '.id // empty' 2>/dev/null || true)"
    if [[ -n "$project_id" ]]; then
        printf '%s\n' "$project_id"
        return
    fi

    # Older glab/self-managed combinations can return a false 404 for a path.
    search_name="${requested##*/}"
    search_query="$(jq -rn --arg value "$search_name" '$value | @uri')"
    project_json="$(glab api "projects?search=${search_query}&simple=true&per_page=100")" || \
        die "cannot search GitLab for project: $requested"
    matches="$(printf '%s' "$project_json" | jq --arg path "$requested" \
        '[.[] | select(.path_with_namespace == $path)]')"
    [[ "$(printf '%s' "$matches" | jq 'length')" -eq 1 ]] || \
        die "could not uniquely resolve project: $requested; pass its numeric ID"
    printf '%s' "$matches" | jq -r '.[0].id'
}

project_id="$(resolve_project_id "$project")"
project_json="$(glab api "projects/${project_id}")" || die "cannot read project ${project_id}"
project_path="$(printf '%s' "$project_json" | jq -r '.path_with_namespace // empty')"
[[ -n "$project_path" ]] || die "project ${project_id} did not return a namespace path"
if [[ -z "$target_branch" ]]; then
    target_branch="$(printf '%s' "$project_json" | jq -r '.default_branch // empty')"
fi
[[ -n "$target_branch" ]] || die 'target branch is unavailable; pass --target-branch explicitly'
printf 'Project: %s (%s)\n' "$project_path" "$project_id"
printf 'Target branch: %s\n' "$target_branch"

rules_json="$(glab api "projects/${project_id}/approval_rules")" || \
    die 'cannot read project approval rules; Premium/Ultimate and an authenticated project member are required'
protected_json="$(glab api "projects/${project_id}/protected_branches" 2>/dev/null || printf '[]')"
if printf '%s' "$protected_json" | jq -e --arg target "$target_branch" \
    'any(.[]; .name == $target)' >/dev/null 2>&1; then
    target_is_protected=true
else
    target_is_protected=false
fi
qualifying_rules="$(printf '%s' "$rules_json" | jq \
    --argjson minimum "$minimum" \
    --arg target "$target_branch" \
    --argjson target_is_protected "$target_is_protected" '
    [.[] |
      select((.approvals_required // 0) >= $minimum) |
      select(
        (((.protected_branches // []) | length) == 0 and
          (.applies_to_all_protected_branches // false) == false) or
        ((.protected_branches // []) | map(.name) | index($target) != null) or
        ((.applies_to_all_protected_branches // false) == true and
          $target_is_protected)
      )
    ]')"
if [[ "$(printf '%s' "$qualifying_rules" | jq 'length')" -gt 0 ]]; then
    printf 'PASS approval rule for %s requires at least %d approval(s): %s\n' \
        "$target_branch" "$minimum" \
        "$(printf '%s' "$qualifying_rules" | jq -r 'map("\(.name) (\(.approvals_required))") | join(", ")')"
else
    printf 'FAIL no approval rule for %s requires at least %d approval(s)\n' \
        "$target_branch" "$minimum"
    rules_failed=true
fi

settings_json=''
settings_format=''
settings_candidate="$(glab api "projects/${project_id}/merge_request_approval_setting" 2>/dev/null || true)"
if printf '%s' "$settings_candidate" | jq -e \
    '(.allow_author_approval.value | type) == "boolean" and
     (.allow_overrides_to_approver_list_per_merge_request.value | type) == "boolean"' \
    >/dev/null 2>&1; then
    settings_json="$settings_candidate"
    settings_format='current'
else
    settings_candidate="$(glab api "projects/${project_id}/approvals" 2>/dev/null || true)"
    if printf '%s' "$settings_candidate" | jq -e \
        '(.merge_requests_author_approval | type) == "boolean" and
         (.disable_overriding_approvers_per_merge_request | type) == "boolean"' \
        >/dev/null 2>&1; then
        settings_json="$settings_candidate"
        settings_format='legacy'
    else
        die 'cannot read project approval settings; rerun with a Maintainer token (a Developer token is inconclusive)'
    fi
fi
unset settings_candidate

case "$settings_format" in
    current)
        allow_author="$(printf '%s' "$settings_json" | jq -r '.allow_author_approval.value')"
        allow_overrides="$(printf '%s' "$settings_json" | jq -r '.allow_overrides_to_approver_list_per_merge_request.value')"
        ;;
    legacy)
        allow_author="$(printf '%s' "$settings_json" | jq -r '.merge_requests_author_approval')"
        overrides_disabled="$(printf '%s' "$settings_json" | jq -r '.disable_overriding_approvers_per_merge_request')"
        if [[ "$overrides_disabled" == true ]]; then
            allow_overrides=false
        else
            allow_overrides=true
        fi
        ;;
esac

failures=0
if [[ "${rules_failed:-false}" == true ]]; then
    failures=$((failures + 1))
fi
if [[ "$allow_author" == false ]]; then
    printf '%s\n' 'PASS merge-request authors cannot self-approve'
else
    printf '%s\n' 'FAIL merge-request authors can self-approve'
    failures=$((failures + 1))
fi
if [[ "$allow_overrides" == false ]]; then
    printf '%s\n' 'PASS per-merge-request approval-rule overrides are disabled'
else
    printf '%s\n' 'FAIL per-merge-request approval-rule overrides are allowed'
    failures=$((failures + 1))
fi

if [[ "$failures" -eq 0 ]]; then
    printf '%s\n' 'PASS repository approval safeguards are enforced'
    exit 0
fi

printf '%s\n' 'FAIL repository approval safeguards need Maintainer action'
exit 1
