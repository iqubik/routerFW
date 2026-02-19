<#
.SYNOPSIS
    V3: виджеты из CHANGELOG — heatmap, river, pulse bars, stats strip (только новые файлы, текущий код не трогаем).
# file: system/changelog-to-svg-v3.ps1
.DESCRIPTION
    Парсит CHANGELOG.md (формат get-git.ps1), извлекает максимум метрик и генерирует горизонтальные
    анимированные SVG (light/dark): heatmap активности, река объёма релизов, пульс-бары, полоска статистики.
    Высота виджетов до 500px, ширина 800px (responsive viewBox).
.EXAMPLE
    .\system\changelog-to-svg-v3.ps1
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

$blockRegex = [regex]'(?ms)^## ========== TAG: ([^\r\n=]+?) ==========\r?\n(.*?)(?=^## ========== TAG: |\z)'
$blockMatches = $blockRegex.Matches($content)

foreach ($bm in $blockMatches) {
    $tagName = $bm.Groups[1].Value.Trim()
    $block = $bm.Groups[2].Value
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
        tag          = $tagName
        published    = $published
        title        = $meta['title']
        url          = $meta['url']
        bullet_count = $bulletCount
        body_length  = $bodyLength
    })
}

$releases = $releases | Sort-Object -Property published
$n = $releases.Count
if ($n -eq 0) {
    Write-Host "No releases parsed. V3 SVG generation skipped."
    exit 0
}

$minDate = ($releases | Measure-Object -Property published -Minimum).Minimum
$maxDate = ($releases | Measure-Object -Property published -Maximum).Maximum
$dateRange = ($maxDate - $minDate).TotalDays
if ($dateRange -lt 1) { $dateRange = 1 }

$totalBullets = ($releases | Measure-Object -Property bullet_count -Sum).Sum
$maxBullet = ($releases | Measure-Object -Property bullet_count -Maximum).Maximum
if ($maxBullet -lt 1) { $maxBullet = 1 }

function EscapeXml($s) {
    if (-not $s) { return "" }
    return [System.Net.WebUtility]::HtmlEncode($s)
}

# ---- 1) Heatmap: только недели с данными, ось дат, легенда (информативная) ----
$heatmapW = 800
$heatmapH = 160
$heatmapPadL = 12
$heatmapPadR = 140
$heatmapPadT = 32
$heatmapPadB = 28
$heatmapChartW = $heatmapW - $heatmapPadL - $heatmapPadR
$heatmapCellH = 36

# Недели в диапазоне релизов (каждая колонка = одна неделя)
$heatmapWeeksTotal = [math]::Max(1, [math]::Min(52, [math]::Ceiling($dateRange / 7)))
$heatmapWeekBuckets = @{}
for ($w = 0; $w -lt $heatmapWeeksTotal; $w++) { $heatmapWeekBuckets[$w] = @{ count = 0; bullets = 0 } }
foreach ($r in $releases) {
    $weekIndex = [int](($r.published - $minDate).TotalDays / 7)
    if ($weekIndex -ge $heatmapWeeksTotal) { $weekIndex = $heatmapWeeksTotal - 1 }
    if ($weekIndex -lt 0) { $weekIndex = 0 }
    $heatmapWeekBuckets[$weekIndex].count++
    $heatmapWeekBuckets[$weekIndex].bullets += $r.bullet_count
}

$heatmapMaxVal = 1
foreach ($w in 0..($heatmapWeeksTotal - 1)) {
    $v = $heatmapWeekBuckets[$w].bullets + $heatmapWeekBuckets[$w].count * 5
    if ($v -gt $heatmapMaxVal) { $heatmapMaxVal = $v }
}
$heatmapCellW = $heatmapChartW / $heatmapWeeksTotal

