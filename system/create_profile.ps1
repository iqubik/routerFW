<#
.SYNOPSIS
    OpenWrt/ImmortalWrt Universal Profile Creator.
    file: system\create_profile.ps1
.VERSION
    2.3 (arch fix)
.DESCRIPTION
    Скрипт-мастер (Wizard) для создания конфигурационных файлов профилей сборки.
    Поддерживает:
    - Выбор между OpenWrt и ImmortalWrt.
    - Парсинг HTML-директорий релизов и таргетов.
    - Чтение JSON-профилей устройств (profiles.json).
    - Умный анализ пакетов (Target Default + Device Specific).
    - Навигацию (Назад/Выход) через машину состояний.
    - UX 2.0: Автозаполнение (Luci), системные имена файлов и защита от перезаписи.
    Fully synchronized with Bash version.
    - Handles new profiles.json structure (titles array).
    - Robust State Machine.
#>

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- БЛОК ЛОКАЛИЗАЦИИ ---
$FORCE_LANG = "AUTO" # Варианты: AUTO, RU, EN
$ru_score = 0
try {
    $uiLang = Get-ItemProperty "HKCU:\Control Panel\Desktop" -Name PreferredUILanguages -ErrorAction SilentlyContinue
    if ($uiLang.PreferredUILanguages -match "ru-RU") { $ru_score += 3 }
    $insLang = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\Language" -Name InstallLanguage -ErrorAction SilentlyContinue
    if ($insLang.InstallLanguage -eq "0419") { $ru_score += 2 }
    $cultureName = (Get-Culture).Name
    $userLangs = (Get-WinUserLanguageList).LanguageTag
    if ($cultureName -match "ru" -or $userLangs -match "ru") { $ru_score += 4 }
} catch {}
if ([console]::OutputEncoding.CodePage -eq 866) { $ru_score += 1 }
$DetectedLang = if ($ru_score -ge 5) { "RU" } else { "EN" }
# Логика приоритета: FORCE_LANG > env:SYS_LANG > Detected
if ($FORCE_LANG -ne "AUTO") {
    $Lang = $FORCE_LANG
} elseif ($env:SYS_LANG) {
    $Lang = $env:SYS_LANG
} else {
    $Lang = $DetectedLang
}

# --- СЛОВАРЬ (DICTIONARY) ---
$L = @{}
if ($Lang -eq "RU") {
    $L.HeaderTitle    = "UNIVERSAL Profile Creator (v2.28 UX++)"
    $L.StructureLabel = "СТРУКТУРА ТИПОВОГО ИМЕНИ ПРОШИВКИ:"
    $L.PathLabel      = "ПУТЬ: "
    $L.PromptSelect   = "Выберите номер"
    $L.PromptBack     = "Назад"
    $L.PromptExit     = "Выход"
    $L.ErrInput       = "Ошибка: Некорректный ввод."
    $L.Step1_Title    = "Шаг 1: Выбор источника прошивки"
    $L.Step1_OW       = "OpenWrt (Официальная, стабильная)"
    $L.Step1_IW       = "ImmortalWrt (Больше пакетов, оптимизации)"
    $L.Step2_Title    = "Шаг 2: Выбор релиза"
    $L.Step2_Fetch    = "Получение списка..."
    $L.Step3_Title    = "Шаг 3: Выбор Target"
    $L.Step4_Title    = "Шаг 4: Выбор Subtarget"
    $L.Step5_Title    = "Шаг 5: Выбор модели устройства"
    $L.Step5_Err      = "Ошибка загрузки profiles.json."
    $L.Step6_Title    = "Шаг 6: Финализация"
    $L.Step6_ErrIB    = "ОШИБКА: ImageBuilder не найден!"
    $L.Step6_Mirror   = "Выберите источник загрузки IB:"
    $L.Step6_DefPkgs  = "Пакеты по умолчанию:"
    $L.Step6_AddPkgs  = "Дополнительные пакеты [luci] (Z - Назад)"
    $L.Step6_FileName = "Введите имя файла конфига (без .conf)"
    $L.Step6_Exists   = "[!] Файл уже существует!"
    $L.Step6_Overwrite= "Перезаписать? (y/n) [n]"
    $L.Step6_Saved    = "Конфиг успешно сохранен:"
    $L.FinalAction    = "Нажмите Enter для создания нового профиля или 'Q' для выхода..."
} else {
    $L.HeaderTitle    = "UNIVERSAL Profile Creator (v2.28 UX+)"
    $L.StructureLabel = "TYPICAL FIRMWARE FILENAME STRUCTURE:"
    $L.PathLabel      = "PATH: "
    $L.PromptSelect   = "Select number"
    $L.PromptBack     = "Back"
    $L.PromptExit     = "Exit"
    $L.ErrInput       = "Error: Invalid input."
    $L.Step1_Title    = "Step 1: Firmware Source Selection"
    $L.Step1_OW       = "OpenWrt (Official, stable)"
    $L.Step1_IW       = "ImmortalWrt (More packages, optimized)"
    $L.Step2_Title    = "Step 2: Release Selection"
    $L.Step2_Fetch    = "Fetching list..."
    $L.Step3_Title    = "Step 3: Target Selection"
    $L.Step4_Title    = "Step 4: Subtarget Selection"
    $L.Step5_Title    = "Step 5: Device Model Selection"
    $L.Step5_Err      = "Error loading profiles.json."
    $L.Step6_Title    = "Step 6: Finalization"
    $L.Step6_ErrIB    = "ERROR: ImageBuilder not found!"
    $L.Step6_Mirror   = "Select IB download source:"
    $L.Step6_DefPkgs  = "Default packages:"
    $L.Step6_AddPkgs  = "Additional packages [luci] (Z - Back)"
    $L.Step6_FileName = "Enter config filename (without .conf)"
    $L.Step6_Exists   = "[!] File already exists!"
    $L.Step6_Overwrite= "Overwrite? (y/n) [n]"
    $L.Step6_Saved    = "Config successfully saved:"
    $L.FinalAction    = "Press Enter for new profile or 'Q' to exit..."
}

