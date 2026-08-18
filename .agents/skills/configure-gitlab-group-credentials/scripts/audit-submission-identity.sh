#!/usr/bin/env bash
# Verify current and branch commit metadata against an intended GitLab identity.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: audit-submission-identity.sh (--from-token | --expected-name NAME --expected-email EMAIL) [--base REF] [WORKSPACE]

Check the repository-local Git identity and every commit after BASE. With
--from-token, derive the expected name and commit email from `glab api user`
without displaying the token. BASE defaults to origin/HEAD, then origin/main.

This audit checks commit author and committer metadata. Push and merge-request
actors are separate GitLab identities and must be checked independently.
EOF
}

from_token=false
expected_name=''
expected_email=''
base_ref=''
while [[ $# -gt 0 ]]; do
    case "$1" in
        --from-token)
            from_token=true
            shift
            ;;
        --expected-name)
            [[ $# -ge 2 ]] || { usage >&2; exit 2; }
            expected_name="$2"
            shift 2
            ;;
        --expected-email)
            [[ $# -ge 2 ]] || { usage >&2; exit 2; }
            expected_email="$2"
            shift 2
            ;;
        --base)
            [[ $# -ge 2 ]] || { usage >&2; exit 2; }
            base_ref="$2"
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
            printf 'error: unknown option: %s\n' "$1" >&2
            exit 2
            ;;
        *)
            break
            ;;
    esac
done

[[ $# -le 1 ]] || { usage >&2; exit 2; }
workspace="${1:-$PWD}"
workspace="$(cd "$workspace" && pwd -P)"
git -C "$workspace" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    printf 'error: not a Git worktree: %s\n' "$workspace" >&2
    exit 2
}

if [[ "$from_token" == true ]]; then
    [[ -z "$expected_name" && -z "$expected_email" ]] || {
        printf '%s\n' 'error: --from-token cannot be combined with explicit identity fields' >&2
        exit 2
    }
    command -v glab >/dev/null 2>&1 || {
        printf '%s\n' 'error: glab is required with --from-token' >&2
        exit 2
    }
    identity_json="$(cd "$workspace" && glab api user)"
    expected_name="$(printf '%s' "$identity_json" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')"
    expected_email="$(printf '%s' "$identity_json" | sed -n 's/.*"commit_email":"\([^"]*\)".*/\1/p')"
    unset identity_json
else
    [[ -n "$expected_name" && -n "$expected_email" ]] || {
        printf '%s\n' 'error: provide --from-token or both expected identity fields' >&2
        exit 2
    }
fi

[[ -n "$expected_name" && -n "$expected_email" ]] || {
    printf '%s\n' 'error: expected identity could not be resolved' >&2
    exit 2
}

if [[ -z "$base_ref" ]]; then
    base_ref="$(git -C "$workspace" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    [[ -n "$base_ref" ]] || base_ref='origin/main'
fi
git -C "$workspace" rev-parse --verify "${base_ref}^{commit}" >/dev/null 2>&1 || {
    printf 'error: base ref is unavailable: %s\n' "$base_ref" >&2
    exit 2
}

failures=0
actual_name="$(git -C "$workspace" config --get user.name || true)"
actual_email="$(git -C "$workspace" config --get user.email || true)"
if [[ "$actual_name" == "$expected_name" && "$actual_email" == "$expected_email" ]]; then
    printf 'PASS future commits use %s <%s>\n' "$expected_name" "$expected_email"
else
    printf 'FAIL future commits use %s <%s>; expected %s <%s>\n' \
        "$actual_name" "$actual_email" "$expected_name" "$expected_email"
    failures=$((failures + 1))
fi

mismatched_commits=0
while IFS=$'\t' read -r commit_hash author_name author_email committer_name committer_email; do
    [[ -n "$commit_hash" ]] || continue
    if [[ "$author_name" != "$expected_name" || "$author_email" != "$expected_email" \
        || "$committer_name" != "$expected_name" || "$committer_email" != "$expected_email" ]]; then
        printf 'FAIL %s author=%s <%s> committer=%s <%s>\n' \
            "$commit_hash" "$author_name" "$author_email" "$committer_name" "$committer_email"
        mismatched_commits=$((mismatched_commits + 1))
    fi
done < <(git -C "$workspace" log --reverse --format='%h%x09%an%x09%ae%x09%cn%x09%ce' "${base_ref}..HEAD")

if [[ "$mismatched_commits" -eq 0 ]]; then
    printf 'PASS commits after %s match the expected identity\n' "$base_ref"
else
    printf 'FAIL %d commit(s) after %s have different metadata\n' "$mismatched_commits" "$base_ref"
    failures=$((failures + 1))
fi

if [[ "$failures" -eq 0 ]]; then
    printf '%s\n' 'PASS commit submission identity is consistent'
    exit 0
fi

printf '%s\n' 'FAIL resolve identity mismatches before commit, push, or merge'
exit 1
