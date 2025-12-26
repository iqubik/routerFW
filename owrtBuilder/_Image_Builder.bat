@echo off
setlocal enabledelayedexpansion
cls
chcp 65001 >nul

echo [INIT] Очистка неиспользуемых сетей Docker...
docker network prune --force
echo.

:: === 0. РАСПАКОВКА ВСТРОЕННЫХ ФАЙЛОВ ===
call :EXTRACT_RESOURCES

:: Запоминаем текущую папку
set "PROJECT_DIR=%CD%"

:: === 1. ИНИЦИАЛИЗАЦИЯ ПАПОК ===
call :CHECK_DIR "profiles"
call :CHECK_DIR "custom_packages"
call :CHECK_DIR "custom_files"
call :CHECK_DIR "firmware_output"

:: === 2. ПРОВЕРКА НАЛИЧИЯ ПРОФИЛЕЙ ===
if not exist "profiles\*.conf" (
    echo.
    echo [INIT] Папка 'profiles' пуста. Создаю пример профиля...
    call :CREATE_EXAMPLE_PROFILE
    echo [INFO] Файл 'profiles\example_841n.conf' создан.
)

:MENU
cls
echo ========================================
echo  OpenWrt Smart Builder v4.2 (iqubik)
echo ========================================
echo.
echo Обнаруженные профили:
echo.

set count=0
for %%f in (profiles\*.conf) do (
    set /a count+=1
    set "profile[!count!]=%%~nxf"
    set "p_id=%%~nf"
    
    :: Создаем папку профиля, если нет
    if not exist "custom_files\!p_id!" (
        mkdir "custom_files\!p_id!"
    )
    :: Вызываем безопасную функцию для создания скрипта прав
    call :CREATE_PERMS_SCRIPT "!p_id!"    
    echo    [!count!] %%~nxf
)

echo.
echo    [A] Собрать ВСЕ профили (Параллельно)
echo    [0] Выход
echo.
set /p choice="Выберите опцию: "

if /i "%choice%"=="0" exit /b
if /i "%choice%"=="A" goto BUILD_ALL

set /a num_choice=%choice% 2>nul
if "%num_choice%"=="0" if not "%choice%"=="0" goto INVALID
if %num_choice% gtr %count% goto INVALID
if %num_choice% lss 1 goto INVALID

:: === ОДИНОЧНАЯ СБОРКА ===
set "SELECTED_CONF=!profile[%choice%]!"
call :BUILD_ROUTINE "%SELECTED_CONF%"
echo Сборка завершена.
goto MENU

:BUILD_ALL
echo.
echo === ЗАПУСК ПАРАЛЛЕЛЬНОЙ СБОРКИ ===
echo Новые окна откроются автоматически...
echo.
for /L %%i in (1,1,%count%) do (
    set "CURRENT_CONF=!profile[%%i]!"
    call :BUILD_ROUTINE "!CURRENT_CONF!"
)
echo.
echo === ВСЕ ЗАДАЧИ ЗАПУЩЕНЫ ===
echo Не закрывайте это окно до завершения работы.
pause
goto MENU

:INVALID
echo Неверный выбор!
pause
goto MENU

:: =========================================================
::  ПОДПРОГРАММА СБОРКИ
:: =========================================================
:BUILD_ROUTINE
set "CONF_FILE=%~1"
set "PROFILE_ID=%~n1"

echo.
echo ----------------------------------------------------
echo [PROCESSING] Профиль: %CONF_FILE%
echo ----------------------------------------------------

set "URL_CLEAN="
for /f "usebackq tokens=2 delims==" %%a in (`type "profiles\%CONF_FILE%" ^| findstr "IMAGEBUILDER_URL"`) do (
    set "VAL=%%a"
    set "VAL=!VAL:"=!"
    for /f "tokens=* delims= " %%b in ("!VAL!") do set "URL_CLEAN=%%b"
)

if "%URL_CLEAN%"=="" (
    echo [ERROR] URL не найден в конфиге %CONF_FILE%!
    exit /b
)

set "IS_LEGACY="
echo "!URL_CLEAN!" | findstr /C:"/19." >nul && set IS_LEGACY=1
echo "!URL_CLEAN!" | findstr /C:"/18." >nul && set IS_LEGACY=1
echo "!URL_CLEAN!" | findstr /C:"/17." >nul && set IS_LEGACY=1

IF DEFINED IS_LEGACY (
    set "BUILDER_SERVICE=builder-oldwrt"
) ELSE (
    set "BUILDER_SERVICE=builder-openwrt"
)

if not exist "firmware_output\imagebuilder\%PROFILE_ID%" (
    mkdir "firmware_output\imagebuilder\%PROFILE_ID%"
)

echo [LAUNCH] Запуск окна для: %PROFILE_ID%...
echo [DEBUG] URL определен как: !URL_CLEAN!

