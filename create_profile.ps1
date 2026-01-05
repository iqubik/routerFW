<#
.SYNOPSIS
    OpenWrt/ImmortalWrt Universal Profile Creator.

.DESCRIPTION
    Скрипт-мастер (Wizard) для создания конфигурационных файлов профилей сборки.
    Поддерживает:
    - Выбор между OpenWrt и ImmortalWrt.
    - Парсинг HTML-директорий релизов и таргетов.
    - Чтение JSON-профилей устройств (profiles.json).
    - Умный анализ пакетов (Target Default + Device Specific).
    - Навигацию (Назад/Выход) через машину состояний.
    - UX 2.0: Автозаполнение (Luci), системные имена файлов и защита от перезаписи.

.VERSION
    2.25 (Header Fix + Smart Navigation)
#>

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- ИНИЦИАЛИЗАЦИЯ ОКРУЖЕНИЯ ---
# Создаем рабочую папку для профилей, если её нет
if (-not (Test-Path "profiles")) { New-Item -ItemType Directory -Name "profiles" | Out-Null }

# --- ХРАНИЛИЩЕ СОСТОЯНИЯ (GLOBAL STATE) ---
# Позволяет реализовать логику "Назад" без потери контекста.
$GlobalState = @{
    Source     = $null # OpenWrt или ImmortalWrt
    BaseUrl    = $null # Базовый URL загрузок
    RepoUrl    = $null # URL Git-репозитория
    Release    = $null # Версия релиза (или snapshots)
    Target     = $null # Архитектура (напр. ramips)
    Subtarget  = $null # Под-архитектура (напр. mt7621)
    ModelID    = $null # ID профиля (напр. beeline_smartbox-giga)
    ModelName  = $null # Человекочитаемое название
    DefPkgs    = $null # Вычисленный список пакетов
    IBUrl      = $null # Ссылка на ImageBuilder
    LastStep   = 1    # Для отслеживания направления движения
}

# --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---

function Show-Header {
    <#
    .SYNOPSIS
        Отображает шапку и текущий статус выбора (хлебные крошки).
    .PARAMETER StepName
        Название текущего шага для заголовка.
    #>
    param([string]$StepName, [int]$StepNum)
    Clear-Host
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  UNIVERSAL Profile Creator (v2.26 UX+)" -ForegroundColor Cyan
    Write-Host "  $StepName" -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Cyan
    
    # --- ВИЗУАЛИЗАЦИЯ ИМЕНИ ФАЙЛА ---
    Write-Host "  FIRMWARE BINARY STRUCTURE:" -ForegroundColor Gray
    Write-Host "  " -NoNewline

    # Функция-помощник для покраски сегментов
    function Out-Part {
        param($Value, $Default, $PartStep)
        $display = if ($Value) { $Value.ToLower() } else { $Default }
        if ($StepNum -eq $PartStep) {
            Write-Host "[$display]" -NoNewline -ForegroundColor Magenta
        } elseif ($Value) {
            Write-Host $display -NoNewline -ForegroundColor Green
        } else {
            Write-Host $display -NoNewline -ForegroundColor DarkGray
        }
    }

    # Собираем структуру: source-target-subtarget-model-suffix
    Out-Part $GlobalState.Source "source" 1
    Write-Host "-" -NoNewline -ForegroundColor DarkGray
    Out-Part $GlobalState.Target "target" 3
    Write-Host "-" -NoNewline -ForegroundColor DarkGray
    Out-Part $GlobalState.Subtarget "subtarget" 4
    Write-Host "-" -NoNewline -ForegroundColor DarkGray
    Out-Part $GlobalState.ModelID "model" 5
    Write-Host "-squashfs-sysupgrade.bin" -ForegroundColor DarkGray    

    # --- ХЛЕБНЫЕ КРОШКИ ---
    $crumbs = @()
    if ($GlobalState.Source)    { $crumbs += $GlobalState.Source }
    if ($GlobalState.Release)   { $crumbs += $GlobalState.Release }
    if ($GlobalState.Target)    { $crumbs += $GlobalState.Target }
    if ($GlobalState.Subtarget) { $crumbs += $GlobalState.Subtarget }
    if ($GlobalState.ModelName) { $crumbs += $GlobalState.ModelName }
    
    # 2. Выводим разноцветную строку
    if ($crumbs.Count -gt 0) {
        Write-Host "  PATH: " -NoNewline -ForegroundColor Gray
        for ($i = 0; $i -lt $crumbs.Count; $i++) {
            # Значение (Ярко-зеленый)
            Write-Host $crumbs[$i] -NoNewline -ForegroundColor Green
            # Разделитель (Только если это не последний элемент)
            if ($i -lt ($crumbs.Count - 1)) { Write-Host " > " -NoNewline -ForegroundColor DarkGray }
        }
        Write-Host ""
    }
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkGray
}

