# T3 Code APT Archive

Copyright (C) 2014-2026 Laurier Sylph. All rights reserved.

A git-managed, statically hosted APT archive that redistributes the
official T3 Code `.deb` builds published by
[pingdotgg/t3code](https://github.com/pingdotgg/t3code), with locally
generated and signed repository metadata.

This project is not affiliated with T3 Tools Inc. The packages are
unmodified upstream builds; see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## Layout

```text
conf/repo.conf                 archive settings (suite, arches, base URL)
scripts/keygen.sh              create the archive signing key
scripts/fetch.sh               download + verify upstream .deb files
scripts/verify.sh              re-check pool/ against pinned hashes
scripts/index.sh               build Packages/Release/InRelease + sign
scripts/check.sh               verify signatures and file references
scripts/install-hint.sh        print the apt setup snippet for BASE_URL
scripts/latest-version.sh      resolve the newest upstream release
scripts/prune.sh               keep only the newest N pool versions
scripts/prepare-site.sh        assemble the Pages site within budget
scripts/deploy.sh              rsync the archive to a static host
scripts/setup-git.sh           enable the repo's git hooks
scripts/hooks/pre-commit       block secrets/binaries, re-check signatures
key/t3code-archive-keyring.asc public signing key (safe to commit)
upstream/debs.sha256           pinned SHA256 of every redistributed .deb
pool/main/*.deb                upstream binaries (git-ignored, see below)
dists/stable/                  signed metadata (committed)
```

`pool/` is intentionally not tracked by git: each file is ~200 MB, above
GitHub's 100 MB per-file limit. The pinned hashes in `upstream/debs.sha256`
make the pool reproducible with `make fetch` on any host.

## Requirements

`git`, `gpg`, `dpkg-deb`, `apt-ftparchive` (package `apt-utils`), `curl`,
`jq`, `gzip`, `xz`.

## First-time setup

```sh
scripts/setup-git.sh     # enable the pre-commit guard (once per clone)
make key                 # create key material in secrets/gnupg (git-ignored)
make fetch VERSION=0.1.11
make index               # writes dists/stable and refreshes key/
make check
```

Set `BASE_URL` in `conf/repo.conf` to the public URL of this repository as
it will be served, then regenerate nothing else: the URL is only used by
`scripts/install-hint.sh` and the docs.

## Publishing

GitHub Actions builds, signs and publishes the archive to GitHub Pages on
every push to `main`, on a daily schedule, and on manual dispatch
(`.github/workflows/apt.yml`). The workflow needs one repository secret:

| Secret | Purpose |
| --- | --- |
| `APT_GPG_PRIVATE_KEY` | armored private signing key |
| `APT_GPG_PASSPHRASE` | key passphrase, only if the key has one |

Export the local key once and store it:

```sh
GNUPGHOME=secrets/gnupg gpg --armor --export-secret-keys laurier@sylph.re
```

The job fails if the imported key does not reproduce the committed
`key/t3code-archive-keyring.asc`, so a wrong or rotated key cannot
silently publish a repository clients already trust. Enable Pages with
source "GitHub Actions" in the repository settings.

The published site keeps the newest `KEEP_VERSIONS` releases (default 2)
and retries with fewer if the site would exceed 1 GB.

The repository root is also the web root for non-Pages hosting. Serve
these paths unchanged:

```text
/dists/stable/InRelease
/dists/stable/Release
/dists/stable/Release.gpg
/dists/stable/main/binary-amd64/Packages{,.gz,.xz}
/dists/stable/main/binary-arm64/Packages{,.gz,.xz}
/pool/main/*.deb
/key/t3code-archive-keyring.asc
```

Any static host works (nginx, Apache, S3/R2, GitHub Pages). For a local
smoke test:

```sh
make serve               # http://127.0.0.1:8080
```

To push a build out with rsync:

```sh
make deploy DEST=user@host:/srv/t3code
```

Then on a client machine, with `BASE_URL=https://sylphre.github.io/t3code-apt`
for the Pages deployment:

```sh
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSL -o /etc/apt/keyrings/t3code-archive-keyring.asc \
  "$BASE_URL/key/t3code-archive-keyring.asc"
echo "deb [signed-by=/etc/apt/keyrings/t3code-archive-keyring.asc] $BASE_URL stable main" \
  | sudo tee /etc/apt/sources.list.d/t3code.list
sudo apt-get update
sudo apt-get install t3code
```

`make hint` prints the same snippet with `BASE_URL` already substituted.

## Adding a new upstream version

```sh
make fetch VERSION=0.1.12
make index
make check
git add -A && git commit -m "t3code 0.1.12"
```

Old versions stay in the pool so apt can still resolve pinned downgrades.
Remove them from `pool/main` and `upstream/debs.sha256`, then re-run
`make index`, when they are no longer wanted.

## Signing key

`make key` creates a passphrase-less Ed25519 key named in `conf/repo.conf`
and writes the public half to `key/`. The private half stays in
`secrets/gnupg`, which is git-ignored and must be backed up: losing it
means clients must re-trust a new key.

Clients pin trust through `signed-by=`, so the key does not need to be in
`/etc/apt/trusted.gpg.d`.

## Verifying without apt

```sh
make verify    # pool files match upstream/debs.sha256
make check     # signatures valid, every Filename resolves
```
