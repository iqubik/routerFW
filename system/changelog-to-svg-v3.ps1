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
$heatmapH = 80
$heatmapPadL = 12
$heatmapPadR = 140
$heatmapPadT = 18
$heatmapPadB = 14
$heatmapChartW = $heatmapW - $heatmapPadL - $heatmapPadR
$heatmapCellH = 18

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

    $cellY = $heatmapPadT + 2
    $cellY1 = $cellY + 1
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
        $moveBegin = [math]::Round(0.5 + $w * 0.5, 2)
        $cellW = [math]::Max(4, [int]($heatmapCellW - 2))
        [void]$sb.AppendLine('<rect class="hm-cell" x="' + [int]$x + '" y="' + $cellY + '" width="' + $cellW + '" height="' + ($heatmapCellH - 2) + '" rx="4" fill="' + $fill + '" style="animation-delay:' + $delay + 's"><animate attributeName="y" values="' + $cellY + ';' + $cellY1 + ';' + $cellY + '" dur="4s" repeatCount="indefinite" begin="' + $moveBegin + 's" keyTimes="0;0.5;1" calcMode="spline" keySplines="0.4 0 0.6 1; 0.4 0 0.6 1"/></rect>')
    }

    $week0Start = $minDate
    $weekNEnd = $maxDate
    $labelStart = (EscapeXml($week0Start.ToString("dd MMM yyyy", [System.Globalization.CultureInfo]::InvariantCulture)))
    $labelEnd = (EscapeXml($weekNEnd.ToString("dd MMM yyyy", [System.Globalization.CultureInfo]::InvariantCulture)))
    [void]$sb.AppendLine('<text x="' + $heatmapPadL + '" y="' + ($heatmapH - 6) + '" fill="' + $muted + '" font-size="9" font-family="system-ui,sans-serif">' + $labelStart + '</text>')
    [void]$sb.AppendLine('<text x="' + ($heatmapPadL + $heatmapChartW) + '" y="' + ($heatmapH - 6) + '" fill="' + $muted + '" font-size="9" text-anchor="end" font-family="system-ui,sans-serif">' + $labelEnd + '</text>')
    [void]$sb.AppendLine('<text x="' + ($heatmapPadL + $heatmapChartW / 2) + '" y="' + ($heatmapPadT - 6) + '" fill="' + $muted + '" font-size="10" text-anchor="middle" font-family="system-ui,sans-serif">Releases by week</text>')
    $heatmapTotalBullets = 0
    foreach ($b in $heatmapWeekBuckets.Values) { $heatmapTotalBullets += $b.bullets }
    $heatmapSubtitle = [string]$releases.Count + ' releases · ' + [string]$heatmapWeeksTotal + ' weeks · ' + [string]$heatmapTotalBullets + ' items'
    [void]$sb.AppendLine('<text x="' + ($heatmapPadL + $heatmapChartW / 2) + '" y="' + ($heatmapH - 14) + '" fill="' + $muted + '" font-size="9" text-anchor="middle" font-family="system-ui,sans-serif">' + (EscapeXml($heatmapSubtitle)) + '</text>')

    $legX = $heatmapW - $heatmapPadR + 8
    $legY = $heatmapPadT + $heatmapCellH / 2 - 8
    [void]$sb.AppendLine('<rect x="' + $legX + '" y="' + $legY + '" width="8" height="8" rx="2" fill="' + $accentLow + '"/>')
    [void]$sb.AppendLine('<text x="' + ($legX + 12) + '" y="' + ($legY + 6) + '" fill="' + $muted + '" font-size="8" font-family="system-ui,sans-serif">Low</text>')
    [void]$sb.AppendLine('<rect x="' + $legX + '" y="' + ($legY + 12) + '" width="8" height="8" rx="2" fill="' + $accentMid + '"/>')
    [void]$sb.AppendLine('<text x="' + ($legX + 12) + '" y="' + ($legY + 18) + '" fill="' + $muted + '" font-size="8" font-family="system-ui,sans-serif">Mid</text>')
    [void]$sb.AppendLine('<rect x="' + $legX + '" y="' + ($legY + 24) + '" width="8" height="8" rx="2" fill="' + $accentHigh + '"/>')
    [void]$sb.AppendLine('<text x="' + ($legX + 12) + '" y="' + ($legY + 30) + '" fill="' + $muted + '" font-size="8" font-family="system-ui,sans-serif">High</text>')

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

    $baseY = $riverCenterY
    $riverX = @()
    $topBaseY = @()
    $bottomBaseY = @()
    $riverAmp = @()
    for ($i = 0; $i -lt $n; $i++) {
        $r = $releases[$i]
        $xi = Get-RiverX $r.published
        $halfH = [math]::Max(3, [math]::Min(65, $maxRiverWidth * ([math]::Log10(1 + $r.bullet_count) / [math]::Log10(1 + $maxBullet))))
        $riverX += $xi
        $topBaseY += [int]($baseY - $halfH)
        $bottomBaseY += [int]($baseY + $halfH)
        $riverAmp += (1.5 + ($i % 3) * 0.5)
    }
    $polyPoints = (0..($n - 1) | ForEach-Object { "$($riverX[$_]),$($topBaseY[$_])" }) -join " "
    $polyPoints += " " + (($n - 1)..0 | ForEach-Object { "$($riverX[$_]),$($bottomBaseY[$_])" }) -join " "

    function Get-RiverDisp($phase, $amp) {
        if ($phase -lt 0.25) { return -$amp * ($phase / 0.25) }
        if ($phase -lt 0.5) { return -$amp * (1 - ($phase - 0.25) / 0.25) }
        if ($phase -lt 0.75) { return $amp * 0.6 * (($phase - 0.5) / 0.25) }
        return $amp * 0.6 * (1 - ($phase - 0.75) / 0.25)
    }
    $polyKeyframes = @()
    foreach ($k in 0..4) {
        $t = $k * 1.25
        $ptList = [System.Collections.ArrayList]@()
        for ($i = 0; $i -lt $n; $i++) {
            $phase = ($t - $i * 0.12) / 5.0
            $phase = $phase - [math]::Floor($phase)
            if ($phase -lt 0) { $phase += 1 }
            $disp = Get-RiverDisp $phase $riverAmp[$i]
            [void]$ptList.Add("$($riverX[$i]),$([int]($topBaseY[$i] + $disp))")
        }
        for ($i = $n - 1; $i -ge 0; $i--) {
            $phase = ($t - $i * 0.12) / 5.0
            $phase = $phase - [math]::Floor($phase)
            if ($phase -lt 0) { $phase += 1 }
            $disp = Get-RiverDisp $phase $riverAmp[$i]
            [void]$ptList.Add("$($riverX[$i]),$([int]($bottomBaseY[$i] + $disp))")
        }
        $polyKeyframes += $ptList -join " "
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 ' + $riverW + ' ' + $riverH + '" width="100%" height="' + $riverH + '">')
    [void]$sb.AppendLine('<defs><linearGradient id="riverGrad" x1="0%" y1="0%" x2="100%" y2="0%"><stop offset="0%" stop-color="' + $accent2 + '"/><stop offset="100%" stop-color="' + $accent + '"/></linearGradient></defs>')
    [void]$sb.AppendLine('<style>.rv-poly{ opacity:0; animation:rvFade 1s ease 0.15s forwards; } .rv-dot{ opacity:0; animation:rvFade 0.4s ease forwards; } .rv-label{ opacity:0; animation:rvFade 0.4s ease forwards; } @keyframes rvFade{ to{ opacity:1; } }</style>')
    [void]$sb.AppendLine('<rect width="' + $riverW + '" height="' + $riverH + '" fill="' + $bg + '" rx="8"/>')

    [void]$sb.AppendLine('<text x="' + ($riverPadL + $riverChartW / 2) + '" y="' + ($riverPadT - 12) + '" fill="' + $muted + '" font-size="12" text-anchor="middle" font-family="system-ui,sans-serif">Changelog size over time (width = items per release)</text>')

    [void]$sb.AppendLine('<line x1="' + $riverPadL + '" y1="' + $riverCenterY + '" x2="' + ($riverPadL + $riverChartW) + '" y2="' + $riverCenterY + '" stroke="' + $grid + '" stroke-width="1" stroke-dasharray="4 4" opacity="0.7"/>')
    $polyValues = $polyKeyframes -join ';'
    [void]$sb.AppendLine('<polygon class="rv-poly" points="' + $polyPoints + '" fill="url(#riverGrad)" opacity="0.9"><animate attributeName="points" values="' + $polyValues + '" dur="5s" repeatCount="indefinite" begin="0.5s" keyTimes="0;0.25;0.5;0.75;1" calcMode="spline" keySplines="0.4 0 0.6 1; 0.4 0 0.6 1; 0.4 0 0.6 1; 0.4 0 0.6 1"/></polygon>')

    $cy0 = [int]$riverCenterY
    foreach ($i in 0..($n - 1)) {
        $r = $releases[$i]
        $x = Get-RiverX $r.published
        $delay = [math]::Round(0.25 + $i * 0.03, 2)
        $moveBegin = [math]::Round(0.5 + $i * 0.12, 2)
        $amp = 1.5 + ($i % 3) * 0.5
        $cy1 = [int]($cy0 - $amp)
        $cy2 = [int]($cy0 + $amp * 0.6)
        [void]$sb.AppendLine('<circle class="rv-dot" cx="' + $x + '" cy="' + $cy0 + '" r="3" fill="' + $fg + '" stroke="' + $accent + '" stroke-width="1.5" style="animation-delay:' + $delay + 's"><animate attributeName="cy" values="' + $cy0 + ';' + $cy1 + ';' + $cy0 + ';' + $cy2 + ';' + $cy0 + '" dur="5s" repeatCount="indefinite" begin="' + $moveBegin + 's" keyTimes="0;0.25;0.5;0.75;1" calcMode="spline" keySplines="0.4 0 0.6 1; 0.4 0 0.6 1; 0.4 0 0.6 1; 0.4 0 0.6 1"/></circle>')
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

# ---- 3) Bars: топ релизов по размеру чейнджлога — компактно, с числами ----
$barsW = 800
$barsPadL = 52
$barsPadR = 20
$barsPadT = 28
$barsPadB = 28
$barsChartW = $barsW - $barsPadL - $barsPadR
$barsTopN = 10
$barsRows = [math]::Min($barsTopN, $n)
$barHeight = 14
$barGap = 3
$barsChartH = $barsRows * $barHeight + ([math]::Max(0, $barsRows - 1) * $barGap)
$barsH = $barsPadT + $barsChartH + $barsPadB + 18

$barsReleasesSorted = $releases | Sort-Object -Property bullet_count -Descending
$barsTopReleases = $barsReleasesSorted | Select-Object -First $barsTopN
$barsOtherCount = [math]::Max(0, $n - $barsTopN)
$barsOtherBullets = 0
if ($barsOtherCount -gt 0) {
    $barsReleasesSorted | Select-Object -Skip $barsTopN | ForEach-Object { $barsOtherBullets += $_.bullet_count }
}
$barsMaxInTop = if ($barsTopReleases.Count -gt 0) { ($barsTopReleases | Measure-Object -Property bullet_count -Maximum).Maximum } else { 1 }

function Write-BarsSvg($path, $isDark) {
    $bg = if ($isDark) { "#0d1117" } else { "#ffffff" }
    $fg = if ($isDark) { "#e6edf3" } else { "#1f2328" }
    $muted = if ($isDark) { "#8b949e" } else { "#656d76" }
    $accent = if ($isDark) { "#58a6ff" } else { "#0969da" }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + $barsW + ' ' + $barsH + '" width="100%" height="' + $barsH + '">')
    [void]$sb.AppendLine('<style>.pb-bar{ transform-origin:left center; transform:scaleX(0); animation:pbGrow 0.4s ease forwards; } .pb-dot{ opacity:0; animation:pbFade 0.3s ease forwards; } @keyframes pbGrow{ to{ transform:scaleX(1); } } @keyframes pbFade{ to{ opacity:1; } }</style>')
    [void]$sb.AppendLine('<rect width="' + $barsW + '" height="' + $barsH + '" fill="' + $bg + '" rx="8"/>')
    [void]$sb.AppendLine('<text x="' + $barsPadL + '" y="' + ($barsPadT - 8) + '" fill="' + $muted + '" font-size="11" font-family="system-ui,sans-serif">Top ' + $barsRows + ' releases by changelog size (items)</text>')

    $barX0 = $barsPadL
    $barLenMax = $barsChartW - 90
    $idx = 0
    foreach ($r in $barsTopReleases) {
        $y = $barsPadT + $idx * ($barHeight + $barGap) + $barHeight / 2
        $barY = [int]$y - $barHeight / 2
        $barY1 = $barY + 2
        $len = 8
        if ($barsMaxInTop -gt 0) { $len = [math]::Max(8, $barLenMax * $r.bullet_count / $barsMaxInTop) }
        $x2 = [math]::Min($barX0 + $len, $barX0 + $barLenMax)
        $delay = [math]::Round(0.03 * $idx, 2)
        $moveBegin = [math]::Round(0.5 + $idx * 0.5, 2)
        [void]$sb.AppendLine('<rect class="pb-bar" x="' + [int]$barX0 + '" y="' + $barY + '" width="' + [int]($x2 - $barX0) + '" height="' + $barHeight + '" rx="3" fill="' + $accent + '" style="animation-delay:' + $delay + 's"><animate attributeName="y" values="' + $barY + ';' + $barY1 + ';' + $barY + '" dur="4s" repeatCount="indefinite" begin="' + $moveBegin + 's" keyTimes="0;0.5;1" calcMode="spline" keySplines="0.4 0 0.6 1; 0.4 0 0.6 1"/></rect>')
        [void]$sb.AppendLine('<text class="pb-dot" x="' + ($barX0 - 6) + '" y="' + ([int]$y + 4) + '" fill="' + $muted + '" font-size="10" text-anchor="end" font-family="system-ui,sans-serif" style="animation-delay:' + $delay + 's">' + (EscapeXml($r.tag)) + '</text>')
        [void]$sb.AppendLine('<text class="pb-dot" x="' + ([int]$x2 + 8) + '" y="' + ([int]$y + 4) + '" fill="' + $fg + '" font-size="10" font-weight="600" font-family="system-ui,sans-serif" style="animation-delay:' + $delay + 's">' + $r.bullet_count + '</text>')
        $idx++
    }

    $footerY = $barsH - 10
    if ($barsOtherCount -gt 0) {
        $footerText = "… +" + $barsOtherCount + " releases (" + $barsOtherBullets + " items)"
        [void]$sb.AppendLine('<text x="' + $barsPadL + '" y="' + $footerY + '" fill="' + $muted + '" font-size="10" font-family="system-ui,sans-serif">' + (EscapeXml($footerText)) + '</text>')
    }
    [void]$sb.AppendLine('<text x="' + ($barsW - $barsPadR) + '" y="' + $footerY + '" fill="' + $muted + '" font-size="9" text-anchor="end" font-family="system-ui,sans-serif">max ' + $barsMaxInTop + '</text>')
    [void]$sb.AppendLine('</svg>')
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $sb.ToString(), $utf8)
}