function Read-Selection {
    <#
    .SYNOPSIS
        Безопасное чтение ввода пользователя с валидацией и навигацией.
    .PARAMETER MaxCount
        Максимальное число в списке выбора.
    .PARAMETER AllowBack
        Разрешить ли ввод 'Z' для возврата назад.
    .OUTPUTS
        Число (индекс) или -1 (код возврата).
    #>
    param($MaxCount, $AllowBack = $true)
    do {
        $prompt = "`nВыберите номер (1-$MaxCount)"
        if ($AllowBack) { $prompt += ", [Z] Назад" }
        $prompt += ", [Q] Выход: "
        $inputVal = Read-Host $prompt
        # Игнорируем пустой ввод
        if ([string]::IsNullOrWhiteSpace($inputVal)) { continue }
        $val = $inputVal.Trim().ToLower()
        # Обработка выхода
        # Обработка возврата (Код -1)
        if ($val -eq 'q') { exit }
        if ($AllowBack -and $val -eq 'z') { return -1 } 
        # Валидация числа
        if ($val -match '^\d+$') {
            $idx = [int]$val
            if ($idx -ge 1 -and $idx -le $MaxCount) { return $idx }
        }
        Write-Host "Ошибка: Некорректный ввод." -ForegroundColor Red
    } while ($true)
}

# Логика скрипта построена на машине состояний.
# Переменная $Step определяет текущий экран.
# Это позволяет легко реализовать кнопки "Назад" ($Step--) и повтор шагов.
# --- ОСНОВНОЙ ЦИКЛ ---

$Step = 1

