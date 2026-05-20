#!/usr/bin/env pwsh
# Bootstrap helper for first-time install of the mikko-* skill namespace on
# Windows. Runs install.mjs with --adopt --force so any pre-existing mikko-help
# / mikko-skills / etc. directories (which have no .mikko-install-source
# marker) get replaced rather than skipped.
#
# Usage:
#   pwsh bootstrap.ps1                      # source defaults to this script's repo
#   pwsh bootstrap.ps1 -Source <path>       # explicit source repo
#   pwsh bootstrap.ps1 -Target project      # install to <cwd>/.claude/skills/ instead
#   pwsh bootstrap.ps1 -DryRun              # show what would happen
#
# After the first run, subsequent updates can use `/mikko-install` directly
# (the marker is in place; no --adopt needed).

[CmdletBinding()]
param(
  [string]$Source,
  [ValidateSet('user','project')] [string]$Target = 'user',
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Default source is the repo this script lives in (.claude/skills/mikko-install/bootstrap.ps1
# → repo root is three levels up).
if (-not $Source) {
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  $Source = Resolve-Path (Join-Path $scriptDir '..\..\..\') | Select-Object -ExpandProperty Path
}

if (-not (Test-Path (Join-Path $Source '.claude\skills'))) {
  Write-Error "source $Source has no .claude/skills/ — wrong path?"
  exit 3
}

$installScript = Join-Path $Source '.claude\skills\mikko-install\install.mjs'
if (-not (Test-Path $installScript)) {
  Write-Error "install.mjs not found at $installScript"
  exit 3
}

Write-Host "mikko-* bootstrap"
Write-Host "  flags : --adopt --force$(if ($DryRun) { ' --dry-run' })"
Write-Host ""
# install.mjs prints source/target/method itself.

$args = @('--source', $Source, '--target', $Target, '--method', 'copy', '--adopt', '--force')
if ($DryRun) { $args += '--dry-run' }

& node $installScript @args
exit $LASTEXITCODE
