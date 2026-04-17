# Publishes the catalog bundle to Firebase Storage.
# This is the channel for the next Firebase-backed app release.

param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectId = "",

  [Parameter(Mandatory = $false)]
  [string]$Bucket = "",

  [Parameter(Mandatory = $false)]
  [string]$Game = "pokemon",

  [Parameter(Mandatory = $false)]
  [string]$BundleDir = "dist/pokemon_bundle",

  [Parameter(Mandatory = $false)]
  [string]$Version = "",

  [Parameter(Mandatory = $false)]
  [string[]]$ArtifactPatterns = @(
    "canonical_catalog_snapshot*.json.gz",
    "pokemon_legacy*.db.gz"
  ),

  [Parameter(Mandatory = $false)]
  [switch]$Force,

  [Parameter(Mandatory = $false)]
  [switch]$SkipLatest,

  [Parameter(Mandatory = $false)]
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Assert-File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing required file: $Path"
  }
}

function Get-DefaultFirebaseProjectId {
  $firebaseRcPath = Join-Path (Get-Location) ".firebaserc"
  if (-not (Test-Path -LiteralPath $firebaseRcPath -PathType Leaf)) {
    return ""
  }
  $firebaseRc = Get-Content -LiteralPath $firebaseRcPath -Raw | ConvertFrom-Json
  $defaultProject = $firebaseRc.projects.default
  if ($null -eq $defaultProject) {
    return ""
  }
  return [string]$defaultProject
}

function Get-FirebaseStorageDownloadUrl {
  param(
    [string]$BucketName,
    [string]$ObjectPath
  )
  $encodedPath = [System.Uri]::EscapeDataString($ObjectPath)
  return "https://firebasestorage.googleapis.com/v0/b/$BucketName/o/${encodedPath}?alt=media"
}

function ConvertTo-StorageManifest {
  param(
    [object]$Manifest,
    [string]$BucketName,
    [string]$ReleasePrefix
  )

  $copy = $Manifest | ConvertTo-Json -Depth 100 -Compress | ConvertFrom-Json

  function Update-Artifacts {
    param([object[]]$Artifacts)
    foreach ($artifact in $Artifacts) {
      $name = ([string]$artifact.name).Trim()
      if ([string]::IsNullOrWhiteSpace($name)) {
        $path = ([string]$artifact.path).Trim()
        $name = Split-Path -Path $path -Leaf
      }
      if ([string]::IsNullOrWhiteSpace($name)) {
        throw "Manifest artifact is missing both name and path."
      }
      $objectPath = "$ReleasePrefix/$name"
      $artifact.path = $objectPath
      if ($artifact.PSObject.Properties.Name -contains "download_url") {
        $artifact.download_url = Get-FirebaseStorageDownloadUrl `
          -BucketName $BucketName `
          -ObjectPath $objectPath
      } else {
        $artifact | Add-Member `
          -NotePropertyName "download_url" `
          -NotePropertyValue (Get-FirebaseStorageDownloadUrl `
            -BucketName $BucketName `
            -ObjectPath $objectPath)
      }
    }
  }

  if ($copy.PSObject.Properties.Name -contains "artifacts" -and $copy.artifacts) {
    Update-Artifacts -Artifacts @($copy.artifacts)
  }

  if ($copy.PSObject.Properties.Name -contains "bundles" -and $copy.bundles) {
    foreach ($bundle in @($copy.bundles)) {
      if ($bundle.PSObject.Properties.Name -contains "artifacts" -and $bundle.artifacts) {
        Update-Artifacts -Artifacts @($bundle.artifacts)
      }
      if ($bundle.PSObject.Properties.Name -contains "manifest_path" -and $bundle.manifest_path) {
        $manifestName = Split-Path -Path ([string]$bundle.manifest_path) -Leaf
        $bundle.manifest_path = "$ReleasePrefix/$manifestName"
      }
    }
  }

  return $copy
}

function Invoke-Upload {
  param(
    [string]$LocalPath,
    [string]$DestinationUri,
    [string]$CacheControl
  )
  Write-Host "[publish] upload $LocalPath -> $DestinationUri"
  if ($DryRun) {
    return
  }
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    $output = & gcloud storage cp `
      --cache-control=$CacheControl `
      $LocalPath `
      $DestinationUri 2>&1
    $uploadExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  if ($uploadExitCode -ne 0) {
    throw "Upload failed for $LocalPath`: $($output | Out-String)"
  }
}

if (-not $DryRun) {
  Assert-Command -Name "gcloud"
}

