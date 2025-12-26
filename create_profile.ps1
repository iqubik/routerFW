$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Создаем папку для профилей, если её нет
if (-not (Test-Path "profiles")) { New-Item -ItemType Directory -Name "profiles" | Out-Null }

function Show-Header($Text) {
    Clear-Host
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  OpenWrt Profile Creator (v0.93 iqubik)" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host ""
}

try {
    # --- ШАГ 1: ВЫБОР РЕЛИЗА ---
    Show-Header "Шаг 1: Выбор релиза"
    
    # Косметика: Ссылка на TOH
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
    # Косметика: подсказка по TARGET
    Write-Host "Не знаете TARGET своего роутера?" -ForegroundColor Gray
    Write-Host "Найдите его на странице роутера в графе HARDWARE - TARGET" -ForegroundColor Blue
    Write-Host "Или внутри ссылки на любую доступную прошивку" -ForegroundColor Red
    Write-Host "Пример: smartbox giga часть ссылки: -ramips-mt7621-beeline_smartbox-giga-" -ForegroundColor Blue
    Write-Host "Для  beeline  giga  внутри  ссылки: -ramips-****************************-" -ForegroundColor Red    
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
    # Косметика: подсказка по CPU
    Write-Host "Не знаете CPU своего роутера?" -ForegroundColor Gray
    Write-Host "Найдите его на странице роутера в графе HARDWARE - CPU" -ForegroundColor Blue
    Write-Host "Или внутри ссылки на любую доступную прошивку" -ForegroundColor Red
    Write-Host "Пример: smartbox giga часть ссылки: -ramips-mt7621-beeline_smartbox-giga-" -ForegroundColor Blue
    Write-Host "Для  beeline  giga  внутри  ссылки: -******-mt7621-*********************-" -ForegroundColor Red
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
    # Косметика: подсказка по Модели
    Write-Host "Не знаете точное название модели своего роутера?" -ForegroundColor Gray
    Write-Host "Найдите его на странице роутера внутри ссылки на любую доступную прошивку" -ForegroundColor Blue
    Write-Host "Пример: smartbox giga часть ссылки: -ramips-mt7621-beeline_smartbox-giga-" -ForegroundColor Blue
    Write-Host "Для  beeline  giga  внутри  ссылки: -******-******-beeline_smartbox-giga-" -ForegroundColor Red
    
    Write-Host "--------------------------------------------------------------------------`n"
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

    # --- ШАГ 6: СОХРАНЕНИЕ ---
    Show-Header "Шаг 6: Сохранение профиля"
    $pkgs = Read-Host "Введите пакеты (через пробел)"
    $profileName = Read-Host "Введите имя конфига (например: giga)"
    if ([string]::IsNullOrWhiteSpace($profileName)) { $profileName = "default" }

    $confPath = "profiles\$profileName.conf"
    
    $content = @"
PROFILE_NAME="$profileName"
TARGET_PROFILE="$targetProfile"
IMAGEBUILDER_URL="$ibUrl"
PKGS="$pkgs"
"@
    
    $content | Out-File -FilePath $confPath -Encoding ascii -Force
    
    Write-Host "`n[OK] Конфиг создан: $confPath" -ForegroundColor Green
    Write-Host "Запуск сборщика _Image_Builder.bat..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2

    # Запуск батника сборщика
    if (Test-Path "_Image_Builder.bat") {
        cmd.exe /c _Image_Builder.bat
    } else {
        Write-Host "`nПредупреждение: Файл _Image_Builder.bat не найден в текущей папке." -ForegroundColor Yellow
        Pause
    }

} catch {
    Write-Host "`nОШИБКА: $($_.Exception.Message)" -ForegroundColor Red
    Pause
}