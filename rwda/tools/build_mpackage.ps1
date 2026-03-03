param(
  [string]$OutputDir = "dist",
  [string]$PackageBaseName = "RWDA_Bootstrap",
  [string]$Version = "0.3.0",
  [string]$Author = "Project Silverfury",
  [string]$Title = "RWDA Bootstrap Loader"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path "."
$bootstrapXml = Join-Path $projectRoot "RWDA_Bootstrap.xml"

if (-not (Test-Path $bootstrapXml)) {
  throw "Missing RWDA_Bootstrap.xml at project root."
}

$outDirPath = Join-Path $projectRoot $OutputDir
New-Item -ItemType Directory -Path $outDirPath -Force | Out-Null

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("rwda_pkg_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
  $configLua = @(
    "mpackage = [[${PackageBaseName}]]"
    "author = [[${Author}]]"
    "title = [[${Title}]]"
    "version = [[${Version}]]"
    "created = """ + (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK") + """"
  ) -join "`r`n"

  Set-Content -Path (Join-Path $tempRoot "config.lua") -Value $configLua -Encoding UTF8
  Copy-Item -Path $bootstrapXml -Destination (Join-Path $tempRoot "RWDA_Bootstrap.xml") -Force

  $outFile = Join-Path $outDirPath ("{0}.mpackage" -f $PackageBaseName)
  $zipFile = Join-Path $outDirPath ("{0}.zip" -f $PackageBaseName)
  if (Test-Path $outFile) { Remove-Item -Path $outFile -Force }
  if (Test-Path $zipFile) { Remove-Item -Path $zipFile -Force }

  Compress-Archive -Path (Join-Path $tempRoot "*") -DestinationPath $zipFile -Force
  Rename-Item -Path $zipFile -NewName (Split-Path $outFile -Leaf)
  Write-Host ("Built {0}" -f $outFile)
}
finally {
  if (Test-Path $tempRoot) {
    Remove-Item -Path $tempRoot -Recurse -Force
  }
}
