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

$argsForRelease = @(
  "-ExecutionPolicy", "Bypass",
  "-File", (Join-Path $PSScriptRoot "release_pokemon_bundle.ps1"),
  "-SourceDir", $SourceDir,
  "-Repo", $Repo,
  "-Profile", $Profile,
  "-Languages", $Languages,
  "-LanguageBundles", $LanguageBundles,
  "-PackageLayout", $PackageLayout,
  "-ApiWorkers", $ApiWorkers,
  "-CompatLabel", $CompatLabel,
  "-SourceRepo", $SourceRepo,
  "-SourceRef", $SourceRef,
  "-OutputDir", $OutputDir
)

if ($SkipPull) { $argsForRelease += "-SkipPull" }
if ($SkipPublish) { $argsForRelease += "-SkipPublish" }
if ($ForceBuild) { $argsForRelease += "-ForceBuild" }

Write-Host "[prod] GitHub Release channel for the current production app." -ForegroundColor Cyan
& powershell @argsForRelease
if ($LASTEXITCODE -ne 0) {
  throw "prod release failed with exit code $LASTEXITCODE"
}
