# Скрипт импорта IPK v2.1 (Architecture Visibility Mode)
$ipkDir = "custom_packages"
$outDir = "src_packages"
$tempDir = "system\.ipk_temp"
$overwriteAll = $false

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " IMPORTING CUSTOM IPK PACKAGES v0.9" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if (-not (Test-Path $ipkDir)) { Write-Host "[!] Folder $ipkDir not found." -ForegroundColor Yellow; exit }
$ipkFiles = Get-ChildItem -Path "$ipkDir\*.ipk"
if ($ipkFiles.Count -eq 0) { Write-Host "[!] No .ipk files found." -ForegroundColor Yellow; exit }
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

foreach ($ipk in $ipkFiles) {
    Write-Host "`n[+] Processing: $($ipk.Name)..." -ForegroundColor Cyan
    
    # 1. Распаковка метаданных
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue }
    $null = New-Item -ItemType Directory -Path "$tempDir\unpack" -Force
    # 2. Распаковка IPK
    tar -xf "$ipkDir\$($ipk.Name)" -C "$tempDir\unpack"
    # 3. Распаковка control.tar.gz
    $null = New-Item -ItemType Directory -Path "$tempDir\control_data" -Force
    tar -xf "$tempDir\unpack\control.tar.gz" -C "$tempDir\control_data"

    # 2. Парсинг данных
    $pkgName = ""; $pkgDeps = ""; $pkgArch = ""; $postinst = ""
    $controlContent = Get-Content "$tempDir\control_data\control"
    foreach($line in $controlContent) {
        if ($line -match "^Package: (.*)") { $pkgName = $matches[1].Trim() }
        if ($line -match "^Architecture: (.*)") { $pkgArch = $matches[1].Trim() }
        if ($line -match "^Depends: (.*)") { 
            $depsList = ($line -split ":")[1].Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "libc" -and $_ -ne "" }
            if ($depsList) { $pkgDeps = "+" + ($depsList -join " +") }
        }
    }

    if (-not $pkgName) { Write-Host "    [!] Failed to parse Package name. Skipping." -ForegroundColor Red; continue }

    # Вывод информации об архитектуре
    if ($pkgArch -eq "all") {
        Write-Host "    Package: $pkgName (Arch: all)" -ForegroundColor Green
    } else {
        Write-Host "    Package: $pkgName (Arch: $pkgArch)" -ForegroundColor Yellow
    }

    # Читаем postinst и экранируем символ $ для Makefile
    if (Test-Path "$tempDir\control_data\postinst") {
        $postinst = Get-Content "$tempDir\control_data\postinst" -Raw
        $postinst = $postinst -replace '\$', '$$$$'
    }

    # 3. Логика перезаписи
    $targetPkgDir = "$outDir\$pkgName"
    if (Test-Path $targetPkgDir) {
        if (-not $overwriteAll) {
            Write-Host "    [?] Package already exists." -ForegroundColor Gray
            $choice = Read-Host "    Overwrite? [Y]es / [N]o / [A]ll"
            if ($choice -eq 'A' -or $choice -eq 'a') { $overwriteAll = $true }
            elseif ($choice -ne 'Y' -and $choice -ne 'y') { continue }
        }
    }

    # 4. Подготовка структуры и копирование
    if (Test-Path $targetPkgDir) { Remove-Item -Recurse -Force $targetPkgDir }
    $null = New-Item -ItemType Directory -Path $targetPkgDir -Force
    # ВАЖНО: Просто копируем сжатый архив data.tar.gz (сохраняем симлинки внутри него)
    Copy-Item "$tempDir\unpack\data.tar.gz" -Destination "$targetPkgDir\data.tar.gz"

    # 4. Генерация умного Makefile
    $template = @'
include $(TOPDIR)/rules.mk

PKG_NAME:={0}
PKG_VERSION:=binary
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

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
    $makefileContent = $template -f $pkgName, $pkgDeps, $postinst
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $finalContent = $makefileContent -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText("$targetPkgDir\Makefile", $finalContent, $utf8NoBom)
    
    Write-Host "    [OK] Successfully imported." -ForegroundColor Green
}

if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue }
Write-Host "`n[DONE] Подготовка IPK с интеграции в SourceBuild завершена." -ForegroundColor Red
Write-Host "[WARN] Проверьте соответствие архитектуры (Arch: $pkgArch) пакетов вашему устройству перед запуском компиляции!" -ForegroundColor Red
Write-Host "`n" -ForegroundColor Red