#!/usr/bin/env pwsh
#requires -Version 5.1
# One-command setup for the claude-skills repo on Windows. Installs both
# layouts in this repo:
#
#   1. The legacy audit skill (via install.sh — run through Git Bash)
#   2. The mikko-* skill namespace (via .claude\skills\mikko-install\bootstrap.ps1)
#
# By default the script asks whether to install user-wide or project-only.
# Pass -Target explicitly to skip the prompt.
#
# Usage:
#   .\setup.ps1                                # prompt user-wide vs project
#   .\setup.ps1 -Target user                   # install user-wide (~/.claude/skills/)
#   .\setup.ps1 -Target project                # install into <cwd>\.claude\skills\
#   .\setup.ps1 -Yes                           # skip every prompt; default to user-wide
#   .\setup.ps1 -DryRun                        # preview, write nothing
#
# Prereqs:
#   - PowerShell 5.1+ (Windows PowerShell) or 7+ (PowerShell Core)
#   - Node.js 18+ (for the mikko-* installer)
#   - Git Bash (for the audit-skill install.sh — installed with Git for Windows)

[CmdletBinding()]
param(
  [ValidateSet('user','project')] [string]$Target,
  [switch]$Yes,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Check Node.
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "Node.js (>=18) is required. Install from https://nodejs.org and re-run."
    exit 3
}

# Check Git Bash for the audit-skill install.sh.
$gitBash = Get-Command bash -ErrorAction SilentlyContinue
if (-not $gitBash) {
    Write-Error "bash not found. Install Git for Windows (https://git-scm.com) and re-run — install.sh needs Git Bash."
    exit 3
}

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Resolve target — prompt if not given.
if (-not $Target) {
    if ($Yes) {
        $Target = 'user'
    } else {
        Write-Host "Where should the skills be installed?"
        Write-Host "  1) user-wide    — $HOME\.claude\skills\         (available in every project) [default]"
        Write-Host "  2) project-only — $(Get-Location)\.claude\skills\   (available only when Claude Code runs here)"
        Write-Host ""
        $choice = Read-Host "Pick 1 or 2 [1]"
        if (-not $choice) { $choice = '1' }
        switch ($choice.ToLower()) {
            '1'       { $Target = 'user' }
            'user'    { $Target = 'user' }
            '2'       { $Target = 'project' }
            'project' { $Target = 'project' }
            default   { Write-Error "Invalid choice. Aborted."; exit 2 }
        }
    }
}

Write-Host ""
Write-Host "claude-skills setup"
Write-Host "  target : $Target"
if ($DryRun) { Write-Host "  mode   : dry-run (nothing will be written)" }
Write-Host ""

# 1. Legacy audit skill via install.sh (Git Bash).
Write-Host "[1/2] audit skill..."
$installSh = Join-Path -Path $RepoRoot -ChildPath 'install.sh'
$installArgs = @('--target', $Target)
if ($Target -eq 'project') { $installArgs += @('--repo', (Get-Location).Path) }
if ($DryRun) { $installArgs += '--dry-run' }

& bash $installSh @installArgs
if ($LASTEXITCODE -ne 0) { Write-Error "install.sh failed (exit $LASTEXITCODE)"; exit $LASTEXITCODE }

# 2. mikko-* namespace via bootstrap.ps1.
Write-Host ""
Write-Host "[2/2] mikko-* namespace..."
$bootstrapScript = Join-Path -Path $RepoRoot -ChildPath '.claude/skills/mikko-install/bootstrap.ps1'
$bootstrapArgs = @('-Source', $RepoRoot, '-Target', $Target)
if ($Yes) { $bootstrapArgs += '-Yes' }
if ($DryRun) { $bootstrapArgs += '-DryRun' }

& $bootstrapScript @bootstrapArgs
if ($LASTEXITCODE -ne 0) { Write-Error "bootstrap.ps1 failed (exit $LASTEXITCODE)"; exit $LASTEXITCODE }

Write-Host ""
if ($DryRun) {
    Write-Host "Dry-run complete — nothing was written."
} else {
    Write-Host "Done. Restart Claude Code, then type /mikko-help in any project to confirm."
}