START "Build: %PROFILE_ID%" /D "%PROJECT_DIR%" cmd /c "set SELECTED_CONF=%CONF_FILE%&& set HOST_FILES_DIR=./custom_files/%PROFILE_ID%&& set HOST_OUTPUT_DIR=./firmware_output/imagebuilder/%PROFILE_ID%&& docker-compose -p build_%PROFILE_ID% up --build --force-recreate --remove-orphans %BUILDER_SERVICE% & echo. & echo === WORK FINISHED === & pause"

exit /b

:: =========================================================
::  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
:: =========================================================

:EXTRACT_RESOURCES
for %%F in ("docker-compose.yaml" "dockerfile" "dockerfile.841n" "openssl.cnf") do (
    if not exist "%%~F" (
        echo [INIT] Извлечение %%~F...
        powershell -Command "$ext = '%%~F'; $content = Get-Content '%~f0'; $start = $false; $b64 = ''; foreach($line in $content){ if($line -match 'BEGIN_B64_ ' + $ext){ $start = $true; continue }; if($line -match 'END_B64_ ' + $ext){ $start = $false; break }; if($start){ $b64 += $line.Trim() } }; if($b64){ [IO.File]::WriteAllBytes($ext, [Convert]::FromBase64String($b64)) }"
    )
)
exit /b

:CHECK_DIR
if not exist "%~1" mkdir "%~1"
exit /b

:CREATE_EXAMPLE_PROFILE
if not exist "custom_files\example_841n" mkdir "custom_files\example_841n"
if not exist "custom_files\giga" mkdir "custom_files\giga"
if not exist "custom_files\nanopi-r5c" mkdir "custom_files\nanopi-r5c"
powershell -Command "$text = \"# === Example Profile for TL-WR841N v9 ===`nPROFILE_NAME=`\"example_841n`\"`nTARGET_PROFILE=`\"tl-wr841-v9`\"`nIMAGEBUILDER_URL=`\"https://downloads.openwrt.org/releases/19.07.9/targets/ar71xx/tiny/openwrt-imagebuilder-19.07.9-ar71xx-tiny.Linux-x86_64.tar.xz`\"`nPKGS=`\"luci-base luci-mod-admin-full luci-theme-bootstrap luci-i18n-base-ru luci-i18n-opkg-ru uhttpd luci-app-firewall libiwinfo-lua relayd luci-proto-relay iw rpcd-mod-rrdns opkg -luci -iw-full -luci-proto-ipv6 -luci-proto-ppp -ipv6 -kmod-ipv6 -ip6tables -kmod-ip6tables -odhcp6c -odhcpd-ipv6only -libip6tc -ppp -ppp-mod-pppoe -kmod-ppp -kmod-pppoe -kmod-pppox -kmod-slhc -kmod-lib-crc-ccitt -luci-app-ntpc -luci-i18n-ntpc-ru -ntpclient -libpthread -librt -uboot-envtools -kmod-nf-conntrack6 -kmod-usb-core -kmod-usb2`\"\"; [IO.File]::WriteAllText('profiles\example_841n.conf', $text)"
powershell -Command "$text = \"# === Example Profile for SmartBox Giga ===`nPROFILE_NAME=`\"giga`\"`nTARGET_PROFILE=`\"beeline_smartbox-giga`\"`nIMAGEBUILDER_URL=`\"https://mirror-03.infra.openwrt.org/releases/24.10.4/targets/ramips/mt7621/openwrt-imagebuilder-24.10.4-ramips-mt7621.Linux-x86_64.tar.zst`\"`nPKGS=`\"wpad-openssl coreutils bzip2 tar unzip gzip grep sed gawk shadow-utils bind-host knot-host drill e2fsprogs tcpdump fdisk cfdisk ca-certificates libustream-openssl kmod-mtd-rw ip-full vnstat batctl-full arp-scan arp-scan-database curl openssh-sftp-server mc htop screen wget-ssl iw-full iftop bash nano coreutils-ls block-mount kmod-usb3 kmod-usb2 kmod-usb-uhci kmod-usb-ohci kmod-usb-storage kmod-usb-storage-uas kmod-fs-ext4 kmod-fs-exfat kmod-fs-ntfs3 kmod-fs-vfat kmod-fs-netfs kmod-fs-ksmbd kmod-fs-smbfs-common luci luci-compat luci-proto-batman-adv luci-proto-vxlan luci-app-nlbwmon luci-app-firewall luci-app-commands luci-app-statistics luci-app-ttyd luci-app-attendedsysupgrade luci-app-wol luci-app-transmission luci-app-ksmbd luci-app-minidlna luci-app-adblock-fast luci-app-package-manager collectd-mod-ping luci-i18n-base-ru luci-i18n-commands-ru luci-i18n-firewall-ru luci-i18n-ksmbd-ru luci-i18n-minidlna-ru luci-i18n-statistics-ru luci-i18n-ttyd-ru luci-i18n-usteer-ru luci-i18n-wol-ru luci-i18n-attendedsysupgrade-ru luci-i18n-transmission-ru luci-i18n-adblock-fast-ru luci-i18n-filemanager-ru luci-i18n-package-manager-ru kmod-nls-utf8 opkg kmod-nls-cp1251 kmod-nls-cp866 -wpad-basic-mbedtls -iw -ca-bundle -libustream-mbedtls`\"\"; [IO.File]::WriteAllText('profiles\giga.conf', $text)"
powershell -Command "$text = \"# === Example Profile for nanopi-r5c ===`nPROFILE_NAME=`\"nanopi-r5c`\"`nTARGET_PROFILE=`\"friendlyarm_nanopi-r5c`\"`nIMAGEBUILDER_URL=`\"https://downloads.openwrt.org/releases/24.10.5/targets/rockchip/armv8/openwrt-imagebuilder-24.10.5-rockchip-armv8.Linux-x86_64.tar.zst`\"`nPKGS=`\"base-files blkid block-mount bmon ca-bundle ca-certificates collectd-mod-thermal -dnsmasq dnsmasq-full dropbear e2fsprogs ethtool-full fdisk firewall4 fstools htop hwclock i2c-tools iftop ip-full irqbalance kmod-ata-ahci-platform kmod-gpio-button-hotplug kmod-nft-offload kmod-r8125-rss kmod-sdhci kmod-tcp-bbr kmod-usb2 kmod-usb3 libc libgcc libustream-mbedtls logd lm-sensors lsblk luci luci-app-irqbalance luci-app-nlbwmon luci-app-statistics luci-app-upnp luci-i18n-base-ru luci-i18n-firewall-ru luci-i18n-irqbalance-ru luci-i18n-nlbwmon-ru luci-i18n-package-manager-ru luci-i18n-statistics-ru luci-i18n-ttyd-ru luci-i18n-upnp-ru miniupnpd-nftables mkf2fs mmc-utils mtd netifd nftables odhcp6c odhcpd-ipv6only openssl-util opkg parted partx-utils ppp ppp-mod-pppoe procd-ujail smartmontools uboot-envtools uci uclient-fetch urandom-seed urngd usbutils wget-ssl alwaysonline`\"`nROOTFS_SIZE=`\"512`\"`nKERNEL_SIZE=`\"64`\"`nEXTRA_IMAGE_NAME=`\"v2-stable`\"`nDISABLED_SERVICES=`\"transmission-daemon minidlna`\"`nCUSTOM_KEYS=`\"https://fantastic-packages.github.io/releases/24.10/53ff2b6672243d28.pub`\"`nCUSTOM_REPOS=`\"src/gz fantastic_luci https://fantastic-packages.github.io/releases/24.10/packages/aarch64_generic/luci`nsrc/gz fantastic_packages https://fantastic-packages.github.io/releases/24.10/packages/aarch64_generic/packages`nsrc/gz fantastic_special https://fantastic-packages.github.io/releases/24.10/packages/aarch64_generic/special`\"\"; [System.IO.Directory]::CreateDirectory('profiles'); [IO.File]::WriteAllText('profiles\nanopi-r5c.conf', $text)"
exit /b

