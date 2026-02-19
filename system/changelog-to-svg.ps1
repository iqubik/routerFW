<#
.SYNOPSIS
    Парсит CHANGELOG.md, считает метрики по релизам и генерирует анимированные SVG (light/dark).
# file: system/changelog-to-svg.ps1
.DESCRIPTION
    Читает CHANGELOG.md из корня репозитория (формат get-git.ps1), извлекает блоки по тегам,
    парсит tag, published, title, url и метрики тела (bullet_count, body_length), строит
    временную шкалу (release-timeline*.svg) и древо развития фич (release-tree*.svg) в dist/.
.EXAMPLE
    .\system\changelog-to-svg.ps1
#>

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Get-Item $ScriptDir).Parent.FullName
$ChangelogPath = Join-Path $ProjectRoot "CHANGELOG.md"
$DistDir = Join-Path $ProjectRoot "dist"

if (-not (Test-Path $ChangelogPath)) {
    Write-Error "CHANGELOG.md not found: $ChangelogPath"
    exit 1
}

$content = Get-Content -Path $ChangelogPath -Raw -Encoding UTF8
$releases = [System.Collections.ArrayList]@()

# Blocks: ## ========== TAG: X ========== ... (until next TAG or EOF)
$blockRegex = [regex]'(?ms)^## ========== TAG: ([^\r\n=]+?) ==========\r?\n(.*?)(?=^## ========== TAG: |\z)'
$blockMatches = $blockRegex.Matches($content)

