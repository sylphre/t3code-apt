#!/usr/bin/env bash
# Copyright (C) 2014-2026 Laurier Sylph. All rights reserved.
#
# Enable the repository's git hooks. Run once per clone.

set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_cmd git
cd "$ROOT"

git config core.hooksPath scripts/hooks
log "core.hooksPath -> scripts/hooks"
log "hooks: $(find scripts/hooks -maxdepth 1 -type f -printf '%f ' 2>/dev/null)"
