#!/usr/bin/env bash
# Copyright (C) 2014-2026 Laurier Sylph. All rights reserved.
#
# Copy the archive to the configured static host. The destination must
# serve the repository root as-is (dists/, pool/, key/).

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_cmd rsync

DEST="${1:-${DEPLOY_TARGET:-}}"
[[ -n "$DEST" ]] \
  || die "usage: $0 <dest>   e.g. $0 user@host:/srv/t3code   (or set DEPLOY_TARGET in conf/repo.conf)"

[[ -f "${DIST}/InRelease" ]] || die "nothing built yet: run make index"

log "checking archive before deploy"
scripts/check.sh

log "deploying ${ROOT}/ -> ${DEST}"
rsync -av --delete \
  --exclude 'secrets/' \
  --exclude 'tmp/' \
  --exclude '.git/' \
  --exclude '*.part' \
  "${ROOT}/" "${DEST}/"

log "deployed"
