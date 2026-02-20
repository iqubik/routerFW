<#
.SYNOPSIS
    Тетрис версий: модули из ARCHITECTURE_diagram_ru.md, ритм из CHANGELOG (даты релизов).
# file: system/architecture-tetris.ps1
.DESCRIPTION
    Парсит docs/ARCHITECTURE_diagram_ru.md (Mermaid-узлы по порядку), CHANGELOG.md (tag, published),
    строит задержки между блоками из интервалов между релизами, генерирует циклическую SVG-анимацию:
    блоки (модули) падают по одному, цикл повторяется.
.EXAMPLE
    .\system\architecture-tetris.ps1
#>

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Get-Item $ScriptDir).Parent.FullName
$ArchPath = Join-Path $ProjectRoot "docs\ARCHITECTURE_diagram_ru.md"
$ChangelogPath = Join-Path $ProjectRoot "CHANGELOG.md"
$DistDir = Join-Path $ProjectRoot "dist"

if (-not (Test-Path $ArchPath)) {
    Write-Error "ARCHITECTURE_diagram_ru.md not found: $ArchPath"
    exit 1
}
if (-not (Test-Path $ChangelogPath)) {
    Write-Error "CHANGELOG.md not found: $ChangelogPath"
    exit 1
}

# ---- Parse architecture: extract node IDs and labels from Mermaid (order of first appearance) ----
$archContent = Get-Content -Path $ArchPath -Raw -Encoding UTF8
$modules = [System.Collections.ArrayList]@()
$moduleLabels = @{}   # ID -> short Russian/readable label from diagram
$seen = @{}
$mermaidBlockRegex = [regex]'(?ms)```mermaid\r?\n(.*?)```'
$blockMatches = $mermaidBlockRegex.Matches($archContent)

function Short-Label($raw) {
    $t = ($raw -replace '\\n', ' ').Trim()
    if ($t.Length -gt 28) { $t = $t.Substring(0, 27) + "…" }
    return $t
}

foreach ($bm in $blockMatches) {
    $block = $bm.Groups[1].Value
    foreach ($line in ($block -split '\r?\n')) {
        $line = $line.Trim()
        if (-not $line -or $line.StartsWith('flowchart')) { continue }
        # Node definitions with label: ID[content], ID([content]), ID{content}
        if ($line -match '(\w+)\s*\[\s*([^\]]+)\]') {
            $id = $Matches[1]; $content = $Matches[2]
            if (-not $seen[$id]) { $seen[$id] = $true; [void]$modules.Add($id) }
            $moduleLabels[$id] = Short-Label $content
        }
        if ($line -match '(\w+)\s*\(\[\s*([^\]]+)\]\)') {
            $id = $Matches[1]; $content = $Matches[2]
            if (-not $seen[$id]) { $seen[$id] = $true; [void]$modules.Add($id) }
            $moduleLabels[$id] = Short-Label $content
        }
        if ($line -match '(\w+)\s*\{\s*([^\}]+)\}') {
            $id = $Matches[1]; $content = $Matches[2]
            if (-not $seen[$id]) { $seen[$id] = $true; [void]$modules.Add($id) }
            $moduleLabels[$id] = Short-Label $content
        }
        if ($line -match '(\w+)\s*\[') {
            $id = $Matches[1]
            if (-not $seen[$id]) { $seen[$id] = $true; [void]$modules.Add($id) }
        }
        if ($line -match '(\w+)\s*\(\[') {
            $id = $Matches[1]
            if (-not $seen[$id]) { $seen[$id] = $true; [void]$modules.Add($id) }
        }
        if ($line -match '(\w+)\s*\{') {
            $id = $Matches[1]
            if (-not $seen[$id]) { $seen[$id] = $true; [void]$modules.Add($id) }
        }
        # Edges: A --> B (extract node IDs from both sides)
        if ($line -match '-->') {
            $leftRight = $line -split '-->', 2
            $left = $leftRight[0].Trim()
            $right = $leftRight[1].Trim()
            $right = ($right -replace '\s*\|[^\[\{]*([\[\{].*)?$', '').Trim()
            if ($right -match '^(\w+)') { $right = $Matches[1] } else { $right = $null }
            foreach ($part in ($left -split '&')) {
                $n = ($part.Trim() -replace '\s*\|[^\[\{]*([\[\{].*)?$', '').Trim()
                if ($n -match '^(\w+)') { $n = $Matches[1] } else { $n = $null }
                if ($n -and -not $seen[$n]) { $seen[$n] = $true; [void]$modules.Add($n) }
            }
            if ($right -and -not $seen[$right]) { $seen[$right] = $true; [void]$modules.Add($right) }
        }
    }
}