# --- INIT ---
$ProfilesDir = Join-Path (Split-Path -Parent $PSScriptRoot) "profiles"
# Создаем рабочую папку для профилей, если её нет
if (-not (Test-Path $ProfilesDir)) { New-Item -ItemType Directory -Path $ProfilesDir | Out-Null }

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
    Write-Host "  $($L.HeaderTitle) [$Lang]" -ForegroundColor Cyan
    Write-Host "  $StepName" -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Cyan
    
    # --- ВИЗУАЛИЗАЦИЯ ИМЕНИ ФАЙЛА ---
    Write-Host "  $($L.StructureLabel)" -ForegroundColor Gray
    Write-Host "  " -NoNewline
    # Функция-помощник для покраски сегментов
    
    function Out-Part {
        param($Value, $Default, $PartStep)
        $display = if ($Value) { $Value.ToLower() } else { $Default }
        if ($StepNum -eq $PartStep) { Write-Host "[$display]" -NoNewline -ForegroundColor Magenta }
        elseif ($Value) { Write-Host $display -NoNewline -ForegroundColor Green }
        else { Write-Host $display -NoNewline -ForegroundColor DarkGray }
    }

    # Собираем структуру: source-target-subtarget-model-suffix
    Out-Part $GlobalState.Source "source" 1; Write-Host "-" -NoNewline -ForegroundColor DarkGray
    Out-Part $GlobalState.Target "target" 3; Write-Host "-" -NoNewline -ForegroundColor DarkGray
    Out-Part $GlobalState.Subtarget "subtarget" 4; Write-Host "-" -NoNewline -ForegroundColor DarkGray
    Out-Part $GlobalState.ModelID "model" 5; Write-Host "-squashfs-sysupgrade.bin" -ForegroundColor DarkGray    

    # --- ХЛЕБНЫЕ КРОШКИ ---
    $crumbs = @()
    if ($GlobalState.Source)    { $crumbs += $GlobalState.Source }
    if ($GlobalState.Release)   { $crumbs += $GlobalState.Release }
    if ($GlobalState.Target)    { $crumbs += $GlobalState.Target }
    if ($GlobalState.Subtarget) { $crumbs += $GlobalState.Subtarget }
    if ($GlobalState.ModelName) { $crumbs += $GlobalState.ModelName }
    
    # 2. Выводим разноцветную строку
    if ($crumbs.Count -gt 0) {
        Write-Host "  $($L.PathLabel)" -NoNewline -ForegroundColor Gray
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
        $prompt = "`n$($L.PromptSelect) (1-$MaxCount)"
        if ($AllowBack) { $prompt += ", [Z] $($L.PromptBack)" }
        $prompt += ", [Q] $($L.PromptExit): "
        $inputVal = Read-Host $prompt
        # Игнорируем пустой ввод
        if ([string]::IsNullOrWhiteSpace($inputVal)) { continue }
        $val = $inputVal.Trim().ToLower()
        # Обработка выхода
        if ($val -eq 'q') { exit }
        if ($AllowBack -and $val -eq 'z') { return -1 } 
        # Валидация числа
        if ($val -match '^\d+$') {
            $idx = [int]$val
            if ($idx -ge 1 -and $idx -le $MaxCount) { return $idx }
        }
        Write-Host "$($L.ErrInput)" -ForegroundColor Red
    } while ($true)
}