foreach ($bm in $blockMatches) {
    $tagName = $bm.Groups[1].Value.Trim()
    $block = $bm.Groups[2].Value

    # Split metadata (before "--") and body (after "--")
    $parts = $block -split '\r?\n\s*--\s*\r?\n', 2
    $metaSection = $parts[0]
    $bodySection = if ($parts.Count -gt 1) { $parts[1] } else { "" }

    $meta = @{}
    foreach ($line in ($metaSection -split '\r?\n')) {
        if ($line -match '^([^:]+):\s*(.*)$') {
            $meta[$Matches[1].Trim().ToLowerInvariant()] = $Matches[2].Trim()
        }
    }

    $publishedStr = $meta['published']
    if (-not $publishedStr) { continue }

    try {
        $published = [DateTime]::Parse($publishedStr, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
    } catch {
        continue
    }

    $bulletCount = 0
    foreach ($bodyLine in ($bodySection -split '\r?\n')) {
        $t = $bodyLine.TrimStart()
        if ($t.StartsWith('*') -or $t.StartsWith('-')) { $bulletCount++ }
    }
    $bodyLength = $bodySection.Length

    [void]$releases.Add([PSCustomObject]@{
        tag       = $tagName
        published = $published
        title     = $meta['title']
        url       = $meta['url']
        bullet_count = $bulletCount
        body_length  = $bodyLength
    })
}

# Sort by published
$releases = $releases | Sort-Object -Property published
$n = $releases.Count
if ($n -eq 0) {
    Write-Host "No releases parsed from CHANGELOG. Skipping SVG generation."
    exit 0
}

# Timeline bounds
$minDate = ($releases | Measure-Object -Property published -Minimum).Minimum
$maxDate = ($releases | Measure-Object -Property published -Maximum).Maximum
$dateRange = ($maxDate - $minDate).TotalDays
if ($dateRange -lt 1) { $dateRange = 1 }

# SVG dimensions and padding
$width = 800
$height = 360
$padL = 52
$padR = 24
$padT = 28
$padB = 44
$chartW = $width - $padL - $padR
$chartH = $height - $padT - $padB

function Get-XFromDate($d) {
    $t = ($d - $minDate).TotalDays / $dateRange
    return [int]($padL + $t * $chartW)
}

function Get-YFromIndex($i) {
    if ($n -le 1) { return $padT + $chartH / 2 }
    $t = $i / ([double]($n - 1))
    return [int]($padT + (1 - $t) * $chartH)
}

function EscapeXml($s) {
    if (-not $s) { return "" }
    return [System.Net.WebUtility]::HtmlEncode($s)
}

function Write-SvgFile($path, $isDark) {
    $bg = if ($isDark) { "#0d1117" } else { "#ffffff" }
    $fg = if ($isDark) { "#e6edf3" } else { "#1f2328" }
    $grid = if ($isDark) { "#30363d" } else { "#d0d7de" }
    $accent = if ($isDark) { "#58a6ff" } else { "#0969da" }
    $muted = if ($isDark) { "#8b949e" } else { "#656d76" }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 ' + $width + ' ' + $height + '" width="' + $width + '" height="' + $height + '">')
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine('  .pt { opacity: 0; animation: fadeIn 0.4s ease forwards; }')
    [void]$sb.AppendLine('  .ln { opacity: 0; stroke-dasharray: 1000; stroke-dashoffset: 1000; animation: drawLine 1.2s ease forwards; }')
    [void]$sb.AppendLine('  @keyframes fadeIn { to { opacity: 1; } }')
    [void]$sb.AppendLine('  @keyframes drawLine { to { stroke-dashoffset: 0; opacity: 1; } }')
    [void]$sb.AppendLine('</style>')
    [void]$sb.AppendLine('<rect width="' + $width + '" height="' + $height + '" fill="' + $bg + '"/>')

    # Grid: vertical lines by date, horizontal by index
    [void]$sb.AppendLine('<g stroke="' + $grid + '" stroke-width="0.5" opacity="0.6">')
    for ($i = 0; $i -le 4; $i++) {
        $x = $padL + ($i / 4) * $chartW
        [void]$sb.AppendLine('  <line x1="' + $x + '" y1="' + $padT + '" x2="' + $x + '" y2="' + ($height - $padB) + '"/>')
    }
    for ($i = 0; $i -le 4; $i++) {
        $y = $padT + ($i / 4) * $chartH
        [void]$sb.AppendLine('  <line x1="' + $padL + '" y1="' + $y + '" x2="' + ($width - $padR) + '" y2="' + $y + '"/>')
    }
    [void]$sb.AppendLine('</g>')

    # Axis labels (dates)
    [void]$sb.AppendLine('<g fill="' + $muted + '" font-size="10" font-family="system-ui,sans-serif">')
    for ($i = 0; $i -le 4; $i++) {
        $d = $minDate.AddDays(($i / 4) * $dateRange)
        $x = $padL + ($i / 4) * $chartW
        [void]$sb.AppendLine('  <text x="' + $x + '" y="' + ($height - 16) + '" text-anchor="middle">' + (EscapeXml($d.ToString("yyyy-MM-dd"))) + '</text>')
    }
    [void]$sb.AppendLine('</g>')

    # Polyline (path) with animation per segment
    $pathD = ""
    for ($i = 0; $i -lt $n; $i++) {
        $r = $releases[$i]
        $x = Get-XFromDate $r.published
        $y = Get-YFromIndex $i
        if ($i -eq 0) { $pathD = "M $x $y" } else { $pathD += " L $x $y" }
    }
    $delay = 0
    [void]$sb.AppendLine('<path id="tl-path" d="' + $pathD + '" fill="none" stroke="' + $accent + '" stroke-width="2" class="ln" style="animation-delay: 0.2s"/>')
    [void]$sb.AppendLine('<g id="points">')
    for ($i = 0; $i -lt $n; $i++) {
        $r = $releases[$i]
        $x = Get-XFromDate $r.published
        $y = Get-YFromIndex $i
        $delaySec = [math]::Round(0.3 + $i * 0.12, 2)
        $radius = 5
        if ($r.body_length -gt 0) {
            $radius = 4 + [math]::Min(6, [math]::Log10(1 + $r.body_length) * 1.5)
        }
        $label = EscapeXml($r.tag)
        $url = EscapeXml($r.url)

        if ($url) {
            [void]$sb.AppendLine('  <a xlink:href="' + $url + '" target="_blank" rel="noopener">')
        }
        [void]$sb.AppendLine('    <circle class="pt" cx="' + $x + '" cy="' + $y + '" r="' + [int]$radius + '" fill="' + $accent + '" stroke="' + $fg + '" stroke-width="1.5" style="animation-delay: ' + $delaySec + 's"/>')
        [void]$sb.AppendLine('    <text class="pt" x="' + $x + '" y="' + ($y - $radius - 6) + '" text-anchor="middle" fill="' + $fg + '" font-size="11" font-family="system-ui,sans-serif" style="animation-delay: ' + $delaySec + 's">' + $label + '</text>')
        if ($url) {
            [void]$sb.AppendLine('  </a>')
        }
    }
    [void]$sb.AppendLine('</g>')

    [void]$sb.AppendLine('</svg>')

    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $sb.ToString(), $utf8NoBom)
}

# ---- Древо развития фич: вертикальное дерево, размер узла = объём фич (bullet_count/body) ----
$treeNodeHeight = 56
$treeWidth = 520
$treeHeight = [math]::Max(320, $n * $treeNodeHeight)
$treePadL = 28
$treePadR = 24
$treePadT = 24
$treePadB = 24
$treeCenterX = $treePadL + 32
$treeChartH = $treeHeight - $treePadT - $treePadB

function Get-TreeY($i) {
    if ($n -le 1) { return $treePadT + $treeChartH / 2 }
    $t = $i / ([double]($n - 1))
    return [int]($treePadT + $t * $treeChartH)
}