:CREATE_PERMS_SCRIPT
set "P_ID=%~1"
set "PERM_FILE=custom_files\%P_ID%\etc\uci-defaults\99-permissions.sh"
if exist "%PERM_FILE%" exit /b
rem echo    [AUTO] Создание 99-permissions.sh для %P_ID%...
powershell -Command "[System.IO.Directory]::CreateDirectory('custom_files\%P_ID%\etc\uci-defaults')" >nul 2>&1
set "B64=IyEvYmluL3NoCiMgRml4IFNTSCBwZXJtaXNzaW9ucwpbIC1kIC9ldGMvZHJvcGJZYXIgXSAmJiBjaG1vZCA3MDAgL2V0Yy9kcm9wYmVhcgpbIC1mIC9ldGMvZHJvcGJZYXIvYXV0aG9yaXplZF9rZXlzIF0gJiYgY2htb2QgNjAwIC9ldGMvZHJvcGJZYXIvYXV0aG9yaXplZF9rZXlzCiMgRml4IFNoYWRvdwpbIC1mIC9ldGMvc2hhZG93IF0gJiYgY2htb2QgNjAwIC9ldGMvc2hhZG93CiMgRml4IHJvb3QgU1NIIGtleXMKWyAtZCAvcm9vdC8uc3NoIF0gJiYgY2htb2QgNzAwIC9yb290Ly5zc2gKWyAtZiAvcm9vdC8uc3NoL2lkX3JzYSBdICYmIGNobW9kIDYwMCAvcm9vdC8uc3NoL2lkX3JzYQpleGl0IDAK"
powershell -Command "[IO.File]::WriteAllBytes('%PERM_FILE%', [Convert]::FromBase64String('%B64%'))"
exit /b

