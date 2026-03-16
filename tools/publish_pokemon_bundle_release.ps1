param(
  [Parameter(Mandatory = $false)]
  [string]$Repo = "Navalik/tcg_tracker",

  [Parameter(Mandatory = $false)]
  [string]$Tag = "",

  [Parameter(Mandatory = $false)]
  [string]$Title = "",

  [Parameter(Mandatory = $false)]
  [string]$Notes = "Offline Pokemon bundle",

  [Parameter(Mandatory = $false)]
  [string]$BundleDir = "dist/pokemon_bundle",

  [Parameter(Mandatory = $false)]
  [switch]$Draft,

  [Parameter(Mandatory = $false)]
  [switch]$Prerelease
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Ensure-File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing required file: $Path"
  }
}

function Ensure-AnyFile {
  param([array]$Files, [string]$Kind)
  if (-not $Files -or $Files.Count -eq 0) {
    throw "Missing required $Kind files in bundle directory."
  }
}

Require-Command -Name "gh"

$bundlePath = Resolve-Path -LiteralPath $BundleDir
$snapshotFiles = @(Get-ChildItem -Path $bundlePath -Filter "canonical_catalog_snapshot*.json.gz" -File)
$legacyDbFiles = @(Get-ChildItem -Path $bundlePath -Filter "pokemon_legacy*.db.gz" -File)
$manifestFiles = @(Get-ChildItem -Path $bundlePath -Filter "manifest*.json" -File)

Ensure-AnyFile -Files $snapshotFiles -Kind "snapshot"
Ensure-AnyFile -Files $legacyDbFiles -Kind "legacy db"
Ensure-AnyFile -Files $manifestFiles -Kind "manifest"

if ([string]::IsNullOrWhiteSpace($Tag)) {
  $utcNow = (Get-Date).ToUniversalTime()
  $Tag = "pokemon-bundle-{0}" -f $utcNow.ToString("yyyyMMdd-HHmm")
}

if ([string]::IsNullOrWhiteSpace($Title)) {
  $Title = "Pokemon bundle $Tag"
}

Write-Host "[publish] repo=$Repo"
Write-Host "[publish] tag=$Tag"
Write-Host "[publish] bundle=$bundlePath"

$createArgs = @(
  "release", "create", $Tag,
  "--repo", $Repo,
  "--title", $Title,
  "--notes", $Notes
)
if ($Draft) { $createArgs += "--draft" }
if ($Prerelease) { $createArgs += "--prerelease" }
Write-Host "[publish] ensuring release exists..."
$createOutput = & gh @createArgs 2>&1
$createExit = $LASTEXITCODE
if ($createExit -ne 0) {
  $createText = ($createOutput | Out-String).ToLowerInvariant()
  if ($createText.Contains("already_exists") -or $createText.Contains("already exists")) {
    Write-Host "[publish] release already exists, continuing..."
  } else {
    throw "Failed creating release: $($createOutput | Out-String)"
  }
}

$uploadArgs = @(
  "release", "upload", $Tag,
  "--repo", $Repo,
  "--clobber"
)
$uploadArgs += $snapshotFiles.FullName
$uploadArgs += $legacyDbFiles.FullName
$uploadArgs += $manifestFiles.FullName
$uploadOutput = & gh @uploadArgs 2>&1
if ($LASTEXITCODE -ne 0) {
  throw "Failed uploading assets: $($uploadOutput | Out-String)"
}

Write-Host "[publish] done"
Write-Host "[publish] release URL:"
$viewOutput = & gh release view $Tag --repo $Repo --json url --jq ".url" 2>&1
if ($LASTEXITCODE -ne 0) {
  throw "Failed reading release URL: $($viewOutput | Out-String)"
}
Write-Host $viewOutput
