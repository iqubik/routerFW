# file : system/apk_scanner.ps1
# Скрипт сканирования и валидации APK-пакетов в custom_packages

param (
    [Parameter(Mandatory = $false)]
    [string]$ProfileID = "",
    [Parameter(Mandatory = $false)]
    [string]$TargetArch = "",
    [Parameter(Mandatory = $false)]
    [string]$Lang = ""
)

$ScriptVersion = "1.0"

# --- ЯЗЫК (передаётся от билдера) ---
$IsRU = ($Lang -eq "RU")

if ($IsRU) {
    $T_SCAN_TITLE  = "APK СКАНЕР"
    $T_SCANNING    = "Сканирую APK в..."
    $T_NO_FILES    = "APK-файлы не найдены."
    $T_PARSE_FAIL  = "Ошибка чтения метаданных"
    $T_ARCH_UNIV   = "Универсальная"
    $T_ARCH_MATCH  = "Совпадение"
    $T_ARCH_WARN   = "⚠ НЕСОВПАДЕНИЕ АРХИТЕКТУРЫ"
    $T_ARCH_DETAIL = "Пакет имеет архитектуру, отличную от профиля"
    $T_NAME_OK     = "Имя соответствует"
    $T_NAME_WARN   = "⚠ НЕСООТВЕТСТВИЕ ИМЕНИ"
    $T_NAME_FILE   = "  Имя файла   :"
    $T_NAME_INT    = "  Внутреннее  :"
    $T_RENAME_PMT  = "  Переименовать? [Y/n]: "
    $T_RENAMED     = "  ✓ Переименован в"
    $T_SKIPPED     = "  Пропущено"
    $T_DONE        = "ГОТОВО: проверено {0}, переименовано {1}, предупреждений {2}"
    $T_NOT_FOUND   = "не найдена"
    $T_RENAME_FAIL = "Не удалось переименовать"
} else {
    $T_SCAN_TITLE  = "APK SCANNER"
    $T_SCANNING    = "Scanning APKs in..."
    $T_NO_FILES    = "No APK files found."
    $T_PARSE_FAIL  = "Metadata parse failed"
    $T_ARCH_UNIV   = "Universal"
    $T_ARCH_MATCH  = "Match"
    $T_ARCH_WARN   = "⚠ ARCHITECTURE MISMATCH"
    $T_ARCH_DETAIL = "Package architecture differs from profile target"
    $T_NAME_OK     = "Name matches"
    $T_NAME_WARN   = "⚠ NAME MISMATCH"
    $T_NAME_FILE   = "  Filename   :"
    $T_NAME_INT    = "  Internal   :"
    $T_RENAME_PMT  = "  Rename? [Y/n]: "
    $T_RENAMED     = "  ✓ Renamed to"
    $T_SKIPPED     = "  Skipped"
    $T_DONE        = "DONE: {0} scanned, {1} renamed, {2} warnings"
    $T_NOT_FOUND   = "not found"
    $T_RENAME_FAIL = "Failed to rename"
}

# --- ПУТИ ---
if ($ProfileID -ne "") {
    $apkDir = "custom_packages\$ProfileID"
} else {
    $apkDir = "custom_packages"
}

# --- ЗАГОЛОВОК ---
Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  $T_SCAN_TITLE v$ScriptVersion" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
$profDisp = if ($ProfileID) { $ProfileID } else { "GLOBAL" }
Write-Host "[TARGET]  " -NoNewline -ForegroundColor Cyan
Write-Host "Profile: " -NoNewline -ForegroundColor Gray
Write-Host "$profDisp" -ForegroundColor White
Write-Host "          " -NoNewline -ForegroundColor Cyan
Write-Host "Arch   : " -NoNewline -ForegroundColor Gray
Write-Host "$(if ($TargetArch) { $TargetArch } else { $T_NOT_FOUND })" -ForegroundColor White
Write-Host "[PATHS]   " -NoNewline -ForegroundColor Cyan
Write-Host "Source : " -NoNewline -ForegroundColor Gray
Write-Host "$apkDir" -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Cyan

# --- ПРОВЕРКА ---
if (-not (Test-Path $apkDir)) {
    Write-Host "[!] $apkDir $T_NOT_FOUND." -ForegroundColor Yellow
    exit 0
}

$apkFiles = Get-ChildItem -Path $apkDir -File | Where-Object { $_.Extension -eq ".apk" }
if ($apkFiles.Count -eq 0) {
    Write-Host "[+] $T_NO_FILES" -ForegroundColor Green
    exit 0
}

