# file : system/import_ipk.ps1
# Скрипт импорта IPK (APK support)

param (
    [Parameter(Mandatory=$false)]
    [string]$ProfileID = "",
    [Parameter(Mandatory=$false)]
    [string]$TargetArch = ""  # Подхватывается из батника (SRC_ARCH)
)

$ScriptVersion = "2.9"

# --- ИНИЦИАЛИЗАЦИЯ ПУТЕЙ ---
if ($ProfileID -ne "") {
    $ipkDir = "custom_packages\$ProfileID"
    $outDir = "src_packages\$ProfileID"
} else {
    $ipkDir = "custom_packages"
    $outDir = "src_packages"
}

$tempDir = "system\.ipk_temp"
$overwriteAll = $false
$importedCount = 0

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  IPK IMPORT WIZARD v$ScriptVersion [$TargetArch][Source Mode]" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "[CONTEXT] " -NoNewline -ForegroundColor Cyan
Write-Host "Profile: " -NoNewline -ForegroundColor Gray
$ProfileDisplay = if ($ProfileID) { $ProfileID } else { "GLOBAL" }
Write-Host "$ProfileDisplay" -ForegroundColor White

Write-Host " [TARGET]  " -NoNewline -ForegroundColor Cyan
Write-Host "Arch   : " -NoNewline -ForegroundColor Gray
if ($TargetArch) { 
    Write-Host "$TargetArch" -ForegroundColor Green 
} else { 
    Write-Host "NOT DEFINED (Validation Disabled)" -ForegroundColor Red 
}

Write-Host " [PATHS]   " -NoNewline -ForegroundColor Cyan
Write-Host "Source : " -NoNewline -ForegroundColor Gray
Write-Host "$ipkDir" -ForegroundColor Gray
Write-Host "           Output : " -NoNewline -ForegroundColor Gray
Write-Host "$outDir" -ForegroundColor Gray
Write-Host "           Temp   : " -NoNewline -ForegroundColor Gray
Write-Host "$tempDir" -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Cyan

# --- ПРОВЕРКИ ОКРУЖЕНИЯ ---
if (-not (Test-Path $ipkDir)) { Write-Host "[!] Folder $ipkDir not found." -ForegroundColor Yellow; exit }
$ipkFiles = Get-ChildItem -Path $ipkDir | Where-Object { $_.Extension -match '\.(ipk|apk)$' }
if ($ipkFiles.Count -eq 0) { Write-Host "[!] No .ipk or .apk files found in $ipkDir" -ForegroundColor Yellow; exit }
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