function Write-HeatmapSvg($path, $isDark) {
    $bg = if ($isDark) { "#0d1117" } else { "#f6f8fa" }
    $fg = if ($isDark) { "#e6edf3" } else { "#1f2328" }
    $muted = if ($isDark) { "#8b949e" } else { "#656d76" }
    $grid = if ($isDark) { "#21262d" } else { "#d0d7de" }
    $accentLow = if ($isDark) { "#238636" } else { "#2da44e" }
    $accentMid = if ($isDark) { "#58a6ff" } else { "#0969da" }
    $accentHigh = if ($isDark) { "#a371f7" } else { "#8250df" }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 ' + $heatmapW + ' ' + $heatmapH + '" width="100%" height="' + $heatmapH + '">')
    [void]$sb.AppendLine('<style>.hm-cell{ opacity:0; transform-origin:center; animation:hmPop 0.35s ease forwards; } @keyframes hmPop{ 0%{ opacity:0; transform:scale(0.7); } 100%{ opacity:1; transform:scale(1); } }</style>')
    [void]$sb.AppendLine('<rect width="' + $heatmapW + '" height="' + $heatmapH + '" fill="' + $bg + '" rx="8"/>')

    for ($w = 0; $w -lt $heatmapWeeksTotal; $w++) {
        $x = $heatmapPadL + $w * $heatmapCellW + 2
        $val = $heatmapWeekBuckets[$w].bullets + $heatmapWeekBuckets[$w].count * 5
        $intensity = $val / $heatmapMaxVal
        if ($intensity -gt 1) { $intensity = 1 }
        $fill = $grid
        if ($intensity -gt 0.01) {
            if ($intensity -lt 0.33) { $fill = $accentLow }
            elseif ($intensity -lt 0.66) { $fill = $accentMid }
            else { $fill = $accentHigh }
        }
        $delay = [math]::Round(0.03 * $w, 2)
        $cellW = [math]::Max(4, [int]($heatmapCellW - 2))
        [void]$sb.AppendLine('<rect class="hm-cell" x="' + [int]$x + '" y="' + ($heatmapPadT + 2) + '" width="' + $cellW + '" height="' + ($heatmapCellH - 2) + '" rx="4" fill="' + $fill + '" style="animation-delay:' + $delay + 's"/>')
    }

    $week0Start = $minDate
    $weekNEnd = $maxDate
    $labelStart = (EscapeXml($week0Start.ToString("dd MMM yyyy", [System.Globalization.CultureInfo]::InvariantCulture)))
    $labelEnd = (EscapeXml($weekNEnd.ToString("dd MMM yyyy", [System.Globalization.CultureInfo]::InvariantCulture)))
    [void]$sb.AppendLine('<text x="' + $heatmapPadL + '" y="' + ($heatmapH - 8) + '" fill="' + $muted + '" font-size="10" font-family="system-ui,sans-serif">' + $labelStart + '</text>')
    [void]$sb.AppendLine('<text x="' + ($heatmapPadL + $heatmapChartW) + '" y="' + ($heatmapH - 8) + '" fill="' + $muted + '" font-size="10" text-anchor="end" font-family="system-ui,sans-serif">' + $labelEnd + '</text>')
    [void]$sb.AppendLine('<text x="' + ($heatmapPadL + $heatmapChartW / 2) + '" y="' + ($heatmapPadT - 10) + '" fill="' + $muted + '" font-size="11" text-anchor="middle" font-family="system-ui,sans-serif">Releases by week</text>')

    $legX = $heatmapW - $heatmapPadR + 8
    $legY = $heatmapPadT + $heatmapCellH / 2 - 6
    [void]$sb.AppendLine('<rect x="' + $legX + '" y="' + $legY + '" width="10" height="10" rx="2" fill="' + $accentLow + '"/>')
    [void]$sb.AppendLine('<text x="' + ($legX + 14) + '" y="' + ($legY + 8) + '" fill="' + $muted + '" font-size="9" font-family="system-ui,sans-serif">Low</text>')
    [void]$sb.AppendLine('<rect x="' + $legX + '" y="' + ($legY + 18) + '" width="10" height="10" rx="2" fill="' + $accentMid + '"/>')
    [void]$sb.AppendLine('<text x="' + ($legX + 14) + '" y="' + ($legY + 26) + '" fill="' + $muted + '" font-size="9" font-family="system-ui,sans-serif">Mid</text>')
    [void]$sb.AppendLine('<rect x="' + $legX + '" y="' + ($legY + 36) + '" width="10" height="10" rx="2" fill="' + $accentHigh + '"/>')
    [void]$sb.AppendLine('<text x="' + ($legX + 14) + '" y="' + ($legY + 44) + '" fill="' + $muted + '" font-size="9" font-family="system-ui,sans-serif">High</text>')

    [void]$sb.AppendLine('</svg>')
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $sb.ToString(), $utf8)
}

