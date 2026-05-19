#!/usr/bin/env bash
# Install a skill from this library into a Claude Code skills directory.
#
# Usage:
#   ./install.sh <skill-name> --target user                  ~/.claude/skills/<name>          (every project)
#   ./install.sh <skill-name> --target project --repo PATH   PATH/.claude/skills/<name>       (project-local)
#   ./install.sh --list                                      list available skills
#   ./install.sh --help                                      this help
#
# Skills live in this repo under `skills/<name>/SKILL.md`. The installer creates
# a symlink, so updates pulled into this repo propagate automatically — no
# re-install needed after a `git pull`.
#
# Idempotent: re-running updates the symlink without duplicating.
# Refuses to overwrite an existing non-symlink directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOT="${SCRIPT_DIR}/skills"

list_skills() {
    if [[ ! -d "${SKILLS_ROOT}" ]]; then
        echo "no skills directory at ${SKILLS_ROOT}" >&2
        exit 1
    fi
    for d in "${SKILLS_ROOT}"/*/; do
        name="$(basename "${d}")"
        if [[ -f "${d}SKILL.md" ]]; then
            printf '  %s\n' "${name}"
        fi
    done
}

print_help() {
    sed -n 's/^# \{0,1\}//p' "$0" | head -n 14
}

SKILL_NAME=""
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
        --list)
            list_skills
            exit 0
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        --*)
            echo "error: unknown flag '$1'" >&2
            exit 2
            ;;
        *)
            if [[ -n "${SKILL_NAME}" ]]; then
                echo "error: too many positional arguments (got '${SKILL_NAME}' and '$1')" >&2
                exit 2
            fi
            SKILL_NAME="$1"
            shift
            ;;
    esac
done

if [[ -z "${SKILL_NAME}" ]]; then
    echo "error: missing skill name. Run with --list to see available skills." >&2
    print_help
    exit 2
fi

SKILL_SRC="${SKILLS_ROOT}/${SKILL_NAME}"
if [[ ! -d "${SKILL_SRC}" ]] || [[ ! -f "${SKILL_SRC}/SKILL.md" ]]; then
    echo "error: skill '${SKILL_NAME}' not found at ${SKILL_SRC}/SKILL.md" >&2
    echo "available skills:" >&2
    list_skills >&2
    exit 1
fi

if [[ "${TARGET}" == "user" ]]; then
    DEST="${HOME}/.claude/skills/${SKILL_NAME}"
elif [[ "${TARGET}" == "project" ]]; then
    if [[ -z "${REPO}" ]]; then
        echo "error: --target project requires --repo PATH" >&2
        exit 2
    fi
    if [[ ! -d "${REPO}" ]]; then
        echo "error: repo not found: ${REPO}" >&2
        exit 2
    fi
    DEST="${REPO%/}/.claude/skills/${SKILL_NAME}"
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
