#!/usr/bin/env bash
# Install the single `audit` skill (sourced from skill/SKILL.md in this repo)
# into a Claude Code skills directory. This script handles ONLY that skill.
#
# For the mikko-* skill namespace under .claude/skills/mikko-*/, use the
# `mikko-install` skill instead; its companion script lives at
# .claude/skills/mikko-install/install.mjs. The two installers are independent
# and this one is not deprecated — it still works as documented below.
#
# Two targets:
#   --target user              ~/.claude/skills/audit   (available in every project)
#   --target project --repo P  P/.claude/skills/audit   (project-local)
#
# Flags:
#   --dry-run                  Preview the install. Runs the same arg parsing,
#                              source/dest resolution, and existence checks as
#                              a real install; prints what would happen and
#                              exits with the same exit code the real run would
#                              produce (e.g. 3 if dest exists and isn't a symlink).
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
DRY_RUN=""

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
        --dry-run)
            DRY_RUN="yes"
            shift
            ;;
        -h|--help)
            sed -n 's/^# \{0,1\}//p' "$0" | head -n 18
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
if [[ -z "${DRY_RUN}" ]]; then
    mkdir -p "${DEST_PARENT}"
fi

if [[ -L "${DEST}" ]]; then
    LINK_TARGET="$(readlink "${DEST}")"
    if [[ "${LINK_TARGET}" == "${SKILL_SRC}" ]]; then
        if [[ -n "${DRY_RUN}" ]]; then
            echo "already up-to-date: ${DEST}"
        else
            echo "ok: symlink already present and correct -> ${DEST}"
        fi
        exit 0
    fi
    if [[ -n "${DRY_RUN}" ]]; then
        echo "would replace existing symlink (-> ${LINK_TARGET}) with -> ${SKILL_SRC}"
        exit 0
    fi
    echo "replacing existing symlink (-> ${LINK_TARGET})"
    rm "${DEST}"
elif [[ -e "${DEST}" ]]; then
    if [[ -n "${DRY_RUN}" ]]; then
        echo "would refuse: ${DEST} exists and is not a symlink" >&2
        exit 3
    fi
    echo "error: ${DEST} exists and is not a symlink. Refusing to overwrite." >&2
    echo "       Remove or rename it manually, then rerun." >&2
    exit 3
fi

if [[ -n "${DRY_RUN}" ]]; then
    echo "would install: ${DEST} -> ${SKILL_SRC}"
    exit 0
fi

ln -s "${SKILL_SRC}" "${DEST}"
echo "installed: ${DEST} -> ${SKILL_SRC}"
