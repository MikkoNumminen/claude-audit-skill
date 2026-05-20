#!/usr/bin/env bash
# One-command setup for the claude-skills repo on macOS / Linux (and Git Bash
# on Windows). Installs both layouts in this repo:
#
#   1. The legacy audit skill (via install.sh)
#   2. The mikko-* skill namespace (via .claude/skills/mikko-install/bootstrap.sh)
#
# By default the script asks whether to install user-wide or project-only.
# Pass --target explicitly to skip the prompt.
#
# Usage:
#   bash setup.sh                       # prompt user-wide vs project
#   bash setup.sh --target user         # install user-wide (~/.claude/skills/)
#   bash setup.sh --target project      # install into $(pwd)/.claude/skills/
#   bash setup.sh --yes                 # skip every prompt; default to user-wide
#   bash setup.sh --dry-run             # preview, write nothing
#
# Prereqs:
#   - bash 3.2+ (macOS-stock bash is fine)
#   - node 18+ (for the mikko-* installer)

set -euo pipefail

TARGET=""
YES=""
DRY_RUN=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            [[ -z "${2:-}" || "$2" == --* ]] && { echo "error: --target requires a value (user|project)" >&2; exit 2; }
            TARGET="$2"; shift 2
            ;;
        --yes|-y)   YES="yes"; shift ;;
        --dry-run)  DRY_RUN="--dry-run"; shift ;;
        -h|--help)
            sed -n 's/^# \{0,1\}//p' "$0" | head -n 22
            exit 0
            ;;
        *) echo "error: unknown arg '$1'" >&2; exit 2 ;;
    esac
done

# Check Node — the mikko-* installer needs it.
if ! command -v node >/dev/null 2>&1; then
    echo "error: Node.js (>=18) is required." >&2
    echo "       Install from https://nodejs.org and re-run." >&2
    exit 3
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve target — prompt if not given and we're interactive.
if [[ -z "$TARGET" ]]; then
    if [[ -n "$YES" || ! -t 0 ]]; then
        TARGET="user"
    else
        echo "Where should the skills be installed?"
        echo "  1) user-wide   — ~/.claude/skills/         (available in every project) [default]"
        echo "  2) project-only — $(pwd)/.claude/skills/   (available only when Claude Code runs here)"
        echo ""
        read -r -p "Pick 1 or 2 [1]: " choice
        case "${choice:-1}" in
            1|user)    TARGET="user" ;;
            2|project) TARGET="project" ;;
            *)         echo "Invalid choice. Aborted." >&2; exit 2 ;;
        esac
    fi
fi

if [[ "$TARGET" != "user" && "$TARGET" != "project" ]]; then
    echo "error: --target must be 'user' or 'project', got '$TARGET'" >&2
    exit 2
fi

echo ""
echo "claude-skills setup"
echo "  target : $TARGET"
[[ -n "$DRY_RUN" ]] && echo "  mode   : dry-run (nothing will be written)"
echo ""

# 1. Legacy audit skill via install.sh.
echo "[1/2] audit skill..."
INSTALL_ARGS=("--target" "$TARGET")
[[ "$TARGET" == "project" ]] && INSTALL_ARGS+=("--repo" "$(pwd)")
[[ -n "$DRY_RUN" ]] && INSTALL_ARGS+=("--dry-run")
bash "$REPO_ROOT/install.sh" "${INSTALL_ARGS[@]}"

# 2. mikko-* namespace via bootstrap.sh.
echo ""
echo "[2/2] mikko-* namespace..."
BOOTSTRAP_ARGS=("--source" "$REPO_ROOT" "--target" "$TARGET")
[[ -n "$YES" ]] && BOOTSTRAP_ARGS+=("--yes")
[[ -n "$DRY_RUN" ]] && BOOTSTRAP_ARGS+=("--dry-run")

bash "$REPO_ROOT/.claude/skills/mikko-install/bootstrap.sh" "${BOOTSTRAP_ARGS[@]}"

echo ""
if [[ -n "$DRY_RUN" ]]; then
    echo "Dry-run complete — nothing was written."
else
    echo "Done. Restart Claude Code, then type /mikko-help in any project to confirm."
fi
