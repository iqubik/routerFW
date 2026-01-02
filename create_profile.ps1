$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Создаем папку для профилей, если её нет
if (-not (Test-Path "profiles")) { New-Item -ItemType Directory -Name "profiles" | Out-Null }

# --- ИЗМЕНЕНИЕ 1: Обновленная функция заголовка ---
function Show-Header($Text, $Selection = $null) {
    Clear-Host
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  OpenWrt UNIVERSAL Profile Creator (v1.3 iqubik/UI-Mod)" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Cyan
    
    # Если есть выбранные параметры, показываем их
    if ($null -ne $Selection) {
        Write-Host "  ВЫБРАНО: $Selection" -ForegroundColor Green
        Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# Функция безопасного выбора из списка
function Read-Selection($MaxCount) {
    if ($MaxCount -lt 1) { return 0 }
    
    do {
        $inputVal = Read-Host "`nВыберите номер (1-$MaxCount)"
        
        # Проверка на пустоту
        if ([string]::IsNullOrWhiteSpace($inputVal)) {
            Write-Host "Ошибка: Ввод не может быть пустым." -ForegroundColor Red
            continue
        }

        # Проверка, что это число
        if ($inputVal -match '^\d+$') {
            $idx = [int]$inputVal
            if ($idx -ge 1 -and $idx -le $MaxCount) {
                return $idx # Возвращаем корректный индекс (1-based)
            } else {
                Write-Host "Ошибка: Число должно быть от 1 до $MaxCount." -ForegroundColor Red
            }
        } else {
            Write-Host "Ошибка: Введите число." -ForegroundColor Red
        }
    } while ($true)
}

try {
    # --- ШАГ 1: ВЫБОР РЕЛИЗА ---
    Show-Header "Шаг 1: Выбор релиза"
    
    Write-Host "Не знаете параметры своего роутера?" -ForegroundColor Gray
    Write-Host "Найдите его в OpenWrt Table of Hardware (ToH):"
    Write-Host "https://openwrt.org/toh/start" -ForegroundColor Blue
    Write-Host "--------------------------------------------------------------------------`n"

    Write-Host "Получение списка релизов..."
    $baseUrl = "https://downloads.openwrt.org/releases/"
    $html = (Invoke-WebRequest -Uri $baseUrl -UseBasicParsing).Content
    $releases = @([regex]::Matches($html, 'href="(\d{2}\.\d{2}\.[^"/]+/|snapshots/)"') | 
                ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | 
                Select-Object -Unique | Sort-Object -Descending)

    for ($i=0; $i -lt $releases.Count; $i++) { Write-Host (" {0,2}. {1}" -f ($i+1), $releases[$i]) }
    
    # ВАЛИДАЦИЯ ВВОДА
    $resIdx = Read-Selection -MaxCount $releases.Count
    $selectedRelease = $releases[($resIdx-1)]

    # --- ШАГ 2: ВЫБОР TARGET ---
    # ИЗМЕНЕНИЕ 2: Передаем статус
    Show-Header "Шаг 2: Выбор Target" "Release: [$selectedRelease]"
    
    Write-Host "Пример: внутри ссылки -ramips-mt7621-beeline_smartbox-giga-" -ForegroundColor Gray
    Write-Host "TARGET здесь: ramips" -ForegroundColor Blue
    Write-Host "--------------------------------------------------------------------------`n"
    
    $targetUrl = if ($selectedRelease -eq "snapshots") { "https://downloads.openwrt.org/snapshots/targets/" } else { "$baseUrl$selectedRelease/targets/" }
    
    $html = (Invoke-WebRequest -Uri $targetUrl -UseBasicParsing).Content
    $targets = @([regex]::Matches($html, 'href="([^"\./ ]+/)"') | 
            ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | 
            Where-Object { $_ -notin @('backups', 'kmodindex') })

    for ($i=0; $i -lt $targets.Count; $i++) { Write-Host (" {0,2}. {1}" -f ($i+1), $targets[$i]) }
    
    # ВАЛИДАЦИЯ ВВОДА
    $tarIdx = Read-Selection -MaxCount $targets.Count
    $selectedTarget = $targets[($tarIdx-1)]

    # --- ШАГ 3: ВЫБОР SUBTARGET ---
    # ИЗМЕНЕНИЕ 3: Передаем статус
    Show-Header "Шаг 3: Выбор Subtarget" "Release: [$selectedRelease] > Target: [$selectedTarget]"
    
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
        
        # ВАЛИДАЦИЯ ВВОДА
        $subIdx = Read-Selection -MaxCount $subtargets.Count
        $selectedSubtarget = $subtargets[($subIdx-1)]
    }

    # --- ШАГ 4: ВЫБОР МОДЕЛИ ---
    # ИЗМЕНЕНИЕ 4: Передаем статус
    Show-Header "Шаг 4: Выбор модели" "Release: [$selectedRelease] > Target: [$selectedTarget] > Sub: [$selectedSubtarget]"
    
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
    
    # ВАЛИДАЦИЯ ВВОДА
    $profIdx = Read-Selection -MaxCount $profileList.Count
    $targetProfile = $profileList[($profIdx-1)].ID

    # --- ШАГ 5: ПОИСК IMAGEBUILDER ---
    # ИЗМЕНЕНИЕ 5: Передаем полный статус
    Show-Header "Шаг 5: Поиск ImageBuilder" "Release: [$selectedRelease] > Target: [$selectedTarget] > Sub: [$selectedSubtarget] > Device: [$targetProfile]"
    
    $folderHtml = (Invoke-WebRequest -Uri $finalFolderUrl -UseBasicParsing).Content
    if ($folderHtml -match 'href="(openwrt-imagebuilder-[^"]+\.tar\.(xz|zst))"') {
        $ibFileName = $Matches[1]
        $ibUrl = "$finalFolderUrl$ibFileName"
    } else {
        throw "Не удалось найти файл ImageBuilder в папке $finalFolderUrl"
    }

    # --- ШАГ 6: ГЕНЕРАЦИЯ УНИВЕРСАЛЬНОГО ПРОФИЛЯ ---
    # ИЗМЕНЕНИЕ 6: Передаем полный статус
    Show-Header "Шаг 6: Финализация" "Release: [$selectedRelease] > Target: [$selectedTarget] > Sub: [$selectedSubtarget] > Device: [$targetProfile]"
    
    $pkgs = Read-Host "Введите пакеты (через пробел, можно из буфера)"
    
    # Валидация имени профиля
    do {
        $profileName = Read-Host "Введите имя конфига (без пробелов, в нижнем регистре. Например: my_router)"
        if ([string]::IsNullOrWhiteSpace($profileName)) {
            $profileName = "new_profile" 
            Write-Host "Имя не введено. Используется стандартное: $profileName" -ForegroundColor DarkGray
            break
        }
        if ($profileName -match '\s') {
            Write-Host "Ошибка: Имя не должно содержать пробелов." -ForegroundColor Red
        } else {
            break
        }
    } while ($true)

    $confPath = "profiles\$profileName.conf"
    
    # Определяем ветку git
    if ($selectedRelease -eq "snapshots") {
        $gitBranch = "master"
    } else {
        $gitBranch = "v$selectedRelease"
    }

    # Формируем контент
    $content = @"
# === Profile for $targetProfile (OpenWrt $selectedRelease) ===

PROFILE_NAME="$profileName"
TARGET_PROFILE="$targetProfile"

COMMON_LIST="$pkgs"

# === IMAGE BUILDER CONFIG
IMAGEBUILDER_URL="$ibUrl"
PKGS="`$COMMON_LIST"
EXTRA_IMAGE_NAME="custom"
#CUSTOM_KEYS="https://fantastic-packages.github.io/releases/24.10/53ff2b6672243d28.pub"
#CUSTOM_REPOS="src/gz fantastic_luci https://fantastic-packages.github.io/releases/24.10/packages/mipsel_24kc/luci
#src/gz fantastic_packages https://fantastic-packages.github.io/releases/24.10/packages/mipsel_24kc/packages
#src/gz fantastic_special https://fantastic-packages.github.io/releases/24.10/packages/mipsel_24kc/special"
#DISABLED_SERVICES="transmission-daemon minidlna"

# === SOURCE BUILDER CONFIG
SRC_REPO="https://github.com/openwrt/openwrt.git"
SRC_BRANCH="$gitBranch"
SRC_TARGET="$selectedTarget"
SRC_SUBTARGET="$selectedSubtarget"
SRC_PACKAGES="`$PKGS"

# === Extra config options
#ROOTFS_SIZE="512"
#KERNEL_SIZE="64"
SRC_EXTRA_CONFIG="CONFIG_TARGET_MULTI_PROFILE=n \
CONFIG_BUILD_LOG=y"

##ЭКОНОМИЯ МЕСТА (Для 4MB / 8MB флешек)
#    - CONFIG_LUCI_SRCDIET=y      -> Сжимает Lua/JS в LuCI (экономит ~100-200KB)
#    - CONFIG_IPV6=n              -> Полностью вырезает IPv6 (экономит ~300KB)
#    - CONFIG_KERNEL_DEBUG_INFO=n -> Удаляет отладочную инфо из ядра
#    - CONFIG_STRIP_KERNEL_EXPORTS=y -> Удаляет таблицу экспортов (если не нужны kmod)
# SRC_EXTRA_CONFIG="CONFIG_LUCI_SRCDIET=y CONFIG_IPV6=n CONFIG_KERNEL_DEBUG_INFO=n"
##ФАЙЛОВЫЕ СИСТЕМЫ (Для SD-карт / x86 / NanoPi)
#    По умолчанию создается SquashFS (только чтение). Для одноплатников лучше EXT4.
#    - CONFIG_TARGET_ROOTFS_SQUASHFS=n -> Отключить SquashFS
#    - CONFIG_TARGET_ROOTFS_EXT4FS=y   -> Включить EXT4 (RW раздел)
#    - CONFIG_TARGET_ROOTFS_TARGZ=y    -> Создать архив (для контейнеров/бэкапа)
# CONFIG_TARGET_ROOTFS_SQUASHFS=n CONFIG_TARGET_ROOTFS_EXT4FS=y
##ОТЛАДКА И ЛОГИ
#    - CONFIG_KERNEL_PRINTK=n     -> Отключает вывод лога загрузки на экран (тихий бут)
#    - CONFIG_BUILD_LOG=y         -> Сохраняет логи сборки каждого пакета (для отладки ошибок)
# CONFIG_BUILD_LOG=y
##ПРИНУДИТЕЛЬНОЕ ВКЛЮЧЕНИЕ МОДУЛЕЙ
#    Если пакет не ставится через SRC_PACKAGES, можно включить его тут.
# CONFIG_PACKAGE_kmod-usb-net-rndis=y
"@
    
    # Сохраняем в UTF8
    $content | Out-File -FilePath $confPath -Encoding utf8 -Force
    
    Write-Host "`n[OK] Универсальный профиль создан: $confPath" -ForegroundColor Green
    Write-Host "--------------------------------------------------------"
    Write-Host "Первые 20 строк файла:" -ForegroundColor Gray
    $content -split "`n" | Select-Object -First 20 | Write-Host -ForegroundColor Cyan
    Write-Host "..." -ForegroundColor Cyan
    Write-Host "--------------------------------------------------------"
    Pause

} catch {
    Write-Host "`nОШИБКА: $($_.Exception.Message)" -ForegroundColor Red
    Pause
}