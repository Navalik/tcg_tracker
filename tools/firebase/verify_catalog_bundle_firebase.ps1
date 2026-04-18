# Verifies a published catalog bundle on Firebase Storage.
# This is read-only: it downloads the latest manifest and referenced artifacts,
# then checks contract fields, size_bytes, and sha256.

param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectId = "",

  [Parameter(Mandatory = $false)]
  [string]$Bucket = "",

  [Parameter(Mandatory = $false)]
  [ValidateSet("pokemon", "mtg")]
  [string]$Game = "pokemon",

  [Parameter(Mandatory = $false)]
  [string]$ManifestUrl = "",

  [Parameter(Mandatory = $false)]
  [string]$DownloadDir = "",

  [Parameter(Mandatory = $false)]
  [switch]$KeepDownloads
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

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

function Read-Utf8JsonFileNoBom {
  param([string]$Path)

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $offset = 0
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $offset = 3
  }
  return [System.Text.Encoding]::UTF8.GetString($bytes, $offset, $bytes.Length - $offset)
}

function Assert-NotBlank {
  param(
    [object]$Value,
    [string]$Label
  )
  if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
    throw "Missing required manifest field: $Label"
  }
}

function Get-ObjectProperty {
  param(
    [object]$Object,
    [string]$Name
  )
  if ($null -eq $Object) {
    return $null
  }
  if ($Object.PSObject.Properties.Name -contains $Name) {
    return $Object.$Name
  }
  return $null
}

function Add-Artifact {
  param(
    [System.Collections.Generic.List[object]]$Artifacts,
    [object]$Artifact,
    [string]$BundleId
  )

  if ($null -eq $Artifact) {
    return
  }
  $name = [string](Get-ObjectProperty -Object $Artifact -Name "name")
  $path = [string](Get-ObjectProperty -Object $Artifact -Name "path")
  $downloadUrl = [string](Get-ObjectProperty -Object $Artifact -Name "download_url")
  $sizeBytes = Get-ObjectProperty -Object $Artifact -Name "size_bytes"
  $sha256 = [string](Get-ObjectProperty -Object $Artifact -Name "sha256")

  if ([string]::IsNullOrWhiteSpace($downloadUrl) -and -not [string]::IsNullOrWhiteSpace($path)) {
    $downloadUrl = Get-FirebaseStorageDownloadUrl -BucketName $Bucket -ObjectPath $path
  }

  Assert-NotBlank -Value $name -Label "artifact.name ($BundleId)"
  Assert-NotBlank -Value $downloadUrl -Label "artifact.download_url ($name)"
  Assert-NotBlank -Value $sizeBytes -Label "artifact.size_bytes ($name)"
  Assert-NotBlank -Value $sha256 -Label "artifact.sha256 ($name)"

  $uri = [System.Uri]$downloadUrl
  if ($uri.Scheme -ne "https") {
    throw "Artifact $name must use https: $downloadUrl"
  }

  $Artifacts.Add([pscustomobject]@{
    BundleId = $BundleId
    Name = $name
    Path = $path
    DownloadUrl = $downloadUrl
    SizeBytes = [int64]$sizeBytes
    Sha256 = $sha256.Trim().ToLowerInvariant()
  }) | Out-Null
}

function Get-ManifestArtifacts {
  param([object]$Manifest)

  $artifacts = [System.Collections.Generic.List[object]]::new()
  $topLevelArtifacts = Get-ObjectProperty -Object $Manifest -Name "artifacts"
  if ($null -ne $topLevelArtifacts) {
    foreach ($artifact in @($topLevelArtifacts)) {
      Add-Artifact -Artifacts $artifacts -Artifact $artifact -BundleId "manifest"
    }
  }

  $bundles = Get-ObjectProperty -Object $Manifest -Name "bundles"
  if ($null -eq $bundles -or @($bundles).Count -eq 0) {
    throw "Manifest must contain at least one bundle."
  }

  foreach ($bundle in @($bundles)) {
    $bundleId = [string](Get-ObjectProperty -Object $bundle -Name "id")
    Assert-NotBlank -Value $bundleId -Label "bundle.id"
    Assert-NotBlank -Value (Get-ObjectProperty -Object $bundle -Name "kind") -Label "bundle.kind ($bundleId)"
    $bundleArtifactsRaw = Get-ObjectProperty -Object $bundle -Name "artifacts"
    if ($null -eq $bundleArtifactsRaw -or @($bundleArtifactsRaw).Count -eq 0) {
      throw "Missing required manifest field: bundle.artifacts ($bundleId)"
    }
    foreach ($artifact in @($bundleArtifactsRaw)) {
      Add-Artifact -Artifacts $artifacts -Artifact $artifact -BundleId $bundleId
    }
  }

  $deduped = [System.Collections.Generic.List[object]]::new()
  $seen = @{}
  foreach ($artifact in $artifacts) {
    $key = $artifact.DownloadUrl
    if ($seen.ContainsKey($key)) {
      continue
    }
    $seen[$key] = $true
    $deduped.Add($artifact) | Out-Null
  }
  return $deduped
}

