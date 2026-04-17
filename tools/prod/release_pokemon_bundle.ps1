param(
  [Parameter(Mandatory = $false)]
  [string]$SourceDir = "C:\Users\Naval\Documents\TGC\cards-database",

  [Parameter(Mandatory = $false)]
  [string]$Repo = "Navalik/tcg_tracker",

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
  [string]$OutputDir = "dist/pokemon_bundle",

  [Parameter(Mandatory = $false)]
  [switch]$SkipPull,

  [Parameter(Mandatory = $false)]
  [switch]$SkipPublish,

  [Parameter(Mandatory = $false)]
  [switch]$ForceBuild
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
if (-not $SkipPublish) {
  Require-Command -Name "gh"
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sharedToolsDir = Join-Path $repoRoot "tools/shared"
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
  python (Join-Path $sharedToolsDir "check_pokemon_bundle_updates.py") --source-dir $resolvedSourceDir
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

$dateCompact = Get-Date -Format "yyyyMMdd"
$dateTitle = Get-Date -Format "yyyy-MM-dd"
$version = "$dateCompact-$Profile-$PackageLayout-$CompatLabel"
$tag = "pokemon-bundle-$dateCompact"
$title = "Pokemon bundle $dateTitle"
$notes = "Offline Pokemon bundle ($Profile, $Languages, $PackageLayout, $CompatLabel)"

Invoke-Step "Reset output directory" {
  Remove-Item $resolvedOutputDir -Recurse -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Path $resolvedOutputDir | Out-Null
}

Invoke-Step "Build bundle artifacts" {
  python (Join-Path $sharedToolsDir "build_pokemon_bundle.py") `
    --source-tcgdex-api `
    --output-dir $resolvedOutputDir `
    --profile $Profile `
    --version $version `
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
  Invoke-Step "Publish GitHub release" {
    powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "publish_pokemon_bundle_release.ps1") `
      -Repo $Repo `
      -Tag $tag `
      -Title $title `
      -Notes $notes `
      -BundleDir $resolvedOutputDir
    if ($LASTEXITCODE -ne 0) {
      throw "release publish failed"
    }
  }

  Invoke-Step "Verify published manifest" {
    python (Join-Path $sharedToolsDir "check_pokemon_bundle_updates.py") --source-dir $resolvedSourceDir
    if ($LASTEXITCODE -ne 0) {
      throw "final verification failed with exit code $LASTEXITCODE"
    }
  }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "source commit: $sourceCommit"
Write-Host "version:      $version"
Write-Host "tag:          $tag"
if (-not $SkipPublish) {
  Write-Host "release:      https://github.com/$Repo/releases/tag/$tag"
}