# ---- 2) River: поток объёма по времени + ось, маркеры релизов, подписи пиков, легенда ----
$riverW = 800
$riverH = 220
$riverPadL = 48
$riverPadR = 28
$riverPadT = 38
$riverPadB = 36
$riverChartW = $riverW - $riverPadL - $riverPadR
$riverChartH = $riverH - $riverPadT - $riverPadB
$riverCenterY = $riverPadT + $riverChartH / 2
$maxRiverWidth = [math]::Max(8, [math]::Min(65, [math]::Log10(1 + $maxBullet) * 22))

function Get-RiverX($d) {
    $t = ($d - $minDate).TotalDays / $dateRange
    return [int]($riverPadL + $t * $riverChartW)
}

# Индексы релизов с наибольшим bullet_count — подпишем пики (не более 6)
$riverPeakIndices = @(0..($n - 1) | Sort-Object { $releases[$_].bullet_count } -Descending | Select-Object -First 6)

function Write-RiverSvgSimple($path, $isDark) {
    $bg = if ($isDark) { "#0d1117" } else { "#ffffff" }
    $fg = if ($isDark) { "#e6edf3" } else { "#1f2328" }
    $muted = if ($isDark) { "#8b949e" } else { "#656d76" }
    $grid = if ($isDark) { "#21262d" } else { "#d0d7de" }
    $accent = if ($isDark) { "#58a6ff" } else { "#0969da" }
    $accent2 = if ($isDark) { "#3fb950" } else { "#1a7f37" }

    $pts = [System.Collections.ArrayList]@()
    $baseY = $riverCenterY
    for ($i = 0; $i -lt $n; $i++) {
        $r = $releases[$i]
        $x = Get-RiverX $r.published
        $halfH = [math]::Max(3, [math]::Min(65, $maxRiverWidth * ([math]::Log10(1 + $r.bullet_count) / [math]::Log10(1 + $maxBullet))))
        [void]$pts.Add("$x," + [int]($baseY - $halfH))
    }
    for ($i = $n - 1; $i -ge 0; $i--) {
        $r = $releases[$i]
        $x = Get-RiverX $r.published
        $halfH = [math]::Max(3, [math]::Min(65, $maxRiverWidth * ([math]::Log10(1 + $r.bullet_count) / [math]::Log10(1 + $maxBullet))))
        [void]$pts.Add("$x," + [int]($baseY + $halfH))
    }
    $polyPoints = $pts -join " "

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 ' + $riverW + ' ' + $riverH + '" width="100%" height="' + $riverH + '">')
    [void]$sb.AppendLine('<defs><linearGradient id="riverGrad" x1="0%" y1="0%" x2="100%" y2="0%"><stop offset="0%" stop-color="' + $accent2 + '"/><stop offset="100%" stop-color="' + $accent + '"/></linearGradient></defs>')
    [void]$sb.AppendLine('<style>.rv-poly{ opacity:0; animation:rvFade 1s ease 0.15s forwards; } .rv-dot{ opacity:0; animation:rvFade 0.4s ease forwards; } .rv-label{ opacity:0; animation:rvFade 0.4s ease forwards; } @keyframes rvFade{ to{ opacity:1; } }</style>')
    [void]$sb.AppendLine('<rect width="' + $riverW + '" height="' + $riverH + '" fill="' + $bg + '" rx="8"/>')

    [void]$sb.AppendLine('<text x="' + ($riverPadL + $riverChartW / 2) + '" y="' + ($riverPadT - 12) + '" fill="' + $muted + '" font-size="12" text-anchor="middle" font-family="system-ui,sans-serif">Changelog size over time (width = items per release)</text>')

    [void]$sb.AppendLine('<line x1="' + $riverPadL + '" y1="' + $riverCenterY + '" x2="' + ($riverPadL + $riverChartW) + '" y2="' + $riverCenterY + '" stroke="' + $grid + '" stroke-width="1" stroke-dasharray="4 4" opacity="0.7"/>')
    [void]$sb.AppendLine('<polygon class="rv-poly" points="' + $polyPoints + '" fill="url(#riverGrad)" opacity="0.9"/>')

    foreach ($i in 0..($n - 1)) {
        $r = $releases[$i]
        $x = Get-RiverX $r.published
        $delay = [math]::Round(0.25 + $i * 0.03, 2)
        [void]$sb.AppendLine('<circle class="rv-dot" cx="' + $x + '" cy="' + $riverCenterY + '" r="3" fill="' + $fg + '" stroke="' + $accent + '" stroke-width="1.5" style="animation-delay:' + $delay + 's"/>')
    }

    foreach ($i in $riverPeakIndices) {
        if ($i -lt 0 -or $i -ge $n) { continue }
        $r = $releases[$i]
        $x = Get-RiverX $r.published
        $halfH = [math]::Max(3, [math]::Min(65, $maxRiverWidth * ([math]::Log10(1 + $r.bullet_count) / [math]::Log10(1 + $maxBullet))))
        $labelY = [int]($baseY - $halfH - 6)
        $delay = [math]::Round(0.4 + $i * 0.03, 2)
        [void]$sb.AppendLine('<text class="rv-label" x="' + $x + '" y="' + $labelY + '" fill="' + $muted + '" font-size="9" text-anchor="middle" font-family="system-ui,sans-serif" style="animation-delay:' + $delay + 's">' + (EscapeXml($r.tag)) + ' (' + $r.bullet_count + ')</text>')
    }

    $labelStart = (EscapeXml($minDate.ToString("dd MMM yyyy", [System.Globalization.CultureInfo]::InvariantCulture)))
    $labelEnd = (EscapeXml($maxDate.ToString("dd MMM yyyy", [System.Globalization.CultureInfo]::InvariantCulture)))
    [void]$sb.AppendLine('<text x="' + $riverPadL + '" y="' + ($riverH - 10) + '" fill="' + $muted + '" font-size="10" font-family="system-ui,sans-serif">' + $labelStart + '</text>')
    [void]$sb.AppendLine('<text x="' + ($riverPadL + $riverChartW) + '" y="' + ($riverH - 10) + '" fill="' + $muted + '" font-size="10" text-anchor="end" font-family="system-ui,sans-serif">' + $labelEnd + '</text>')

    [void]$sb.AppendLine('<text x="' + ($riverW - $riverPadR - 4) + '" y="' + ($riverCenterY - 22) + '" fill="' + $muted + '" font-size="9" text-anchor="end" font-family="system-ui,sans-serif">width ∝</text>')
    [void]$sb.AppendLine('<text x="' + ($riverW - $riverPadR - 4) + '" y="' + ($riverCenterY - 12) + '" fill="' + $muted + '" font-size="9" text-anchor="end" font-family="system-ui,sans-serif">items</text>')

    [void]$sb.AppendLine('</svg>')
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $sb.ToString(), $utf8)
}

