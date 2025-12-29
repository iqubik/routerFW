<# :
@echo off
setlocal
cd /d "%~dp0"

:: Заголовок для запуска PowerShell из Bat-файла без ограничения на длину
:: Используем [System.IO.File]::ReadAllText, чтобы прочитать весь файл целиком
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression ([System.IO.File]::ReadAllText('%~f0'))"
exit /b
:>

# =========================================================
#  OPENWRT PROFILE CREATOR v2.1 (Hybrid Bat/PS)
# =========================================================

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Создаем папку для профилей, если её нет
if (-not (Test-Path "profiles")) { New-Item -ItemType Directory -Name "profiles" | Out-Null }

function Show-Header($Text) {
    Clear-Host
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  OpenWrt UNIVERSAL Profile Creator (v2.1 iqubik)" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host ""
}

try {
    # --- ШАГ 1: ВЫБОР РЕЛИЗА ---
    Show-Header "Шаг 1: Выбор релиза OpenWrt"
    
    Write-Host "Подключение к downloads.openwrt.org..." -ForegroundColor Gray
    $baseUrl = "http://downloads.openwrt.org/releases/"
    
    try {
        $html = (Invoke-WebRequest -Uri $baseUrl -UseBasicParsing).Content
    } catch {
        throw "Не удалось соединиться с сервером OpenWrt. Проверьте интернет."
    }

    # Парсим версии (24.x, 23.x, snapshots)
    $releases = @([regex]::Matches($html, 'href="(\d{2}\.\d{2}\.[^"/]+/|snapshots/)"') | 
                ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | 
                Select-Object -Unique | Sort-Object -Descending)

    if ($releases.Count -eq 0) { throw "Не удалось найти релизы на странице." }

    for ($i=0; $i -lt $releases.Count; $i++) { Write-Host (" {0,2}. {1}" -f ($i+1), $releases[$i]) }
    
    do {
        $resIdx = Read-Host "`nВыберите номер релиза"
        if ($resIdx -match '^\d+$' -and $resIdx -gt 0 -and $resIdx -le $releases.Count) { break }
        Write-Host "Неверный ввод." -ForegroundColor Red
    } while ($true)
    
    $selectedRelease = $releases[($resIdx-1)]

    # --- ШАГ 2: ВЫБОР TARGET ---
    Show-Header "Шаг 2: Выбор Target ($selectedRelease)"
    
    $targetUrl = if ($selectedRelease -eq "snapshots") { "http://downloads.openwrt.org/snapshots/targets/" } else { "$baseUrl$selectedRelease/targets/" }
    
    Write-Host "Загрузка списка архитектур..." -ForegroundColor Gray
    $html = (Invoke-WebRequest -Uri $targetUrl -UseBasicParsing).Content
    $targets = @([regex]::Matches($html, 'href="([^"\./ ]+/)"') | 
            ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | 
            Where-Object { $_ -notin @('backups', 'kmodindex', 'luci') })

    for ($i=0; $i -lt $targets.Count; $i++) { Write-Host (" {0,2}. {1}" -f ($i+1), $targets[$i]) }
    
    do {
        $tarIdx = Read-Host "`nВыберите номер Target"
        if ($tarIdx -match '^\d+$' -and $tarIdx -gt 0 -and $tarIdx -le $targets.Count) { break }
    } while ($true)
    $selectedTarget = $targets[($tarIdx-1)]

    # --- ШАГ 3: ВЫБОР SUBTARGET ---
    Show-Header "Шаг 3: Выбор Subtarget ($selectedTarget)"
    
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
        do {
            $subIdx = Read-Host "`nВыберите номер Subtarget"
            if ($subIdx -match '^\d+$' -and $subIdx -gt 0 -and $subIdx -le $subtargets.Count) { break }
        } while ($true)
        $selectedSubtarget = $subtargets[($subIdx-1)]
    }

    # --- ШАГ 4: ВЫБОР МОДЕЛИ ---
    Show-Header "Шаг 4: Выбор модели устройства"
    Write-Host "Загрузка profiles.json..." -ForegroundColor Gray
    
    $finalFolderUrl = "$targetUrl$selectedTarget/$selectedSubtarget/"
    
    try {
        $data = Invoke-RestMethod -Uri "$($finalFolderUrl)profiles.json"
    } catch {
        throw "Не удалось загрузить profiles.json по адресу $finalFolderUrl"
    }
    
    $profileIds = @($data.profiles.PSObject.Properties.Name | Sort-Object)
    $profileList = @()
    for ($i=0; $i -lt $profileIds.Count; $i++) {
        $id = $profileIds[$i]
        $title = $data.profiles.$id.title
        Write-Host (" {0,3}. {1} ({2})" -f ($i+1), $title, $id)
        $profileList += [PSCustomObject]@{ ID = $id; Title = $title }
    }
    
    do {
        $profIdx = Read-Host "`nВыберите номер устройства"
        if ($profIdx -match '^\d+$' -and $profIdx -gt 0 -and $profIdx -le $profileList.Count) { break }
    } while ($true)
    
    $targetProfile = $profileList[($profIdx-1)].ID
    $targetTitle = $profileList[($profIdx-1)].Title

    # --- ШАГ 5: ПОИСК IMAGEBUILDER ---
    Show-Header "Шаг 5: Поиск ссылки на ImageBuilder"
    Write-Host "Сканирование папки файлов..." -ForegroundColor Gray
    $folderHtml = (Invoke-WebRequest -Uri $finalFolderUrl -UseBasicParsing).Content
    
    # Ищем архив ImageBuilder (поддерживаем .tar.xz и .tar.zst)
    if ($folderHtml -match 'href="(openwrt-imagebuilder-[^"]+\.tar\.(xz|zst))"') {
        $ibFileName = $Matches[1]
        $ibUrl = "$finalFolderUrl$ibFileName"
        Write-Host "Найден: $ibFileName" -ForegroundColor Green
    } else {
        Write-Host "ПРЕДУПРЕЖДЕНИЕ: ImageBuilder не найден автоматически." -ForegroundColor Red
        $ibUrl = "https://downloads.openwrt.org/..."
    }

    # --- ШАГ 6: ФИНАЛИЗАЦИЯ ---
    Show-Header "Шаг 6: Настройка параметров"
    
    $pkgs = Read-Host "Введите список пакетов через пробел (напр. luci htop)"
    if ([string]::IsNullOrWhiteSpace($pkgs)) { $pkgs = "luci" }
    
    $profileName = Read-Host "Введите имя файла профиля (без пробелов, напр. my_router)"
    if ([string]::IsNullOrWhiteSpace($profileName)) { $profileName = "custom_profile" }
    
    $confPath = "profiles\$profileName.conf"
    
    # Определяем ветку git
    if ($selectedRelease -eq "snapshots") {
        $gitBranch = "master"
    } else {
        $gitBranch = "v$selectedRelease"
    }

    # === ГЕНЕРАЦИЯ КОНТЕНТА ===
    # Используем Here-String с экранированием переменных через обратный апостроф (`)
    
    $content = @"
