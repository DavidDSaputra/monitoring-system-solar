$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$dist = Join-Path $root 'dist'
$packageDir = Join-Path $dist 'backend-vps'
$zipPath = Join-Path $dist 'jarwinn-backend-vps.zip'

function Assert-UnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RootPath
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($RootPath)
    if (-not $fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to operate outside workspace: $fullPath"
    }
}

New-Item -ItemType Directory -Force -Path $dist | Out-Null
Assert-UnderRoot -Path $packageDir -RootPath $root
Assert-UnderRoot -Path $zipPath -RootPath $root

if (Test-Path -LiteralPath $packageDir) {
    Remove-Item -LiteralPath $packageDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $packageDir | Out-Null

$apiSource = Join-Path $root 'api'
$apiDest = Join-Path $packageDir 'api'

robocopy $apiSource $apiDest /E /XD cache /XF *.log | Out-Host
if ($LASTEXITCODE -gt 7) {
    throw "robocopy failed with exit code $LASTEXITCODE"
}

$cacheDest = Join-Path $apiDest 'cache'
New-Item -ItemType Directory -Force -Path $cacheDest | Out-Null
Copy-Item -LiteralPath (Join-Path $apiSource 'cache\.htaccess') -Destination (Join-Path $cacheDest '.htaccess') -Force
Copy-Item -LiteralPath (Join-Path $apiSource 'cache\.gitkeep') -Destination (Join-Path $cacheDest '.gitkeep') -Force

Copy-Item -LiteralPath (Join-Path $root '.env.example') -Destination (Join-Path $packageDir '.env.example') -Force
Copy-Item -LiteralPath (Join-Path $root 'deploy\backend-root.htaccess') -Destination (Join-Path $packageDir '.htaccess') -Force
Copy-Item -LiteralPath (Join-Path $root 'docs\vps_backend_deploy.md') -Destination (Join-Path $packageDir 'README.md') -Force

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path (Join-Path $packageDir '*') -DestinationPath $zipPath -Force

Write-Host ''
Write-Host "Backend VPS package ready:"
Write-Host "  Folder: $packageDir"
Write-Host "  Zip:    $zipPath"