:: СЕКЦИЯ ДЛЯ BASE64 КОДА (НЕ УДАЛЯТЬ ЭТИ МЕТКИ)
:: BEGIN_B64_ docker-compose.yaml
IyBmaWxlOiBzcmNCdWlsZGVyXGRvY2tlci1jb21wb3NlLXNyYy55YW1sIHYxLjAKc2VydmljZXM6CiAgYnVpbGRlci1zcmMtb3BlbndydDoKICAgIGJ1aWxkOgogICAgICBjb250ZXh0OiAuCiAgICAgIGRvY2tlcmZpbGU6IHNyYy5kb2NrZXJmaWxlCiAgICB1c2VyOiAicm9vdCIKICAgIGVudmlyb25tZW50OgogICAgICAtIENPTkZfRklMRT0ke1NFTEVDVEVEX0NPTkZ9CiAgICB2b2x1bWVzOgogICAgICAtIHNyYy13b3JrZGlyOi9ob21lL2J1aWxkL29wZW53cnQKICAgICAgLSBzcmMtZGwtY2FjaGU6L2hvbWUvYnVpbGQvb3BlbndydC9kbAogICAgICAtIC4vc3JjX3Byb2ZpbGVzOi9wcm9maWxlcwogICAgICAtIC4vY3VzdG9tX3BhY2thZ2VzOi9pbnB1dF9wYWNrYWdlcwogICAgICAtICR7SE9TVF9GSUxFU19ESVJ9Oi9vdmVybGF5X2ZpbGVzCiAgICAgIC0gJHtIT1NUX09VVFBVVF9ESVJ9Oi9vdXRwdXQKICAgICAgLSAuL29wZW5zc2wuY25mOi9vcGVuc3NsLmNuZgogICAgY29tbWFuZDogJnNyY19idWlsZF9zY3JpcHQgfAogICAgICAvYmluL2Jhc2ggLWMgIgogICAgICBzZXQgLWUKICAgICAgZWNobyAnW0lOSVRdIENoZWNraW5nIHZvbHVtZSBwZXJtaXNzaW9ucy4uLicKICAgICAgIyDQmNGB0L/QvtC70YzQt9GD0LXQvCAkJCguLi4pINGH0YLQvtCx0YsgZG9ja2VyLWNvbXBvc2Ug0L3QtSDQv9GL0YLQsNC70YHRjyDQuNC90YLQtdGA0L/RgNC10YLQuNGA0L7QstCw0YLRjCDQv9C10YDQtdC80LXQvdC90YPRjgogICAgICBpZiBbIFwiJCQoc3RhdCAtYyAnJVUnIC9ob21lL2J1aWxkL29wZW53cnQpXCIgIT0gXCJidWlsZFwiIF07IHRoZW4KICAgICAgICAgIGVjaG8gXCJbSU5JVF0gRmlyc3QgcnVuIGRldGVjdGVkOiBGaXhpbmcgb3duZXJzaGlwIG9mIHdvcmtkaXIuLi5cIgogICAgICAgICAgY2hvd24gLVIgYnVpbGQ6YnVpbGQgL2hvbWUvYnVpbGQvb3BlbndydAogICAgICBmaQogICAgICAKICAgICAgIyDQodC+0LfQtNCw0LXQvCDRgdC60YDQuNC/0YIg0YHQsdC+0YDQutC4INCy0L3Rg9GC0YDQuCDQutC+0L3RgtC10LnQvdC10YDQsAogICAgICBjYXQgPDwgJ0VPRicgPiAvdG1wL2J1aWxkX3NjcmlwdC5zaCAgICAgIAogICAgICBzZXQgLWUKICAgICAgZXhwb3J0IEhPTUU9L2hvbWUvYnVpbGQKICAgICAgUFJPRklMRV9JRD0kJChiYXNlbmFtZSBcIiQkQ09ORl9GSUxFXCIgLmNvbmYpCgogICAgICAjID09PSAwLiBTZXR1cCBFbnZpcm9ubWVudCA9PT0KICAgICAgaWYgWyAhIC1mIFwiL3Byb2ZpbGVzLyQkQ09ORl9GSUxFXCIgXTsgdGhlbgogICAgICAgIGVjaG8gXCJGQVRBTDogUHJvZmlsZSAvcHJvZmlsZXMvJCRDT05GX0ZJTEUgbm90IGZvdW5kIVwiCiAgICAgICAgZXhpdCAxCiAgICAgIGZpCiAgICAgIAogICAgICAjIEZpeCBDUkxGCiAgICAgIHRyIC1kICdcXHInIDwgXCIvcHJvZmlsZXMvJCRDT05GX0ZJTEVcIiA+IC90bXAvY2xlYW5fY29uZmlnLmVudgogICAgICBzb3VyY2UgL3RtcC9jbGVhbl9jb25maWcuZW52CiAgICAgIAogICAgICBlY2hvIFwiPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT1cIgogICAgICBlY2hvIFwiICAgT3BlbldydCBTT1VSQ0UgQnVpbGRlciBmb3IgJCRQUk9GSUxFX05BTUVcIgogICAgICBlY2hvIFwiPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT1cIgogICAgICAKICAgICAgU1RBUlRfVElNRT0kJChkYXRlICslcykKICAgICAgVElNRVNUQU1QPSQkKFRaPSdVVEMtMycgZGF0ZSArJWQlbSV5LSVIJU0lUykKICAgICAgCiAgICAgICMgPT09IDEuIEdJVCBTRVRVUCA9PT0KICAgICAgaWYgWyAhIC1kIFwiLmdpdFwiIF07IHRoZW4KICAgICAgICAgIGVjaG8gXCJbR0lUXSBJbml0aWFsaXppbmcgcmVwbyBpbiBub24tZW1wdHkgZGlyLi4uXCIKICAgICAgICAgICMg0KPQsdC40YDQsNC10Lwg0L3QsNC00L7QtdC00LvQuNCy0L7QtSDQv9GA0LXQtNGD0L/RgNC10LbQtNC10L3QuNC1INC+INCy0LXRgtC60LUgbWFzdGVyL21haW4KICAgICAgICAgIGdpdCBjb25maWcgLS1nbG9iYWwgaW5pdC5kZWZhdWx0QnJhbmNoIG1hc3RlcgogICAgICAgICAgZ2l0IGluaXQKICAgICAgICAgIGdpdCByZW1vdGUgYWRkIG9yaWdpbiBcIiQkU1JDX1JFUE9cIgogICAgICBmaQogICAgICAKICAgICAgZWNobyBcIltHSVRdIEZldGNoaW5nICQkU1JDX0JSQU5DSC4uLlwiCiAgICAgIGdpdCBmZXRjaCBvcmlnaW4gXCIkJFNSQ19CUkFOQ0hcIgogICAgICAKICAgICAgZWNobyBcIltHSVRdIENoZWNrb3V0L1Jlc2V0IHRvICQkU1JDX0JSQU5DSC4uLlwiICAgICAgCiAgICAgIGdpdCBjb25maWcgLS1nbG9iYWwgYWR2aWNlLmRldGFjaGVkSGVhZCBmYWxzZQogICAgICBnaXQgY2hlY2tvdXQgLWYgXCJGRVRDSF9IRUFEXCIKICAgICAgZ2l0IHJlc2V0IC0taGFyZCBcIkZFVENIX0hFQURcIgoKICAgICAgIyA9PT0gU1dJVENIIFRPIEdJVEhVQiBNSVJST1JTID09PSAgICAgIAogICAgICBpZiBbIC1mIGZlZWRzLmNvbmYuZGVmYXVsdCBdOyB0aGVuCiAgICAgICAgICBlY2hvIFwiW0ZJWF0gU3dpdGNoaW5nIGZlZWRzIHRvIEdpdEh1YiBtaXJyb3JzLi4uXCIKICAgICAgICAgIHNlZCAtaSAnc3xodHRwczovL2dpdC5vcGVud3J0Lm9yZy9mZWVkL3xodHRwczovL2dpdGh1Yi5jb20vb3BlbndydC98ZycgZmVlZHMuY29uZi5kZWZhdWx0CiAgICAgICAgICBzZWQgLWkgJ3N8aHR0cHM6Ly9naXQub3BlbndydC5vcmcvcHJvamVjdC98aHR0cHM6Ly9naXRodWIuY29tL29wZW53cnQvfGcnIGZlZWRzLmNvbmYuZGVmYXVsdAogICAgICBmaQoKICAgICAgIyA9PT0gMi4gRkVFRFMgPT09CiAgICAgIGVjaG8gXCJbRkVFRFNdIFVwZGF0aW5nIGFuZCBJbnN0YWxsaW5nIGZlZWRzLi4uXCIKICAgICAgLi9zY3JpcHRzL2ZlZWRzIHVwZGF0ZSAtYQogICAgICAuL3NjcmlwdHMvZmVlZHMgaW5zdGFsbCAtYQoKICAgICAgIyA9PT0gQ1VTVE9NIFNPVVJDRVMgPT09CiAgICAgICMg0JLQkNCW0J3Qnjog0KHRjtC00LAg0L3Rg9C20L3QviDQutC70LDRgdGC0Ywg0J/QkNCf0JrQmCDRgSDQuNGB0YXQvtC00L3QuNC60LDQvNC4IChNYWtlZmlsZSksINCwINC90LUgLmlwayDRhNCw0LnQu9GLIQogICAgICBpZiBbIC1kIFwiL2lucHV0X3BhY2thZ2VzXCIgXSAmJiBbIFwiJCQobHMgLUEgL2lucHV0X3BhY2thZ2VzKVwiIF07IHRoZW4KICAgICAgICAgIGVjaG8gXCJbUEtHXSBJbmplY3RpbmcgY3VzdG9tIHNvdXJjZXMgaW50byBwYWNrYWdlLyBkaXJlY3RvcnkuLi5cIgogICAgICAgICAgY3AgLXJmIC9pbnB1dF9wYWNrYWdlcy8qIHBhY2thZ2UvCiAgICAgIGZpCgogICAgICAjID09PSAzLiBDT05GSUdVUkFUSU9OID09PQogICAgICBlY2hvIFwiW0NPTkZJR10gR2VuZXJhdGluZyAuY29uZmlnLi4uXCIKICAgICAgcm0gLWYgLmNvbmZpZwogICAgICAKICAgICAgIyDQkdCw0LfQvtCy0LDRjyDQutC+0L3RhNC40LPRg9GA0LDRhtC40Y8gVGFyZ2V0CiAgICAgIGVjaG8gXCJDT05GSUdfVEFSR0VUXyQkU1JDX1RBUkdFVD15XCIgPj4gLmNvbmZpZwogICAgICBlY2hvIFwiQ09ORklHX1RBUkdFVF8kJHtTUkNfVEFSR0VUfV8kJHtTUkNfU1VCVEFSR0VUfT15XCIgPj4gLmNvbmZpZwogICAgICBlY2hvIFwiQ09ORklHX1RBUkdFVF8kJHtTUkNfVEFSR0VUfV8kJHtTUkNfU1VCVEFSR0VUfV9ERVZJQ0VfJCRTUkNfREVWSUNFPXlcIiA+PiAuY29uZmlnCiAgICAgIAogICAgICAjINCU0L7QsdCw0LLQu9GP0LXQvCDQv9C+0LvRjNC30L7QstCw0YLQtdC70YzRgdC60LjQtSDQv9Cw0LrQtdGC0Ysg0LjQtyBTUkNfUEFDS0FHRVMKICAgICAgZm9yIHBrZyBpbiAkJFNSQ19QQUNLQUdFUzsgZG8KICAgICAgICAgIGlmIFtbIFwiJCRwa2dcIiA9PSAtKiBdXTsgdGhlbgogICAgICAgICAgICAgIGNsZWFuX3BrZz1cIiQke3BrZyMtfVwiCiAgICAgICAgICAgICAgZWNobyBcIiMgQ09ORklHX1BBQ0tBR0VfJCRjbGVhbl9wa2cgaXMgbm90IHNldFwiID4+IC5jb25maWcKICAgICAgICAgIGVsc2UKICAgICAgICAgICAgICBlY2hvIFwiQ09ORklHX1BBQ0tBR0VfJCRwa2c9eVwiID4+IC5jb25maWcKICAgICAgICAgIGZpCiAgICAgIGRvbmUKICAgICAgCiAgICAgICMgQXBwbHkgTFVDSSBkZWZhdWx0ICjQtdGB0LvQuCDQv9C+0LvRjNC30L7QstCw0YLQtdC70Ywg0L3QtSDRg9C60LDQt9Cw0Lsg0LXQs9C+INGB0LDQvCkgICAgICAKICAgICAgaWYgISBncmVwIC1xIFwiQ09ORklHX1BBQ0tBR0VfbHVjaT15XCIgLmNvbmZpZzsgdGhlbgogICAgICAgICAgZWNobyBcIkNPTkZJR19QQUNLQUdFX2x1Y2k9eVwiID4+IC5jb25maWcKICAgICAgZmkKICAgICAgCiAgICAgICMgU2l6ZXMKICAgICAgaWYgWyAtbiBcIiQkU1JDX1JPT1RGU19TSVpFXCIgXTsgdGhlbgogICAgICAgIGVjaG8gXCJDT05GSUdfVEFSR0VUX1JPT1RGU19QQVJUU0laRT0kJFNSQ19ST09URlNfU0laRVwiID4+IC5jb25maWcKICAgICAgZmkKCiAgICAgIGlmIFsgLW4gXCIkJFNSQ19LRVJORUxfU0laRVwiIF07IHRoZW4KICAgICAgICBlY2hvIFwiQ09ORklHX1RBUkdFVF9LRVJORUxfUEFSVFNJWkU9JCRTUkNfS0VSTkVMX1NJWkVcIiA+PiAuY29uZmlnCiAgICAgIGZpCgogICAgICBlY2hvIFwiW0RFQlVHXSBTaG93aW5nIGdlbmVyYXRlZCBTRUVEIC5jb25maWc6XCIKICAgICAgZWNobyBcIi0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS1cIgogICAgICBjYXQgLmNvbmZpZwogICAgICBlY2hvIFwiLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLVwiCiAgICAgIG1ha2UgZGVmY29uZmlnCiAgICAgIAogICAgICAjID09PSA0LiBDVVNUT00gRklMRVMgPT09CiAgICAgIGlmIFsgLWQgXCIvb3ZlcmxheV9maWxlc1wiIF0gJiYgWyBcIiQkKGxzIC1BIC9vdmVybGF5X2ZpbGVzKVwiIF07IHRoZW4KICAgICAgICAgIGVjaG8gXCJbRklMRVNdIENvcHlpbmcgb3ZlcmxheSBmaWxlcy4uLlwiCiAgICAgICAgICBta2RpciAtcCBmaWxlcwogICAgICAgICAgY3AgLXIgL292ZXJsYXlfZmlsZXMvKiBmaWxlcy8KICAgICAgZmkKICAgICAgCiAgICAgICMgPT09IDUuIERPV05MT0FEID09PQogICAgICBlY2hvIFwiW0RPV05MT0FEXSBEb3dubG9hZGluZyBzb3VyY2VzIHRvIGNhY2hlLi4uXCIKICAgICAgbWtkaXIgLXAgZGwgICAgICAKICAgICAgbWFrZSBkb3dubG9hZCB8fCAoZWNobyBcIltFUlJPUl0gRG93bmxvYWQgZmFpbGVkISBSZXRyeWluZyB3aXRoIGxvZ2dpbmcuLi5cIiAmJiBtYWtlIGRvd25sb2FkIFY9cyAmJiBleGl0IDEpCiAgICAgIAogICAgICAjID09PSA2LiBCVUlMRCA9PT0KICAgICAgZWNobyBcIltCVUlMRF0gU3RhcnRpbmcgY29tcGlsYXRpb24gKEpvYnM6ICQkKG5wcm9jKSkuLi5cIiAgICAgIAogICAgICBtYWtlIC1qJCQobnByb2MpIHx8IChlY2hvIFwiW0VSUk9SXSBNdWx0aWNvcmUgYnVpbGQgZmFpbGVkLiBSZXRyeWluZyBzaW5nbGUgY29yZSBWPXMuLi5cIiAmJiBtYWtlIC1qMSBWPXMpCiAgICAgIAogICAgICAjID09PSA3LiBBUlRJRkFDVFMgPT09CiAgICAgIGVjaG8gXCJbU0FWRV0gU2F2aW5nIGFydGlmYWN0cy4uLlwiCiAgICAgIFRBUkdFVF9ESVI9XCIvb3V0cHV0LyQkVElNRVNUQU1QXCIKICAgICAgbWtkaXIgLXAgXCIkJFRBUkdFVF9ESVJcIgogICAgICAKICAgICAgIyDQmNGJ0LXQvCDRhNCw0LnQu9GLINCyIGJpbi90YXJnZXRzCiAgICAgIGZpbmQgYmluL3RhcmdldHMvJCRTUkNfVEFSR0VULyQkU1JDX1NVQlRBUkdFVCAtdHlwZSBmIC1ub3QgLXBhdGggXCIqL3BhY2thZ2VzLypcIiAtZXhlYyBjcCB7fSBcIiQkVEFSR0VUX0RJUi9cIiBcXDsKICAgICAgCiAgICAgICMg0KHQvtGF0YDQsNC90Y/QtdC8INC40YLQvtCz0L7QstGL0Lkg0LrQvtC90YTQuNCzINC00LvRjyDRgdC/0YDQsNCy0LrQuAogICAgICBjcCAuY29uZmlnIFwiJCRUQVJHRVRfRElSL2J1aWxkLmNvbmZpZ1wiCiAgICAgIAogICAgICBFTkRfVElNRT0kJChkYXRlICslcykKICAgICAgRUxBUFNFRD0kJCgoRU5EX1RJTUUgLSBTVEFSVF9USU1FKSkKICAgICAgCiAgICAgIGVjaG8gXCJcIgogICAgICBlY2hvIFwiPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09XCIKICAgICAgZWNobyBcIj09PSDQodCx0L7RgNC60LAgJCRQUk9GSUxFX05BTUUg0LfQsNCy0LXRgNGI0LXQvdCwINC30LAgJCR7RUxBUFNFRH3RgS5cIgogICAgICBlY2hvIFwiPT09INCe0LHRgNCw0LfRizogZmlybXdhcmVfb3V0cHV0L3NvdXJjZWJ1aWxkZXIvJCRQUk9GSUxFX0lELyQkVElNRVNUQU1QXCIKICAgICAgZWNobyBcIj09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PVwiCiAgICAgIEVPRgogICAgICAKICAgICAgY2htb2QgK3ggL3RtcC9idWlsZF9zY3JpcHQuc2gKICAgICAgY2hvd24gYnVpbGQ6YnVpbGQgL3RtcC9idWlsZF9zY3JpcHQuc2gKICAgICAgCiAgICAgIGVjaG8gJ1tFWEVDXSBTd2l0Y2hpbmcgdG8gdXNlciBidWlsZC4uLicKICAgICAgc3VkbyAtRSAtdSBidWlsZCBiYXNoIC90bXAvYnVpbGRfc2NyaXB0LnNoCiAgICAgICIKCiAgYnVpbGRlci1zcmMtb2xkd3J0OgogICAgYnVpbGQ6CiAgICAgIGNvbnRleHQ6IC4KICAgICAgZG9ja2VyZmlsZTogc3JjLmRvY2tlcmZpbGUubGVnYWN5CiAgICB1c2VyOiAicm9vdCIKICAgIGVudmlyb25tZW50OgogICAgICAtIENPTkZfRklMRT0ke1NFTEVDVEVEX0NPTkZ9CiAgICB2b2x1bWVzOgogICAgICAtIHNyYy13b3JrZGlyOi9ob21lL2J1aWxkL29wZW53cnQKICAgICAgLSBzcmMtZGwtY2FjaGU6L2hvbWUvYnVpbGQvb3BlbndydC9kbAogICAgICAtIC4vc3JjX3Byb2ZpbGVzOi9wcm9maWxlcwogICAgICAtIC4vY3VzdG9tX3BhY2thZ2VzOi9pbnB1dF9wYWNrYWdlcwogICAgICAtICR7SE9TVF9GSUxFU19ESVJ9Oi9vdmVybGF5X2ZpbGVzCiAgICAgIC0gJHtIT1NUX09VVFBVVF9ESVJ9Oi9vdXRwdXQKICAgICAgLSAuL29wZW5zc2wuY25mOi9vcGVuc3NsLmNuZgogICAgY29tbWFuZDogKnNyY19idWlsZF9zY3JpcHQKCnZvbHVtZXM6CiAgc3JjLWRsLWNhY2hlOgogIHNyYy13b3JrZGlyOgo=
:: END_B64_ docker-compose.yaml

