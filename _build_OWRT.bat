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
echo  OpenWrt Smart Builder v3.5 (iqubik)
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
    set "BUILDER_SERVICE=builder-841n"
) ELSE (
    set "BUILDER_SERVICE=builder-beeline"
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
powershell -Command "$text = \"# === Example Profile for TL-WR841N v9 ===`nPROFILE_NAME=`\"example_841n`\"`nTARGET_PROFILE=`\"tl-wr841-v9`\"`nIMAGEBUILDER_URL=`\"https://downloads.openwrt.org/releases/19.07.9/targets/ar71xx/tiny/openwrt-imagebuilder-19.07.9-ar71xx-tiny.Linux-x86_64.tar.xz`\"`nPKGS=`\"luci-base luci-mod-admin-full luci-theme-bootstrap luci-i18n-base-ru luci-i18n-opkg-ru uhttpd luci-app-firewall libiwinfo-lua relayd luci-proto-relay iw rpcd-mod-rrdns opkg -luci -iw-full -luci-proto-ipv6 -luci-proto-ppp -ipv6 -kmod-ipv6 -ip6tables -kmod-ip6tables -odhcp6c -odhcpd-ipv6only -libip6tc -ppp -ppp-mod-pppoe -kmod-ppp -kmod-pppoe -kmod-pppox -kmod-slhc -kmod-lib-crc-ccitt -luci-app-ntpc -luci-i18n-ntpc-ru -ntpclient -libpthread -librt -uboot-envtools -kmod-nf-conntrack6 -kmod-usb-core -kmod-usb2`\"\"; [IO.File]::WriteAllText('profiles\example_841n.conf', $text)"
powershell -Command "$text = \"# === Example Profile for SmartBox Giga ===`nPROFILE_NAME=`\"giga`\"`nTARGET_PROFILE=`\"beeline_smartbox-giga`\"`nIMAGEBUILDER_URL=`\"https://mirror-03.infra.openwrt.org/releases/24.10.4/targets/ramips/mt7621/openwrt-imagebuilder-24.10.4-ramips-mt7621.Linux-x86_64.tar.zst`\"`nPKGS=`\"wpad-openssl coreutils bzip2 tar unzip gzip grep sed gawk shadow-utils bind-host knot-host drill e2fsprogs tcpdump fdisk cfdisk ca-certificates libustream-openssl kmod-mtd-rw ip-full vnstat batctl-full arp-scan arp-scan-database curl openssh-sftp-server mc htop screen wget-ssl iw-full iftop bash nano coreutils-ls block-mount kmod-usb3 kmod-usb2 kmod-usb-uhci kmod-usb-ohci kmod-usb-storage kmod-usb-storage-uas kmod-fs-ext4 kmod-fs-exfat kmod-fs-ntfs3 kmod-fs-vfat kmod-fs-netfs kmod-fs-ksmbd kmod-fs-smbfs-common luci luci-compat luci-proto-batman-adv luci-proto-vxlan luci-app-nlbwmon luci-app-firewall luci-app-commands luci-app-statistics luci-app-ttyd luci-app-attendedsysupgrade luci-app-wol luci-app-transmission luci-app-ksmbd luci-app-minidlna luci-app-adblock-fast luci-app-package-manager collectd-mod-ping luci-i18n-base-ru luci-i18n-commands-ru luci-i18n-firewall-ru luci-i18n-ksmbd-ru luci-i18n-minidlna-ru luci-i18n-statistics-ru luci-i18n-ttyd-ru luci-i18n-usteer-ru luci-i18n-wol-ru luci-i18n-attendedsysupgrade-ru luci-i18n-transmission-ru luci-i18n-adblock-fast-ru luci-i18n-filemanager-ru luci-i18n-package-manager-ru kmod-nls-utf8 opkg kmod-nls-cp1251 kmod-nls-cp866 -wpad-basic-mbedtls -iw -ca-bundle -libustream-mbedtls`\"\"; [IO.File]::WriteAllText('profiles\giga.conf', $text)"
exit /b

:: СЕКЦИЯ ДЛЯ BASE64 КОДА (НЕ УДАЛЯТЬ ЭТИ МЕТКИ)
:: BEGIN_B64_ docker-compose.yaml
c2VydmljZXM6DQogICMgPT09IE1PREVSTiBCVUlMREVSIChVYnVudHUgMjIuMDQp
ID09PQ0KICBidWlsZGVyLWJlZWxpbmU6DQogICAgYnVpbGQ6IC4NCiAgICBlbnZp
cm9ubWVudDoNCiAgICAgIC0gQ09ORl9GSUxFPSR7U0VMRUNURURfQ09ORn0NCiAg
ICB2b2x1bWVzOg0KICAgICAgIyAxLiDQmtCt0Kgg0JDQoNCl0JjQktCe0JINCiAg
ICAgIC0gaW1hZ2VidWlsZGVyLWNhY2hlOi9jYWNoZQ0KICAgICAgIyAyLiDQmtCt
0Kgg0J/QkNCa0JXQotCe0JINCiAgICAgIC0gaXBrLWNhY2hlOi9idWlsZGVyX3dv
cmtzcGFjZS9kbA0KICAgICAgIyAzLiDQoNCV0J/QntCX0JjQotCe0KDQmNCZINCf
0JDQmtCV0KLQntCSDQogICAgICAtIC4vY3VzdG9tX3BhY2thZ2VzOi9pbnB1dF9w
YWNrYWdlcw0KICAgICAgIyA0LiDQlNCY0J3QkNCc0JjQp9CV0KHQmtCY0JUg0J/Q
o9Ci0JgNCiAgICAgIC0gJHtIT1NUX0ZJTEVTX0RJUn06L292ZXJsYXlfZmlsZXMN
CiAgICAgIC0gJHtIT1NUX09VVFBVVF9ESVJ9Oi9vdXRwdXQNCiAgICAgICMgNS4g
0JrQntCd0KTQmNCT0KPQoNCQ0KbQmNCvDQogICAgICAtIC4vcHJvZmlsZXM6L3By
b2ZpbGVzDQogICAgICAjIDYuINCk0LjQutGBIFNTTCAo0LXRgdC70Lgg0L3Rg9C2
0LXQvSkNCiAgICAgIC0gLi9vcGVuc3NsLmNuZjovb3BlbnNzbC5jbmYNCiAgICBj
b21tYW5kOiAmYnVpbGRfc2NyaXB0IHwNCiAgICAgIC9iaW4vYmFzaCAtYyAiDQog
ICAgICBzZXQgLWUgICMg0J/RgNC10YDRi9Cy0LDRgtGMINC/0YDQuCDQvtGI0LjQ
sdC60LDRhQ0KICAgICAgDQogICAgICAjINCf0YDQvtCy0LXRgNC60LAg0L/RgNC+
0YTQuNC70Y8NCiAgICAgIGlmIFsgISAtZiBcIi9wcm9maWxlcy8kJENPTkZfRklM
RVwiIF07IHRoZW4NCiAgICAgICAgZWNobyBcIkZBVEFMOiBQcm9maWxlIC9wcm9m
aWxlcy8kJENPTkZfRklMRSBub3QgZm91bmQhXCINCiAgICAgICAgZXhpdCAxDQog
ICAgICBmaQ0KICAgICAgDQogICAgICAjID09PSBbRklYXSDQmtCe0J3QktCV0KDQ
otCQ0KbQmNCvIENSTEYgLT4gTEYgPT09DQogICAgICBlY2hvIFwiW0lOSVRdIE5v
cm1hbGl6aW5nIGNvbmZpZyBsaW5lIGVuZGluZ3MuLi5cIg0KICAgICAgdHIgLWQg
J1xccicgPCBcIi9wcm9maWxlcy8kJENPTkZfRklMRVwiID4gL3RtcC9jbGVhbl9j
b25maWcuZW52DQoNCiAgICAgICMg0J/QvtC00LPRgNGD0LbQsNC10Lwg0L3QsNGB
0YLRgNC+0LnQutC4DQogICAgICBzb3VyY2UgL3RtcC9jbGVhbl9jb25maWcuZW52
DQogICAgICANCiAgICAgICMg0JfQkNCh0JXQmtCQ0JXQnCDQktCg0JXQnNCvDQog
ICAgICBTVEFSVF9USU1FPSQkKGRhdGUgKyVzKQ0KICAgICAgVElNRVNUQU1QPSQk
KFRaPSdVVEMtMycgZGF0ZSArJWQlbSV5LSVIJU0lUykNCg0KICAgICAgIyAtLS0g
MS4g0JrQrdCo0JjQoNCe0JLQkNCd0JjQlSBJTUFHRUJVSUxERVIgLS0tDQogICAg
ICBBUkNISVZFX05BTUU9JCQoYmFzZW5hbWUgXCIkJElNQUdFQlVJTERFUl9VUkxc
IikNCiAgICAgIENBQ0hFX0ZJTEU9XCIvY2FjaGUvJCRBUkNISVZFX05BTUVcIg0K
DQogICAgICBpZiBbICEgLWYgXCIkJENBQ0hFX0ZJTEVcIiBdOyB0aGVuDQogICAg
ICAgIGVjaG8gXCJbQ0FDSEUgTUlTU10gRG93bmxvYWRpbmcgJCRBUkNISVZFX05B
TUUuLi5cIiAgICAgICAgDQogICAgICAgIHdnZXQgLXEgXCIkJElNQUdFQlVJTERF
Ul9VUkxcIiAtTyBcIiQkQ0FDSEVfRklMRVwiDQogICAgICBlbHNlDQogICAgICAg
IGVjaG8gXCJbQ0FDSEUgSElUXSBVc2luZyAkJEFSQ0hJVkVfTkFNRVwiDQogICAg
ICBmaQ0KICAgICAgDQogICAgICBlY2hvIFwiRXh0cmFjdGluZy4uLlwiDQogICAg
ICBpZiBlY2hvIFwiJCRJTUFHRUJVSUxERVJfVVJMXCIgfCBncmVwIC1xICcuenN0
JCQnOyB0aGVuDQogICAgICAgICAgdGFyIC1JIHpzdGQgLXhmIFwiJCRDQUNIRV9G
SUxFXCIgLS1zdHJpcC1jb21wb25lbnRzPTENCiAgICAgIGVsc2UNCiAgICAgICAg
ICB0YXIgLXhKZiBcIiQkQ0FDSEVfRklMRVwiIC0tc3RyaXAtY29tcG9uZW50cz0x
DQogICAgICBmaQ0KDQogICAgICAjIC0tLSAyLiDQpNCY0JrQodCrICjQktCe0KHQ
odCi0JDQndCe0JLQm9CV0J0g0J/QoNCQ0JLQmNCb0KzQndCr0Jkg0J/Qo9Ci0Kwp
IC0tLQ0KICAgICAgaWYgWyAtZiAvb3BlbnNzbC5jbmYgXTsgdGhlbg0KICAgICAg
ICAgZWNobyBcIkFwcGx5aW5nIE9wZW5TU0wgRml4IHRvIC9idWlsZGVyL3NoYXJl
ZC13b3JrZGlyLy4uLlwiDQogICAgICAgICAjINCh0L7Qt9C00LDQtdC8INC/0YPR
gtGMLdC+0LHQvNCw0L3QutGDLCDQutC+0YLQvtGA0YvQuSDQt9Cw0YjQuNGCINCy
INCx0LjQvdCw0YDQvdC40LrQsNGFIE9wZW5XcnQNCiAgICAgICAgIG1rZGlyIC1w
IC9idWlsZGVyL3NoYXJlZC13b3JrZGlyL2J1aWxkL3N0YWdpbmdfZGlyL2hvc3Qv
ZXRjL3NzbA0KICAgICAgICAgY3AgL29wZW5zc2wuY25mIC9idWlsZGVyL3NoYXJl
ZC13b3JrZGlyL2J1aWxkL3N0YWdpbmdfZGlyL2hvc3QvZXRjL3NzbC9vcGVuc3Ns
LmNuZg0KICAgICAgZmkNCiAgICAgIA0KICAgICAgIyDQmtC+0L/QuNGA0YPQtdC8
INC60LDRgdGC0L7QvNC90YvQtSBJUEsNCiAgICAgIFsgLWQgL2lucHV0X3BhY2th
Z2VzIF0gJiYgY3AgL2lucHV0X3BhY2thZ2VzLyouaXBrIHBhY2thZ2VzLyAyPi9k
ZXYvbnVsbCB8fCB0cnVlDQoNCiAgICAgIGV4cG9ydCBTT1VSQ0VfREFURV9FUE9D
SD0kJChkYXRlICslcykNCiAgICAgIA0KICAgICAgIyAtLS0gMy4g0KHQkdCe0KDQ
mtCQIC0tLQ0KICAgICAgZWNobyBcIlN0YXJ0aW5nIG1ha2UgaW1hZ2UgZm9yICQk
VEFSR0VUX1BST0ZJTEUuLi5cIg0KICAgICAgbWFrZSBpbWFnZSBQUk9GSUxFPVwi
JCRUQVJHRVRfUFJPRklMRVwiIEZJTEVTPVwiL292ZXJsYXlfZmlsZXNcIiBQQUNL
QUdFUz1cIiQkUEtHU1wiDQoNCiAgICAgICMgLS0tIDQuINCh0J7QpdCg0JDQndCV
0J3QmNCVIC0tLQ0KICAgICAgZWNobyBcIlNhdmluZyBhcnRpZmFjdHMuLi5cIg0K
ICAgICAgZmluZCBiaW4vdGFyZ2V0cyAtbmFtZSBcIipzeXN1cGdyYWRlLmJpblwi
IC1vIC1uYW1lIFwiKmZhY3RvcnkuYmluXCIgLW8gLW5hbWUgXCIqZmFjdG9yeS5p
bWdcIiB8IHdoaWxlIHJlYWQgZjsgZG8NCiAgICAgICAgICBjcCBcIiQkZlwiIFwi
L291dHB1dC8kJFBST0ZJTEVfTkFNRS0kJFRJTUVTVEFNUC0kJChiYXNlbmFtZSBc
IiQkZlwiKVwiDQogICAgICBkb25lDQoNCiAgICAgICMgLS0tIDUuINCg0JDQodCn
0JXQoiDQktCg0JXQnNCV0J3QmCAtLS0NCiAgICAgIEVORF9USU1FPSQkKGRhdGUg
KyVzKQ0KICAgICAgRUxBUFNFRD0kJCgoRU5EX1RJTUUgLSBTVEFSVF9USU1FKSkN
CiAgICAgIA0KICAgICAgZWNobyBcIlwiDQogICAgICBlY2hvIFwiPT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09XCINCiAgICAgIGVjaG8gXCI9PT0g0KHQsdC+0YDQutCwICQkUFJPRklMRV9O
QU1FINC30LDQstC10YDRiNC10L3QsCDQt9CwICQke0VMQVBTRUR90YEuXCINCiAg
ICAgIGVjaG8gXCI9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT1cIg0KICAgICAgIg0KDQogICMgPT09IExF
R0FDWSBCVUlMREVSIChVYnVudHUgMTguMDQpID09PQ0KICBidWlsZGVyLTg0MW46
DQogICAgYnVpbGQ6DQogICAgICBjb250ZXh0OiAuDQogICAgICBkb2NrZXJmaWxl
OiBkb2NrZXJmaWxlLjg0MW4NCiAgICBlbnZpcm9ubWVudDoNCiAgICAgIC0gQ09O
Rl9GSUxFPSR7U0VMRUNURURfQ09ORn0NCiAgICB2b2x1bWVzOg0KICAgICAgLSBp
bWFnZWJ1aWxkZXItY2FjaGU6L2NhY2hlDQogICAgICAtIGlway1jYWNoZTovYnVp
bGRlcl93b3Jrc3BhY2UvZGwNCiAgICAgIC0gLi9jdXN0b21fcGFja2FnZXM6L2lu
cHV0X3BhY2thZ2VzDQogICAgICAtICR7SE9TVF9GSUxFU19ESVJ9Oi9vdmVybGF5
X2ZpbGVzDQogICAgICAtICR7SE9TVF9PVVRQVVRfRElSfTovb3V0cHV0DQogICAg
ICAtIC4vcHJvZmlsZXM6L3Byb2ZpbGVzDQogICAgY29tbWFuZDogKmJ1aWxkX3Nj
cmlwdA0KDQp2b2x1bWVzOg0KICBpbWFnZWJ1aWxkZXItY2FjaGU6DQogIGlway1j
YWNoZTo=
:: END_B64_ docker-compose.yaml

:: BEGIN_B64_ dockerfile
IyBmaWxlIGJlZWxpbmUvZG9ja2VyZmlsZQpGUk9NIHVidW50dToyMi4wNAoKRU5W
IERFQklBTl9GUk9OVEVORD1ub25pbnRlcmFjdGl2ZQoKIyDQo9GB0YLQsNC90LDQ
stC70LjQstCw0LXQvCDQt9Cw0LLQuNGB0LjQvNC+0YHRgtC4INC00LvRjyDRgdC+
0LLRgNC10LzQtdC90L3Ri9GFINCy0LXRgNGB0LjQuSBPcGVuV3J0ClJVTiBhcHQt
Z2V0IHVwZGF0ZSAmJiBhcHQtZ2V0IGluc3RhbGwgLXkgXAoJYnVpbGQtZXNzZW50
aWFsIFwKCWdpdCBcCglsaWJuY3Vyc2VzNS1kZXYgXAoJemxpYjFnLWRldiBcCglz
dWJ2ZXJzaW9uIFwKCW1lcmN1cmlhbCBcCglhdXRvY29uZiBcCglsaWJ0b29sIFwK
CWxpYnNzbC1kZXYgXAoJbGliZ2xpYjIuMC1kZXYgXAoJbGliZ21wLWRldiBcCgls
aWJtcGMtZGV2IFwKCWxpYm1wZnItZGV2IFwKCXRleGluZm8gXAoJZ2F3ayBcCglw
eXRob24zLWRpc3R1dGlscyBcCglweXRob24zLXNldHVwdG9vbHMgXAoJcnN5bmMg
XAoJdW56aXAgXAoJd2dldCBcCglmaWxlIFwKCXpzdGQgXAoJJiYgcm0gLXJmIC92
YXIvbGliL2FwdC9saXN0cy8qCgojINCa0L7Qv9C40YDRg9C10Lwg0LzQuNC90LjQ
vNCw0LvRjNC90YvQuSDQutC+0L3RhNC40LMgT3BlblNTTCwg0YfRgtC+0LHRiyDQ
uNC30LHQtdC20LDRgtGMINC+0YjQuNCx0L7QuiBEU08KQ09QWSBvcGVuc3NsLmNu
ZiAvZXRjL3NzbC9vcGVuc3NsLmNuZgoKIyDQodC+0LfQtNCw0LXQvCDRgNCw0LHQ
vtGH0YPRjiDQv9Cw0L/QutGDINCy0L3Rg9GC0YDQuCDQutC+0L3RgtC10LnQvdC1
0YDQsApXT1JLRElSIC9idWlsZGVyX3dvcmtzcGFjZQ==
:: END_B64_ dockerfile

:: BEGIN_B64_ dockerfile.841n
IyBmaWxlIGJlZWxpbmUvZG9ja2VyZmlsZS44NDFuCkZST00gdWJ1bnR1OjE4LjA0
CgpFTlYgREVCSUFOX0ZST05URU5EPW5vbmludGVyYWN0aXZlCgojINCj0YHRgtCw
0L3QsNCy0LvQuNCy0LDQtdC8INC30LDQstC40YHQuNC80L7RgdGC0Lgg0LTQu9GP
IE9wZW5XcnQgMTguMDYKUlVOIGFwdC1nZXQgdXBkYXRlICYmIGFwdC1nZXQgaW5z
dGFsbCAteSBcCglweXRob24zIFwKCWJ1aWxkLWVzc2VudGlhbCBcCglweXRob24y
LjcgXAoJbGlibmN1cnNlczUtZGV2IFwKCWxpYm5jdXJzZXN3NS1kZXYgXAoJemxp
YjFnLWRldiBcCglnYXdrIFwKCWdpdCBcCglnZXR0ZXh0IFwKCWxpYnNzbC1kZXYg
XAoJeHNsdHByb2MgXAoJd2dldCBcCgl1bnppcCBcCgl4ei11dGlscyBcCgljYS1j
ZXJ0aWZpY2F0ZXMgXAoJJiYgdXBkYXRlLWNhLWNlcnRpZmljYXRlcyBcCQoJJiYg
bG4gLXNmIC91c3IvYmluL3B5dGhvbjIuNyAvdXNyL2Jpbi9weXRob24gXAoJJiYg
cm0gLXJmIC92YXIvbGliL2FwdC9saXN0cy8qCgojINCh0L7Qt9C00LDQtdC8INGA
0LDQsdC+0YfRg9GOINC/0LDQv9C60YMg0LLQvdGD0YLRgNC4INC60L7QvdGC0LXQ
udC90LXRgNCwCldPUktESVIgL2J1aWxkZXJfd29ya3NwYWNlCg==
:: END_B64_ dockerfile.841n

:: BEGIN_B64_ openssl.cnf
IyBmaWxlIGJlZWxpbmVcb3BlbnNzbC5jbmYKIyBTdXBlciBtaW5pbWFsIG9wZW5z
c2wuY25mIGZvciBzdGF0aWMgT3BlblNTTCBidWlsZHMKIyBJdCBkZWxpYmVyYXRl
bHkgYXZvaWRzIGxvYWRpbmcgZHluYW1pYyBwcm92aWRlcnMuCm9wZW5zc2xfY29u
ZiA9IGRlZmF1bHRfY29uZl9zZWN0aW9uCgpbZGVmYXVsdF9jb25mX3NlY3Rpb25d
CiMgQW4gZW1wdHkgc2VjdGlvbiBpcyB2YWxpZCBhbmQgZG9lcyBub3RoaW5nLgoj
IGVuZCBmaWxlIGJlZWxpbmVcb3BlbnNzbC5jbmYK
:: END_B64_ openssl.cnf