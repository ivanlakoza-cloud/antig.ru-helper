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

# Compute SHA256 base64 hash
$bytes = [System.IO.File]::ReadAllBytes($HtmlFile)
$sha = [System.Security.Cryptography.SHA256]::Create()
$hashBytes = $sha.ComputeHash($bytes)
$hash = [Convert]::ToBase64String($hashBytes)

# Read product.json
$content = [System.IO.File]::ReadAllText($ProductJson)

# Check if the pattern exists at all
$pattern = '("vs/code/electron-browser/workbench/workbench-jetski-agent\.html": ")([^"]+)(")'
$match = [regex]::Match($content, $pattern)

if (!$match.Success) {
    Write-Host "[WARN] Checksum entry not found in product.json" -ForegroundColor Yellow
    Write-Host "       Looking for: workbench-jetski-agent.html" -ForegroundColor Yellow
    
    # Debug: show what keys exist
    $found = [regex]::Matches($content, '"(vs/code/[^"]*workbench[^"]*)"')
    if ($found.Count -gt 0) {
        Write-Host "       Found workbench entries:" -ForegroundColor Yellow
        foreach ($m in $found) {
            Write-Host "         $($m.Groups[1].Value)" -ForegroundColor Yellow
        }
    }
    exit 1
}

$oldHash = $match.Groups[2].Value

if ($oldHash -eq $hash) {
    Write-Host "      Checksum already up to date: $hash" -ForegroundColor Green
    exit 0
}

# Update checksum
$replacement = '${1}' + $hash + '${3}'
$newContent = [regex]::Replace($content, $pattern, $replacement)
[System.IO.File]::WriteAllText($ProductJson, $newContent)
Write-Host "      Checksum: $hash" -ForegroundColor Green
