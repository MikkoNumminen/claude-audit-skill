#!/usr/bin/env pwsh
# Bootstrap helper for first-time install of the mikko-* skill namespace on
# Windows. Runs install.mjs with --adopt --force so any pre-existing mikko-help
# / mikko-skills / etc. directories (which have no .mikko-install-source
# marker) get replaced rather than skipped.
#
# By default the script does a dry-run first, shows what would change, and
# prompts before applying. Pass -Yes to skip the prompt (e.g. for CI).
#
# Usage:
#   pwsh bootstrap.ps1                      # source defaults to this script's repo
#   pwsh bootstrap.ps1 -Source <path>       # explicit source repo
#   pwsh bootstrap.ps1 -Target project      # install to <cwd>/.claude/skills/ instead
#   pwsh bootstrap.ps1 -Yes                 # skip the confirmation prompt
#   pwsh bootstrap.ps1 -DryRun              # show what would happen, do NOT apply
#
# After the first run, subsequent updates can use `/mikko-install` directly
# (the marker is in place; no --adopt needed).

[CmdletBinding()]
param(
  [string]$Source,
  [ValidateSet('user','project')] [string]$Target = 'user',
  [switch]$DryRun,
  [switch]$Yes
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

# If the user explicitly passed -DryRun, just do that and exit.
if ($DryRun) {
  & node $installScript --source $Source --target $Target --adopt --force --dry-run
  exit $LASTEXITCODE
}

# Otherwise: dry-run first to show what would happen.
Write-Host "Preview (dry-run):"
Write-Host ""
$output = & node $installScript --source $Source --target $Target --adopt --force --dry-run 2>&1 | Out-String
Write-Host $output

# Anything actually changing?
if ($output -notmatch 'would (install|update|adopt)') {
  Write-Host "Nothing to do — all up-to-date."
  exit 0
}

# Prompt unless -Yes.
if (-not $Yes) {
  $response = Read-Host "Proceed with these changes? [y/N]"
  if ($response -notmatch '^[yY]([eE][sS])?$') {
    Write-Host "Aborted — nothing changed."
    exit 0
  }
}

Write-Host ""
& node $installScript --source $Source --target $Target --adopt --force
exit $LASTEXITCODE
