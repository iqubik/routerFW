# Скрипт преобразования .ipk в "бинарные исходники" для OpenWrt
$ipkDir = "custom_packages"
$outDir = "src_packages"
$tempDir = "system\.ipk_temp"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " IMPORTING CUSTOM IPK PACKAGES" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if (-not (Test-Path $ipkDir)) { 
    Write-Host "[!] Папка $ipkDir не найдена." -ForegroundColor Yellow
    exit 
}

$ipkFiles = Get-ChildItem -Path "$ipkDir\*.ipk"

if ($ipkFiles.Count -eq 0) {
    Write-Host "[!] В папке $ipkDir нет .ipk файлов." -ForegroundColor Yellow
    exit
}

if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

foreach ($ipk in $ipkFiles) {
    Write-Host "`n[+] Обработка: $($ipk.Name)..." -ForegroundColor Cyan
    
    # 1. Очистка временной папки
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
    $null = New-Item -ItemType Directory -Path "$tempDir\unpack" -Force

    # 2. Распаковка IPK
    tar -xf "$ipkDir\$($ipk.Name)" -C "$tempDir\unpack"

    # 3. Распаковка control.tar.gz
    $null = New-Item -ItemType Directory -Path "$tempDir\control_data" -Force
    tar -xf "$tempDir\unpack\control.tar.gz" -C "$tempDir\control_data"

    # 4. Парсинг control
    $pkgName = ""
    $pkgDeps = ""
    $controlContent = Get-Content "$tempDir\control_data\control"
    foreach($line in $controlContent) {
        if ($line -match "^Package: (.*)") { $pkgName = $matches[1].Trim() }
        if ($line -match "^Depends: (.*)") { $pkgDeps = $matches[1].Trim() -replace ",", " " }
    }
    
    if (-not $pkgName) {
        Write-Host "    [!] Не удалось определить имя пакета. Пропуск." -ForegroundColor Red
        continue
    }

    Write-Host "    Пакет: $pkgName"
    Write-Host "    Зависимости: $pkgDeps"

    # 5. Создание структуры
    $targetPkgDir = "$outDir\$pkgName"
    if (Test-Path $targetPkgDir) { Remove-Item -Recurse -Force $targetPkgDir }
    $null = New-Item -ItemType Directory -Path "$targetPkgDir\files" -Force

    # 6. Распаковка данных
    tar -xf "$tempDir\unpack\data.tar.gz" -C "$targetPkgDir\files"

    # 7. Генерируем Makefile через оператор форматирования (-f)
    # Используем одинарные кавычки @' ... '@ - в них PS ничего не раскрывает.
    # {0} и {1} - это заглушки для $pkgName и $pkgDeps
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
	$(CP) ./files/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	# Nothing to compile
endef

define Package/$(PKG_NAME)/install
	$(CP) $(PKG_BUILD_DIR)/* $(1)/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
'@

    # Заполняем шаблон данными
    $makefileContent = $template -f $pkgName, $pkgDeps

    # Сохраняем файл с принудительными Unix-окончаниями строк (LF)
    # Это критично для сборки в Docker/Linux
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $finalContent = $makefileContent -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText("$targetPkgDir\Makefile", $finalContent, $utf8NoBom)
    
    Write-Host "    [OK] Пакет создан в $targetPkgDir" -ForegroundColor Green
}

if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
Write-Host "`n[DONE] Все пакеты успешно импортированы в $outDir!" -ForegroundColor Green