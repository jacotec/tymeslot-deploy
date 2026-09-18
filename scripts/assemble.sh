#!/usr/bin/env bash
# Assembles the deploy tree in DIR (default: ./src): the latest upstream
# release tag with every branch listed in branches.txt merged on top, in order.
#
# Conflicts are resolved automatically where that is safe:
#   - git rerere replays resolutions recorded in rr-cache/ (see README),
#   - Gettext catalogues (.po/.pot) are resolved by scripts/resolve_po.py.
# Any other conflict stops the run with a list of the files involved.
#
# Environment:
#   FORK_URL      fork to take the branches from (default jacotec/tymeslot)
#   UPSTREAM_URL  upstream to take the release tag from (default Tymeslot/tymeslot)
#   RELEASE_TAG   build on this tag instead of the latest release
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
dir=${1:-src}
fork_url=${FORK_URL:-https://github.com/jacotec/tymeslot.git}
upstream_url=${UPSTREAM_URL:-https://github.com/Tymeslot/tymeslot.git}

branches=$(grep -vE '^\s*(#|$)' "$here/branches.txt")

if [ ! -d "$dir/.git" ]; then
  git clone --quiet --no-checkout "$fork_url" "$dir"
fi
cd "$dir"

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$upstream_url"
git fetch --quiet origin
git fetch --quiet --tags upstream

tag=${RELEASE_TAG:-$(git tag -l 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)}
echo "Release: $tag"

git config user.name "tymeslot-deploy"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git config rerere.enabled true
git config rerere.autoupdate true
mkdir -p .git/rr-cache
if [ -d "$here/rr-cache" ]; then
  cp -R "$here/rr-cache/." .git/rr-cache/
fi

git checkout --quiet --force -B deploy "refs/tags/$tag"

for branch in $branches; do
  echo "Merging $branch ($(git rev-parse --short "origin/$branch"))"

  if git merge --quiet --no-ff --no-edit -m "Merge $branch into deploy" "origin/$branch" >/dev/null 2>&1; then
    continue
  fi

  unresolved=$(git diff --name-only --diff-filter=U)
  others=$(printf '%s\n' "$unresolved" | grep -vE '\.pot?$' || true)

  if [ -n "$others" ]; then
    echo "::error::Unresolved conflicts merging $branch:"
    printf '  %s\n' $others
    exit 1
  fi

  if [ -n "$unresolved" ]; then
    python3 "$here/scripts/resolve_po.py" $unresolved
    git add $unresolved
  fi

  git commit --quiet --no-edit
done

echo "Assembled $(git rev-parse --short HEAD) from $tag + $(echo "$branches" | wc -l) branches"
