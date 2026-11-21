#!/usr/bin/env bash
# Copyright (C) 2014-2026 Laurier Sylph. All rights reserved.
#
# Keep only the newest N package versions in pool/main so a Pages site
# stays under its 1 GB publishing limit. The manifest is trimmed to match.

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_cmd awk sort find basename

KEEP="${1:-2}"
if [[ ! "$KEEP" =~ ^[0-9]+$ ]] || [[ "$KEEP" -lt 1 ]]; then
  die "usage: $0 <keep-count>   e.g. $0 2"
fi

MANIFEST="${ROOT}/upstream/debs.sha256"
[[ -f "$MANIFEST" ]] || die "missing manifest: upstream/debs.sha256"

mapfile -t versions < <(
  find "$POOL" -maxdepth 1 -name 'T3-Code-*-*.deb' -printf '%f\n' \
    | sed -E 's/^T3-Code-(.+)-(amd64|arm64)\.deb$/\1/' \
    | sort -uV
)

[[ "${#versions[@]}" -gt 0 ]] || { log "pool is empty, nothing to prune"; exit 0; }

mapfile -t keep_list < <(printf '%s\n' "${versions[@]}" | tail -n "$KEEP")
drop_set="$(printf '%s\n' "${versions[@]}" | head -n -"$KEEP" || true)"

if [[ -z "$drop_set" ]]; then
  log "pool already within the last ${KEEP} version(s)"
  exit 0
fi

while IFS= read -r v; do
  [[ -n "$v" ]] || continue
  for arch in $ARCHES; do
    f="${POOL}/T3-Code-${v}-${arch}.deb"
    if [[ -f "$f" ]]; then
      rm -f "$f"
      log "pruned pool/${COMPONENT}/$(basename "$f")"
    fi
  done
done <<< "$drop_set"

tmp="$(mktemp)"
{
  head -1 "$MANIFEST"
  while IFS= read -r line; do
    [[ "$line" =~ ^# ]] && continue
    name="${line##*  }"
    for v in "${keep_list[@]}"; do
      [[ "$name" == "T3-Code-${v}-"* ]] && printf '%s\n' "$line" && break
    done
  done < <(tail -n +2 "$MANIFEST" | sort)
} > "$tmp"
mv "$tmp" "$MANIFEST"

log "kept versions: $(printf '%s ' "${keep_list[@]}")"
log "next: make index"