# ---- 4) Stats dashboard: карточки с метриками + мини-графики по неделям (компактно, высота /2) ----
$statsW = 800
$statsH = 100
$statsPad = 10
$statsCardW = [math]::Floor(($statsW - 2 * $statsPad - 3 * 12) / 4)
$statsCardH = $statsH - 2 * $statsPad
$statsChartH = 26
$statsNumH = 18

$statsWeeks = $heatmapWeeksTotal
$statsWeekCountMax = 1
$statsWeekBulletsMax = 1
for ($w = 0; $w -lt $statsWeeks; $w++) {
    $c = $heatmapWeekBuckets[$w].count
    $b = $heatmapWeekBuckets[$w].bullets
    if ($c -gt $statsWeekCountMax) { $statsWeekCountMax = $c }
    if ($b -gt $statsWeekBulletsMax) { $statsWeekBulletsMax = $b }
}
if ($statsWeekCountMax -lt 1) { $statsWeekCountMax = 1 }
if ($statsWeekBulletsMax -lt 1) { $statsWeekBulletsMax = 1 }

$avgPerWeek = if ($statsWeeks -gt 0) { [math]::Round($n / $statsWeeks, 1) } else { 0 }
$largestRelease = $releases | Sort-Object -Property bullet_count -Descending | Select-Object -First 1

