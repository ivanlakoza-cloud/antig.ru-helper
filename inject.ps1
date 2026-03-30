# inject.ps1 - Inject auto-retry.js script tag into workbench HTML
# Usage: powershell -ExecutionPolicy Bypass -File inject.ps1 -HtmlFile "path"

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
$tag = '<script src="./auto-retry.js"></script>'
$target = '<script src="./jetskiAgent.js" type="module"></script>'

if ($content.Contains($tag)) {
    Write-Host "      Already injected." -ForegroundColor Green
    exit 0
}

if ($content.Contains($target)) {
    $content = $content.Replace($target, $tag + "`n" + $target)
    [System.IO.File]::WriteAllText($HtmlFile, $content)
    Write-Host "      Script tag injected before jetskiAgent.js" -ForegroundColor Green
} else {
    Write-Host "[WARN] jetskiAgent.js not found, trying </head>..." -ForegroundColor Yellow
    $headIdx = $content.IndexOf('</head>')
    if ($headIdx -gt 0) {
        $content = $content.Insert($headIdx, $tag + "`n")
        [System.IO.File]::WriteAllText($HtmlFile, $content)
        Write-Host "      Injected before </head>" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Cannot find injection point!" -ForegroundColor Red
        exit 1
    }
}
