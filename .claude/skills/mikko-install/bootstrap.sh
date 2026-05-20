#!/usr/bin/env bash
# Bootstrap helper for first-time install of the mikko-* skill namespace on
# POSIX systems (macOS, Linux). Runs install.mjs with --adopt --force so any
# pre-existing mikko-* directories (which have no .mikko-install-source marker)
# get replaced rather than skipped.
#
# By default the script does a dry-run first, shows what would change, and
# prompts before applying. Pass --yes to skip the prompt (e.g. for CI).
#
# Usage:
#   bash bootstrap.sh                       # source defaults to this script's repo
#   bash bootstrap.sh --source PATH         # explicit source repo
#   bash bootstrap.sh --target project      # install to <cwd>/.claude/skills/ instead
#   bash bootstrap.sh --yes                 # skip the confirmation prompt
#   bash bootstrap.sh --dry-run             # show what would happen, do NOT apply
#
# After the first run, subsequent updates can use `/mikko-install` directly
# (the marker is in place; no --adopt needed).

set -euo pipefail

SOURCE=""
TARGET="user"
DRY_RUN=""
YES=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)   SOURCE="$2"; shift 2 ;;
        --target)   TARGET="$2"; shift 2 ;;
        --dry-run)  DRY_RUN="--dry-run"; shift ;;
        --yes|-y)   YES="yes"; shift ;;
        -h|--help)
            sed -n 's/^# \{0,1\}//p' "$0" | head -n 18
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

# If the user explicitly passed --dry-run, just do that and exit.
if [[ -n "$DRY_RUN" ]]; then
    exec node "$INSTALL_SCRIPT" \
        --source "$SOURCE" --target "$TARGET" \
        --adopt --force --dry-run
fi

# Otherwise: dry-run first to show what would happen.
echo "Preview (dry-run):"
echo ""
OUTPUT=$(node "$INSTALL_SCRIPT" \
    --source "$SOURCE" --target "$TARGET" \
    --adopt --force --dry-run 2>&1)
echo "$OUTPUT"
echo ""

# Anything actually changing?
if ! echo "$OUTPUT" | grep -qE 'would (install|update|adopt)'; then
    echo "Nothing to do — all up-to-date."
    exit 0
fi

# Prompt unless --yes.
if [[ -z "$YES" ]]; then
    read -r -p "Proceed with these changes? [y/N] " response
    case "$response" in
        [yY]|[yY][eE][sS]) ;;
        *) echo "Aborted — nothing changed."; exit 0 ;;
    esac
fi

echo ""
exec node "$INSTALL_SCRIPT" \
    --source "$SOURCE" --target "$TARGET" \
    --adopt --force
