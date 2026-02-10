# file : system/import_ipk.ps1
# Скрипт импорта IPK v2.61 (version ipk fix)
param (
    [Parameter(Mandatory=$false)]
    [string]$ProfileID = "",
    [Parameter(Mandatory=$false)]
    [string]$TargetArch = ""  # Подхватывается из батника (SRC_ARCH)
)

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
Write-Host "  IPK IMPORT WIZARD v2.6 [$TargetArch] [Source Mode]" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [CONTEXT] " -NoNewline -ForegroundColor Cyan
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
$ipkFiles = Get-ChildItem -Path "$ipkDir\*.ipk"
if ($ipkFiles.Count -eq 0) { Write-Host "[!] No .ipk files found in $ipkDir" -ForegroundColor Yellow; exit }
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

foreach ($ipk in $ipkFiles) {
    Write-Host "[+] Processing: $($ipk.Name)..." -ForegroundColor Cyan
    
    # 1. Распаковка метаданных
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue }
    $null = New-Item -ItemType Directory -Path "$tempDir\unpack" -Force
    
    # 2. Распаковка IPK (используем встроенный tar Windows)
    tar -xf "$ipkDir\$($ipk.Name)" -C "$tempDir\unpack"
    
    # 3. Распаковка control.tar.gz
    $null = New-Item -ItemType Directory -Path "$tempDir\control_data" -Force
    if (Test-Path "$tempDir\unpack\control.tar.gz") {
        tar -xf "$tempDir\unpack\control.tar.gz" -C "$tempDir\control_data"
    }

    # 4. Глубокий парсинг файла Control
    $pkgName = ""; $pkgVersion = ""; $pkgDeps = ""; $pkgArch = ""; $postinst = ""
    if (Test-Path "$tempDir\control_data\control") {
        $controlContent = Get-Content "$tempDir\control_data\control"
        foreach($line in $controlContent) {
            if ($line -match "^Package: (.*)") { $pkgName = $matches[1].Trim() }
            if ($line -match "^Version: (.*)") { $pkgVersion = $matches[1].Trim() }
            if ($line -match "^Architecture: (.*)") { $pkgArch = $matches[1].Trim() }
            if ($line -match "^Depends: (.*)") { 
                $depsRaw = ($line -split ":")[1].Trim() -replace ",", " "
                $depsList = $depsRaw -split "\s+" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "libc" -and $_ -ne "" }            
                
                # Маппинг зависимостей
                $depsList = $depsList | ForEach-Object {
                    if ($_ -eq "libnetfilter-queue1") { "libnetfilter-queue" }
                    elseif ($_ -eq "libnfnetlink0") { "libnfnetlink" }
                    elseif ($_ -eq "libopenssl1.1") { "libopenssl" }
                    else { $_ }
                }
                if ($depsList) { $pkgDeps = "+" + ($depsList -join " +") }
            }
        }
    }

    if (-not $pkgName) { Write-Host "    [!] Error: Could not parse package name. Skipping." -ForegroundColor Red; continue }
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
    if (Test-Path "$tempDir\control_data\postinst") {
        $postinst = Get-Content "$tempDir\control_data\postinst" -Raw        
        # Убираем лишние шебанги (#!/bin/sh), если они есть внутри импортируемого кода
        $postinst = $postinst -replace '(?m)^#!/.+$', ''        
        # Экранируем знак доллара для Makefile (превращаем $ в $$)
        $postinst = $postinst -replace '\$', '$$$$'         
        # Убираем лишние пустые строки в начале и конце
        $postinst = $postinst.Trim()
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
    if (Test-Path "$tempDir\unpack\data.tar.gz") {
        Copy-Item "$tempDir\unpack\data.tar.gz" -Destination "$targetPkgDir\data.tar.gz"
    } else {
        Write-Host "    [!] Error: data.tar.gz not found!" -ForegroundColor Red; continue
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
	cp ./data.tar.gz $(PKG_BUILD_DIR)/
endef

define Build/Compile
	# Nothing to compile
endef

define Package/$(PKG_NAME)/install
	mkdir -p $(1)
	# Распаковка внутри Linux сохраняет симлинки и структуру
	tar -xzf $(PKG_BUILD_DIR)/data.tar.gz -C $(1)
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
{2}
fi
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
'@

    # Сохраняем файл с принудительными Unix-окончаниями строк (LF)
    # Это критично для сборки в Docker/Linux
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