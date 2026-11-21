#!/usr/bin/env bash
# Copyright (C) 2014-2026 Laurier Sylph. All rights reserved.
#
# Verify that every .deb in the pool is pinned in upstream/debs.sha256 and
# still matches its recorded SHA256.

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_cmd sha256sum find grep

MANIFEST="${ROOT}/upstream/debs.sha256"
[[ -f "$MANIFEST" ]] || die "missing manifest: upstream/debs.sha256"
[[ -d "$POOL" ]] || die "no pool yet: run scripts/fetch.sh <version>"

status=0
while IFS= read -r -d '' deb; do
  name="$(basename "$deb")"
  if ! grep -qF "  ${name}" "$MANIFEST"; then
    log "unpinned package in pool: ${name}"
    status=1
  fi
done < <(find "$POOL" -maxdepth 1 -name '*.deb' -print0)

[[ "$status" -eq 0 ]] || die "verification failed: pin or remove the files above"

(cd "$POOL" && sha256sum -c --ignore-missing --quiet "$MANIFEST") \
  || die "checksum mismatch against upstream/debs.sha256"

log "all pool packages are pinned and match upstream/debs.sha256"
