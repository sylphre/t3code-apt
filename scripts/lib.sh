#!/usr/bin/env bash
# Copyright (C) 2014-2026 Laurier Sylph. All rights reserved.
#
# Shared helpers for the T3 Code APT archive scripts.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT

# shellcheck source=../conf/repo.conf
# shellcheck disable=SC1091
source "${ROOT}/conf/repo.conf"

POOL="${ROOT}/pool/${COMPONENT}"
DIST="${ROOT}/dists/${SUITE}"
KEYRING_ASC="${ROOT}/key/t3code-archive-keyring.asc"
export POOL DIST KEYRING_ASC

export GNUPGHOME

log() { printf '[t3-apt] %s\n' "$*" >&2; }
die() { printf '[t3-apt] error: %s\n' "$*" >&2; exit 1; }

require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "required command not found: $c"
  done
}

# Copyright notice as a control field, accepted in Packages and Release files.
copyright_field() {
  printf 'Copyright: %s\n' "$COPYRIGHT"
}
