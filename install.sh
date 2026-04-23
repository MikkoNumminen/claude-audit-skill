#!/usr/bin/env bash
# Install the `audit` skill into a Claude Code skills directory.
#
# Two targets:
#   --target user              ~/.claude/skills/audit   (available in every project)
#   --target project --repo P  P/.claude/skills/audit   (project-local)
#
# Idempotent: re-running updates the symlink without duplicating.
# Refuses to overwrite an existing non-symlink directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="${SCRIPT_DIR}/skill"

if [[ ! -d "${SKILL_SRC}" ]]; then
    echo "error: skill source not found at ${SKILL_SRC}" >&2
    exit 1
fi

TARGET=""
REPO=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET="$2"
            shift 2
            ;;
        --repo)
            REPO="$2"
            shift 2
            ;;
        -h|--help)
            sed -n 's/^# \{0,1\}//p' "$0" | head -n 10
            exit 0
            ;;
        *)
            echo "error: unknown argument '$1'" >&2
            exit 2
            ;;
    esac
done

if [[ "${TARGET}" == "user" ]]; then
    DEST="${HOME}/.claude/skills/audit"
elif [[ "${TARGET}" == "project" ]]; then
    if [[ -z "${REPO}" ]]; then
        echo "error: --target project requires --repo PATH" >&2
        exit 2
    fi
    if [[ ! -d "${REPO}" ]]; then
        echo "error: repo not found: ${REPO}" >&2
        exit 2
    fi
    DEST="${REPO%/}/.claude/skills/audit"
else
    echo "error: --target must be 'user' or 'project'" >&2
    exit 2
fi

DEST_PARENT="$(dirname "${DEST}")"
mkdir -p "${DEST_PARENT}"

if [[ -L "${DEST}" ]]; then
    LINK_TARGET="$(readlink "${DEST}")"
    if [[ "${LINK_TARGET}" == "${SKILL_SRC}" ]]; then
        echo "ok: symlink already present and correct -> ${DEST}"
        exit 0
    fi
    echo "replacing existing symlink (-> ${LINK_TARGET})"
    rm "${DEST}"
elif [[ -e "${DEST}" ]]; then
    echo "error: ${DEST} exists and is not a symlink. Refusing to overwrite." >&2
    echo "       Remove or rename it manually, then rerun." >&2
    exit 3
fi

ln -s "${SKILL_SRC}" "${DEST}"
echo "installed: ${DEST} -> ${SKILL_SRC}"
