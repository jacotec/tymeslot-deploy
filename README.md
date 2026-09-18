# tymeslot-deploy

Builds `ghcr.io/jacotec/tymeslot`: the latest [Tymeslot](https://github.com/Tymeslot/tymeslot)
release with the branches of the fork [jacotec/tymeslot](https://github.com/jacotec/tymeslot)
listed in [`branches.txt`](branches.txt) merged on top. The image is built from the
upstream `Dockerfile.docker` (default target, bundled PostgreSQL), so it replaces
`luka1thb/tymeslot` one to one.

## Tags

| Tag | Meaning |
|---|---|
| `deploy` | Latest build |
| `<version>-deploy` | Build on top of release `<version>`, e.g. `1.15.8-deploy` |

## How a build runs

[`.github/workflows/build.yml`](.github/workflows/build.yml) runs nightly and on demand
(**Actions → Build deploy image → Run workflow**, with *force* to rebuild anyway).

1. It fingerprints the latest upstream release tag, the head commit of every listed
   branch and the contents of this repository's scripts and `rr-cache/`, and compares
   the fingerprint with the label on the published `deploy` image. Nightly runs stop
   here when nothing changed.
2. [`scripts/assemble.sh`](scripts/assemble.sh) checks out the release tag and merges
   the branches in order.
3. The Gettext catalogues are regenerated (`mix gettext.extract --merge`); a fuzzy
   entry fails the run.
4. `mix compile --warnings-as-errors` and `mix test` run on the assembled tree.
5. The image is built for `linux/amd64` and pushed.

## Merge conflicts

The branches are independent upstream pull requests, so merging them together can
conflict:

- **Gettext catalogues** (`.po`/`.pot`) are resolved automatically by
  [`scripts/resolve_po.py`](scripts/resolve_po.py): both sides are kept, and the
  catalogues are regenerated afterwards.
- **Everything else** is resolved with `git rerere` from the resolutions recorded in
  [`rr-cache/`](rr-cache). A conflict with no recorded resolution fails the run and
  names the files.

To record a new resolution:

```sh
scripts/assemble.sh /tmp/deploy          # stops at the unresolved conflict
cd /tmp/deploy
# resolve the listed files, then:
git rerere                               # records the resolution
cp -R .git/rr-cache/. <this repo>/rr-cache/
```

Only commit the entries for the conflict you resolved (not the ones git also recorded
for `.po` files), then run `scripts/assemble.sh` again until it completes.

Running `assemble.sh` locally needs git and Python 3. `RELEASE_TAG` builds on a
different release.
