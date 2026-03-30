# checksum.ps1 - Update checksum in product.json for modified HTML
# Usage: powershell -ExecutionPolicy Bypass -File checksum.ps1 -HtmlFile "path" -ProductJson "path"

param(
    [Parameter(Mandatory=$true)]
    [string]$HtmlFile,
    
    [Parameter(Mandatory=$true)]
    [string]$ProductJson
)

$ErrorActionPreference = 'Stop'

if (!(Test-Path $HtmlFile)) {
    Write-Host "[ERROR] HTML file not found: $HtmlFile" -ForegroundColor Red
    exit 1
}

if (!(Test-Path $ProductJson)) {
    Write-Host "[ERROR] product.json not found: $ProductJson" -ForegroundColor Red
    exit 1
}

# Determine the key based on filename
$fileName = [System.IO.Path]::GetFileName($HtmlFile)
switch ($fileName) {
    "workbench.html" {
        $key = "vs/code/electron-browser/workbench/workbench.html"
    }
    "workbench-jetski-agent.html" {
        $key = "vs/code/electron-browser/workbench/workbench-jetski-agent.html"
    }
    default {
        Write-Host "[ERROR] Unknown HTML file: $fileName" -ForegroundColor Red
        exit 1
    }
}

# Compute SHA256 base64 hash
$bytes = [System.IO.File]::ReadAllBytes($HtmlFile)
$sha = [System.Security.Cryptography.SHA256]::Create()
$hashBytes = $sha.ComputeHash($bytes)
$hash = [Convert]::ToBase64String($hashBytes)

# Read product.json
$content = [System.IO.File]::ReadAllText($ProductJson)

# Escape key for regex
$escapedKey = [regex]::Escape($key)

# Check if the pattern exists
$pattern = "(""$escapedKey"": "")([^""]+)("")"
$match = [regex]::Match($content, $pattern)

if (!$match.Success) {
    Write-Host "      $fileName - no checksum entry found (skipping)" -ForegroundColor Yellow
    exit 0
}

$oldHash = $match.Groups[2].Value

if ($oldHash -eq $hash) {
    Write-Host "      $fileName - checksum OK" -ForegroundColor Green
    exit 0
}

# Update checksum
$replacement = '${1}' + $hash + '${3}'
$newContent = [regex]::Replace($content, $pattern, $replacement)
[System.IO.File]::WriteAllText($ProductJson, $newContent)
Write-Host "      $fileName - $hash" -ForegroundColor Green
