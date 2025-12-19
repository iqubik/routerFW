# Скрипт для создания профилей OpenWrt
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 1. Создаем папку для профилей
if (-not (Test-Path "profiles")) { New-Item -ItemType Directory -Name "profiles" | Out-Null }

function Show-Header($Text) {
    Clear-Host
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host "  OpenWrt Profile Creator: $Text" -ForegroundColor Cyan
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host ""
}

try {
    # --- ШАГ 1: ВЫБОР РЕЛИЗА ---
    Show-Header "Выбор релиза"
    Write-Host "Получение списка релизов с downloads.openwrt.org..."
    $baseUrl = "https://downloads.openwrt.org/releases/"
    $html = (Invoke-WebRequest -Uri $baseUrl -UseBasicParsing).Content
    
    # Находим все ссылки вида 23.05.0 или snapshots
    $releases = [regex]::Matches($html, 'href="(\d{2}\.\d{2}\.[^"/]+/|snapshots/)"') | 
                ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | 
                Select-Object -Unique | Sort-Object -Descending

    if ($releases.Count -eq 0) { throw "Не удалось найти релизы. Проверьте интернет." }

    for ($i=0; $i -lt $releases.Count; $i++) {
        Write-Host (" {0,2}. {1}" -f ($i+1), $releases[$i])
    }
    $resIdx = Read-Host "`nВыберите номер релиза"
    $selectedRelease = $releases[($resIdx-1)]

    # --- ШАГ 2: ВЫБОР TARGET ---
    Show-Header "Выбор Target ($selectedRelease)"
    $targetUrl = "$baseUrl$selectedRelease/targets/"
    $html = (Invoke-WebRequest -Uri $targetUrl -UseBasicParsing).Content
    $targets = [regex]::Matches($html, 'href="([^"\./ ]+/)"') | 
               ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | 
               Where-Object { $_ -notin @('backups', 'kmodindex') }

    for ($i=0; $i -lt $targets.Count; $i++) {
        Write-Host (" {0,2}. {1}" -f ($i+1), $targets[$i])
    }
    $tarIdx = Read-Host "`nВыберите номер Target"
    $selectedTarget = $targets[($tarIdx-1)]

    # --- ШАГ 3: ВЫБОР SUBTARGET ---
    Show-Header "Выбор Subtarget"
    $subUrl = "$targetUrl$selectedTarget/"
    $html = (Invoke-WebRequest -Uri $subUrl -UseBasicParsing).Content
    $subtargets = [regex]::Matches($html, 'href="([^"\./ ]+/)"') | 
                  ForEach-Object { $_.Groups[1].Value.TrimEnd('/') } | 
                  Where-Object { $_ -notin @('backups', 'kmodindex', 'packages') }

    if ($subtargets.Count -eq 0) {
        $selectedSubtarget = "generic"
    } elseif ($subtargets.Count -eq 1) {
        $selectedSubtarget = $subtargets[0]
    } else {
        for ($i=0; $i -lt $subtargets.Count; $i++) {
            Write-Host (" {0,2}. {1}" -f ($i+1), $subtargets[$i])
        }
        $subIdx = Read-Host "`nВыберите номер Subtarget"
        $selectedSubtarget = $subtargets[($subIdx-1)]
    }

    # --- ШАГ 4: ВЫБОР ПРОФИЛЯ ---
    Show-Header "Выбор модели устройства"
    Write-Host "Загрузка profiles.json..."
    $jsonUrl = "$baseUrl$selectedRelease/targets/$selectedTarget/$selectedSubtarget/profiles.json"
    $data = Invoke-RestMethod -Uri $jsonUrl
    
    $profileIds = $data.profiles.PSObject.Properties.Name | Sort-Object
    $profileList = @()
    
    for ($i=0; $i -lt $profileIds.Count; $i++) {
        $id = $profileIds[$i]
        $title = $data.profiles.$id.title
        Write-Host (" {0,3}. {1} ({2})" -f ($i+1), $title, $id)
        $profileList += [PSCustomObject]@{ ID = $id; Title = $title }
    }

    $profIdx = Read-Host "`nВыберите номер устройства"
    $selectedProfile = $profileList[($profIdx-1)].ID

    # --- ШАГ 5: ПАКЕТЫ И СОХРАНЕНИЕ ---
    Show-Header "Завершение"
    Write-Host "Выбрано: $selectedProfile"
    $pkgs = Read-Host "Введите список пакетов через пробел (или оставьте пустым)"
    $filename = Read-Host "Введите имя файла профиля (без .conf, по умолчанию: $selectedProfile)"
    if ([string]::IsNullOrWhiteSpace($filename)) { $filename = $selectedProfile }

    $confPath = "profiles\$filename.conf"
    $content = @"
PROFILE="$selectedProfile"
TARGET="$selectedTarget"
SUBTARGET="$selectedSubtarget"
PACKAGES="$pkgs"
RELEASE="$selectedRelease"
"@
    $content | Out-File -FilePath $confPath -Encoding ascii -Force
    
    Write-Host "`nГОТОВО! Файл создан: $confPath" -ForegroundColor Green
} catch {
    Write-Host "`nОШИБКА: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nНажмите любую клавишу, чтобы выйти..."
$null = [Console]::ReadKey($true)