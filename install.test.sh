#!/usr/bin/env bash
# Smoke tests for install.sh (the single-`audit`-skill installer at the repo
# root). Focuses on the --dry-run code paths: same arg parsing and source/dest
# resolution as a real install, but no filesystem side effects.
#
# Run with:  bash install.test.sh   (from the worktree root, alongside install.sh)
# Exits 0 on all-green, 1 on any failure.
#
# Conventions mirror .claude/skills/mikko-install/install.test.mjs:
#   - test "name" fn   — one isolated tmpdir per test, trap-based cleanup
#   - assert <cond> msg — fail fast with a clear assertion message
#   - final line: "N passed, M failed" (plus an optional "K skipped")
#
# Coverage gaps (intentional):
#   - Real install (no --dry-run) is not exercised here. The mjs tests cover
#     that style for the mikko-install installer; this script's real-install
#     path is one ln -s + an idempotent re-run, exercised manually.
#   - The "matching symlink" and "would replace existing symlink" cases require
#     a working ln -s in the fixture. On Git Bash for Windows without Developer
#     Mode that fails; those tests are skipped via can_symlink() rather than
#     counted as failures.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/install.sh"
SKILL_SRC="${SCRIPT_DIR}/skill"

if [[ ! -f "${SCRIPT}" ]]; then
    echo "fatal: install.sh not found at ${SCRIPT}" >&2
    exit 1
fi

passed=0
failed=0
skipped=0
CURRENT_TMP=""

cleanup_current() {
    if [[ -n "${CURRENT_TMP}" && -d "${CURRENT_TMP}" ]]; then
        rm -rf "${CURRENT_TMP}" || true
    fi
    CURRENT_TMP=""
}
trap cleanup_current EXIT

assert() {
    # Usage: assert <command...> -- <msg>
    # Simpler form used below: assert "[[ cond ]]" "msg"
    local cond="$1"
    local msg="${2:-assertion failed}"
    if ! eval "${cond}"; then
        echo "ASSERT FAILED: ${msg}" >&2
        return 1
    fi
}

test() {
    local name="$1"
    local fn="$2"
    CURRENT_TMP="$(mktemp -d 2>/dev/null || mktemp -d -t 'install-test')"
    if "${fn}"; then
        echo "  ok   ${name}"
        passed=$((passed + 1))
    else
        echo "  FAIL ${name}" >&2
        failed=$((failed + 1))
    fi
    cleanup_current
}

skip() {
    local name="$1"
    local reason="$2"
    echo "  skip ${name} (${reason})"
    skipped=$((skipped + 1))
}

can_symlink() {
    local tmp
    tmp="$(mktemp -d 2>/dev/null || mktemp -d -t 'symcheck')"
    if ln -s "${tmp}" "${tmp}/_test_link" 2>/dev/null; then
        rm -rf "${tmp}"
        return 0
    fi
    rm -rf "${tmp}"
    return 1
}

run_install() {
    # Capture stdout, stderr, and exit code. Echoes "CODE\nSTDOUT\x1eSTDERR".
    # We use a sentinel because stdout/stderr may contain newlines.
    local stdout_file="${CURRENT_TMP}/_stdout"
    local stderr_file="${CURRENT_TMP}/_stderr"
    local code=0
    bash "${SCRIPT}" "$@" >"${stdout_file}" 2>"${stderr_file}" || code=$?
    LAST_STDOUT="$(cat "${stdout_file}")"
    LAST_STDERR="$(cat "${stderr_file}")"
    LAST_CODE="${code}"
}

# ----------------------------------------------------------------------------
# Test cases
# ----------------------------------------------------------------------------

t_user_dry_run_fresh() {
    local home="${CURRENT_TMP}/fakehome"
    mkdir -p "${home}"
    HOME="${home}" run_install --target user --dry-run
    assert '[[ "${LAST_CODE}" -eq 0 ]]' "expected exit 0, got ${LAST_CODE} (stderr: ${LAST_STDERR})" || return 1
    assert '[[ "${LAST_STDOUT}" == *"would install:"* ]]' "expected 'would install:' in stdout, got: ${LAST_STDOUT}" || return 1
    assert '[[ ! -e "${home}/.claude/skills/audit" ]]' "dry-run created the dest dir at ${home}/.claude/skills/audit" || return 1
    # Parent should also not exist — we only mkdir -p in the non-dry path.
    assert '[[ ! -e "${home}/.claude/skills" ]]' "dry-run created parent dir ${home}/.claude/skills" || return 1
}

t_project_dry_run_fresh() {
    local repo="${CURRENT_TMP}/repo"
    mkdir -p "${repo}"
    run_install --target project --repo "${repo}" --dry-run
    assert '[[ "${LAST_CODE}" -eq 0 ]]' "expected exit 0, got ${LAST_CODE} (stderr: ${LAST_STDERR})" || return 1
    assert '[[ "${LAST_STDOUT}" == *"would install:"* ]]' "expected 'would install:' in stdout, got: ${LAST_STDOUT}" || return 1
    assert '[[ ! -e "${repo}/.claude/skills/audit" ]]' "dry-run created the dest at ${repo}/.claude/skills/audit" || return 1
    assert '[[ ! -e "${repo}/.claude/skills" ]]' "dry-run created parent dir ${repo}/.claude/skills" || return 1
}

