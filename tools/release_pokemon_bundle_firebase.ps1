param(
  [Parameter(Mandatory = $false)]
  [string]$SourceDir = "C:\Users\Naval\Documents\TGC\cards-database",

  [Parameter(Mandatory = $false)]
  [string]$ProjectId = "",

  [Parameter(Mandatory = $false)]
  [string]$Bucket = "",

  [Parameter(Mandatory = $false)]
  [string]$Game = "pokemon",

  [Parameter(Mandatory = $false)]
  [string]$Profile = "full",

  [Parameter(Mandatory = $false)]
  [string]$Languages = "en,it",

  [Parameter(Mandatory = $false)]
  [string]$LanguageBundles = "en,it",

  [Parameter(Mandatory = $false)]
  [string]$PackageLayout = "base-delta",

  [Parameter(Mandatory = $false)]
  [int]$ApiWorkers = 10,

  [Parameter(Mandatory = $false)]
  [string]$CompatLabel = "compat2",

  [Parameter(Mandatory = $false)]
  [string]$SourceRepo = "https://github.com/tcgdex/cards-database.git",

  [Parameter(Mandatory = $false)]
  [string]$SourceRef = "master",

  [Parameter(Mandatory = $false)]
  [string]$OutputDir = "dist/pokemon_bundle_firebase",

  [Parameter(Mandatory = $false)]
  [string]$Version = "",

  [Parameter(Mandatory = $false)]
  [switch]$SkipPull,

  [Parameter(Mandatory = $false)]
  [switch]$SkipPublish,

  [Parameter(Mandatory = $false)]
  [switch]$SkipLatest,

  [Parameter(Mandatory = $false)]
  [switch]$ForceBuild,

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

Require-Command -Name "git"
Require-Command -Name "python"
if (-not $SkipPublish -and -not $DryRunPublish) {
  Require-Command -Name "gcloud"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$resolvedSourceDir = (Resolve-Path -LiteralPath $SourceDir).Path
$resolvedOutputDir = Join-Path $repoRoot $OutputDir

if (-not $SkipPull) {
  Invoke-Step "Update source checkout" {
    git -C $resolvedSourceDir pull --ff-only
    if ($LASTEXITCODE -ne 0) {
      throw "git pull failed"
    }
  }
}

Invoke-Step "Check for upstream bundle updates" {
  python (Join-Path $PSScriptRoot "check_pokemon_bundle_updates.py") --source-dir $resolvedSourceDir
  $script:checkExit = $LASTEXITCODE
  if ($script:checkExit -ne 0 -and $script:checkExit -ne 10) {
    throw "update check failed with exit code $script:checkExit"
  }
}

if ($script:checkExit -eq 0 -and -not $ForceBuild) {
  Write-Host ""
  Write-Host "No source updates detected. Exiting without rebuild/publish." -ForegroundColor Yellow
  return
}

$sourceCommit = (git -C $resolvedSourceDir rev-parse HEAD).Trim()
if (-not $sourceCommit) {
  throw "Could not resolve source commit from $resolvedSourceDir"
}

if ([string]::IsNullOrWhiteSpace($Version)) {
  $dateTimeCompact = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
  $shortCommit = $sourceCommit.Substring(0, 7)
  $Version = "$dateTimeCompact-$Profile-$PackageLayout-$CompatLabel-tcgdex-$shortCommit"
}

Invoke-Step "Reset Firebase output directory" {
  Remove-Item $resolvedOutputDir -Recurse -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Path $resolvedOutputDir | Out-Null
}

Invoke-Step "Build Firebase bundle artifacts" {
  python (Join-Path $PSScriptRoot "build_pokemon_bundle.py") `
    --source-tcgdex-api `
    --output-dir $resolvedOutputDir `
    --profile $Profile `
    --version $Version `
    --languages $Languages `
    --language-bundles $LanguageBundles `
    --package-layout $PackageLayout `
    --api-workers $ApiWorkers `
    --source-repo $SourceRepo `
    --source-ref $SourceRef `
    --source-commit $sourceCommit
  if ($LASTEXITCODE -ne 0) {
    throw "bundle build failed"
  }
}

if (-not $SkipPublish) {
  Invoke-Step "Publish Firebase Storage bundle" {
    $publishArgs = @(
      "-ExecutionPolicy", "Bypass",
      "-File", (Join-Path $PSScriptRoot "publish_catalog_bundle_firebase.ps1"),
      "-ProjectId", $ProjectId,
      "-Bucket", $Bucket,
      "-Game", $Game,
      "-BundleDir", $resolvedOutputDir,
      "-Version", $Version
    )
    if ($ForcePublish) { $publishArgs += "-Force" }
    if ($SkipLatest) { $publishArgs += "-SkipLatest" }
    if ($DryRunPublish) { $publishArgs += "-DryRun" }

    & powershell @publishArgs
    if ($LASTEXITCODE -ne 0) {
      throw "Firebase publish failed with exit code $LASTEXITCODE"
    }
  }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "channel:       Firebase Storage"
Write-Host "source commit: $sourceCommit"
Write-Host "version:       $Version"
Write-Host "output:        $resolvedOutputDir"
if (-not $SkipPublish) {
  Write-Host "release path:  catalog/$Game/releases/$Version"
  if (-not $SkipLatest) {
    Write-Host "latest path:   catalog/$Game/latest/manifest.json"
  }
}
