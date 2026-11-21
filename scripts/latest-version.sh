#!/usr/bin/env bash
# Copyright (C) 2014-2026 Laurier Sylph. All rights reserved.
#
# Print the newest upstream version that ships .deb builds for every
# configured architecture. Used by CI when no version is supplied.

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_cmd curl jq awk

api="https://api.github.com/repos/${UPSTREAM_REPO}/releases?per_page=40"
curl -fsSL -H 'Accept: application/vnd.github+json' "$api" > "${TMPDIR:-/tmp}/t3-releases.json"

version="$(jq -r --arg suffix_amd64 '-amd64.deb' --arg suffix_arm64 '-arm64.deb' '
  [ .[] | select(.draft == false and .prerelease == false) ]
  | map(select(
      ([.assets[].name] | any(endswith($suffix_amd64)))
      and ([.assets[].name] | any(endswith($suffix_arm64)))
    ))
  | first
  | .tag_name // empty
' "${TMPDIR:-/tmp}/t3-releases.json" | sed -E 's/^v//')"

[[ -n "$version" ]] || die "no upstream release with .deb assets found"

printf '%s\n' "$version"
