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
echo  OpenWrt Smart Builder v4.0 (iqubik)
echo ========================================
echo.
echo Обнаруженные профили:
echo.

set count=0
for %%f in (profiles\*.conf) do (
    set /a count+=1
    set "profile[!count!]=%%~nxf"
    set "p_id=%%~nf"
    
    if not exist "custom_files\!p_id!" (
        rem echo [INFO] Создаю папку custom_files\!p_id!
        mkdir "custom_files\!p_id!"
    )
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

if not exist "firmware_output\%PROFILE_ID%" (
    mkdir "firmware_output\%PROFILE_ID%"
)

echo [LAUNCH] Запуск окна для: %PROFILE_ID%...
echo [DEBUG] URL определен как: !URL_CLEAN!

START "Build: %PROFILE_ID%" /D "%PROJECT_DIR%" cmd /c "set SELECTED_CONF=%CONF_FILE%&& set HOST_FILES_DIR=./custom_files/%PROFILE_ID%&& set HOST_OUTPUT_DIR=./firmware_output/%PROFILE_ID%&& docker-compose -p build_%PROFILE_ID% up --build --force-recreate --remove-orphans %BUILDER_SERVICE% & echo. & echo === WORK FINISHED === & pause"

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
powershell -Command "$text = \"# === Example Profile for nanopi-r5c ===`nPROFILE_NAME=`\"nanopi-r5c`\"`nTARGET_PROFILE=`\"friendlyarm_nanopi-r5c`\"`nIMAGEBUILDER_URL=`\"https://downloads.openwrt.org/releases/24.10.5/targets/rockchip/armv8/openwrt-imagebuilder-24.10.5-rockchip-armv8.Linux-x86_64.tar.zst`\"`nPKGS=`\"base-files blkid block-mount bmon ca-bundle ca-certificates collectd-mod-thermal -dnsmasq dnsmasq-full dropbear e2fsprogs ethtool-full fdisk firewall4 fstools htop hwclock i2c-tools iftop ip-full irqbalance kmod-ata-ahci-platform kmod-gpio-button-hotplug kmod-nft-offload kmod-r8125-rss kmod-sdhci kmod-tcp-bbr kmod-usb2 kmod-usb3 libc libgcc libustream-mbedtls logd lm-sensors lsblk luci luci-app-irqbalance luci-app-nlbwmon luci-app-statistics luci-app-upnp luci-i18n-base-ru luci-i18n-firewall-ru luci-i18n-irqbalance-ru luci-i18n-nlbwmon-ru luci-i18n-package-manager-ru luci-i18n-statistics-ru luci-i18n-ttyd-ru luci-i18n-upnp-ru miniupnpd-nftables mkf2fs mmc-utils mtd netifd nftables odhcp6c odhcpd-ipv6only openssl-util opkg parted partx-utils ppp ppp-mod-pppoe procd-ujail smartmontools uboot-envtools uci uclient-fetch urandom-seed urngd usbutils wget-ssl`\"`nROOTFS_SIZE=`\"512`\"\"; [IO.File]::WriteAllText('profiles\nanopi-r5c.conf', $text)"
exit /b

:: СЕКЦИЯ ДЛЯ BASE64 КОДА (НЕ УДАЛЯТЬ ЭТИ МЕТКИ)
:: BEGIN_B64_ docker-compose.yaml
IyBmaWxlOiBkb2NrZXItY29tcG9zZS55YW1sIFYxLjAKc2VydmljZXM6ICAKICBidWlsZGVyLW9wZW53cnQ6CiAgICBidWlsZDogLgogICAgZW52aXJvbm1lbnQ6CiAgICAgIC0gQ09ORl9GSUxFPSR7U0VMRUNURURfQ09ORn0KICAgIHZvbHVtZXM6CiAgICAgIC0gaW1hZ2VidWlsZGVyLWNhY2hlOi9jYWNoZQogICAgICAtIGlway1jYWNoZTovYnVpbGRlcl93b3Jrc3BhY2UvZGwKICAgICAgLSAuL2N1c3RvbV9wYWNrYWdlczovaW5wdXRfcGFja2FnZXMKICAgICAgLSAke0hPU1RfRklMRVNfRElSfTovb3ZlcmxheV9maWxlcwogICAgICAtICR7SE9TVF9PVVRQVVRfRElSfTovb3V0cHV0CiAgICAgIC0gLi9wcm9maWxlczovcHJvZmlsZXMKICAgICAgLSAuL29wZW5zc2wuY25mOi9vcGVuc3NsLmNuZgogICAgY29tbWFuZDogJmJ1aWxkX3NjcmlwdCB8CiAgICAgIC9iaW4vYmFzaCAtYyAiCiAgICAgIHNldCAtZSAgIyDQn9GA0LXRgNGL0LLQsNGC0Ywg0L/RgNC4INC+0YjQuNCx0LrQsNGFCiAgICAgICMg0J/RgNC+0LLQtdGA0LrQsCDQv9GA0L7RhNC40LvRjwogICAgICBpZiBbICEgLWYgXCIvcHJvZmlsZXMvJCRDT05GX0ZJTEVcIiBdOyB0aGVuCiAgICAgICAgZWNobyBcIkZBVEFMOiBQcm9maWxlIC9wcm9maWxlcy8kJENPTkZfRklMRSBub3QgZm91bmQhXCIKICAgICAgICBleGl0IDEKICAgICAgZmkKICAgICAgIyA9PT0gW0ZJWF0g0JrQntCd0JLQldCg0KLQkNCm0JjQryBDUkxGIC0+IExGID09PQogICAgICBlY2hvIFwiW0lOSVRdIE5vcm1hbGl6aW5nIGNvbmZpZyBsaW5lIGVuZGluZ3MuLi5cIgogICAgICB0ciAtZCAnXFxyJyA8IFwiL3Byb2ZpbGVzLyQkQ09ORl9GSUxFXCIgPiAvdG1wL2NsZWFuX2NvbmZpZy5lbnYKICAgICAgc291cmNlIC90bXAvY2xlYW5fY29uZmlnLmVudgogICAgICAjID09PSDQl9CQ0KHQldCa0JDQldCcINCS0KDQldCc0K8gPT09CiAgICAgIFNUQVJUX1RJTUU9JCQoZGF0ZSArJXMpCiAgICAgIFRJTUVTVEFNUD0kJChUWj0nVVRDLTMnIGRhdGUgKyVkJW0leS0lSCVNJVMpCiAgICAgICMgLS0tIDEuINCa0K3QqNCY0KDQntCS0JDQndCY0JUgSU1BR0VCVUlMREVSIC0tLQogICAgICBBUkNISVZFX05BTUU9JCQoYmFzZW5hbWUgXCIkJElNQUdFQlVJTERFUl9VUkxcIikKICAgICAgQ0FDSEVfRklMRT1cIi9jYWNoZS8kJEFSQ0hJVkVfTkFNRVwiCiAgICAgIGlmIFsgISAtZiBcIiQkQ0FDSEVfRklMRVwiIF07IHRoZW4KICAgICAgICBlY2hvIFwiW0NBQ0hFIE1JU1NdIERvd25sb2FkaW5nICQkQVJDSElWRV9OQU1FLi4uXCIKICAgICAgICB3Z2V0IC1xIFwiJCRJTUFHRUJVSUxERVJfVVJMXCIgLU8gXCIkJENBQ0hFX0ZJTEVcIgogICAgICBlbHNlCiAgICAgICAgZWNobyBcIltDQUNIRSBISVRdIFVzaW5nICQkQVJDSElWRV9OQU1FXCIKICAgICAgZmkKICAgICAgZWNobyBcIkV4dHJhY3RpbmcuLi5cIgogICAgICBpZiBlY2hvIFwiJCRJTUFHRUJVSUxERVJfVVJMXCIgfCBncmVwIC1xICcuenN0JCQnOyB0aGVuCiAgICAgICAgICB0YXIgLUkgenN0ZCAteGYgXCIkJENBQ0hFX0ZJTEVcIiAtLXN0cmlwLWNvbXBvbmVudHM9MQogICAgICBlbHNlCiAgICAgICAgICB0YXIgLXhKZiBcIiQkQ0FDSEVfRklMRVwiIC0tc3RyaXAtY29tcG9uZW50cz0xCiAgICAgIGZpCiAgICAgICMgLS0tIDIuINCg0JDQodCo0JjQoNCV0J3QmNCvIC0tLQogICAgICBpZiBbIC1mIC9vcGVuc3NsLmNuZiBdOyB0aGVuCiAgICAgICAgIGVjaG8gXCJBcHBseWluZyBPcGVuU1NMIEZpeCB0byAvYnVpbGRlci9zaGFyZWQtd29ya2Rpci8uLi5cIiAKICAgICAgICAgbWtkaXIgLXAgL2J1aWxkZXIvc2hhcmVkLXdvcmtkaXIvYnVpbGQvc3RhZ2luZ19kaXIvaG9zdC9ldGMvc3NsCiAgICAgICAgIGNwIC9vcGVuc3NsLmNuZiAvYnVpbGRlci9zaGFyZWQtd29ya2Rpci9idWlsZC9zdGFnaW5nX2Rpci9ob3N0L2V0Yy9zc2wvb3BlbnNzbC5jbmYKICAgICAgZmkKICAgICAgIyDQmtC+0L/QuNGA0YPQtdC8INC60LDRgdGC0L7QvNC90YvQtSBJUEsKICAgICAgWyAtZCAvaW5wdXRfcGFja2FnZXMgXSAmJiBjcCAvaW5wdXRfcGFja2FnZXMvKi5pcGsgcGFja2FnZXMvIDI+L2Rldi9udWxsIHx8IHRydWUKICAgICAgI2ZpeCDQtNC70Y8g0LTRgNC10LLQvdC40YUg0YHQsdC+0YDQvtC6CiAgICAgIGV4cG9ydCBTT1VSQ0VfREFURV9FUE9DSD0kJChkYXRlICslcykKICAgICAgIyA9PT0g0JjQl9Cc0JXQndCV0J3QmNCVINCg0JDQl9Cc0JXQoNCQINCg0JDQl9CU0JXQm9Ce0JIgPT09CiAgICAgICMgUm9vdEZTCiAgICAgIGlmIFsgLW4gXCIkJFJPT1RGU19TSVpFXCIgXTsgdGhlbgogICAgICAgIGVjaG8gXCJbQ09ORklHXSBTZXR0aW5nIFJvb3RGUyBzaXplIHRvICQkUk9PVEZTX1NJWkUgTUIuLi5cIgogICAgICAgIHRvdWNoIC5jb25maWcKICAgICAgICBzZWQgLWkgJy9DT05GSUdfVEFSR0VUX1JPT1RGU19QQVJUU0laRS9kJyAuY29uZmlnCiAgICAgICAgZWNobyBcIkNPTkZJR19UQVJHRVRfUk9PVEZTX1BBUlRTSVpFPSQkUk9PVEZTX1NJWkVcIiA+PiAuY29uZmlnCiAgICAgIGVsc2UKICAgICAgICBlY2hvIFwiW0NPTkZJR10gVXNpbmcgZGVmYXVsdCBSb290RlMgc2l6ZVwiCiAgICAgIGZpCiAgICAgICMgS2VybmVsIFNpemUKICAgICAgaWYgWyAtbiBcIiQkS0VSTkVMX1NJWkVcIiBdOyB0aGVuCiAgICAgICAgZWNobyBcIltDT05GSUddIFNldHRpbmcgS2VybmVsIHNpemUgdG8gJCRLRVJORUxfU0laRSBNQi4uLlwiCiAgICAgICAgdG91Y2ggLmNvbmZpZwogICAgICAgIHNlZCAtaSAnL0NPTkZJR19UQVJHRVRfS0VSTkVMX1BBUlRTSVpFL2QnIC5jb25maWcKICAgICAgICBlY2hvIFwiQ09ORklHX1RBUkdFVF9LRVJORUxfUEFSVFNJWkU9JCRLRVJORUxfU0laRVwiID4+IC5jb25maWcKICAgICAgZWxzZQogICAgICAgIGVjaG8gXCJbQ09ORklHXSBVc2luZyBkZWZhdWx0IEtlcm5lbEZTIHNpemVcIgogICAgICBmaQogICAgICAjID09PSDQlNCe0JHQkNCS0JvQldCd0JjQlSDQoNCV0J/QntCX0JjQotCe0KDQmNCV0JIgPT09CiAgICAgIGlmIFsgLW4gXCIkJEVYVFJBX1JFUE9fVVJMXCIgXTsgdGhlbgogICAgICAgICBlY2hvIFwiW1JFUE9dIEFkZGluZyBjdXN0b20gcmVwby4uLlwiCiAgICAgICAgIGVjaG8gXCJzcmMvZ3ogY3VzdG9tX3JlcG8gJCRFWFRSQV9SRVBPX1VSTFwiID4+IHJlcG9zaXRvcmllcy5jb25mCiAgICAgIGVsc2UKICAgICAgICBlY2hvIFwiW0NPTkZJR10gTm8gRVhUUkFfUkVQT19VUkwgY29uZiBmb3VuZCBpbiBwcm9maWxlLlwiIAogICAgICBmaQogICAgICAjIC0tLSAzLiDQodCR0J7QoNCa0JAgLS0tCiAgICAgIGVjaG8gXCJTdGFydGluZyBtYWtlIGltYWdlIGZvciAkJFRBUkdFVF9QUk9GSUxFLi4uXCIKICAgICAgTUFLRV9BUkdTPVwiUFJPRklMRT1cXFwiJCRUQVJHRVRfUFJPRklMRVxcXCIgRklMRVM9XFxcIi9vdmVybGF5X2ZpbGVzXFxcIiBQQUNLQUdFUz1cXFwiJCRQS0dTXFxcIlwiCiAgICAgIGlmIFsgLW4gXCIkJEVYVFJBX0lNQUdFX05BTUVcIiBdOyB0aGVuCiAgICAgICAgICBNQUtFX0FSR1M9XCIkJE1BS0VfQVJHUyBFWFRSQV9JTUFHRV9OQU1FPVxcXCIkJEVYVFJBX0lNQUdFX05BTUVcXFwiXCIKICAgICAgZmkKICAgICAgaWYgWyAtbiBcIiQkRElTQUJMRURfU0VSVklDRVNcIiBdOyB0aGVuCiAgICAgICAgICBNQUtFX0FSR1M9XCIkJE1BS0VfQVJHUyBESVNBQkxFRF9TRVJWSUNFUz1cXFwiJCRESVNBQkxFRF9TRVJWSUNFU1xcXCJcIgogICAgICBmaQogICAgICBlY2hvIFwiUnVubmluZzogbWFrZSBpbWFnZSAkJE1BS0VfQVJHU1wiCiAgICAgIGV2YWwgbWFrZSBpbWFnZSAkJE1BS0VfQVJHUwogICAgICAjIC0tLSA0LiDQodCe0KXQoNCQ0J3QldCd0JjQlSAtLS0KICAgICAgZWNobyBcIlNhdmluZyBhcnRpZmFjdHMuLi5cIgogICAgICBUQVJHRVRfRElSPVwiL291dHB1dC8kJFRJTUVTVEFNUFwiCiAgICAgIG1rZGlyIC1wIFwiJCRUQVJHRVRfRElSXCIKICAgICAgZmluZCBiaW4vdGFyZ2V0cyAtdHlwZSBmIC1ub3QgLXBhdGggXCIqL3BhY2thZ2VzLypcIiB8IHdoaWxlIHJlYWQgZjsgZG8KICAgICAgICAgIGNwIFwiJCRmXCIgXCIkJFRBUkdFVF9ESVIvXCIKICAgICAgZG9uZQogICAgICAjIC0tLSA1LiDQoNCQ0KHQp9CV0KIg0JLQoNCV0JzQldCd0JggLS0tCiAgICAgIEVORF9USU1FPSQkKGRhdGUgKyVzKQogICAgICBFTEFQU0VEPSQkKChFTkRfVElNRSAtIFNUQVJUX1RJTUUpKQogICAgICBlY2hvIFwiXCIKICAgICAgZWNobyBcIj09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PVwiCiAgICAgIGVjaG8gXCI9PT0g0KHQsdC+0YDQutCwICQkUFJPRklMRV9OQU1FINC30LDQstC10YDRiNC10L3QsCDQt9CwICQke0VMQVBTRUR90YEuXCIKICAgICAgZWNobyBcIj09PSDQpNCw0LnQu9GLINGB0L7RhdGA0LDQvdC10L3RiyDQsjogZmlybXdhcmVfb3V0cHV0LyQkUFJPRklMRV9OQU1FLyQkVElNRVNUQU1QXCIKICAgICAgZWNobyBcIj09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PVwiCiAgICAgICIKCiAgYnVpbGRlci1vbGR3cnQ6CiAgICBidWlsZDoKICAgICAgY29udGV4dDogLgogICAgICBkb2NrZXJmaWxlOiBkb2NrZXJmaWxlLjg0MW4KICAgIGVudmlyb25tZW50OgogICAgICAtIENPTkZfRklMRT0ke1NFTEVDVEVEX0NPTkZ9CiAgICB2b2x1bWVzOgogICAgICAtIGltYWdlYnVpbGRlci1jYWNoZTovY2FjaGUKICAgICAgLSBpcGstY2FjaGU6L2J1aWxkZXJfd29ya3NwYWNlL2RsCiAgICAgIC0gLi9jdXN0b21fcGFja2FnZXM6L2lucHV0X3BhY2thZ2VzCiAgICAgIC0gJHtIT1NUX0ZJTEVTX0RJUn06L292ZXJsYXlfZmlsZXMKICAgICAgLSAke0hPU1RfT1VUUFVUX0RJUn06L291dHB1dAogICAgICAtIC4vcHJvZmlsZXM6L3Byb2ZpbGVzCiAgICAgIC0gLi9vcGVuc3NsLmNuZjovb3BlbnNzbC5jbmYKICAgIGNvbW1hbmQ6ICpidWlsZF9zY3JpcHQKCnZvbHVtZXM6CiAgaW1hZ2VidWlsZGVyLWNhY2hlOgogIGlway1jYWNoZTo=
:: END_B64_ docker-compose.yaml

:: BEGIN_B64_ dockerfile
IyBmaWxlIGRvY2tlcmZpbGUKRlJPTSB1YnVudHU6MjIuMDQKRU5WIERFQklBTl9GUk9OVEVORD1ub25pbnRlcmFjdGl2ZQojINCj0YHRgtCw0L3QsNCy0LvQuNCy0LDQtdC8INC30LDQstC40YHQuNC80L7RgdGC0Lgg0LTQu9GPINGB0L7QstGA0LXQvNC10L3QvdGL0YUg0LLQtdGA0YHQuNC5IE9wZW5XcnQKUlVOIGFwdC1nZXQgdXBkYXRlICYmIGFwdC1nZXQgaW5zdGFsbCAteSBcCglidWlsZC1lc3NlbnRpYWwgZ2l0IGxpYm5jdXJzZXM1LWRldiB6bGliMWctZGV2IHN1YnZlcnNpb24gbWVyY3VyaWFsIGF1dG9jb25mIGxpYnRvb2wgbGlic3NsLWRldiBsaWJnbGliMi4wLWRldiBsaWJnbXAtZGV2IGxpYm1wYy1kZXYgbGlibXBmci1kZXYgdGV4aW5mbyBnYXdrIHB5dGhvbjMtZGlzdHV0aWxzIHB5dGhvbjMtc2V0dXB0b29scyByc3luYyB1bnppcCB3Z2V0IGZpbGUgenN0ZCBcCgkmJiBybSAtcmYgL3Zhci9saWIvYXB0L2xpc3RzLyoKIyDQmtC+0L/QuNGA0YPQtdC8INC80LjQvdC40LzQsNC70YzQvdGL0Lkg0LrQvtC90YTQuNCzIE9wZW5TU0wsINGH0YLQvtCx0Ysg0LjQt9Cx0LXQttCw0YLRjCDQvtGI0LjQsdC+0LogRFNPCkNPUFkgb3BlbnNzbC5jbmYgL2V0Yy9zc2wvb3BlbnNzbC5jbmYKIyDQodC+0LfQtNCw0LXQvCDRgNCw0LHQvtGH0YPRjiDQv9Cw0L/QutGDINCy0L3Rg9GC0YDQuCDQutC+0L3RgtC10LnQvdC10YDQsApXT1JLRElSIC9idWlsZGVyX3dvcmtzcGFjZQo=
:: END_B64_ dockerfile

:: BEGIN_B64_ dockerfile.841n
IyBmaWxlIGRvY2tlcmZpbGUuODQxbgpGUk9NIHVidW50dToxOC4wNApFTlYgREVCSUFOX0ZST05URU5EPW5vbmludGVyYWN0aXZlCiMg0KPRgdGC0LDQvdCw0LLQu9C40LLQsNC10Lwg0LfQsNCy0LjRgdC40LzQvtGB0YLQuCDQtNC70Y8gT3BlbldydCAxOC4wNgpSVU4gYXB0LWdldCB1cGRhdGUgJiYgYXB0LWdldCBpbnN0YWxsIC15IFwKCXB5dGhvbjMgYnVpbGQtZXNzZW50aWFsIHB5dGhvbjIuNyBsaWJuY3Vyc2VzNS1kZXYgbGlibmN1cnNlc3c1LWRldiB6bGliMWctZGV2IGdhd2sgZ2l0IGdldHRleHQgbGlic3NsLWRldiB4c2x0cHJvYyB3Z2V0IHVuemlwIHh6LXV0aWxzIGNhLWNlcnRpZmljYXRlcyBcCgkmJiB1cGRhdGUtY2EtY2VydGlmaWNhdGVzIFwKCSYmIGxuIC1zZiAvdXNyL2Jpbi9weXRob24yLjcgL3Vzci9iaW4vcHl0aG9uIFwKCSYmIHJtIC1yZiAvdmFyL2xpYi9hcHQvbGlzdHMvKgojINCa0L7Qv9C40YDRg9C10Lwg0LzQuNC90LjQvNCw0LvRjNC90YvQuSDQutC+0L3RhNC40LMgT3BlblNTTCwg0YfRgtC+0LHRiyDQuNC30LHQtdC20LDRgtGMINC+0YjQuNCx0L7QuiBEU08KQ09QWSBvcGVuc3NsLmNuZiAvZXRjL3NzbC9vcGVuc3NsLmNuZgojINCh0L7Qt9C00LDQtdC8INGA0LDQsdC+0YfRg9GOINC/0LDQv9C60YMg0LLQvdGD0YLRgNC4INC60L7QvdGC0LXQudC90LXRgNCwCldPUktESVIgL2J1aWxkZXJfd29ya3NwYWNlCg==
:: END_B64_ dockerfile.841n

:: BEGIN_B64_ openssl.cnf
IyBmaWxlIG9wZW5zc2wuY25mCm9wZW5zc2xfY29uZiA9IGRlZmF1bHRfY29uZl9zZWN0aW9uCltkZWZhdWx0X2NvbmZfc2VjdGlvbl0K
:: END_B64_ openssl.cnf