while ($true) {
    try {
        switch ($Step) {
            
            # ==========================================
            # ШАГ 1: ВЫБОР ИСТОЧНИКА
            # ==========================================
            1 {
                # Сброс состояния при возврате в начало
                $GlobalState.Source = $null
                Show-Header "Шаг 1: Выбор источника прошивки" 1
                Write-Host " 1. OpenWrt (Официальная, стабильная)"
                Write-Host " 2. ImmortalWrt (Больше пакетов, оптимизации)"
                $sel = Read-Selection -MaxCount 2 -AllowBack $false
                if ($sel -eq 1) {
                    $GlobalState.Source  = "OpenWrt"
                    $GlobalState.BaseUrl = "https://downloads.openwrt.org"
                    $GlobalState.RepoUrl = "https://github.com/openwrt/openwrt.git"
                } else {
                    $GlobalState.Source  = "ImmortalWrt"
                    $GlobalState.BaseUrl = "https://downloads.immortalwrt.org"
                    $GlobalState.RepoUrl = "https://github.com/immortalwrt/immortalwrt.git"
                }
                $GlobalState.LastStep = 1; $Step++ 
            }

            # ==========================================
            # ШАГ 2: ВЫБОР РЕЛИЗА
            # ==========================================
            2 {
                $GlobalState.Release = $null
                Show-Header "Шаг 2: Выбор релиза ($($GlobalState.Source))" 2
                Write-Host "Получение списка..."
                $url = "$($GlobalState.BaseUrl)/releases/"
                $html = (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
                # Regex парсит ссылки вида "23.05.0/" или "snapshots/"
                $releases = @([regex]::Matches($html, 'href="(\d{2}\.\d{2}\.[^"/]+/|snapshots/)"') | 
                            ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | 
                            Select-Object -Unique | Sort-Object -Descending)
                for ($i=0; $i -lt $releases.Count; $i++) { Write-Host (" {0,2}. {1}" -f ($i+1), $releases[$i]) }
                $idx = Read-Selection -MaxCount $releases.Count
                if ($idx -eq -1) { $Step--; continue }
                $GlobalState.Release = $releases[($idx-1)]
                $GlobalState.LastStep = 2; $Step++
            }

            # ==========================================
            # ШАГ 3: ВЫБОР АРХИТЕКТУРЫ (TARGET)
            # ==========================================
            3 {
                $GlobalState.Target = $null
                Show-Header "Шаг 3: Выбор Target" 3
                $rel = $GlobalState.Release
                $baseUrl = $GlobalState.BaseUrl
                # Формируем URL в зависимости от того, релиз это или снапшот
                $targetUrl = if ($rel -eq "snapshots") { "$baseUrl/snapshots/targets/" } else { "$baseUrl/releases/$rel/targets/" }
                $html = (Invoke-WebRequest -Uri $targetUrl -UseBasicParsing).Content
                # Исключаем служебные папки (backups, kmodindex)
                $targets = @([regex]::Matches($html, 'href="([^"\./ ]+/)"') | 
                        ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | 
                        Where-Object { $_ -notin @('backups', 'kmodindex') })
                for ($i=0; $i -lt $targets.Count; $i++) { Write-Host (" {0,2}. {1}" -f ($i+1), $targets[$i]) }
                $idx = Read-Selection -MaxCount $targets.Count
                if ($idx -eq -1) { $Step--; continue }
                $GlobalState.Target = $targets[($idx-1)]
                $GlobalState.LastStep = 3; $Step++
            }

            # ==========================================
            # ШАГ 4: ВЫБОР ПОД-АРХИТЕКТУРЫ (SUBTARGET)
            # ==========================================
            4 {
                $GlobalState.Subtarget = $null
                $rel = $GlobalState.Release; $baseUrl = $GlobalState.BaseUrl; $tar = $GlobalState.Target
                $baseTargetUrl = if ($rel -eq "snapshots") { "$baseUrl/snapshots/targets/$tar/" } else { "$baseUrl/releases/$rel/targets/$tar/" }
                $GlobalState.CurrentTargetUrl = $baseTargetUrl
                $html = (Invoke-WebRequest -Uri $baseTargetUrl -UseBasicParsing).Content
                $subtargets = @([regex]::Matches($html, 'href="([^"\./ ]+/)"') | 
                            ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | 
                            Where-Object { $_ -notin @('backups', 'kmodindex', 'packages') })

                # АВТОМАТИЗАЦИЯ: Если папка одна (часто generic), пропускаем выбор
                if ($subtargets.Count -le 1) {
                    # АВТО-ПЕРЕХОД
                    if ($GlobalState.LastStep -eq 5) { $Step--; continue } # Если шли назад с 5-го, прыгаем на 3-й
                    $GlobalState.Subtarget = if ($subtargets.Count -eq 1) { $subtargets[0] } else { "generic" }
                    $GlobalState.LastStep = 4; $Step++ 
                    continue
                } else {
                    Show-Header "Шаг 4: Выбор Subtarget" 4
                    for ($i=0; $i -lt $subtargets.Count; $i++) { Write-Host (" {0,2}. {1}" -f ($i+1), $subtargets[$i]) }
                    $idx = Read-Selection -MaxCount $subtargets.Count
                    if ($idx -eq -1) { $Step--; continue }
                    $GlobalState.Subtarget = $subtargets[($idx-1)]
                    $GlobalState.LastStep = 4; $Step++
                }
            }

            # ==========================================
            # ШАГ 5: ВЫБОР МОДЕЛИ И АНАЛИЗ ПАКЕТОВ
            # ==========================================
            5 {
                $GlobalState.ModelID = $null; $GlobalState.ModelName = $null
                Show-Header "Шаг 5: Выбор модели устройства" 5
                $finalUrl = "$($GlobalState.CurrentTargetUrl)$($GlobalState.Subtarget)/"
                $GlobalState.FinalUrl = $finalUrl
                try {
                    $data = Invoke-RestMethod -Uri "$($finalUrl)profiles.json"
                } catch {
                    Write-Host "Ошибка загрузки profiles.json." -ForegroundColor Red; Start-Sleep 2; $Step--; continue
                }
                # Получаем список ID профилей и их названий
                $profileIds = @($data.profiles.PSObject.Properties.Name | Sort-Object)
                $profileList = @()
                for ($i=0; $i -lt $profileIds.Count; $i++) {
                    $id = $profileIds[$i]; $title = $data.profiles.$id.title
                    Write-Host (" {0,3}. {1} ({2})" -f ($i+1), $title, $id)
                    $profileList += [PSCustomObject]@{ ID = $id; Title = $title }
                }
                $idx = Read-Selection -MaxCount $profileList.Count
                if ($idx -eq -1) { $GlobalState.LastStep = 5; $Step--; continue }
                $selectedProfile = $profileList[($idx-1)]
                $GlobalState.ModelID = $selectedProfile.ID
                $GlobalState.ModelName = $selectedProfile.Title
                
                # Анализ пакетов
                $basePackages = @($data.default_packages); $devicePackages = @($data.profiles.$($selectedProfile.ID).device_packages)
                $pkgsToRemove = @(); $pkgsToAdd = @()
                foreach ($pkg in $devicePackages) {
                    $p = [string]$pkg
                    if ($p.StartsWith("-")) { $pkgsToRemove += $p.Substring(1) } else { $pkgsToAdd += $p }
                }
                # 3. Фильтруем базовый список и добавляем специфичные пакеты
                $finalList = $basePackages | Where-Object { $_ -notin $pkgsToRemove }
                $finalList += $pkgsToAdd
                # 4. Сохраняем чистый список (строкой)
                $GlobalState.DefPkgs = ($finalList | Select-Object -Unique | Sort-Object) -join " "
                $GlobalState.LastStep = 5; $Step++
            }

            # ==========================================
            # ШАГ 6: ГЕНЕРАЦИЯ КОНФИГА
            # ==========================================
            6 {
                # 1. Поиск ImageBuilder
                Show-Header "Шаг 6: Финализация" 6
                $folderHtml = (Invoke-WebRequest -Uri $GlobalState.FinalUrl -UseBasicParsing).Content
                if ($folderHtml -match 'href="((openwrt|immortalwrt)-imagebuilder-[^"]+\.tar\.(xz|zst))"') {
                    # --- ВЫБОР ЗЕРКАЛА (ТОЛЬКО ДЛЯ IMMORTALWRT) ---
                    $ibFileName = $Matches[1]; $currentUrl = "$($GlobalState.FinalUrl)$ibFileName"
                    if ($GlobalState.Source -eq "ImmortalWrt") {
                        Write-Host "Выберите источник загрузки IB:`n 1. Official`n 2. KyaruCloud (CDN)" -ForegroundColor Yellow
                        $mirrorSel = Read-Host "`nВаш выбор (1-2) [Default: 2]"
                        $GlobalState.IBUrl = if ($mirrorSel -eq '1') { $currentUrl } else { $currentUrl.Replace("https://downloads.immortalwrt.org", "https://immortalwrt.kyarucloud.moe") }
                    } else { $GlobalState.IBUrl = $currentUrl }
                } else {
                    Write-Host "ОШИБКА: ImageBuilder не найден!" -ForegroundColor Red; Read-Host; $Step--; continue
                }

                # 2. Отображение пакетов
                # ---------------------------------------------------------
                Write-Host "Пакеты по умолчанию:`n$($GlobalState.DefPkgs)`n" -ForegroundColor Gray
                $inputPkgs = Read-Host "Дополнительные пакеты [luci] (Z - Назад)"
                if ($inputPkgs.ToLower() -eq 'z') { $GlobalState.LastStep = 6; $Step--; continue }
                $pkgs = if ([string]::IsNullOrWhiteSpace($inputPkgs)) { "luci" } else { $inputPkgs }

                # 3. Имя файла (Системная генерация + Защита)
                # ---------------------------------------------------------
                $verClean = ($GlobalState.Release -replace '\.', '') -replace 'snapshots', 'snap'
                $srcShort = if ($GlobalState.Source -eq 'ImmortalWrt') { 'iw' } else { 'ow' }
                $modClean = $GlobalState.ModelID -replace '-', '_'
                $defaultName = "${modClean}_${verClean}_${srcShort}_full"

                $profileName = $null
                do {
                    Write-Host "`nВведите имя файла конфига (без .conf)" -ForegroundColor Gray
                    $inputName = Read-Host "Имя файла [$defaultName] (Z - Назад)"
                    
                    # Навигация
                    if ($inputName.ToLower() -eq 'z') { $GlobalState.LastStep = 6; $Step--; continue 2 }
                    if ($inputName.ToLower() -eq 'q') { exit }

                    # Логика выбора и нормализации
                    if ([string]::IsNullOrWhiteSpace($inputName)) { 
                        $profileName = $defaultName
                    } else {
                        # Форматирование: только мелкие буквы, цифры и подчеркивания
                        $cleanName = $inputName.Trim().ToLower() -replace '[\s\-\.]+', '_'
                        $cleanName = $cleanName -replace '[^a-z0-9_]', ''
                        
                        if ([string]::IsNullOrWhiteSpace($cleanName)) {
                            Write-Host "Ошибка: некорректное имя." -ForegroundColor Red
                            continue
                        }
                        $profileName = $cleanName
                        if ($inputName -ne $profileName) {
                            Write-Host "  -> Автокоррекция: $profileName" -ForegroundColor Cyan
                        }
                    }

                    # Проверка на существование
                    if (Test-Path "profiles\$profileName.conf") {
                        Write-Host " [!] Файл '$profileName.conf' уже существует!" -ForegroundColor Yellow
                        $ovr = Read-Host " Перезаписать? (y/n) [n]"
                        if ($ovr.Trim().ToLower() -ne 'y') { continue }
                    }
                    break 
                } while ($true)

                # 4. Сохранение
                # ---------------------------------------------------------
                $confPath = "profiles\$profileName.conf"
                $gitBranch = if ($GlobalState.Release -eq "snapshots") { "master" } else { "v$($GlobalState.Release)" }
                
                # Твой расширенный шаблон контента
                $content = @"
# === Profile for $($GlobalState.ModelID) ($($GlobalState.Source) $($GlobalState.Release)) ===

PROFILE_NAME="$profileName"
TARGET_PROFILE="$($GlobalState.ModelID)"

# Пакеты по умолчанию (Target Default +/- Device Specific)
DEFAULT_PACKAGES="$($GlobalState.DefPkgs)"

# Ваши дополнительные пакеты
COMMON_LIST="$pkgs"

# === IMAGE BUILDER CONFIG
IMAGEBUILDER_URL="$($GlobalState.IBUrl)"
PKGS="`$DEFAULT_PACKAGES `$COMMON_LIST"
EXTRA_IMAGE_NAME="custom"
#CUSTOM_KEYS="https://fantastic-packages.github.io/releases/24.10/53ff2b6672243d28.pub"
#CUSTOM_REPOS="src/gz fantastic_luci https://fantastic-packages.github.io/releases/24.10/packages/mipsel_24kc/luci
#src/gz fantastic_packages https://fantastic-packages.github.io/releases/24.10/packages/mipsel_24kc/packages
#src/gz fantastic_special https://fantastic-packages.github.io/releases/24.10/packages/mipsel_24kc/special"
#DISABLED_SERVICES="transmission-daemon minidlna"

# === SOURCE BUILDER CONFIG
SRC_REPO="$($GlobalState.RepoUrl)"
SRC_BRANCH="$gitBranch"
SRC_TARGET="$($GlobalState.Target)"
SRC_SUBTARGET="$($GlobalState.Subtarget)"
SRC_PACKAGES="`$PKGS"
SRC_CORES="safe"

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
                $content | Out-File -FilePath $confPath -Encoding utf8 -Force
                Write-Host "`n[OK] Конфиг успешно сохранен: $confPath" -ForegroundColor Green
                
                Write-Host "`nНажмите Enter для создания нового профиля или 'Q' для выхода..."
                $finalAction = Read-Host
                if ($finalAction -eq 'q') { exit }
                $Step = 1
            } # <-- Закрывает Шаг 6
        } # <-- Закрывает Switch
    } catch {
        Write-Host "`nКРИТИЧЕСКАЯ ОШИБКА: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Нажмите Enter для повтора..."
    }
} # <-- Закрывает While