# Логика скрипта построена на машине состояний.
# Переменная $Step определяет текущий экран.
# --- ОСНОВНОЙ ЦИКЛ ---
$Step = 1
:MainLoop while ($true) {
    try {
        switch ($Step) {
            # ШАГ 1: ВЫБОР ИСТОЧНИКА
            1 {
                # Сброс состояния при возврате в начало
                $GlobalState.Source = $null
                Show-Header "$($L.Step1_Title)" 1
                Write-Host " 1. $($L.Step1_OW)"
                Write-Host " 2. $($L.Step1_IW)"
                $sel = Read-Selection -MaxCount 2 -AllowBack $false
                if ($sel -eq 1) {
                    $GlobalState.Source = "OpenWrt"
                    $GlobalState.BaseUrl = "https://downloads.openwrt.org"
                    $GlobalState.RepoUrl = "https://github.com/openwrt/openwrt.git"
                } else {
                    $GlobalState.Source = "ImmortalWrt"
                    $GlobalState.BaseUrl = "https://downloads.immortalwrt.org"
                    $GlobalState.RepoUrl = "https://github.com/immortalwrt/immortalwrt.git"
                }
                $GlobalState.LastStep = 1; $Step++ 
            }

            # ШАГ 2: ВЫБОР РЕЛИЗА
            2 {
                $GlobalState.Release = $null
                Show-Header "$($L.Step2_Title) ($($GlobalState.Source))" 2
                Write-Host "$($L.Step2_Fetch)"
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

            # ШАГ 3: ВЫБОР АРХИТЕКТУРЫ (TARGET)
            3 {
                $GlobalState.Target = $null
                Show-Header "$($L.Step3_Title)" 3
                $rel = $GlobalState.Release
                $baseUrl = $GlobalState.BaseUrl
                # Формируем URL в зависимости от того, релиз это или снапшот
                $targetUrl = if ($rel -eq "snapshots") { "$baseUrl/snapshots/targets/" } else { "$baseUrl/releases/$rel/targets/" }
                $html = (Invoke-WebRequest -Uri $targetUrl -UseBasicParsing).Content
                # Исключаем служебные папки (backups, kmodindex)
                $targets = @([regex]::Matches($html, 'href="([^"\./ ]+/)"') | 
                        ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | 
                        Where-Object { $_ -notin @('backups', 'kmodindex', 'parent') })
                for ($i=0; $i -lt $targets.Count; $i++) { Write-Host (" {0,2}. {1}" -f ($i+1), $targets[$i]) }
                $idx = Read-Selection -MaxCount $targets.Count
                if ($idx -eq -1) { $Step--; continue }
                $GlobalState.Target = $targets[($idx-1)]
                $GlobalState.LastStep = 3; $Step++
            }

            # ШАГ 4: ВЫБОР ПОД-АРХИТЕКТУРЫ (SUBTARGET)
            4 {
                $GlobalState.Subtarget = $null
                $rel = $GlobalState.Release; $baseUrl = $GlobalState.BaseUrl; $tar = $GlobalState.Target
                $baseTargetUrl = if ($rel -eq "snapshots") { "$baseUrl/snapshots/targets/$tar/" } else { "$baseUrl/releases/$rel/targets/$tar/" }
                $GlobalState.CurrentTargetUrl = $baseTargetUrl
                $html = (Invoke-WebRequest -Uri $baseTargetUrl -UseBasicParsing).Content
                $subtargets = @([regex]::Matches($html, 'href="([^"\./ ]+/)"') | 
                            ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | 
                            Where-Object { $_ -notin @('backups', 'kmodindex', 'packages', 'parent') })

                # АВТОМАТИЗАЦИЯ: Если папка одна (часто generic), пропускаем выбор
                if ($subtargets.Count -le 1) {
                    # АВТО-ПЕРЕХОД
                    if ($GlobalState.LastStep -eq 5) { $Step--; continue } # Если шли назад с 5-го, прыгаем на 3-й
                    $GlobalState.Subtarget = if ($subtargets.Count -eq 1) { $subtargets[0] } else { "generic" }
                    $GlobalState.LastStep = 4; $Step++ 
                    continue
                } else {
                    Show-Header "$($L.Step4_Title)" 4
                    for ($i=0; $i -lt $subtargets.Count; $i++) { Write-Host (" {0,2}. {1}" -f ($i+1), $subtargets[$i]) }
                    $idx = Read-Selection -MaxCount $subtargets.Count
                    if ($idx -eq -1) { $Step--; continue }
                    $GlobalState.Subtarget = $subtargets[($idx-1)]
                    $GlobalState.LastStep = 4; $Step++
                }
            }

            # ШАГ 5: ВЫБОР МОДЕЛИ И АНАЛИЗ ПАКЕТОВ
            5 {
                $GlobalState.ModelID = $null; $GlobalState.ModelName = $null
                Show-Header "$($L.Step5_Title)" 5
                $finalUrl = "$($GlobalState.CurrentTargetUrl)$($GlobalState.Subtarget)/"
                $GlobalState.FinalUrl = $finalUrl
                try {
                    $data = Invoke-RestMethod -Uri "$($finalUrl)profiles.json"
                } catch {
                    Write-Host "$($L.Step5_Err)" -ForegroundColor Red; Start-Sleep 2; $Step--; continue
                }
                # Получаем список ID профилей и их названий
                $profileIds = @($data.profiles.PSObject.Properties.Name | Sort-Object)
                $profileList = @()
                for ($i=0; $i -lt $profileIds.Count; $i++) {
                    $id = $profileIds[$i]
                    $pObj = $data.profiles.$id
                    # Prioritize 'titles' array, fallback to 'title' string, fallback to ID
                    $title = if ($pObj.titles) { $pObj.titles[0].title } else { $pObj.title }
                    if (-not $title) { $title = $id }

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

            # --- ШАГ 6: ФИНАЛИЗАЦИЯ И ГЕНЕРАЦИЯ ---
            6 {
                Show-Header "$($L.Step6_Title)" 6
                
                # 1. Поиск ImageBuilder
                $folderHtml = (Invoke-WebRequest -Uri $GlobalState.FinalUrl -UseBasicParsing).Content
                if ($folderHtml -match 'href="((openwrt|immortalwrt)-imagebuilder-[^"]+\.tar\.(xz|zst))"') {
                    $ibFileName = $Matches[1]; $currentUrl = "$($GlobalState.FinalUrl)$ibFileName"
                    if ($GlobalState.Source -eq "ImmortalWrt") {
                        Write-Host "$($L.Step6_Mirror)`n 1. Official`n 2. KyaruCloud (CDN)" -ForegroundColor Yellow
                        $mirrorSel = Read-Host "`n$($L.PromptSelect) (1-2) [Default: 2]"
                        $GlobalState.IBUrl = if ($mirrorSel -eq '1') { $currentUrl } else { $currentUrl.Replace("https://downloads.immortalwrt.org", "https://immortalwrt.kyarucloud.moe") }
                    } else { $GlobalState.IBUrl = $currentUrl }
                } else {
                    Write-Host "$($L.Step6_ErrIB)" -ForegroundColor Red; Read-Host; $Step--; continue
                }

                # 2. Обработка пакетов (Объединяем всё в один COMMON_LIST как в образце)
                Write-Host "$($L.Step6_DefPkgs)`n$($GlobalState.DefPkgs)`n" -ForegroundColor Gray
                $inputPkgs = Read-Host "$($L.Step6_AddPkgs)"
                if ($inputPkgs.ToLower() -eq 'z') { $GlobalState.LastStep = 6; $Step--; continue }
                
                $extraPkgs = if ([string]::IsNullOrWhiteSpace($inputPkgs)) { "luci" } else { $inputPkgs }
                # Собираем базу + ввод пользователя в одну строку без дубликатов
                $finalCommonList = ("$($GlobalState.DefPkgs) $extraPkgs" -split "\s+" | Where-Object { $_ } | Select-Object -Unique | Sort-Object) -join " "

                # 3. ПОЛНЫЙ МАППИНГ АРХИТЕКТУРЫ (Без сокращений)
                $arch = switch -Wildcard ($GlobalState.Target) {
                    'ramips'   { 'mipsel_24kc' }
                    'ath79'    { 'mips_24kc' }
                    'ar71xx'   { 'mips_24kc' }
                    'lantiq'   { 'mips_24kc' }
                    'realtek'  { 'mips_24kc' }
                    'x86'      { if ($GlobalState.Subtarget -eq '64') { 'x86_64' } else { 'i386_pentium4' } }
                    'mediatek' { 
                        if ($GlobalState.Subtarget -match 'mt798|mt7622|filogic') { 'aarch64_cortex-a53' } 
                        elseif ($GlobalState.Subtarget -eq 'mt7623') { 'arm_cortex-a7_neon-vfpv4' } 
                        else { 'mipsel_24kc' } 
                    }
                    'mvebu'    { 
                        if ($GlobalState.Subtarget -eq 'cortexa72') { 'aarch64_cortex-a72' } 
                        else { 'arm_cortex-a9_vfpv3-d16' } 
                    }
                    'ipq40xx'  { 'arm_cortex-a7_neon-vfpv4' }
                    'ipq806x'  { 'arm_cortex-a15_neon-vfpv4' }
                    'rockchip' { 'aarch64_generic' }
                    'bcm27xx'  { 
                        if ($GlobalState.Subtarget -eq 'bcm2711') { 'aarch64_cortex-a72' } 
                        elseif ($GlobalState.Subtarget -eq 'bcm2710') { 'aarch64_cortex-a53' } 
                        else { 'arm_arm1176jzf-s_vfp' } 
                    }
                    'sunxi'    { 'arm_cortex-a7_neon-vfpv4' }
                    'layerscape' { if ($GlobalState.Subtarget -eq '64b') { 'aarch64_generic' } else { 'arm_cortex-a7_neon-vfpv4' } }
                    '*64*'     { 'aarch64_generic' }
                    default    { '' }
                }

                # 4. Формирование имени файла (Полное, как вы просили)
                $verClean = ($GlobalState.Release -replace '\.', '') -replace 'snapshots', 'snap'
                $srcShort = if ($GlobalState.Source -eq 'ImmortalWrt') { 'iw' } else { 'ow' }
                $modClean = $GlobalState.ModelID -replace '-', '_'
                $defaultName = "${modClean}_${verClean}_${srcShort}_full"

                $profileName = $null
                do {
                    # Навигация
                    Write-Host "`n$($L.Step6_FileName) [$defaultName]: " -NoNewline -ForegroundColor Gray
                    $inputName = Read-Host
                    # continue MainLoop выбрасывает нас из do-while и из switch сразу к началу :MainLoop
                    if ($inputName.ToLower() -eq 'z') { $GlobalState.LastStep = 6; $Step--; continue MainLoop }
                    # Логика выбора и нормализации
                        # Форматирование: только мелкие буквы, цифры и подчеркивания
                    
                    $profileName = if ([string]::IsNullOrWhiteSpace($inputName)) { $defaultName } else { 
                        $inputName.Trim().ToLower() -replace '[\s\-\.]+', '_' -replace '[^a-z0-9_]', ''
                    }

                    # Проверка на существование
                    if (Test-Path (Join-Path $ProfilesDir "$profileName.conf")) {
                        Write-Host " $($L.Step6_Exists)" -ForegroundColor Yellow
                        $ovr = Read-Host " $($L.Step6_Overwrite)"
                        if ($ovr.Trim().ToLower() -ne 'y') { continue }
                    }
                    break 
                } while ($true)

                # 5. СОХРАНЕНИЕ (СТРУКТУРА ПО ВАШЕМУ ОБРАЗЦУ)
                $confPath = Join-Path $ProfilesDir "$profileName.conf"
                $gitBranch = if ($GlobalState.Release -eq "snapshots") { "master" } else { "v$($GlobalState.Release)" }
                
                $content = @"
# === Profile for $($GlobalState.ModelID) ($($GlobalState.Source) $($GlobalState.Release)) ===

PROFILE_NAME="$profileName"
TARGET_PROFILE="$($GlobalState.ModelID)"

COMMON_LIST="$finalCommonList"

# === IMAGE BUILDER CONFIG
IMAGEBUILDER_URL="$($GlobalState.IBUrl)"
#CUSTOM_KEYS="https://fantastic-packages.github.io/releases/24.10/53ff2b6672243d28.pub"
#CUSTOM_REPOS="src/gz fantastic_luci https://fantastic-packages.github.io/releases/24.10/packages/mipsel_24kc/luci
#src/gz fantastic_packages https://fantastic-packages.github.io/releases/24.10/packages/mipsel_24kc/packages
#src/gz fantastic_special https://fantastic-packages.github.io/releases/24.10/packages/mipsel_24kc/special"
#DISABLED_SERVICES="transmission-daemon minidlna"
PKGS="`$COMMON_LIST"
#EXTRA_IMAGE_NAME="custom"

# === Extra config options
#ROOTFS_SIZE="512"
#KERNEL_SIZE="64"

# === SOURCE BUILDER CONFIG
SRC_REPO="$($GlobalState.RepoUrl)"
SRC_BRANCH="$gitBranch"
SRC_TARGET="$($GlobalState.Target)"
SRC_SUBTARGET="$($GlobalState.Subtarget)"
SRC_ARCH="$arch"
SRC_PACKAGES="`$PKGS"
SRC_CORES="safe"

## SPACE SAVING (For 4MB / 8MB flash devices)
#    - CONFIG_LUCI_SRCDIET=y      -> Compresses Lua/JS in LuCI (saves ~100-200KB)
#    - CONFIG_IPV6=n              -> Completely removes IPv6 support (saves ~300KB)
#    - CONFIG_KERNEL_DEBUG_INFO=n -> Removes debugging information from the kernel
#    - CONFIG_STRIP_KERNEL_EXPORTS=y -> Strips kernel export symbols (if no external kmods needed)
## FILE SYSTEMS (For SD cards / x86 / NanoPi)
#    By default, SquashFS (Read-Only) is created. EXT4 is recommended for SBCs.
#    - CONFIG_TARGET_ROOTFS_SQUASHFS=n -> Disable SquashFS
#    - CONFIG_TARGET_ROOTFS_EXT4FS=y   -> Enable EXT4 (Read/Write partition)
#    - CONFIG_TARGET_ROOTFS_TARGZ=y    -> Create an archive (for containers/backups)
## DEBUGGING AND LOGS
#    - CONFIG_KERNEL_PRINTK=n     -> Disables boot log output to console (quiet boot)
#    - CONFIG_BUILD_LOG=y         -> Saves build logs for each package (to debug build errors)
## FORCED MODULE INCLUSION
#    If a package fails to install via SRC_PACKAGES, you can force-enable it here.
# CONFIG_PACKAGE_kmod-usb-net-rndis=y

SRC_EXTRA_CONFIG=''

"@
                [System.IO.File]::WriteAllText($confPath, $content, (New-Object System.Text.UTF8Encoding($false)))
                Write-Host "`n[OK] $($L.Step6_Saved) $confPath" -ForegroundColor Green
                
                Write-Host "`n$($L.FinalAction)"
                if ((Read-Host).ToLower() -eq 'q') { exit }
                $Step = 1
            } # <-- Закрывает Шаг 6
        } # <-- Закрывает Switch
    } catch {
        Write-Host "`nFATAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to retry..."
    }
} # <-- Закрывает While