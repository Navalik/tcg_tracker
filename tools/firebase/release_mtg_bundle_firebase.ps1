param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectId = "",

  [Parameter(Mandatory = $false)]
  [string]$Bucket = "",

  [Parameter(Mandatory = $false)]
  [string]$OutputDir = "dist/mtg_bundle_firebase",

  [Parameter(Mandatory = $false)]
  [string]$CacheDir = "dist/mtg_bulk_cache",

  [Parameter(Mandatory = $false)]
  [string]$Languages = "en,it",

  [Parameter(Mandatory = $false)]
  [string]$Version = "",

  [Parameter(Mandatory = $false)]
  [switch]$ForceDownload,

  [Parameter(Mandatory = $false)]
  [switch]$ForceBuild,

  [Parameter(Mandatory = $false)]
  [switch]$SkipPublish,

  [Parameter(Mandatory = $false)]
  [switch]$SkipLatest,

  [Parameter(Mandatory = $false)]
  [switch]$ForcePublish,

  [Parameter(Mandatory = $false)]
  [switch]$DryRunPublish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Label,

    [Parameter(Mandatory = $true)]
    [scriptblock]$Action
  )
  Write-Host ""
  Write-Host "== $Label ==" -ForegroundColor Cyan
  & $Action
}

Require-Command -Name "python"
if (-not $SkipPublish -and -not $DryRunPublish) {
  Require-Command -Name "gcloud"
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sharedToolsDir = Join-Path $repoRoot "tools/shared"
$resolvedOutputDir = Join-Path $repoRoot $OutputDir
$resolvedCacheDir = Join-Path $repoRoot $CacheDir

Invoke-Step "Build MTG Firebase bundle" {
  $buildArgs = @(
    (Join-Path $sharedToolsDir "build_mtg_bundle.py"),
    "--output-dir", $resolvedOutputDir,
    "--cache-dir", $resolvedCacheDir,
    "--languages", $Languages
  )
  if (-not [string]::IsNullOrWhiteSpace($Version)) {
    $buildArgs += @("--version", $Version)
  }
  if ($ForceDownload) { $buildArgs += "--force-download" }
  if ($ForceBuild) { $buildArgs += "--force-build" }

  python @buildArgs
  if ($LASTEXITCODE -ne 0) {
    throw "MTG bundle build failed"
  }
}

if (-not $SkipPublish) {
  Invoke-Step "Publish MTG Firebase bundle" {
    $publishArgs = @(
      "-ExecutionPolicy", "Bypass",
      "-File", (Join-Path $PSScriptRoot "publish_catalog_bundle_firebase.ps1"),
      "-ProjectId", $ProjectId,
      "-Bucket", $Bucket,
      "-Game", "mtg",
      "-BundleDir", $resolvedOutputDir,
      "-ArtifactPatterns", "mtg_*.json.gz"
    )
    if (-not [string]::IsNullOrWhiteSpace($Version)) {
      $publishArgs += @("-Version", $Version)
    }
    if ($ForcePublish) { $publishArgs += "-Force" }
    if ($SkipLatest) { $publishArgs += "-SkipLatest" }
    if ($DryRunPublish) { $publishArgs += "-DryRun" }

    & powershell @publishArgs
    if ($LASTEXITCODE -ne 0) {
      throw "MTG Firebase publish failed with exit code $LASTEXITCODE"
    }
  }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "channel: Firebase Storage"
Write-Host "game:    mtg"
Write-Host "output:  $resolvedOutputDir"