function Write-TreeSvgFile($path, $isDark) {
    $bg = if ($isDark) { "#0d1117" } else { "#ffffff" }
    $fg = if ($isDark) { "#e6edf3" } else { "#1f2328" }
    $grid = if ($isDark) { "#30363d" } else { "#eaeef2" }
    $accent = if ($isDark) { "#58a6ff" } else { "#0969da" }
    $muted = if ($isDark) { "#8b949e" } else { "#656d76" }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 ' + $treeWidth + ' ' + $treeHeight + '" width="' + $treeWidth + '" height="' + $treeHeight + '">')
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine('  .tr-nd { opacity: 0; animation: trFade 0.35s ease forwards; }')
    [void]$sb.AppendLine('  .tr-ln { opacity: 0; stroke-dasharray: 800; stroke-dashoffset: 800; animation: trDraw 0.8s ease forwards; }')
    [void]$sb.AppendLine('  @keyframes trFade { to { opacity: 1; } }')
    [void]$sb.AppendLine('  @keyframes trDraw { to { stroke-dashoffset: 0; opacity: 1; } }')
    [void]$sb.AppendLine('</style>')
    [void]$sb.AppendLine('<rect width="' + $treeWidth + '" height="' + $treeHeight + '" fill="' + $bg + '"/>')

    # Вертикальная линия ствола (от первого до последнего узла)
    $y0 = Get-TreeY 0
    $yN = Get-TreeY ($n - 1)
    [void]$sb.AppendLine('<line x1="' + $treeCenterX + '" y1="' + $y0 + '" x2="' + $treeCenterX + '" y2="' + $yN + '" stroke="' + $grid + '" stroke-width="2" class="tr-ln" style="animation-delay: 0.1s"/>')

    for ($i = 0; $i -lt $n; $i++) {
        $r = $releases[$i]
        $y = Get-TreeY $i
        $delaySec = [math]::Round(0.15 + $i * 0.08, 2)
        # Размер узла по объёму фич: bullet_count + лог от длины тела
        $vol = $r.bullet_count + [math]::Max(0, [math]::Log10(1 + $r.body_length / 100) * 3)
        $radius = [math]::Max(6, [math]::Min(20, 6 + $vol))
        $label = EscapeXml($r.tag)
        $url = EscapeXml($r.url)
        $hint = if ($r.bullet_count -gt 0) { " (" + $r.bullet_count + ")" } else { "" }
        $tagLabel = $label + $hint

        if ($url) {
            [void]$sb.AppendLine('  <a xlink:href="' + $url + '" target="_blank" rel="noopener">')
        }
        [void]$sb.AppendLine('    <circle class="tr-nd" cx="' + $treeCenterX + '" cy="' + $y + '" r="' + [int]$radius + '" fill="' + $accent + '" stroke="' + $fg + '" stroke-width="1.5" style="animation-delay: ' + $delaySec + 's"/>')
        [void]$sb.AppendLine('    <text class="tr-nd" x="' + ($treeCenterX + $radius + 10) + '" y="' + ($y + 4) + '" fill="' + $fg + '" font-size="12" font-family="system-ui,sans-serif" style="animation-delay: ' + $delaySec + 's">' + (EscapeXml($tagLabel)) + '</text>')
        [void]$sb.AppendLine('    <text class="tr-nd" x="' + ($treeCenterX + $radius + 10) + '" y="' + ($y + 18) + '" fill="' + $muted + '" font-size="9" font-family="system-ui,sans-serif" style="animation-delay: ' + $delaySec + 's">' + (EscapeXml($r.published.ToString("yyyy-MM-dd"))) + '</text>')
        if ($url) {
            [void]$sb.AppendLine('  </a>')
        }
    }

    [void]$sb.AppendLine('</svg>')
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $sb.ToString(), $utf8NoBom)
}

if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

$svgLight = Join-Path $DistDir "release-timeline.svg"
$svgDark = Join-Path $DistDir "release-timeline-dark.svg"
Write-SvgFile -path $svgLight -isDark $false
Write-SvgFile -path $svgDark -isDark $true
# Предпочтительный вариант (тёмная тема)
$darkContent = [System.IO.File]::ReadAllText($svgDark, [System.Text.Encoding]::UTF8)
$darkContent = $darkContent.Insert($darkContent.IndexOf('<svg '), "<!-- Preferred variant: dark theme -->`n")
[System.IO.File]::WriteAllText($svgDark, $darkContent, (New-Object System.Text.UTF8Encoding $false))

$treeLight = Join-Path $DistDir "release-tree.svg"
$treeDark = Join-Path $DistDir "release-tree-dark.svg"
Write-TreeSvgFile -path $treeLight -isDark $false
Write-TreeSvgFile -path $treeDark -isDark $true

Write-Host "Written: $svgLight, $svgDark, $treeLight, $treeDark (releases: $n)"