foreach ($ipk in $ipkFiles) {
    Write-Host "[+] Processing: $($ipk.Name)..." -ForegroundColor Cyan
    
    # 1. Подготовка папок
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue }
    $null = New-Item -ItemType Directory -Path "$tempDir\unpack" -Force
    $null = New-Item -ItemType Directory -Path "$tempDir\control_data" -Force
    
    $isApk = ($ipk.Extension -eq ".apk")
    $pkgName = ""; $pkgVersion = ""; $pkgDeps = ""; $pkgArch = ""; $postinst = ""; $depsList = @()

    if ($isApk) {
        # 2a. Распаковка APK v3 (через Docker/apk-tools)
        Write-Host "    [*] APK v3 detected. Using Docker 'apk adbdump'..." -ForegroundColor Cyan
        
        $apkFullPath = $ipk.FullName
        $apkParentDir = $ipk.DirectoryName
        $apkFileName = $ipk.Name
        
        try {
            # Выполняем docker-команду и ловим ее вывод
            $dockerCommand = "docker run --rm -v ""$apkParentDir`:/data"" alpine:latest apk adbdump /data/$apkFileName"
            $adbdumpOutput = Invoke-Expression $dockerCommand
            $adbdumpOutputString = $adbdumpOutput -join "`n"

            # Если команда не вернула вывод, считаем это ошибкой
            if (-not $adbdumpOutputString) { throw "Docker command returned no output." }

            # Regex для извлечения основных полей
            $pkgName = if ($adbdumpOutputString -match '(?m)^\s*name:\s*(.*)$') { $matches[1].Trim() } else { "" }
            $pkgVersion = if ($adbdumpOutputString -match '(?m)^\s*version:\s*(.*)$') { $matches[1].Trim() } else { "" }
            $pkgArch = if ($adbdumpOutputString -match '(?m)^\s*arch:\s*(.*)$') { $matches[1].Trim() } else { "" }

            # Regex для зависимостей (строгий, между 'depends:' и 'provides:')
            $depsBlockMatch = [regex]::Match($adbdumpOutputString, '(?ms)depends:(.*?)provides:')
            if ($depsBlockMatch.Success) {
                $depsBlock = $depsBlockMatch.Groups[1].Value
                $depsMatches = [regex]::Matches($depsBlock, '-\s+(.*)')
                if ($depsMatches) {
                    $depsList = $depsMatches.Value | ForEach-Object { $_.Substring(1).Trim() }
                }
            } else {
                $depsList = @()
            }

            # Regex для post-install скрипта
            $postinstMatch = [regex]::Match($adbdumpOutputString, '(?ms)post-install:\s*\|(.*?)(?=\n\w|$)')
            if ($postinstMatch.Success) {
                # Убираем отступы в 4 пробела с каждой строки
                $postinst = ($postinstMatch.Groups[1].Value -split '\n' | ForEach-Object { if ($_.Length -gt 4) { $_.Substring(4) } else { $_.TrimStart() } } | Out-String).Trim()
            } else {
                $postinst = ""
            }
            Write-Host "    [+] Metadata extracted successfully via Docker." -ForegroundColor Green

        } catch {
            Write-Host "    [!] Docker command failed. Error: $($_.Exception.Message.Split([Environment]::NewLine)[0])" -ForegroundColor Red
            $pkgName = $null # Позволяем сработать фоллбеку (старому методу)
        }

    } else {
        # 2b. Распаковка IPK
        tar -xf "$ipkDir\$($ipk.Name)" -C "$tempDir\unpack" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    [!] Failed to extract data from $($ipk.Name). The file might be corrupted." -ForegroundColor Red
            continue
        }
        
        if (Test-Path "$tempDir\unpack\control.tar.gz") {
            tar -xf "$tempDir\unpack\control.tar.gz" -C "$tempDir\control_data" 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "    [!] Failed to extract control.tar.gz from $($ipk.Name)." -ForegroundColor Red
                continue
            }
        }
        
        # 3. Парсинг файла control
        if (Test-Path "$tempDir\control_data\control") {
            $controlContent = Get-Content "$tempDir\control_data\control"
            foreach($line in $controlContent) {
                if ($line -match "^Package:\s*(.*)") { $pkgName = $matches[1].Trim() }
                if ($line -match "^Version:\s*(.*)") { $pkgVersion = $matches[1].Trim() }
                if ($line -match "^Architecture:\s*(.*)") { $pkgArch = $matches[1].Trim() }
                if ($line -match "^Depends:\s*(.*)") { 
                    $depsList += ($matches[1] -replace ",", " ") -split "\s+" | ForEach-Object { $_.Trim() }
                }
            }
        }
        if (Test-Path "$tempDir\control_data\postinst") { $postinst = Get-Content "$tempDir\control_data\postinst" -Raw }
    }

    # 4. Общая обработка зависимостей (Маппинг)
    if ($depsList) {
        $mappedDeps = $depsList | Where-Object { $_ -ne "libc" -and $_ -ne "" } | ForEach-Object {
            if ($_ -match "^(so|cmd|pc):") { $null } # Игнорируем виртуальные зависимости APK
            elseif ($_ -eq "libnetfilter-queue1") { "libnetfilter-queue" }
            elseif ($_ -eq "libnfnetlink0") { "libnfnetlink" }
            elseif ($_ -eq "libopenssl1.1") { "libopenssl" }
            else { $_ }
        } | Where-Object { $null -ne $_ }
        if ($mappedDeps) { $pkgDeps = "+" + ($mappedDeps -join " +") }
    }

    # --- 4.5 СМАРТ-ФОЛЛБЕК (Если Windows не смог прочитать APK) ---
    if (-not $pkgName) { 
        Write-Host "    [!] Warning: Windows failed to extract metadata (tar format limitation)." -ForegroundColor Yellow
        Write-Host "    [*] Activating Smart Filename Fallback..." -ForegroundColor Cyan
        
        # Пытаемся вытащить имя и версию из названия файла (например fastfetch-2.59.0-r1.apk)
        if ($ipk.Name -match "^(.*?)-v?(\d.*)\.(apk|ipk)$") {
            $pkgName = $matches[1].Trim()
            $pkgVersion = $matches[2].Trim()
        } else {
            # Если формат нестандартный, просто берем имя файла без расширения
            $pkgName = $ipk.BaseName.Trim()
            $pkgVersion = "binary"
        }
        
        # Обходим проверку архитектуры, так как мы ее не знаем (передаем ответственность на Linux)
        if ($TargetArch) { $pkgArch = $TargetArch } else { $pkgArch = "all" }
        
        Write-Host "    [+] Guessed Name: $pkgName | Ver: $pkgVersion" -ForegroundColor Green
    }
    if (-not $pkgVersion) { $pkgVersion = "binary" }

    # --- 5. УМНАЯ ВАЛИДАЦИЯ АРХИТЕКТУРЫ ---
    if ($pkgArch -eq "all") {
        Write-Host "    Architecture: all (Universal) - OK" -ForegroundColor Green
    } elseif ($TargetArch -ne "") {
        if ($pkgArch -eq $TargetArch) {
            Write-Host "    Architecture: $pkgArch (Match) - OK" -ForegroundColor Green
        } else {
            Write-Host "    ----------------------------------------------------------" -ForegroundColor Red
            Write-Host "    CRITICAL ERROR: ARCHITECTURE MISMATCH!" -ForegroundColor Red
            Write-Host "    Package: $pkgArch" -ForegroundColor Yellow
            Write-Host "    Profile: $TargetArch" -ForegroundColor White
            Write-Host "    ----------------------------------------------------------" -ForegroundColor Red
            Write-Host "    [SKIP] Import of $pkgName blocked to prevent bricking." -ForegroundColor Gray
            continue
        }
    } else {
        Write-Host "    Architecture: $pkgArch (Unchecked)" -ForegroundColor Yellow
        $confirm = Read-Host "    No arch in profile. Continue anyway? [Y/N]"
        if ($confirm -ne "Y" -and $confirm -ne "y") { continue }
    }

    # 6. Обработка Post-Install
    if ($postinst) {
        # Если в скрипте уже есть стандартный вызов, нам не нужно его дублировать
        if ($postinst -match "default_postinst") {
            $postinst = ""
        } else {
            # В противном случае, обрабатываем как кастомный скрипт
            # Убираем лишние шебанги (#!/bin/sh), если они есть
            $postinst = $postinst -replace '(?m)^#!/.+$', ''
            # Экранируем знак доллара для Makefile (превращаем $ в $$)
            $postinst = $postinst -replace '\$', '$$'
            # Убираем лишние пустые строки в начале и конце
            $postinst = $postinst.Trim()
        }
    }

    # 7. Логика перезаписи
    $targetPkgDir = "$outDir\$pkgName"
    if (Test-Path $targetPkgDir) {
        if (-not $overwriteAll) {
            Write-Host "    [?] Package '$pkgName' already exists." -ForegroundColor Gray
            $choice = Read-Host "    Overwrite? [Y]es / [N]o / [A]ll"
            if ($choice -eq 'A' -or $choice -eq 'a') { $overwriteAll = $true }
            elseif ($choice -ne 'Y' -and $choice -ne 'y') { continue }
        }
        Remove-Item -Recurse -Force $targetPkgDir
    }
    
    # 8. Финализация импорта
    $null = New-Item -ItemType Directory -Path $targetPkgDir -Force
    if ($isApk) {
        # Для APK просто копируем исходный файл (как payload)
        Copy-Item "$ipkDir\$($ipk.Name)" -Destination "$targetPkgDir\data.apk"
    } else {
        if (Test-Path "$tempDir\unpack\data.tar.gz") {
            Copy-Item "$tempDir\unpack\data.tar.gz" -Destination "$targetPkgDir\data.tar.gz"
        } else {
            Write-Host "    [!] Error: data.tar.gz not found!" -ForegroundColor Red; continue
        }
    }

    # --- 9. ГЕНЕРАЦИЯ УМНОГО MAKEFILE ---
    $template = @'
