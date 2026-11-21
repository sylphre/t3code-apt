#!/usr/bin/env bash
# Copyright (C) 2014-2026 Laurier Sylph. All rights reserved.
#
# Print the apt one-liner a user needs, with the configured BASE_URL.

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

key_url="${BASE_URL%/}/key/$(basename "$KEYRING_ASC")"

cat <<EOF
# Copyright (C) 2014-2026 Laurier Sylph. All rights reserved.

sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSL -o /etc/apt/keyrings/t3code-archive-keyring.asc '${key_url}'
echo "deb [signed-by=/etc/apt/keyrings/t3code-archive-keyring.asc] ${BASE_URL%/} ${SUITE} ${COMPONENT}" \\
  | sudo tee /etc/apt/sources.list.d/t3code.list >/dev/null
sudo apt-get update
sudo apt-get install t3code
EOF