if ([string]::IsNullOrWhiteSpace($ProjectId)) {
  $ProjectId = Get-DefaultFirebaseProjectId
}
if ([string]::IsNullOrWhiteSpace($ProjectId)) {
  throw "Missing ProjectId. Pass -ProjectId or configure .firebaserc."
}
if ([string]::IsNullOrWhiteSpace($Bucket)) {
  $Bucket = "$ProjectId.firebasestorage.app"
}

$bundlePath = Resolve-Path -LiteralPath $BundleDir
$aggregateManifestPath = Join-Path $bundlePath "manifest.json"
Assert-File -Path $aggregateManifestPath

$manifest = Get-Content -LiteralPath $aggregateManifestPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($Version)) {
  $Version = ([string]$manifest.version).Trim()
}
if ([string]::IsNullOrWhiteSpace($Version)) {
  throw "Missing bundle version. Pass -Version or include version in manifest.json."
}

$releasePrefix = "catalog/$Game/releases/$Version"
$latestPrefix = "catalog/$Game/latest"
$releaseUri = "gs://$Bucket/$releasePrefix"
$latestUri = "gs://$Bucket/$latestPrefix"
$stagingPath = Join-Path $bundlePath "_firebase_publish"

if ((Test-Path -LiteralPath $stagingPath) -and -not $DryRun) {
  Remove-Item -LiteralPath $stagingPath -Recurse -Force
}
if (-not $DryRun) {
  New-Item -ItemType Directory -Path $stagingPath | Out-Null
}

Write-Host "[publish] project=$ProjectId"
Write-Host "[publish] bucket=$Bucket"
Write-Host "[publish] game=$Game"
Write-Host "[publish] version=$Version"
Write-Host "[publish] bundle=$bundlePath"
Write-Host "[publish] release=$releaseUri"

$releaseManifestProbe = "$releaseUri/manifest.json"
if (-not $Force -and -not $DryRun) {
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    $probeOutput = & gcloud storage ls $releaseManifestProbe 2>&1
    $probeExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  if ($probeExitCode -eq 0) {
    throw "Release already exists at $releaseManifestProbe. Use -Force to overwrite."
  }
  $probeText = ($probeOutput | Out-String)
  if ($probeText -notmatch "matched no objects|No URLs matched|not found") {
    throw "Failed checking release path $releaseManifestProbe`: $probeText"
  }
}

$artifactFiles = @()
foreach ($pattern in $ArtifactPatterns) {
  $artifactFiles += @(Get-ChildItem -Path $bundlePath -Filter $pattern -File)
}
$artifactFiles = @($artifactFiles | Sort-Object -Property FullName -Unique)
if (-not $artifactFiles -or $artifactFiles.Count -eq 0) {
  throw "Missing bundle artifact files in $bundlePath."
}

$releaseCacheControl = "public, max-age=31536000, immutable"
$latestCacheControl = "no-cache, max-age=0"

foreach ($file in $artifactFiles) {
  Invoke-Upload `
    -LocalPath $file.FullName `
    -DestinationUri "$releaseUri/$($file.Name)" `
    -CacheControl $releaseCacheControl
}

$manifestFiles = @(Get-ChildItem -Path $bundlePath -Filter "manifest*.json" -File)
foreach ($manifestFile in $manifestFiles) {
  $rawManifest = Get-Content -LiteralPath $manifestFile.FullName -Raw | ConvertFrom-Json
  $storageManifest = ConvertTo-StorageManifest `
    -Manifest $rawManifest `
    -BucketName $Bucket `
    -ReleasePrefix $releasePrefix
  $stagedManifestPath = Join-Path $stagingPath $manifestFile.Name
  if (-not $DryRun) {
    $storageManifest |
      ConvertTo-Json -Depth 100 -Compress |
      Set-Content -LiteralPath $stagedManifestPath -Encoding UTF8
  } else {
    Write-Host "[publish] stage manifest $($manifestFile.Name)"
  }
  Invoke-Upload `
    -LocalPath $stagedManifestPath `
    -DestinationUri "$releaseUri/$($manifestFile.Name)" `
    -CacheControl $releaseCacheControl
}

if (-not $SkipLatest) {
  $latestManifestPath = Join-Path $stagingPath "manifest.json"
  Invoke-Upload `
    -LocalPath $latestManifestPath `
    -DestinationUri "$latestUri/manifest.json" `
    -CacheControl $latestCacheControl
}

Write-Host "[publish] done"
Write-Host "[publish] latest manifest:"
Write-Host (Get-FirebaseStorageDownloadUrl `
  -BucketName $Bucket `
  -ObjectPath "$latestPrefix/manifest.json")