Write-Host "[*] $T_SCANNING $apkDir ($($apkFiles.Count) files)" -ForegroundColor Cyan
Write-Host ""

$scanned  = 0
$renamed  = 0
$warnings = 0

foreach ($apk in $apkFiles) {
    $apkName = $apk.Name
    $apkPath = $apk.FullName
    Write-Host "[$scanned] $apkName" -ForegroundColor Cyan

    # --- 1. Docker adbdump ---
    try {
        $dockerCmd = "docker run --rm -v `"$($apk.DirectoryName)`:/data`" alpine:latest apk adbdump `/data/$apkName"
        $adbdumpOutput = Invoke-Expression $dockerCmd
        $adbdumpString = $adbdumpOutput -join "`n"

        if (-not $adbdumpString) { throw "No output" }

        # Парсинг
        $pkgName    = ""
        $pkgVersion = ""
        $pkgArch    = ""

        foreach ($line in ($adbdumpString -split '\r?\n')) {
            if ($line -match "^  name:\s*(.*)$")    { $pkgName    = $matches[1].Trim(); continue }
            if ($line -match "^  version:\s*(.*)$") { $pkgVersion = $matches[1].Trim(); continue }
            if ($line -match "^  arch:\s*(.*)$")    { $pkgArch    = $matches[1].Trim(); continue }
        }

        if (-not $pkgName -or -not $pkgVersion) {
            throw "Empty name/version"
        }

    } catch {
        Write-Host "    [ERR] $T_PARSE_FAIL : $apkName" -ForegroundColor Red
        $warnings++
        Write-Host ""
        $scanned++
        continue
    }

    # --- 2. Проверка имени файла ---
    $fileBase = $apk.BaseName
    $expectedName = ""
    $expectedVer  = ""

    # Пытаемся распарсить {name}-{version}
    if ($fileBase -match "^(.*)-([0-9].*)$") {
        $expectedName = $matches[1].Trim()
        $expectedVer  = $matches[2].Trim()
    } else {
        $expectedName = $fileBase.Trim()
        $expectedVer  = ""
    }

    $nameMismatch = $false
    if ($expectedName -ne $pkgName) { $nameMismatch = $true }
    if ($expectedVer -and $expectedVer -ne $pkgVersion) { $nameMismatch = $true }

    if ($nameMismatch) {
        Write-Host "    --- $T_NAME_WARN ---" -ForegroundColor Yellow
        Write-Host "$T_NAME_FILE $apkName"
        Write-Host "$T_NAME_INT ${pkgName}-${pkgVersion}"

        $correctName = "${pkgName}-${pkgVersion}.apk"
        $correctPath = Join-Path $apk.DirectoryName $correctName

        if ($correctName -ne $apkName) {
            $null = Read-Host $T_RENAME_PMT
            if ($choice -eq "N" -or $choice -eq "n") {
                Write-Host "    $T_SKIPPED" -ForegroundColor Gray
                $warnings++
            } else {
                try {
                    Rename-Item -Path $apkPath -NewName $correctName -ErrorAction Stop
                    Write-Host "    $T_RENAMED $correctName" -ForegroundColor Green
                    $renamed++
                } catch {
                    Write-Host "    [ERR] $T_RENAME_FAIL : $apkName" -ForegroundColor Red
                    $warnings++
                }
            }
        }
    } else {
        Write-Host "    [OK] $T_NAME_OK" -ForegroundColor Green
    }

    # --- 3. Проверка архитектуры ---
    if ($pkgArch -eq "all" -or $pkgArch -eq "noarch") {
        Write-Host "    [OK] $T_ARCH_UNIV ($pkgArch)" -ForegroundColor Green
    } elseif ($TargetArch -ne "") {
        if ($pkgArch -eq $TargetArch) {
            Write-Host "    [OK] $T_ARCH_MATCH ($pkgArch)" -ForegroundColor Green
        } else {
            Write-Host "    [WARN] $T_ARCH_WARN" -ForegroundColor Yellow
            Write-Host "    [WARN] $T_ARCH_DETAIL : $pkgArch vs $TargetArch" -ForegroundColor Yellow
            $warnings++
        }
    } else {
        Write-Host "    [INFO] $pkgArch (unchecked)" -ForegroundColor Gray
    }

    Write-Host ""
    $scanned++
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ($T_DONE -f $scanned, $renamed, $warnings) -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Пауза
if ($IsRU) {
    Read-Host "`n Нажмите Enter"
} else {
    Read-Host "`n Press Enter"
}

if ($warnings -gt 0) {
    exit 1
}
exit 0
# checksum:MD5=9cb25ea8e35594dc2a2eb39713307baf