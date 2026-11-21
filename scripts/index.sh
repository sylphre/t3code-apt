#!/usr/bin/env bash
# Copyright (C) 2014-2026 Laurier Sylph. All rights reserved.
#
# Rebuild dists/stable from pool/main: Packages (+ .gz/.xz) per
# architecture, a Release file carrying the copyright field, and the
# detached/clearsigned InRelease used by apt. Needs the signing key.

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_cmd apt-ftparchive gzip xz gpg awk find

[[ -d "$POOL" ]] || die "no pool yet: run scripts/fetch.sh <version>"
find "$POOL" -maxdepth 1 -name '*.deb' -print -quit | grep -q . \
  || die "pool is empty: run scripts/fetch.sh <version>"

gpg --batch --list-secret-keys "$KEY_UID" >/dev/null 2>&1 \
  || die "signing key not found: run scripts/keygen.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# apt-ftparchive's --arch filter parses the architecture out of the file name,
# which upstream does not follow (T3-Code-<ver>-<arch>.deb), so index once and
# split the stanzas ourselves by their Architecture field. Run from the repo
# root so the recorded Filename stays relative (pool/main/...) to BASE_URL.
(cd "$ROOT" && apt-ftparchive packages "pool/${COMPONENT}") > "$work/Packages.all"

for arch in $ARCHES; do
  dir="${DIST}/${COMPONENT}/binary-${arch}"
  mkdir -p "$dir"

  awk -v a="$arch" -v copy="$(copyright_field)" '
    BEGIN { RS = ""; ORS = "\n\n" }
    index($0, "\nArchitecture: " a "\n") || $0 ~ ("^Architecture: " a "\n") {
      print $0 "\n" copy
    }
  ' "$work/Packages.all" > "$dir/Packages"

  [[ -s "$dir/Packages" ]] || die "no ${arch} packages found in ${POOL#"$ROOT"/}"

  gzip -9nkc "$dir/Packages" > "$dir/Packages.gz"
  xz -6e -c "$dir/Packages" > "$dir/Packages.xz"
done

# apt-ftparchive only passes through the fields it knows, so add the
# copyright field to Release after it is generated. Drop the old signed
# files first: apt-ftparchive would otherwise hash the previous Release
# and Release.gpg into the new one.
rm -f "${DIST}/Release" "${DIST}/InRelease" "${DIST}/Release.gpg"
{
  copyright_field
  apt-ftparchive \
    -o "APT::FTPArchive::Release::Origin=${ORIGIN}" \
    -o "APT::FTPArchive::Release::Label=${LABEL}" \
    -o "APT::FTPArchive::Release::Suite=${SUITE}" \
    -o "APT::FTPArchive::Release::Codename=${CODENAME}" \
    -o "APT::FTPArchive::Release::Components=${COMPONENT}" \
    -o "APT::FTPArchive::Release::Architectures=${ARCHES}" \
    -o "APT::FTPArchive::Release::Description=${DESCRIPTION}" \
    release "$DIST"
} > "$work/Release"

cp "$work/Release" "${DIST}/Release"

gpg --batch --quiet --yes --local-user "$KEY_UID" --digest-algo SHA256 \
  --clearsign -o "${DIST}/InRelease" "${DIST}/Release"
gpg --batch --quiet --yes --local-user "$KEY_UID" --digest-algo SHA256 \
  --armor --detach-sign -o "${DIST}/Release.gpg" "${DIST}/Release"

gpg --batch --quiet --yes --armor --export "$KEY_UID" \
  | sed "2i Comment: Copyright ${COPYRIGHT}" \
  > "$KEYRING_ASC"

log "generated ${DIST#"$ROOT"/}: Packages, Release, InRelease, Release.gpg"
log "published keyring: key/$(basename "$KEYRING_ASC")"