# Limit to 40 modules if too many (plan: first 2-3 diagrams or key nodes)
$maxModules = 40
if ($modules.Count -gt $maxModules) {
    $modules = $modules | Select-Object -First $maxModules
}
$nModules = $modules.Count
if ($nModules -eq 0) {
    Write-Error "No Mermaid nodes found in ARCHITECTURE_diagram_ru.md"
    exit 1
}

# ---- Parse CHANGELOG: releases (tag, published) ----
$changelogContent = Get-Content -Path $ChangelogPath -Raw -Encoding UTF8
$releases = [System.Collections.ArrayList]@()
$blockRegex = [regex]'(?ms)^## ========== TAG: ([^\r\n=]+?) ==========\r?\n(.*?)(?=^## ========== TAG: |\z)'
$blockMatches = $blockRegex.Matches($changelogContent)

foreach ($bm in $blockMatches) {
    $tagName = $bm.Groups[1].Value.Trim()
    $block = $bm.Groups[2].Value
    $parts = $block -split '\r?\n\s*--\s*\r?\n', 2
    $metaSection = $parts[0]
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
    } catch { continue }
    [void]$releases.Add([PSCustomObject]@{ tag = $tagName; published = $published })
}

$releases = $releases | Sort-Object -Property published
$m = $releases.Count

# Intervals between releases (seconds), normalized to 0.3-1.2s for animation
$rawIntervals = @()
if ($m -gt 1) {
    for ($i = 0; $i -lt $m - 1; $i++) {
        $sec = ($releases[$i + 1].published - $releases[$i].published).TotalSeconds
        $rawIntervals += [math]::Max(0.1, $sec)
    }
    $minI = ($rawIntervals | Measure-Object -Minimum).Minimum
    $maxI = ($rawIntervals | Measure-Object -Maximum).Maximum
    if ($maxI -le $minI) { $maxI = $minI + 1 }
    $normIntervals = @()
    foreach ($s in $rawIntervals) {
        $t = ($s - $minI) / ($maxI - $minI)
        $norm = 0.3 + $t * 0.9
        $normIntervals += $norm
    }
} else {
    $normIntervals = @(0.5)
}

# Delay before block i (cumulative, cycling over normIntervals)
$delayBeforeBlock = @(0)
for ($i = 1; $i -lt $nModules; $i++) {
    $idx = ($i - 1) % $normIntervals.Count
    $delayBeforeBlock += $delayBeforeBlock[$i - 1] + $normIntervals[$idx]
}
$totalDelay = $delayBeforeBlock[$nModules - 1] + 0.6
$dropDuration = 0.5
$pause = 1.0
$cycleDuration = $totalDelay + $dropDuration + $pause
$cycleDurationRounded = [math]::Round($cycleDuration, 2)
$keyframesPct = [math]::Round(100 * $dropDuration / $cycleDurationRounded, 2)

function EscapeXml($s) {
    if (-not $s) { return "" }
    return [System.Net.WebUtility]::HtmlEncode($s)
}

function Get-Palette($isDark) {
    if ($isDark) {
        return @{ bg = "#0d1117"; fg = "#f0f6fc"; muted = "#8b949e"; accent = "#79c0ff"; dateFill = "#b1bac4"; blockFill = "#9ca3af"; blockFillOpacity = "0.18" }
    }
    return @{ bg = "#f6f8fa"; fg = "#1f2328"; muted = "#656d76"; accent = "#0969da"; dateFill = "#57606a"; blockFill = "#6b7280"; blockFillOpacity = "0.2" }
}

# ---- SVG dimensions (height half of before) ----
$svgW = 800
$svgH = 160
$padL = 24
$padR = 24
$padT = 40
$padB = 20
$groundY = $svgH - $padB - 22
$blockH = 18
$gap = 4
$chartW = $svgW - $padL - $padR
$minSlotW = 48
$nCols = [math]::Min($nModules, [math]::Max(1, [math]::Floor($chartW / $minSlotW)))
$slotW = $chartW / $nCols
$blockW = [math]::Max(36, [int]($slotW - $gap))
$rowStep = $blockH + 2
$dropFromYRow0 = -15

