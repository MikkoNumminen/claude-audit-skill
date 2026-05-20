#!/usr/bin/env bash
# Bootstrap helper for first-time install of the mikko-* skill namespace on
# POSIX systems (macOS, Linux). Runs install.mjs with --adopt --force so any
# pre-existing mikko-* directories (which have no .mikko-install-source marker)
# get replaced rather than skipped.
#
# Usage:
#   bash bootstrap.sh                       # source defaults to this script's repo
#   bash bootstrap.sh --source PATH         # explicit source repo
#   bash bootstrap.sh --target project      # install to <cwd>/.claude/skills/ instead
#   bash bootstrap.sh --dry-run             # show what would happen
#
# After the first run, subsequent updates can use `/mikko-install` directly
# (the marker is in place; no --adopt needed).

set -euo pipefail

SOURCE=""
TARGET="user"
DRY_RUN=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)   SOURCE="$2"; shift 2 ;;
        --target)   TARGET="$2"; shift 2 ;;
        --dry-run)  DRY_RUN="--dry-run"; shift ;;
        -h|--help)
            sed -n 's/^# \{0,1\}//p' "$0" | head -n 14
            exit 0
            ;;
        *) echo "error: unknown arg '$1'" >&2; exit 2 ;;
    esac
done

# Default source: the repo this script lives in.
# .claude/skills/mikko-install/bootstrap.sh → repo root is three levels up.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$SOURCE" ]]; then
    SOURCE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

if [[ ! -d "$SOURCE/.claude/skills" ]]; then
    echo "error: source $SOURCE has no .claude/skills/ — wrong path?" >&2
    exit 3
fi

INSTALL_SCRIPT="$SOURCE/.claude/skills/mikko-install/install.mjs"
if [[ ! -f "$INSTALL_SCRIPT" ]]; then
    echo "error: install.mjs not found at $INSTALL_SCRIPT" >&2
    exit 3
fi

echo "mikko-* bootstrap"
echo "  flags : --adopt --force${DRY_RUN:+ $DRY_RUN}"
echo ""
# install.mjs prints source/target/method itself.

# shellcheck disable=SC2086  # DRY_RUN is intentionally word-split when set
exec node "$INSTALL_SCRIPT" \
    --source "$SOURCE" \
    --target "$TARGET" \
    --adopt --force \
    $DRY_RUN
