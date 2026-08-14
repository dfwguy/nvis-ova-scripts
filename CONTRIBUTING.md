# Contributing

## Verify changes locally

Run the same checks as CI before opening a merge request:

```
bash -n scripts/*.sh
shellcheck scripts/*.sh
find README.md docs -name '*.md' -print0 | xargs -0 perl scripts/check-markdown-links.pl
git diff --check
```

## Create a GitLab merge request

Push a topic branch, then normally create its merge request with `glab`:

```
git push --set-upstream origin <branch>
glab mr create --source-branch <branch> --target-branch main --fill
```

For this GitLab instance, `glab mr create` can return a false project `404`:
the path-form project API lookup fails even when the authenticated user owns
the repository. Use the numeric project ID instead. Discover it rather than
assuming it stays constant:

```
glab api 'projects?membership=true&search=nvis-ova-scripts&simple=true'
```

For this repository, the result currently has ID `419896`. Create the merge
request directly against that ID:

```
glab api --method POST 'projects/419896/merge_requests' \
  -f source_branch='<branch>' \
  -f target_branch='main' \
  -f title='<title>' \
  -f description='<description>'
```

The GitLab token needs `api` to create merge requests and `write_repository`
to push branches. Those scopes do not restrict a token below its account's
project role. To prevent automation from merging, use a separate Developer
account or project access token and protect `main` so only Maintainers may
merge.