function Write-TetrisSvg($path, $isDark) {
    $p = Get-Palette $isDark
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + $svgW + ' ' + $svgH + '" width="100%" height="' + $svgH + '">')
    [void]$sb.AppendLine('<style>.at-block{ --drop-from:' + $dropFromYRow0 + 'px; transform:translateY(var(--drop-from)); animation:atDrop ' + $cycleDurationRounded + 's linear infinite; } .at-pulse{ transform:scale(1); animation:atPulse 2.5s ease-in-out infinite; } .at-block:hover{ filter:brightness(1.15); } @keyframes atDrop{ 0%{ transform:translateY(var(--drop-from)); } ' + $keyframesPct + '%{ transform:translateY(0); } 97%{ transform:translateY(0); } 100%{ transform:translateY(var(--drop-from)); } } @keyframes atPulse{ 0%,100%{ transform:scale(1); } 50%{ transform:scale(1.03); } } .at-date{ opacity:0; animation:atDate ' + $cycleDurationRounded + 's linear infinite; } @keyframes atDate{ 0%{ opacity:0; } 8%{ opacity:1; } 92%{ opacity:1; } 100%{ opacity:0; } }</style>')
    [void]$sb.AppendLine('<rect width="' + $svgW + '" height="' + $svgH + '" fill="' + $p.bg + '" rx="8"/>')
    [void]$sb.AppendLine('<text x="' + ($svgW/2) + '" y="22" fill="' + $p.muted + '" font-size="11" text-anchor="middle" font-family="system-ui,sans-serif">Тетрис версий: модули архитектуры</text>')
    [void]$sb.AppendLine('<text x="' + ($svgW/2) + '" y="34" fill="' + $p.muted + '" font-size="8" text-anchor="middle" font-family="system-ui,sans-serif">ритм по датам релизов — дата появляется при приземлении блока</text>')
    [void]$sb.AppendLine('<line x1="' + $padL + '" y1="' + $groundY + '" x2="' + ($svgW - $padR) + '" y2="' + $groundY + '" stroke="' + $p.muted + '" stroke-width="1" stroke-dasharray="4 2" opacity="0.7"/>')

    for ($i = 0; $i -lt $nModules; $i++) {
        $col = $i % $nCols
        $row = [math]::Floor($i / $nCols)
        $x = $padL + $col * $slotW + ($slotW - $blockW) / 2
        $y = $groundY - $blockH - $row * $rowStep
        $delay = $delayBeforeBlock[$i]
        $dropFromY = $dropFromYRow0 - $row * $rowStep
        $id = $modules[$i]
        if ($isDark -and $moduleLabels[$id]) {
            $label = $moduleLabels[$id]
            $maxLen = [math]::Min(28, [int]($blockW / 4.5))
        } else {
            $label = $id
            $maxLen = [math]::Max(10, [math]::Min(14, [int]($blockW / 4)))
        }
        if ($label.Length -gt $maxLen) { $label = $label.Substring(0, $maxLen - 1) + "…" }
        $releaseIdx = $i % [math]::Max(1, $m)
        $dateStr = $releases[$releaseIdx].published.ToString("dd.MM.yy", [System.Globalization.CultureInfo]::InvariantCulture)
        $dateDelay = [math]::Round($delay + $dropDuration, 2)
        $fontSz = if ($isDark) { "8" } else { "7" }
        [void]$sb.AppendLine('  <g transform="translate(' + [int]$x + ',' + [int]$y + ')">')
        [void]$sb.AppendLine('    <g class="at-block" style="--drop-from:' + $dropFromY + 'px; animation-delay:' + [math]::Round($delay, 2) + 's">')
        [void]$sb.AppendLine('      <g class="at-pulse">')
        [void]$sb.AppendLine('        <rect x="0" y="0" width="' + [int]$blockW + '" height="' + $blockH + '" rx="3" fill="' + $p.blockFill + '" fill-opacity="' + $p.blockFillOpacity + '" stroke="' + $p.fg + '" stroke-width="1"/>')
        [void]$sb.AppendLine('        <text x="' + ($blockW/2) + '" y="' + ($blockH - 4) + '" text-anchor="middle" fill="' + $p.fg + '" font-size="' + $fontSz + '" font-family="system-ui,sans-serif">' + (EscapeXml($label)) + '</text>')
        [void]$sb.AppendLine('      </g>')
        [void]$sb.AppendLine('    </g>')
        [void]$sb.AppendLine('    <text class="at-date" x="' + ($blockW/2) + '" y="-6" text-anchor="middle" fill="' + $p.dateFill + '" font-size="7" font-family="system-ui,sans-serif" style="animation-delay:' + $dateDelay + 's">' + (EscapeXml($dateStr)) + '</text>')
        [void]$sb.AppendLine('  </g>')
    }

    [void]$sb.AppendLine('</svg>')
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $sb.ToString(), $utf8)
}

# ---- Output ----
if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

Write-TetrisSvg (Join-Path $DistDir "architecture-tetris.svg") $false
Write-TetrisSvg (Join-Path $DistDir "architecture-tetris-dark.svg") $true

Write-Host "architecture-tetris.svg, architecture-tetris-dark.svg written (modules: $nModules, releases: $m, cycle: $cycleDurationRounded s)"
