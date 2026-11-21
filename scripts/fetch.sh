#!/usr/bin/env bash
# Copyright (C) 2014-2026 Laurier Sylph. All rights reserved.
#
# Fetch the official T3 Code .deb builds for the configured architectures,
# verify each download against the SHA256 digest GitHub publishes for the
# release asset, and place it in pool/main. Verified hashes are pinned in
# upstream/debs.sha256 so the pool can be re-checked with `make verify`.

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_cmd curl sha256sum dpkg-deb awk mv sort jq

VERSION="${1:-}"
[[ -n "$VERSION" ]] || die "usage: $0 <version>   e.g. $0 0.1.11"

TAG="v${VERSION}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$POOL" "${ROOT}/upstream"
MANIFEST="${ROOT}/upstream/debs.sha256"
if [[ -f "$MANIFEST" ]]; then
  grep -q '^# Copyright' "$MANIFEST" \
    || die "manifest lost its header: upstream/debs.sha256"
else
  printf '# Copyright %s\n' "$COPYRIGHT" > "$MANIFEST"
fi

api="https://api.github.com/repos/${UPSTREAM_REPO}/releases/tags/${TAG}"
base="https://github.com/${UPSTREAM_REPO}/releases/download/${TAG}"

log "resolving upstream release ${TAG}"
curl -fsSL -H 'Accept: application/vnd.github+json' -o "$TMP/release.json" "$api" \
  || die "could not read release metadata for ${TAG}"

for arch in $ARCHES; do
  name="T3-Code-${VERSION}-${arch}.deb"
  dest="${POOL}/${name}"

  want="$(jq -r --arg n "$name" \
    '.assets[] | select(.name == $n) | .digest // "" | sub("^sha256:"; "")' \
    "$TMP/release.json")"
  [[ -n "$want" ]] || die "upstream release ${TAG} has no digest for ${name}"

  if [[ -f "$dest" ]]; then
    got="$(sha256sum "$dest" | cut -d' ' -f1)"
    [[ "$got" == "$want" ]] \
      || die "existing pool file differs from upstream: ${name}"
    log "already present and verified: pool/${COMPONENT}/${name}"
  else
    log "downloading ${name}"
    curl -fL --retry 3 --progress-bar -o "$dest.part" "${base}/${name}" \
      || { rm -f "$dest.part"; die "download failed: ${name}"; }

    got="$(sha256sum "$dest.part" | cut -d' ' -f1)"
    if [[ "$got" != "$want" ]]; then
      rm -f "$dest.part"
      die "checksum mismatch for ${name}: expected ${want}, got ${got}"
    fi
    mv "$dest.part" "$dest"
    log "verified ${name} (sha256 ${got})"
  fi

  if ! grep -qF "  ${name}" "$MANIFEST"; then
    printf '%s  %s\n' "$want" "$name" >> "$MANIFEST"
    # Keep the copyright header first while ordering the hash lines.
    { head -1 "$MANIFEST"; tail -n +2 "$MANIFEST" | sort; } > "$MANIFEST.new"
    mv "$MANIFEST.new" "$MANIFEST"
  fi
done

pkg="$(dpkg-deb -f "${POOL}/T3-Code-${VERSION}-amd64.deb" Package)"
log "pool entry: package ${pkg} version ${VERSION}"
log "next: make index"
