#!/usr/bin/env bash
# Copyright (C) 2014-2026 Laurier Sylph. All rights reserved.
#
# Create the archive signing key if it does not exist yet.

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_cmd gpg

mkdir -p "$GNUPGHOME" "$(dirname "$KEYRING_ASC")"
chmod 700 "$GNUPGHOME"

if gpg --batch --list-secret-keys "$KEY_UID" >/dev/null 2>&1; then
  log "signing key already present: $KEY_UID"
  exit 0
fi

log "creating signing key: $KEY_UID"
gpg --batch --quiet --pinentry-mode loopback --passphrase '' \
  --quick-gen-key "$KEY_UID" ed25519 sign never

gpg --batch --quiet --armor --export "$KEY_UID" \
  | sed "2i Comment: Copyright ${COPYRIGHT}" \
  > "$KEYRING_ASC"

log "public key written to key/$(basename "$KEYRING_ASC")"