# ---- 3) Pulse bars: горизонтальные столбцы по релизам, длина = bullet_count, анимация появления ----
$barsW = 800
$barsPadL = 56
$barsPadR = 24
$barsPadT = 36
$barsPadB = 32
$barsChartW = $barsW - $barsPadL - $barsPadR
$barGap = if ($n -gt 20) { 2 } else { 4 }
# Высота: уместить все строки в 500px макс, без выхода за нижний край
$barsMaxH = 500
$barsContentH = $barsMaxH - $barsPadT - $barsPadB
$barHeight = [math]::Max(2, [math]::Floor(($barsContentH - ($n - 1) * $barGap) / $n))
$barsChartH = $n * $barHeight + ($n - 1) * $barGap
$barsH = $barsPadT + $barsChartH + $barsPadB

function Get-BarX($i) {
    if ($n -le 1) { return $barsPadL + $barsChartW / 2 }
    $t = $i / ([double]($n - 1))
    return [int]($barsPadL + $t * $barsChartW)
}

function Write-BarsSvg($path, $isDark) {
    $bg = if ($isDark) { "#0d1117" } else { "#ffffff" }
    $fg = if ($isDark) { "#e6edf3" } else { "#1f2328" }
    $muted = if ($isDark) { "#8b949e" } else { "#656d76" }
    $accent = if ($isDark) { "#58a6ff" } else { "#0969da" }
    $grid = if ($isDark) { "#21262d" } else { "#d0d7de" }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 ' + $barsW + ' ' + $barsH + '" width="100%" height="' + $barsH + '">')
    [void]$sb.AppendLine('<style>.pb-bar{ transform-origin:left center; transform:scaleX(0); animation:pbGrow 0.6s ease forwards; } .pb-dot{ opacity:0; animation:pbFade 0.35s ease forwards; } @keyframes pbGrow{ to{ transform:scaleX(1); } } @keyframes pbFade{ to{ opacity:1; } }</style>')
    [void]$sb.AppendLine('<rect width="' + $barsW + '" height="' + $barsH + '" fill="' + $bg + '" rx="8"/>')

    $barMaxLen = $barsChartW * 0.75
    $barX2Max = $barsPadL + $barsChartW
    foreach ($i in 0..($n - 1)) {
        $r = $releases[$i]
        $x = Get-BarX $i
        $y = $barsPadT + $i * ($barHeight + $barGap) + $barHeight / 2
        $len = 0
        if ($maxBullet -gt 0) { $len = $barMaxLen * [math]::Min(1, ($r.bullet_count + 1) / ($maxBullet + 1)) }
        if ($len -lt 8) { $len = 8 }
        $x2 = [math]::Min($x + $len, $barX2Max)
        $delay = [math]::Round(0.04 * $i, 2)
        $titleShort = if ($r.title) { ($r.title.Trim() -replace '\s+', ' ').Trim() } else { "" }
        if ($titleShort.Length -gt 28) { $titleShort = $titleShort.Substring(0, 25) + "…" }
        if ($titleShort -eq $r.tag) { $titleShort = "" }
        [void]$sb.AppendLine('<line x1="' + $x + '" y1="' + [int]$y + '" x2="' + $x + '" y2="' + [int]$y + '" stroke="' + $grid + '" stroke-width="1" opacity="0.5"/>')
        [void]$sb.AppendLine('<line class="pb-bar" x1="' + $x + '" y1="' + [int]$y + '" x2="' + [int]$x2 + '" y2="' + [int]$y + '" stroke="' + $accent + '" stroke-width="' + [int]$barHeight + '" stroke-linecap="round" style="animation-delay:' + $delay + 's"/>')
        [void]$sb.AppendLine('<text class="pb-dot" x="' + ($x - 6) + '" y="' + ([int]$y + 4) + '" fill="' + $muted + '" font-size="10" text-anchor="end" font-family="system-ui,sans-serif" style="animation-delay:' + $delay + 's">' + (EscapeXml($r.tag)) + '</text>')
        if ($titleShort) {
            [void]$sb.AppendLine('<text class="pb-dot" x="' + ([int]$x2 + 8) + '" y="' + ([int]$y + 4) + '" fill="' + $muted + '" font-size="9" font-family="system-ui,sans-serif" style="animation-delay:' + $delay + 's">' + (EscapeXml($titleShort)) + '</text>')
        }
    }
    [void]$sb.AppendLine('<text x="' + $barsPadL + '" y="' + ($barsPadT - 10) + '" fill="' + $muted + '" font-size="11" font-family="system-ui,sans-serif">Release size (changelog items)</text>')
    [void]$sb.AppendLine('</svg>')
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $sb.ToString(), $utf8)
}