:: BEGIN_B64_ dockerfile
IyBmaWxlIGRvY2tlcmZpbGUKRlJPTSB1YnVudHU6MjIuMDQKRU5WIERFQklBTl9GUk9OVEVORD1ub25pbnRlcmFjdGl2ZQpSVU4gYXB0LWdldCB1cGRhdGUgJiYgYXB0LWdldCBpbnN0YWxsIC15IFwKCWJ1aWxkLWVzc2VudGlhbCBnaXQgbGlibmN1cnNlczUtZGV2IHpsaWIxZy1kZXYgc3VidmVyc2lvbiBtZXJjdXJpYWwgYXV0b2NvbmYgbGlidG9vbCBsaWJzc2wtZGV2IGxpYmdsaWIyLjAtZGV2IGxpYmdtcC1kZXYgbGlibXBjLWRldiBsaWJtcGZyLWRldiB0ZXhpbmZvIGdhd2sgcHl0aG9uMy1kaXN0dXRpbHMgcHl0aG9uMy1zZXR1cHRvb2xzIHJzeW5jIHVuemlwIHdnZXQgZmlsZSB6c3RkIFwKCSYmIHJtIC1yZiAvdmFyL2xpYi9hcHQvbGlzdHMvKgpDT1BZIG9wZW5zc2wuY25mIC9ldGMvc3NsL29wZW5zc2wuY25mCldPUktESVIgL2J1aWxkZXJfd29ya3NwYWNlCg==
:: END_B64_ dockerfile