t_project_dry_run_existing_regular_dir() {
    local repo="${CURRENT_TMP}/repo"
    local dest="${repo}/.claude/skills/audit"
    mkdir -p "${dest}"
    echo "user content" > "${dest}/SENTINEL"
    run_install --target project --repo "${repo}" --dry-run
    assert '[[ "${LAST_CODE}" -eq 3 ]]' "expected exit 3, got ${LAST_CODE} (stderr: ${LAST_STDERR})" || return 1
    assert '[[ "${LAST_STDERR}" == *"would refuse:"* ]]' "expected 'would refuse:' in stderr, got: ${LAST_STDERR}" || return 1
    assert '[[ -d "${dest}" && ! -L "${dest}" ]]' "dest should still be a regular directory at ${dest}" || return 1
    assert '[[ -f "${dest}/SENTINEL" ]]' "sentinel file lost — dry-run mutated existing dir" || return 1
    assert '[[ "$(cat "${dest}/SENTINEL")" == "user content" ]]' "sentinel content changed" || return 1
}

t_bad_arg() {
    run_install --bogus
    assert '[[ "${LAST_CODE}" -eq 2 ]]' "expected exit 2, got ${LAST_CODE} (stderr: ${LAST_STDERR})" || return 1
    assert '[[ "${LAST_STDERR}" == *"unknown argument"* ]]' "expected 'unknown argument' in stderr, got: ${LAST_STDERR}" || return 1
}

t_help_exits_zero() {
    run_install -h
    assert '[[ "${LAST_CODE}" -eq 0 ]]' "expected exit 0, got ${LAST_CODE} (stderr: ${LAST_STDERR})" || return 1
    assert '[[ "${LAST_STDOUT}" == *"target"* ]]' "expected help text to mention 'target', got: ${LAST_STDOUT}" || return 1
}

t_project_missing_repo_arg() {
    # --target project without --repo should exit 2.
    run_install --target project --dry-run
    assert '[[ "${LAST_CODE}" -eq 2 ]]' "expected exit 2, got ${LAST_CODE} (stderr: ${LAST_STDERR})" || return 1
    assert '[[ "${LAST_STDERR}" == *"requires --repo"* ]]' "expected 'requires --repo' in stderr, got: ${LAST_STDERR}" || return 1
}

t_dry_run_matching_symlink() {
    local repo="${CURRENT_TMP}/repo"
    local dest="${repo}/.claude/skills/audit"
    mkdir -p "$(dirname "${dest}")"
    ln -s "${SKILL_SRC}" "${dest}"
    run_install --target project --repo "${repo}" --dry-run
    assert '[[ "${LAST_CODE}" -eq 0 ]]' "expected exit 0, got ${LAST_CODE} (stderr: ${LAST_STDERR})" || return 1
    assert '[[ "${LAST_STDOUT}" == *"already up-to-date:"* ]]' "expected 'already up-to-date:' in stdout, got: ${LAST_STDOUT}" || return 1
    assert '[[ -L "${dest}" ]]' "symlink at ${dest} should still exist" || return 1
}

t_dry_run_drifted_symlink() {
    local repo="${CURRENT_TMP}/repo"
    local dest="${repo}/.claude/skills/audit"
    local other="${CURRENT_TMP}/other-target"
    mkdir -p "$(dirname "${dest}")" "${other}"
    ln -s "${other}" "${dest}"
    run_install --target project --repo "${repo}" --dry-run
    assert '[[ "${LAST_CODE}" -eq 0 ]]' "expected exit 0, got ${LAST_CODE} (stderr: ${LAST_STDERR})" || return 1
    assert '[[ "${LAST_STDOUT}" == *"would replace existing symlink"* ]]' "expected 'would replace existing symlink' in stdout, got: ${LAST_STDOUT}" || return 1
    # Symlink should still be the old one (dry-run doesn't rm/relink).
    assert '[[ -L "${dest}" ]]' "symlink at ${dest} should still exist" || return 1
    local link_target
    link_target="$(readlink "${dest}")"
    assert '[[ "${link_target}" == "${other}" ]]' "symlink target should still be ${other}, got: ${link_target}" || return 1
}

# ----------------------------------------------------------------------------
# Driver
# ----------------------------------------------------------------------------

echo "install.sh --dry-run smoke tests"
echo ""

test "bad arg → exit 2"                                       t_bad_arg
test "-h prints help and exits 0"                             t_help_exits_zero
test "--target project without --repo → exit 2"               t_project_missing_repo_arg
test "--dry-run --target user, fresh → would install + exit 0"     t_user_dry_run_fresh
test "--dry-run --target project, fresh → would install + exit 0"  t_project_dry_run_fresh
test "--dry-run, dest is regular dir → would refuse + exit 3"      t_project_dry_run_existing_regular_dir

if can_symlink; then
    test "--dry-run, matching symlink → already up-to-date + exit 0"   t_dry_run_matching_symlink
    test "--dry-run, drifted symlink → would replace + exit 0"         t_dry_run_drifted_symlink
else
    skip "--dry-run, matching symlink → already up-to-date + exit 0" "symlinks unavailable on this platform"
    skip "--dry-run, drifted symlink → would replace + exit 0"       "symlinks unavailable on this platform"
fi

echo ""
if [[ "${skipped}" -gt 0 ]]; then
    echo "${passed} passed, ${failed} failed, ${skipped} skipped"
else
    echo "${passed} passed, ${failed} failed"
fi

if [[ "${failed}" -gt 0 ]]; then
    exit 1
fi
exit 0