include $(TOPDIR)/rules.mk

PKG_NAME:={0}
PKG_VERSION:={3}
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk
# Запрещаем системе сборки изменять готовые бинарники (решает ошибки Strip/Patchelf)

STRIP:=:
PATCHELF:=:

define Package/$(PKG_NAME)
  SECTION:=utils
  CATEGORY:=Custom-Packages
  TITLE:=Binary wrapper for {0}
  DEPENDS:={1}
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	[ -f ./data.tar.gz ] && cp ./data.tar.gz $(PKG_BUILD_DIR)/ || true
	[ -f ./data.apk ] && cp ./data.apk $(PKG_BUILD_DIR)/ || true
endef

define Build/Compile
	# Nothing to compile
endef

define Package/$(PKG_NAME)/install
	mkdir -p $(1)
	# Распаковка внутри Linux сохраняет симлинки.
	if [ -f $(PKG_BUILD_DIR)/data.tar.gz ]; then \
		tar -xf $(PKG_BUILD_DIR)/data.tar.gz -C $(1); \
	elif [ -f $(PKG_BUILD_DIR)/data.apk ]; then \
		apk add --root $(1) --initdb --no-network --no-scripts --allow-untrusted $(PKG_BUILD_DIR)/data.apk; \
	fi
	# Принудительная правка прав для скриптов и бинарников
	[ -d $(1)/etc/init.d ] && chmod +x $(1)/etc/init.d/* || true
	[ -d $(1)/usr/bin ] && chmod +x $(1)/usr/bin/* || true
	[ -d $(1)/usr/sbin ] && chmod +x $(1)/usr/sbin/* || true
	[ -d $(1)/lib/upgrade/keep.d ] && chmod 644 $(1)/lib/upgrade/keep.d/* || true
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
# Проверка: если мы находимся в процессе сборки (INSTROOT), не запускаем сервисы
if [ -z "$$IPKG_INSTROOT" ]; then
[ "$$IPKG_NO_SCRIPT" = "1" ] && exit 0
[ -s "$$IPKG_INSTROOT/lib/functions.sh" ] || exit 0
. "$$IPKG_INSTROOT/lib/functions.sh"
default_postinst $$0 $$@
{2}
	:
fi
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
'@

    # Сохраняем файл с принудительными Unix-окончаниями строк (LF)
    $makefileContent = $template -f $pkgName, $pkgDeps, $postinst, $pkgVersion
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $finalContent = $makefileContent -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText("$targetPkgDir\Makefile", $finalContent, $utf8NoBom)    
    
    $importedCount++
    Write-Host "    [OK] Successfully imported.`n" -ForegroundColor Green
}

# Очистка
if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue }

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  DONE: $importedCount packages imported." -ForegroundColor Cyan
if ($ProfileID) { Write-Host "  Location: $outDir" -ForegroundColor Gray }
Write-Host "==========================================================`n"