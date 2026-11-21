#!/usr/bin/env bash
# Copyright (C) 2014-2026 Laurier Sylph. All rights reserved.
#
# Check the published archive the way an apt client sees it: verify both
# signatures, parse each Packages file, and confirm every listed file exists.

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_cmd gpgv gpg awk find

[[ -f "${DIST}/InRelease" ]] || die "missing ${DIST#"$ROOT"/}/InRelease"
[[ -f "${DIST}/Release.gpg" ]] || die "missing ${DIST#"$ROOT"/}/Release.gpg"
[[ -f "$KEYRING_ASC" ]] || die "missing key/$(basename "$KEYRING_ASC")"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# gpgv wants a binary keyring; apt accepts the armored .asc directly.
gpg --batch --quiet --dearmor < "$KEYRING_ASC" > "$work/keyring.gpg"

gpgv --keyring "$work/keyring.gpg" "${DIST}/InRelease" 2>"$work/err" \
  || { cat "$work/err" >&2; die "InRelease signature check failed"; }
log "InRelease signature valid"

gpgv --keyring "$work/keyring.gpg" "${DIST}/Release.gpg" "${DIST}/Release" \
  >/dev/null 2>"$work/err" \
  || { cat "$work/err" >&2; die "Release.gpg signature check failed"; }
log "Release.gpg signature valid"

for arch in $ARCHES; do
  list="${DIST}/${COMPONENT}/binary-${arch}/Packages"
  [[ -f "$list" ]] || die "missing Packages for ${arch}"

  count=0
  while read -r file; do
    [[ -f "${ROOT}/${file}" ]] || die "Packages references missing file: ${file}"
    count=$((count + 1))
  done < <(awk '/^Filename: / { print $2 }' "$list")

  [[ "$count" -gt 0 ]] || die "no packages listed for ${arch}"
  log "${arch}: ${count} package(s), all files present"
done

log "archive checks passed"
