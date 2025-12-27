$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Создаем папку для профилей, если её нет
if (-not (Test-Path "profiles")) { New-Item -ItemType Directory -Name "profiles" | Out-Null }

function Show-Header($Text) {
    Clear-Host
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  OpenWrt UNIVERSAL Profile Creator (v1.0 iqubik)" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host ""
}

try {
    # --- ШАГ 1: ВЫБОР РЕЛИЗА ---
    Show-Header "Шаг 1: Выбор релиза"
    
    Write-Host "Не знаете параметры своего роутера?" -ForegroundColor Gray
    Write-Host "Найдите его в OpenWrt Table of Hardware (ToH):"
    Write-Host "http://openwrt.org/toh/start" -ForegroundColor Blue
    Write-Host "--------------------------------------------------------------------------`n"

    Write-Host "Получение списка релизов..."
    $baseUrl = "http://downloads.openwrt.org/releases/"
    $html = (Invoke-WebRequest -Uri $baseUrl -UseBasicParsing).Content
    $releases = @([regex]::Matches($html, 'href="(\d{2}\.\d{2}\.[^"/]+/|snapshots/)"') | 
                ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | 
                Select-Object -Unique | Sort-Object -Descending)

    for ($i=0; $i -lt $releases.Count; $i++) { Write-Host (" {0,2}. {1}" -f ($i+1), $releases[$i]) }
    $resIdx = Read-Host "`nВыберите номер релиза"
    $selectedRelease = $releases[($resIdx-1)]

    # --- ШАГ 2: ВЫБОР TARGET ---
    Show-Header "Шаг 2: Выбор Target ($selectedRelease)"
    Write-Host "Пример: внутри ссылки -ramips-mt7621-beeline_smartbox-giga-" -ForegroundColor Gray
    Write-Host "TARGET здесь: ramips" -ForegroundColor Blue
    Write-Host "--------------------------------------------------------------------------`n"
    
    $targetUrl = if ($selectedRelease -eq "snapshots") { "http://downloads.openwrt.org/snapshots/targets/" } else { "$baseUrl$selectedRelease/targets/" }
    
    $html = (Invoke-WebRequest -Uri $targetUrl -UseBasicParsing).Content
    $targets = @([regex]::Matches($html, 'href="([^"\./ ]+/)"') | 
            ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | 
            Where-Object { $_ -notin @('backups', 'kmodindex') })

    for ($i=0; $i -lt $targets.Count; $i++) { Write-Host (" {0,2}. {1}" -f ($i+1), $targets[$i]) }
    $tarIdx = Read-Host "`nВыберите номер Target"
    $selectedTarget = $targets[($tarIdx-1)]

    # --- ШАГ 3: ВЫБОР SUBTARGET ---
    Show-Header "Шаг 3: Выбор Subtarget"
    Write-Host "Пример: внутри ссылки -ramips-mt7621-beeline_smartbox-giga-" -ForegroundColor Gray
    Write-Host "SUBTARGET здесь: mt7621" -ForegroundColor Blue
    Write-Host "--------------------------------------------------------------------------`n"
    $subUrl = "$targetUrl$selectedTarget/"
    $html = (Invoke-WebRequest -Uri $subUrl -UseBasicParsing).Content
    $subtargets = @([regex]::Matches($html, 'href="([^"\./ ]+/)"') | 
                ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | 
                Where-Object { $_ -notin @('backups', 'kmodindex', 'packages') })

    if ($subtargets.Count -eq 0) {
        $selectedSubtarget = "generic"
    } elseif ($subtargets.Count -eq 1) {
        $selectedSubtarget = $subtargets[0]
    } else {
        for ($i=0; $i -lt $subtargets.Count; $i++) { Write-Host (" {0,2}. {1}" -f ($i+1), $subtargets[$i]) }
        $subIdx = Read-Host "`nВыберите номер Subtarget"
        $selectedSubtarget = $subtargets[($subIdx-1)]
    }

    # --- ШАГ 4: ВЫБОР МОДЕЛИ ---
    Show-Header "Шаг 4: Выбор модели"
    Write-Host "Загрузка profiles.json..." -ForegroundColor Gray
    
    $finalFolderUrl = "$targetUrl$selectedTarget/$selectedSubtarget/"
    $data = Invoke-RestMethod -Uri "$($finalFolderUrl)profiles.json"    
    
    $profileIds = @($data.profiles.PSObject.Properties.Name | Sort-Object)
    $profileList = @()
    for ($i=0; $i -lt $profileIds.Count; $i++) {
        $id = $profileIds[$i]
        $title = $data.profiles.$id.title
        Write-Host (" {0,3}. {1} ({2})" -f ($i+1), $title, $id)
        $profileList += [PSCustomObject]@{ ID = $id; Title = $title }
    }
    $profIdx = Read-Host "`nВыберите номер устройства"
    $targetProfile = $profileList[($profIdx-1)].ID

    # --- ШАГ 5: ПОИСК IMAGEBUILDER ---
    Show-Header "Шаг 5: Поиск ImageBuilder"
    $folderHtml = (Invoke-WebRequest -Uri $finalFolderUrl -UseBasicParsing).Content
    if ($folderHtml -match 'href="(openwrt-imagebuilder-[^"]+\.tar\.(xz|zst))"') {
        $ibFileName = $Matches[1]
        $ibUrl = "$finalFolderUrl$ibFileName"
    } else {
        throw "Не удалось найти файл ImageBuilder в папке $finalFolderUrl"
    }

    # --- ШАГ 6: ГЕНЕРАЦИЯ УНИВЕРСАЛЬНОГО ПРОФИЛЯ ---
    Show-Header "Шаг 6: Финализация"
    $pkgs = Read-Host "Введите пакеты (через пробел, можно из буфера)"
    $profileName = Read-Host "Введите имя конфига (без пробелов, например: my_router)"
    if ([string]::IsNullOrWhiteSpace($profileName)) { $profileName = "new_profile" }

    $confPath = "profiles\$profileName.conf"
    
    # Определяем ветку git (тег)
    if ($selectedRelease -eq "snapshots") {
        $gitBranch = "master"
    } else {
        $gitBranch = "v$selectedRelease"
    }

    # Формируем контент.
    # Используем ` перед $ там, где переменная должна остаться в файле (для Bash),
    # и без ` там, где PowerShell должен подставить значение сейчас.
    $content = @"
# === Profile for $targetProfile (OpenWrt $selectedRelease) ===

PROFILE_NAME="$profileName"
TARGET_PROFILE="$targetProfile"

COMMON_LIST="$pkgs"

# === IMAGE BUILDER CONFIG
IMAGEBUILDER_URL="$ibUrl"
PKGS="`$COMMON_LIST"
#EXTRA_IMAGE_NAME="custom"
#CUSTOM_KEYS=""
#CUSTOM_REPOS=""
#DISABLED_SERVICES=""

# === SOURCE BUILDER CONFIG
SRC_REPO="https://github.com/openwrt/openwrt.git"
SRC_BRANCH="$gitBranch"
SRC_TARGET="$selectedTarget"
SRC_SUBTARGET="$selectedSubtarget"
SRC_PACKAGES="`$PKGS"

# === Extra config options
#ROOTFS_SIZE="512"
#KERNEL_SIZE="64"
"@
    
    # Сохраняем в UTF8 (на случай кириллицы в комментариях)
    $content | Out-File -FilePath $confPath -Encoding utf8 -Force
    
    Write-Host "`n[OK] Универсальный профиль создан: $confPath" -ForegroundColor Green
    Write-Host "--------------------------------------------------------"
    Write-Host "Содержимое:" -ForegroundColor Gray
    Write-Host $content -ForegroundColor Cyan
    Write-Host "--------------------------------------------------------"
    
    Write-Host "Нажмите Enter, чтобы запустить SOURCE Builder, или закройте окно..." -ForegroundColor Yellow
    Pause
    
    if (Test-Path "_Source_Builder.bat") {
        cmd.exe /c _Source_Builder.bat
    }

} catch {
    Write-Host "`nОШИБКА: $($_.Exception.Message)" -ForegroundColor Red
    Pause
}