function Write-StatsSvg($path, $isDark) {
    $bg = if ($isDark) { "#0d1117" } else { "#f6f8fa" }
    $fg = if ($isDark) { "#e6edf3" } else { "#1f2328" }
    $muted = if ($isDark) { "#8b949e" } else { "#656d76" }
    $accent = if ($isDark) { "#58a6ff" } else { "#0969da" }
    $accent2 = if ($isDark) { "#3fb950" } else { "#1a7f37" }
    $cardBg = if ($isDark) { "#161b22" } else { "#ffffff" }
    $cardStroke = if ($isDark) { "#21262d" } else { "#d0d7de" }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + $statsW + ' ' + $statsH + '" width="100%" height="' + $statsH + '">')
    [void]$sb.AppendLine('<style>.st-card{ opacity:0; animation:stPop 0.35s ease forwards; } @keyframes stPop{ to{ opacity:1; } } .st-bar{ transform-origin:bottom; transform:scaleY(0); animation:stBar 0.4s ease forwards; } @keyframes stBar{ to{ transform:scaleY(1); } }</style>')
    [void]$sb.AppendLine('<rect width="' + $statsW + '" height="' + $statsH + '" fill="' + $bg + '" rx="8"/>')

    $cardGap = 12
    $cardLeft = $statsPad
    $chartPad = 10
    $barGap = 2
    $cardTop = $statsPad + 2
    $numY = $cardTop + 14
    $labelY = $cardTop + 26
    $innerChartY = $cardTop + 32
    $barMaxH = $statsChartH - 6
    $captionY = $cardTop + $statsCardH - 4 - 10
    $cardCenterX = $statsCardW / 2
    $midBlockY = $innerChartY + $barMaxH / 2

    for ($card = 0; $card -lt 4; $card++) {
        $cx = $cardLeft + $card * ($statsCardW + $cardGap)
        $cardCenter = $cx + $cardCenterX
        $innerW = $statsCardW - 2 * $chartPad
        $barW = [math]::Max(2, ($innerW - ($statsWeeks - 1) * $barGap) / $statsWeeks)

        [void]$sb.AppendLine('<rect class="st-card" x="' + ($cx + 2) + '" y="' + $cardTop + '" width="' + ($statsCardW - 4) + '" height="' + ($statsCardH - 4) + '" rx="6" fill="' + $cardBg + '" stroke="' + $cardStroke + '" stroke-width="1" style="animation-delay:' + ([math]::Round(0.04 * $card, 2)) + 's"/>')

        if ($card -eq 0) {
            [void]$sb.AppendLine('<g class="st-card" style="animation-delay:0.05s">')
            [void]$sb.AppendLine('<text x="' + ($cx + $chartPad) + '" y="' + $numY + '" fill="' + $fg + '" font-size="16" font-weight="600" font-family="system-ui,sans-serif">' + $n + '</text>')
            [void]$sb.AppendLine('<text x="' + ($cx + $chartPad) + '" y="' + $labelY + '" fill="' + $muted + '" font-size="9" font-family="system-ui,sans-serif">Releases</text>')
            for ($w = 0; $w -lt $statsWeeks; $w++) {
                $v = $heatmapWeekBuckets[$w].count
                $bx = $cx + $chartPad + $w * ($barW + $barGap)
                $bh = if ($statsWeekCountMax -gt 0) { [math]::Max(1, $barMaxH * $v / $statsWeekCountMax) } else { 1 }
                $by = [int]($innerChartY + $barMaxH - $bh)
                $moveBegin = [math]::Round(0.5 + $w * 0.4, 2)
                [void]$sb.AppendLine('<rect class="st-bar" x="' + [int]$bx + '" y="' + $by + '" width="' + [int]$barW + '" height="' + [int]$bh + '" rx="1" fill="' + $accent + '" style="animation-delay:' + ([math]::Round(0.2 + $w * 0.03, 2)) + 's"><animate attributeName="y" values="' + $by + ';' + ($by - 1) + ';' + $by + '" dur="4s" repeatCount="indefinite" begin="' + $moveBegin + 's" keyTimes="0;0.5;1" calcMode="spline" keySplines="0.4 0 0.6 1; 0.4 0 0.6 1"/></rect>')
            }
            [void]$sb.AppendLine('<text x="' + [int]$cardCenter + '" y="' + $captionY + '" fill="' + $muted + '" font-size="8" text-anchor="middle" font-family="system-ui,sans-serif">by week</text>')
            [void]$sb.AppendLine('</g>')
        }
        elseif ($card -eq 1) {
            [void]$sb.AppendLine('<g class="st-card" style="animation-delay:0.08s">')
            [void]$sb.AppendLine('<text x="' + ($cx + $chartPad) + '" y="' + $numY + '" fill="' + $fg + '" font-size="16" font-weight="600" font-family="system-ui,sans-serif">' + $totalBullets + '</text>')
            [void]$sb.AppendLine('<text x="' + ($cx + $chartPad) + '" y="' + $labelY + '" fill="' + $muted + '" font-size="9" font-family="system-ui,sans-serif">Changelog items</text>')
            for ($w = 0; $w -lt $statsWeeks; $w++) {
                $v = $heatmapWeekBuckets[$w].bullets
                $bx = $cx + $chartPad + $w * ($barW + $barGap)
                $bh = if ($statsWeekBulletsMax -gt 0) { [math]::Max(1, $barMaxH * $v / $statsWeekBulletsMax) } else { 1 }
                $by = [int]($innerChartY + $barMaxH - $bh)
                $moveBegin = [math]::Round(0.6 + $w * 0.4, 2)
                [void]$sb.AppendLine('<rect class="st-bar" x="' + [int]$bx + '" y="' + $by + '" width="' + [int]$barW + '" height="' + [int]$bh + '" rx="1" fill="' + $accent2 + '" style="animation-delay:' + ([math]::Round(0.25 + $w * 0.03, 2)) + 's"><animate attributeName="y" values="' + $by + ';' + ($by - 1) + ';' + $by + '" dur="4s" repeatCount="indefinite" begin="' + $moveBegin + 's" keyTimes="0;0.5;1" calcMode="spline" keySplines="0.4 0 0.6 1; 0.4 0 0.6 1"/></rect>')
            }
            [void]$sb.AppendLine('<text x="' + [int]$cardCenter + '" y="' + $captionY + '" fill="' + $muted + '" font-size="8" text-anchor="middle" font-family="system-ui,sans-serif">items per week</text>')
            [void]$sb.AppendLine('</g>')
        }
        elseif ($card -eq 2) {
            [void]$sb.AppendLine('<g class="st-card" style="animation-delay:0.12s">')
            $rangeStr = $minDate.ToString("MMM yyyy", [System.Globalization.CultureInfo]::InvariantCulture) + " — " + $maxDate.ToString("MMM yyyy", [System.Globalization.CultureInfo]::InvariantCulture)
            [void]$sb.AppendLine('<text x="' + [int]$cardCenter + '" y="' + $numY + '" fill="' + $fg + '" font-size="11" font-weight="600" text-anchor="middle" font-family="system-ui,sans-serif">' + (EscapeXml($rangeStr)) + '</text>')
            [void]$sb.AppendLine('<text x="' + [int]$cardCenter + '" y="' + $labelY + '" fill="' + $muted + '" font-size="9" text-anchor="middle" font-family="system-ui,sans-serif">Period</text>')
            $daysTotal = [int]$dateRange
            [void]$sb.AppendLine('<text x="' + [int]$cardCenter + '" y="' + ($midBlockY + 2) + '" fill="' + $muted + '" font-size="9" text-anchor="middle" font-family="system-ui,sans-serif">' + $statsWeeks + ' w · ' + $daysTotal + ' d</text>')
            [void]$sb.AppendLine('</g>')
        }
        else {
            [void]$sb.AppendLine('<g class="st-card" style="animation-delay:0.15s">')
            [void]$sb.AppendLine('<text x="' + ($cx + $chartPad) + '" y="' + $numY + '" fill="' + $fg + '" font-size="16" font-weight="600" font-family="system-ui,sans-serif">~' + $avgPerWeek + '/wk</text>')
            [void]$sb.AppendLine('<text x="' + ($cx + $chartPad) + '" y="' + $labelY + '" fill="' + $muted + '" font-size="9" font-family="system-ui,sans-serif">Pace</text>')
            if ($largestRelease) {
                [void]$sb.AppendLine('<text x="' + [int]$cardCenter + '" y="' + ($midBlockY - 5) + '" fill="' + $muted + '" font-size="8" text-anchor="middle" font-family="system-ui,sans-serif">Largest</text>')
                [void]$sb.AppendLine('<text x="' + [int]$cardCenter + '" y="' + ($midBlockY + 7) + '" fill="' + $fg + '" font-size="10" font-weight="600" text-anchor="middle" font-family="system-ui,sans-serif">' + (EscapeXml($largestRelease.tag)) + ' (' + $largestRelease.bullet_count + ')</text>')
            }
            [void]$sb.AppendLine('</g>')
        }
    }

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