:: BEGIN_B64_ dockerfile.841n
IyBmaWxlIGRvY2tlcmZpbGUuODQxbgpGUk9NIHVidW50dToxOC4wNApFTlYgREVCSUFOX0ZST05URU5EPW5vbmludGVyYWN0aXZlClJVTiBhcHQtZ2V0IHVwZGF0ZSAmJiBhcHQtZ2V0IGluc3RhbGwgLXkgXAoJcHl0aG9uMyBidWlsZC1lc3NlbnRpYWwgcHl0aG9uMi43IGxpYm5jdXJzZXM1LWRldiBsaWJuY3Vyc2VzdzUtZGV2IHpsaWIxZy1kZXYgZ2F3ayBnaXQgZ2V0dGV4dCBsaWJzc2wtZGV2IHhzbHRwcm9jIHdnZXQgdW56aXAgeHotdXRpbHMgY2EtY2VydGlmaWNhdGVzIFwKCSYmIHVwZGF0ZS1jYS1jZXJ0aWZpY2F0ZXMgXAoJJiYgbG4gLXNmIC91c3IvYmluL3B5dGhvbjIuNyAvdXNyL2Jpbi9weXRob24gXAoJJiYgcm0gLXJmIC92YXIvbGliL2FwdC9saXN0cy8qCkNPUFkgb3BlbnNzbC5jbmYgL2V0Yy9zc2wvb3BlbnNzbC5jbmYKV09SS0RJUiAvYnVpbGRlcl93b3Jrc3BhY2UK
:: END_B64_ dockerfile.841n

:: BEGIN_B64_ openssl.cnf
IyBmaWxlOiBvcGVuc3NsLmNuZgpvcGVuc3NsX2NvbmYgPSBkZWZhdWx0X2NvbmZfc2VjdGlvbgpbZGVmYXVsdF9jb25mX3NlY3Rpb25d
:: END_B64_ openssl.cnf