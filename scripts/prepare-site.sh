#!/usr/bin/env bash
# Copyright (C) 2014-2026 Laurier Sylph. All rights reserved.
#
# Assemble the static site that GitHub Pages publishes. Pages caps a
# published site at 1 GB, so when the requested number of retained
# versions does not fit, older versions are pruned and the metadata is
# rebuilt until it does.

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_cmd cp du awk find

OUT="${1:-}"
KEEP="${2:-2}"
LIMIT_MB="${SITE_LIMIT_MB:-950}"

[[ -n "$OUT" ]] || die "usage: $0 <output-dir> [keep-versions]"

size_mb() {
  du -sm "$1" | awk '{ print $1 }'
}

assemble() {
  rm -rf "$OUT"
  mkdir -p "$OUT"
  cp -a "${ROOT}/dists" "${ROOT}/pool" "${ROOT}/key" "$OUT/"
  : > "$OUT/.nojekyll"
  printf '%s\n' 'T3 Code APT archive' > "$OUT/index.html"
  printf '%s\n' 'User-agent: *' 'Disallow: /' > "$OUT/robots.txt"
}

keep="$KEEP"
while :; do
  scripts/prune.sh "$keep" >/dev/null 2>&1 || true
  scripts/index.sh >/dev/null
  scripts/check.sh >/dev/null
  assemble

  mb="$(size_mb "$OUT")"
  log "site with last ${keep} version(s): ${mb} MB"
  if [[ "$mb" -le "$LIMIT_MB" ]]; then
    break
  fi

  if [[ "$keep" -le 1 ]]; then
    die "site is ${mb} MB, over the ${LIMIT_MB} MB budget even with one version"
  fi

  next=$((keep - 1))
  log "over budget, retrying with last ${next} version(s)"
  keep="$next"
done

log "site ready: ${OUT}"
