# remove-inject.ps1 - Remove auto-retry.js script tag from workbench HTML
# Usage: powershell -ExecutionPolicy Bypass -File remove-inject.ps1 -HtmlFile "path"

param(
    [Parameter(Mandatory=$true)]
    [string]$HtmlFile
)

$ErrorActionPreference = 'Stop'

if (!(Test-Path $HtmlFile)) {
    Write-Host "[ERROR] HTML file not found: $HtmlFile" -ForegroundColor Red
    exit 1
}

$content = [System.IO.File]::ReadAllText($HtmlFile)

# Try all possible variations of the script tag (with/without newlines around it)
$content = $content.Replace("`n<script src=""./auto-retry.js""></script>", '')
$content = $content.Replace("<script src=""./auto-retry.js""></script>`n", '')
$content = $content.Replace("<script src=""./auto-retry.js""></script>", '')

[System.IO.File]::WriteAllText($HtmlFile, $content)
Write-Host "      OK" -ForegroundColor Green
