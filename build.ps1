# build.ps1 - Build Auto-Retry bundle without Node.js
# Usage: powershell -ExecutionPolicy Bypass -File build.ps1

param(
    [string]$SrcDir = (Join-Path $PSScriptRoot 'src'),
    [string]$OutDir = (Join-Path $PSScriptRoot 'dist'),
    [string]$OutFile = ''
)

$ErrorActionPreference = 'Stop'

if (-not $OutFile) {
    $OutFile = Join-Path $OutDir 'auto-retry.bundle.js'
}

$modules = @(
    'config.js',
    'state.js',
    'status-badge.js',
    'fetch-retry.js',
    'audio-mute.js',
    'dom-clicker.js',
    'entry.js'
)

$maxLines = 300

Write-Host '=== Auto-Retry Build (PowerShell) ===' -ForegroundColor Cyan
Write-Host ''

# Validate source files
$hasError = $false
foreach ($m in $modules) {
    $f = Join-Path $SrcDir $m
    if (!(Test-Path $f)) {
        Write-Host "[ERROR] File not found: $m" -ForegroundColor Red
        $hasError = $true
        continue
    }
    $lines = (Get-Content $f).Count
    if ($lines -gt $maxLines) {
        Write-Host "[ERROR] $m exceeds $maxLines lines ($lines)" -ForegroundColor Red
        $hasError = $true
    } else {
        Write-Host "  OK $m : $lines lines" -ForegroundColor Green
    }
}

if ($hasError) {
    Write-Host ''
    Write-Host '[ERROR] Build stopped. Fix errors above.' -ForegroundColor Red
    exit 1
}

# Build bundle
Write-Host ''
Write-Host 'Building bundle...' -ForegroundColor Yellow

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$moduleList = $modules -join ', '

$sb = New-Object System.Text.StringBuilder

# Header
$headerBlock = @"
/**
 * Antigravity Auto-Retry Patch v3.0 -- Bundle
 * Built: $timestamp
 * Modules: $moduleList
 */
"@
[void]$sb.AppendLine($headerBlock)

$iifeOpen = "(function() {"
[void]$sb.AppendLine($iifeOpen)
[void]$sb.AppendLine("    'use strict';")
[void]$sb.AppendLine('')

foreach ($m in $modules) {
    $f = Join-Path $SrcDir $m
    $content = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)

    $separator = "    // ========== $m =========="
    [void]$sb.AppendLine($separator)

    $contentLines = $content -split "`n"
    foreach ($rawLine in $contentLines) {
        $line = $rawLine.TrimEnd("`r")
        if ($line -ne '') {
            [void]$sb.AppendLine("    $line")
        } else {
            [void]$sb.AppendLine('')
        }
    }
    [void]$sb.AppendLine('')
}

$iifeClose = "})();"
[void]$sb.AppendLine($iifeClose)

# Create dist/ if needed
if (!(Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$result = $sb.ToString()
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($OutFile, $result, $utf8NoBom)

$totalLines = ($result -split "`n").Count
$totalBytes = [System.Text.Encoding]::UTF8.GetByteCount($result)

Write-Host ''
Write-Host "OK Bundle: $OutFile" -ForegroundColor Green
Write-Host "   $totalLines lines, $totalBytes bytes"
Write-Host ''