# ---- 4) Stats strip: ключевые числа + мини sparkline ----
$statsW = 800
$statsH = 100
$statsPad = 24
$sparkW = 300
$sparkH = 36

# Sparkline: releases per month
$monthBuckets = @{}
foreach ($r in $releases) {
    $key = $r.published.Year * 100 + $r.published.Month
    if (-not $monthBuckets[$key]) { $monthBuckets[$key] = 0 }
    $monthBuckets[$key]++
}
$sortedMonths = $monthBuckets.Keys | Sort-Object
$sparkMax = 1
foreach ($k in $sortedMonths) { if ($monthBuckets[$k] -gt $sparkMax) { $sparkMax = $monthBuckets[$k] } }

function Write-StatsSvg($path, $isDark) {
    $bg = if ($isDark) { "#0d1117" } else { "#f6f8fa" }
    $fg = if ($isDark) { "#e6edf3" } else { "#1f2328" }
    $muted = if ($isDark) { "#8b949e" } else { "#656d76" }
    $accent = if ($isDark) { "#58a6ff" } else { "#0969da" }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + $statsW + ' ' + $statsH + '" width="100%" height="' + $statsH + '">')
    [void]$sb.AppendLine('<style>.st-num{ opacity:0; animation:stPop 0.4s ease forwards; } .st-spark{ opacity:0; stroke-dasharray:500; stroke-dashoffset:500; animation:stDraw 1s ease forwards; } @keyframes stPop{ to{ opacity:1; } } @keyframes stDraw{ to{ stroke-dashoffset:0; opacity:1; } }</style>')
    [void]$sb.AppendLine('<rect width="' + $statsW + '" height="' + $statsH + '" fill="' + $bg + '" rx="8"/>')

    $yCenter = $statsH / 2
    $x = $statsPad
    [void]$sb.AppendLine('<text class="st-num" x="' + $x + '" y="' + ($yCenter - 2) + '" fill="' + $fg + '" font-size="18" font-weight="600" font-family="system-ui,sans-serif">' + $n + '</text>')
    [void]$sb.AppendLine('<text class="st-num" x="' + $x + '" y="' + ($yCenter + 14) + '" fill="' + $muted + '" font-size="10" font-family="system-ui,sans-serif">releases</text>')
    $x += 72
    [void]$sb.AppendLine('<text class="st-num" x="' + $x + '" y="' + ($yCenter - 2) + '" fill="' + $fg + '" font-size="18" font-weight="600" font-family="system-ui,sans-serif" style="animation-delay:0.08s">' + $totalBullets + '</text>')
    [void]$sb.AppendLine('<text class="st-num" x="' + $x + '" y="' + ($yCenter + 14) + '" fill="' + $muted + '" font-size="10" font-family="system-ui,sans-serif" style="animation-delay:0.08s">items</text>')
    $x += 72
    $rangeStr = $minDate.ToString("MMM yyyy", [System.Globalization.CultureInfo]::InvariantCulture) + " — " + $maxDate.ToString("MMM yyyy", [System.Globalization.CultureInfo]::InvariantCulture)
    [void]$sb.AppendLine('<text class="st-num" x="' + $x + '" y="' + $yCenter + '" fill="' + $muted + '" font-size="11" font-family="system-ui,sans-serif" style="animation-delay:0.12s">' + (EscapeXml($rangeStr)) + '</text>')

    $sparkX0 = $statsW - $statsPad - $sparkW
    $sparkY0 = $yCenter - $sparkH / 2
    $sparkPath = ""
    $idx = 0
    foreach ($k in $sortedMonths) {
        $v = $monthBuckets[$k]
        $px = $sparkX0 + ($idx / [math]::Max(1, ($sortedMonths.Count - 1))) * $sparkW
        $py = $sparkY0 + $sparkH - ($v / $sparkMax) * $sparkH
        if ($sparkPath -eq "") { $sparkPath = "M $px $py" } else { $sparkPath += " L $px $py" }
        $idx++
    }
    if ($sparkPath -ne "") {
        [void]$sb.AppendLine('<path class="st-spark" d="' + $sparkPath + '" fill="none" stroke="' + $accent + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="animation-delay:0.3s"/>')
    }
    [void]$sb.AppendLine('<text x="' + ($sparkX0 - 8) + '" y="' + $yCenter + '" fill="' + $muted + '" font-size="9" text-anchor="end" font-family="system-ui,sans-serif">per month</text>')
    [void]$sb.AppendLine('</svg>')
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $sb.ToString(), $utf8)
}

# ---- Output ----
if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

$written = @()

Write-HeatmapSvg (Join-Path $DistDir "release-heatmap-v3.svg") $false
Write-HeatmapSvg (Join-Path $DistDir "release-heatmap-v3-dark.svg") $true
$written += "release-heatmap-v3.svg", "release-heatmap-v3-dark.svg"

Write-RiverSvgSimple (Join-Path $DistDir "release-river-v3.svg") $false
Write-RiverSvgSimple (Join-Path $DistDir "release-river-v3-dark.svg") $true
$written += "release-river-v3.svg", "release-river-v3-dark.svg"

Write-BarsSvg (Join-Path $DistDir "release-bars-v3.svg") $false
Write-BarsSvg (Join-Path $DistDir "release-bars-v3-dark.svg") $true
$written += "release-bars-v3.svg", "release-bars-v3-dark.svg"

Write-StatsSvg (Join-Path $DistDir "release-stats-v3.svg") $false
Write-StatsSvg (Join-Path $DistDir "release-stats-v3-dark.svg") $true
$written += "release-stats-v3.svg", "release-stats-v3-dark.svg"

Write-Host "V3 widgets written to dist/: $($written -join ', ') (releases: $n)"