# === Profile for $targetTitle (OpenWrt $selectedRelease) ===

PROFILE_NAME="$profileName"
TARGET_PROFILE="$targetProfile"

COMMON_LIST="$pkgs"

# === IMAGE BUILDER CONFIG
IMAGEBUILDER_URL="$ibUrl"
PKGS="`$COMMON_LIST"

#CUSTOM_KEYS="https://fantastic-packages.github.io/releases/24.10/53ff2b6672243d28.pub"
#CUSTOM_REPOS=""

# === SOURCE BUILDER CONFIG
SRC_REPO="https://github.com/openwrt/openwrt.git"
SRC_BRANCH="$gitBranch"
SRC_TARGET="$selectedTarget"
SRC_SUBTARGET="$selectedSubtarget"
SRC_PACKAGES="`$PKGS"

# === Extra config options (Source Builder)
#ROOTFS_SIZE="512"
#KERNEL_SIZE="64"

## Тонкая настройка конфигурации .config перед сборкой
SRC_EXTRA_CONFIG=""

## СПРАВОЧНИК ПОЛЕЗНЫХ ОПЦИЙ:
## ------------------------------------------------------------
## ЭКОНОМИЯ МЕСТА (Для 4MB / 8MB флешек)
#    - CONFIG_LUCI_SRCDIET=y      -> Сжимает Lua/JS в LuCI (экономит ~100-200KB)
#    - CONFIG_IPV6=n              -> Полностью вырезает IPv6 (экономит ~300KB)
#    - CONFIG_KERNEL_DEBUG_INFO=n -> Удаляет отладочную инфо из ядра
#    - CONFIG_STRIP_KERNEL_EXPORTS=y -> Удаляет таблицу экспортов (если не нужны kmod)
# SRC_EXTRA_CONFIG="CONFIG_LUCI_SRCDIET=y CONFIG_IPV6=n CONFIG_KERNEL_DEBUG_INFO=n"

## ФАЙЛОВЫЕ СИСТЕМЫ (Для SD-карт / x86 / NanoPi)
#    По умолчанию создается SquashFS (только чтение). Для одноплатников лучше EXT4.
#    - CONFIG_TARGET_ROOTFS_SQUASHFS=n -> Отключить SquashFS
#    - CONFIG_TARGET_ROOTFS_EXT4FS=y   -> Включить EXT4 (RW раздел)
#    - CONFIG_TARGET_ROOTFS_TARGZ=y    -> Создать архив (для контейнеров/бэкапа)
# CONFIG_TARGET_ROOTFS_SQUASHFS=n CONFIG_TARGET_ROOTFS_EXT4FS=y

## ОТЛАДКА И ЛОГИ
#    - CONFIG_KERNEL_PRINTK=n     -> Отключает вывод лога загрузки на экран (тихий бут)
#    - CONFIG_BUILD_LOG=y         -> Сохраняет логи сборки каждого пакета (для отладки ошибок)
# CONFIG_BUILD_LOG=y

## ПРИНУДИТЕЛЬНОЕ ВКЛЮЧЕНИЕ МОДУЛЕЙ
#    Если пакет не ставится через SRC_PACKAGES, можно включить его тут.
# CONFIG_PACKAGE_kmod-usb-net-rndis=y
"@

    # Сохранение файла
    $content | Out-File -FilePath $confPath -Encoding utf8 -Force
    
    Write-Host "`n[OK] Профиль успешно создан: $confPath" -ForegroundColor Green
    Write-Host "--------------------------------------------------------"
    
    # Предложение запустить сборщик
    if (Test-Path "_Source_Builder.bat") {
        Write-Host "Нажмите Enter, чтобы запустить _Source_Builder.bat..." -ForegroundColor Yellow
        Write-Host "Или закройте окно для выхода." -ForegroundColor Gray
        Read-Host
        Start-Process "_Source_Builder.bat"
    } else {
        Write-Host "Готово. Нажмите Enter для выхода."
        Read-Host
    }

} catch {
    Write-Host "`n[CRITICAL ERROR] Произошла ошибка:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Стек вызова:"
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    Write-Host "`nНажмите Enter, чтобы выйти."
    Read-Host
}