if ([string]::IsNullOrWhiteSpace($ProjectId)) {
  $ProjectId = Get-DefaultFirebaseProjectId
}
if ([string]::IsNullOrWhiteSpace($ProjectId) -and [string]::IsNullOrWhiteSpace($Bucket) -and [string]::IsNullOrWhiteSpace($ManifestUrl)) {
  throw "Missing ProjectId. Pass -ProjectId, -Bucket, or -ManifestUrl."
}
if ([string]::IsNullOrWhiteSpace($Bucket) -and -not [string]::IsNullOrWhiteSpace($ProjectId)) {
  $Bucket = "$ProjectId.firebasestorage.app"
}
if ([string]::IsNullOrWhiteSpace($ManifestUrl)) {
  $ManifestUrl = Get-FirebaseStorageDownloadUrl -BucketName $Bucket -ObjectPath "catalog/$Game/latest/manifest.json"
}
if ([string]::IsNullOrWhiteSpace($DownloadDir)) {
  $DownloadDir = Join-Path ([System.IO.Path]::GetTempPath()) ("bindervault_catalog_verify_" + [System.Guid]::NewGuid().ToString("N"))
}

New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
$manifestPath = Join-Path $DownloadDir "manifest.json"

try {
  Write-Host "[verify] game=$Game"
  Write-Host "[verify] manifest=$ManifestUrl"
  Invoke-WebRequest -Uri $ManifestUrl -OutFile $manifestPath -UseBasicParsing -TimeoutSec 60

  $manifestJson = Read-Utf8JsonFileNoBom -Path $manifestPath
  $manifest = $manifestJson | ConvertFrom-Json

  Assert-NotBlank -Value (Get-ObjectProperty -Object $manifest -Name "bundle") -Label "bundle"
  Assert-NotBlank -Value (Get-ObjectProperty -Object $manifest -Name "version") -Label "version"
  Assert-NotBlank -Value (Get-ObjectProperty -Object $manifest -Name "schema_version") -Label "schema_version"
  Assert-NotBlank -Value (Get-ObjectProperty -Object $manifest -Name "compatibility_version") -Label "compatibility_version"

  $manifestBundle = [string](Get-ObjectProperty -Object $manifest -Name "bundle")
  if ($manifestBundle.Trim().ToLowerInvariant() -ne $Game.Trim().ToLowerInvariant()) {
    throw "Manifest bundle mismatch. Expected $Game, got $manifestBundle."
  }

  $version = [string](Get-ObjectProperty -Object $manifest -Name "version")
  $schemaVersion = [string](Get-ObjectProperty -Object $manifest -Name "schema_version")
  $compatVersion = [string](Get-ObjectProperty -Object $manifest -Name "compatibility_version")
  Write-Host "[verify] version=$version schema=$schemaVersion compat=$compatVersion"

  $artifacts = Get-ManifestArtifacts -Manifest $manifest
  if ($artifacts.Count -eq 0) {
    throw "Manifest has no artifacts."
  }
  Write-Host "[verify] artifacts=$($artifacts.Count)"

  foreach ($artifact in $artifacts) {
    $safeName = ($artifact.Name -replace '[^A-Za-z0-9._-]', '_')
    $artifactPath = Join-Path $DownloadDir ([System.Guid]::NewGuid().ToString("N") + "_" + $safeName)
    Write-Host "[verify] download $($artifact.BundleId)/$($artifact.Name)"
    Invoke-WebRequest -Uri $artifact.DownloadUrl -OutFile $artifactPath -UseBasicParsing -TimeoutSec 600

    $actualSize = (Get-Item -LiteralPath $artifactPath).Length
    if ($actualSize -ne $artifact.SizeBytes) {
      throw "Size mismatch for $($artifact.Name): expected $($artifact.SizeBytes), got $actualSize."
    }

    $actualHash = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $artifact.Sha256) {
      throw "SHA-256 mismatch for $($artifact.Name): expected $($artifact.Sha256), got $actualHash."
    }
  }

  Write-Host "[verify] ok" -ForegroundColor Green
} finally {
  if (-not $KeepDownloads) {
    Remove-Item -LiteralPath $DownloadDir -Recurse -Force -ErrorAction SilentlyContinue
  } else {
    Write-Host "[verify] kept downloads at $DownloadDir"
  }
}
