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
call :CHECK_DIR "custom_files"
call :CHECK_DIR "firmware_output"
call :CHECK_DIR "src_packages"

:: === 2. ПРОВЕРКА НАЛИЧИЯ ПРОФИЛЕЙ ===
if not exist "profiles\*.conf" (
    echo.
    echo [INIT] Папка 'profiles' пуста. Создаю пример профиля...
    call :CREATE_EXAMPLE_PROFILE
    echo [INFO] Файл 'profiles\example_source_mt7621.conf' создан.
)

:MENU
cls
echo ========================================
echo  OpenWrt SOURCE Builder v1.1 (iqubik)
echo ========================================
echo.
echo Обнаруженные Source-профили:
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
echo ВНИМАНИЕ: Сборка из исходников требует много CPU/RAM!
echo.
for /L %%i in (1,1,%count%) do (
    set "CURRENT_CONF=!profile[%%i]!"
    call :BUILD_ROUTINE "!CURRENT_CONF!"
)
echo.
echo === ВСЕ ЗАДАЧИ ЗАПУЩЕНЫ ===
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

set "SRC_BRANCH_VAL="
for /f "usebackq tokens=2 delims==" %%a in (`type "profiles\%CONF_FILE%" ^| findstr "SRC_BRANCH"`) do (
    set "VAL=%%a"
    set "VAL=!VAL:"=!"
    for /f "tokens=* delims= " %%b in ("!VAL!") do set "SRC_BRANCH_VAL=%%b"
)

if "%SRC_BRANCH_VAL%"=="" (
    echo [ERROR] SRC_BRANCH не найден в конфиге %CONF_FILE%!
    exit /b
)

set "IS_LEGACY="
echo "!SRC_BRANCH_VAL!" | findstr /C:"19.07" >nul && set IS_LEGACY=1
echo "!SRC_BRANCH_VAL!" | findstr /C:"18.06" >nul && set IS_LEGACY=1

IF DEFINED IS_LEGACY (
    set "BUILDER_SERVICE=builder-src-oldwrt"
) ELSE (
    set "BUILDER_SERVICE=builder-src-openwrt"
)

if not exist "firmware_output\sourcebuilder\%PROFILE_ID%" (
    mkdir "firmware_output\sourcebuilder\%PROFILE_ID%"
)

echo [LAUNCH] Запуск контейнера сборки для: %PROFILE_ID%...
echo [DEBUG] Ветка Git: !SRC_BRANCH_VAL! (Legacy: !IS_LEGACY!)

START "SrcBuild: %PROFILE_ID%" /D "%PROJECT_DIR%" cmd /c "set SELECTED_CONF=%CONF_FILE%&& set HOST_FILES_DIR=./custom_files/%PROFILE_ID%&& set HOST_OUTPUT_DIR=./firmware_output/sourcebuilder/%PROFILE_ID%&& docker-compose -f docker-compose-src.yaml -p srcbuild_%PROFILE_ID% up --build --force-recreate --remove-orphans %BUILDER_SERVICE% & echo. & echo === WORK FINISHED === & pause"

exit /b

:: =========================================================
::  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
:: =========================================================
:CREATE_PERMS_SCRIPT
set "P_ID=%~1"
set "PERM_FILE=custom_files\%P_ID%\etc\uci-defaults\99-permissions.sh"
if exist "%PERM_FILE%" exit /b
rem echo    [AUTO] Создание 99-permissions.sh для %P_ID%...
powershell -Command "[System.IO.Directory]::CreateDirectory('custom_files\%P_ID%\etc\uci-defaults')" >nul 2>&1
set "B64=IyEvYmluL3NoCiMgRml4IFNTSCBwZXJtaXNzaW9ucwpbIC1kIC9ldGMvZHJvcGJZYXIgXSAmJiBjaG1vZCA3MDAgL2V0Yy9kcm9wYmVhcgpbIC1mIC9ldGMvZHJvcGJZYXIvYXV0aG9yaXplZF9rZXlzIF0gJiYgY2htb2QgNjAwIC9ldGMvZHJvcGJZYXIvYXV0aG9yaXplZF9rZXlzCiMgRml4IFNoYWRvdwpbIC1mIC9ldGMvc2hhZG93IF0gJiYgY2htb2QgNjAwIC9ldGMvc2hhZG93CiMgRml4IHJvb3QgU1NIIGtleXMKWyAtZCAvcm9vdC8uc3NoIF0gJiYgY2htb2QgNzAwIC9yb290Ly5zc2gKWyAtZiAvcm9vdC8uc3NoL2lkX3JzYSBdICYmIGNobW9kIDYwMCAvcm9vdC8uc3NoL2lkX3JzYQpleGl0IDAK"
powershell -Command "[IO.File]::WriteAllBytes('%PERM_FILE%', [Convert]::FromBase64String('%B64%'))"
exit /b

:EXTRACT_RESOURCES
for %%F in ("docker-compose-src.yaml" "src.dockerfile" "src.dockerfile.legacy" "openssl.cnf") do (
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
set "FN=profiles\example_source_mt7621.conf"
(
    echo # === Example Source Profile for Xiaomi 4A Gigabit ===
    echo PROFILE_NAME="xiaomi_4a_src"
    echo # Repo Settings
    echo SRC_REPO="https://github.com/openwrt/openwrt.git"
    echo SRC_BRANCH="openwrt-23.05"
    echo # Target Settings ^(Look at OpenWrt Table of Hardware^)
    echo SRC_TARGET="ramips"
    echo SRC_SUBTARGET="mt7621"
    echo TARGET_PROFILE="xiaomi_mi-router-4a-gigabit"
    echo # Packages ^(Space separated, -pkg to remove^)
    echo SRC_PACKAGES="luci uhttpd openssh-sftp-server htop"
    echo # Extra config options ^(optional^)
    echo ROOTFS_SIZE=""
    echo KERNEL_SIZE=""
) > "%FN%"
exit /b

:: СЕКЦИЯ ДЛЯ BASE64 КОДА
:: BEGIN_B64_ docker-compose-src.yaml
IyBmaWxlOiBzcmNCdWlsZGVyXGRvY2tlci1jb21wb3NlLXNyYy55YW1sIHYxLjEKc2VydmljZXM6CiAgYnVpbGRlci1zcmMtb3BlbndydDoKICAgIGJ1aWxkOgogICAgICBjb250ZXh0OiAuCiAgICAgIGRvY2tlcmZpbGU6IHNyYy5kb2NrZXJmaWxlCiAgICB1c2VyOiAicm9vdCIKICAgIGVudmlyb25tZW50OgogICAgICAtIENPTkZfRklMRT0ke1NFTEVDVEVEX0NPTkZ9CiAgICB2b2x1bWVzOgogICAgICAtIHNyYy13b3JrZGlyOi9ob21lL2J1aWxkL29wZW53cnQKICAgICAgLSBzcmMtZGwtY2FjaGU6L2hvbWUvYnVpbGQvb3BlbndydC9kbAogICAgICAtIC4vcHJvZmlsZXM6L3Byb2ZpbGVzCiAgICAgIC0gLi9zcmNfcGFja2FnZXM6L2lucHV0X3BhY2thZ2VzCiAgICAgIC0gJHtIT1NUX0ZJTEVTX0RJUn06L292ZXJsYXlfZmlsZXMKICAgICAgLSAke0hPU1RfT1VUUFVUX0RJUn06L291dHB1dAogICAgICAtIC4vb3BlbnNzbC5jbmY6L29wZW5zc2wuY25mCiAgICBjb21tYW5kOiAmc3JjX2J1aWxkX3NjcmlwdCB8CiAgICAgIC9iaW4vYmFzaCAtYyAiCiAgICAgIHNldCAtZQogICAgICBlY2hvICdbSU5JVF0gQ2hlY2tpbmcgdm9sdW1lIHBlcm1pc3Npb25zLi4uJwogICAgICAjINCY0YHQv9C+0LvRjNC30YPQtdC8ICQkKC4uLikg0YfRgtC+0LHRiyBkb2NrZXItY29tcG9zZSDQvdC1INC/0YvRgtCw0LvRgdGPINC40L3RgtC10YDQv9GA0LXRgtC40YDQvtCy0LDRgtGMINC/0LXRgNC10LzQtdC90L3Rg9GOCiAgICAgIGlmIFsgXCIkJChzdGF0IC1jICclVScgL2hvbWUvYnVpbGQvb3BlbndydClcIiAhPSBcImJ1aWxkXCIgXTsgdGhlbgogICAgICAgICAgZWNobyBcIltJTklUXSBGaXJzdCBydW4gZGV0ZWN0ZWQ6IEZpeGluZyBvd25lcnNoaXAgb2Ygd29ya2Rpci4uLlwiCiAgICAgICAgICBjaG93biAtUiBidWlsZDpidWlsZCAvaG9tZS9idWlsZC9vcGVud3J0CiAgICAgIGZpCiAgICAgIAogICAgICAjINCh0L7Qt9C00LDQtdC8INGB0LrRgNC40L/RgiDRgdCx0L7RgNC60Lgg0LLQvdGD0YLRgNC4INC60L7QvdGC0LXQudC90LXRgNCwCiAgICAgIGNhdCA8PCAnRU9GJyA+IC90bXAvYnVpbGRfc2NyaXB0LnNoICAgICAgCiAgICAgIHNldCAtZQogICAgICBleHBvcnQgSE9NRT0vaG9tZS9idWlsZAogICAgICBQUk9GSUxFX0lEPSQkKGJhc2VuYW1lIFwiJCRDT05GX0ZJTEVcIiAuY29uZikKCiAgICAgICMgPT09IDAuIFNldHVwIEVudmlyb25tZW50ID09PQogICAgICBpZiBbICEgLWYgXCIvcHJvZmlsZXMvJCRDT05GX0ZJTEVcIiBdOyB0aGVuCiAgICAgICAgZWNobyBcIkZBVEFMOiBQcm9maWxlIC9wcm9maWxlcy8kJENPTkZfRklMRSBub3QgZm91bmQhXCIKICAgICAgICBleGl0IDEKICAgICAgZmkKICAgICAgCiAgICAgICMgRml4IENSTEYKICAgICAgdHIgLWQgJ1xccicgPCBcIi9wcm9maWxlcy8kJENPTkZfRklMRVwiID4gL3RtcC9jbGVhbl9jb25maWcuZW52CiAgICAgIHNvdXJjZSAvdG1wL2NsZWFuX2NvbmZpZy5lbnYKICAgICAgCiAgICAgIGVjaG8gXCI9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PVwiCiAgICAgIGVjaG8gXCIgICBPcGVuV3J0IFNPVVJDRSBCdWlsZGVyIGZvciAkJFBST0ZJTEVfTkFNRVwiCiAgICAgIGVjaG8gXCI9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PVwiCiAgICAgIAogICAgICBTVEFSVF9USU1FPSQkKGRhdGUgKyVzKQogICAgICBUSU1FU1RBTVA9JCQoVFo9J1VUQy0zJyBkYXRlICslZCVtJXktJUglTSVTKQogICAgICAKICAgICAgIyA9PT0gMS4gR0lUIFNFVFVQID09PQogICAgICBpZiBbICEgLWQgXCIuZ2l0XCIgXTsgdGhlbgogICAgICAgICAgZWNobyBcIltHSVRdIEluaXRpYWxpemluZyByZXBvIGluIG5vbi1lbXB0eSBkaXIuLi5cIgogICAgICAgICAgIyDQo9Cx0LjRgNCw0LXQvCDQvdCw0LTQvtC10LTQu9C40LLQvtC1INC/0YDQtdC00YPQv9GA0LXQttC00LXQvdC40LUg0L4g0LLQtdGC0LrQtSBtYXN0ZXIvbWFpbgogICAgICAgICAgZ2l0IGNvbmZpZyAtLWdsb2JhbCBpbml0LmRlZmF1bHRCcmFuY2ggbWFzdGVyCiAgICAgICAgICBnaXQgaW5pdAogICAgICAgICAgZ2l0IHJlbW90ZSBhZGQgb3JpZ2luIFwiJCRTUkNfUkVQT1wiCiAgICAgIGZpCiAgICAgIAogICAgICBlY2hvIFwiW0dJVF0gRmV0Y2hpbmcgJCRTUkNfQlJBTkNILi4uXCIKICAgICAgZ2l0IGZldGNoIG9yaWdpbiBcIiQkU1JDX0JSQU5DSFwiCiAgICAgIAogICAgICBlY2hvIFwiW0dJVF0gQ2hlY2tvdXQvUmVzZXQgdG8gJCRTUkNfQlJBTkNILi4uXCIgICAgICAKICAgICAgZ2l0IGNvbmZpZyAtLWdsb2JhbCBhZHZpY2UuZGV0YWNoZWRIZWFkIGZhbHNlCiAgICAgIGdpdCBjaGVja291dCAtZiBcIkZFVENIX0hFQURcIgogICAgICBnaXQgcmVzZXQgLS1oYXJkIFwiRkVUQ0hfSEVBRFwiCgogICAgICAjID09PSBTV0lUQ0ggVE8gR0lUSFVCIE1JUlJPUlMgPT09ICAgICAgCiAgICAgIGlmIFsgLWYgZmVlZHMuY29uZi5kZWZhdWx0IF07IHRoZW4KICAgICAgICAgIGVjaG8gXCJbRklYXSBTd2l0Y2hpbmcgZmVlZHMgdG8gR2l0SHViIG1pcnJvcnMuLi5cIgogICAgICAgICAgc2VkIC1pICdzfGh0dHBzOi8vZ2l0Lm9wZW53cnQub3JnL2ZlZWQvfGh0dHBzOi8vZ2l0aHViLmNvbS9vcGVud3J0L3xnJyBmZWVkcy5jb25mLmRlZmF1bHQKICAgICAgICAgIHNlZCAtaSAnc3xodHRwczovL2dpdC5vcGVud3J0Lm9yZy9wcm9qZWN0L3xodHRwczovL2dpdGh1Yi5jb20vb3BlbndydC98ZycgZmVlZHMuY29uZi5kZWZhdWx0CiAgICAgIGZpCgogICAgICAjID09PSAyLiBGRUVEUyA9PT0KICAgICAgZWNobyBcIltGRUVEU10gVXBkYXRpbmcgYW5kIEluc3RhbGxpbmcgZmVlZHMuLi5cIgogICAgICAuL3NjcmlwdHMvZmVlZHMgdXBkYXRlIC1hCiAgICAgIC4vc2NyaXB0cy9mZWVkcyBpbnN0YWxsIC1hCgogICAgICAjID09PSBDVVNUT00gU09VUkNFUyA9PT0KICAgICAgIyDQktCQ0JbQndCeOiDQodGO0LTQsCDQvdGD0LbQvdC+INC60LvQsNGB0YLRjCDQn9CQ0J/QmtCYINGBINC40YHRhdC+0LTQvdC40LrQsNC80LggKE1ha2VmaWxlKSwg0LAg0L3QtSAuaXBrINGE0LDQudC70YshCiAgICAgIGlmIFsgLWQgXCIvaW5wdXRfcGFja2FnZXNcIiBdICYmIFsgXCIkJChscyAtQSAvaW5wdXRfcGFja2FnZXMpXCIgXTsgdGhlbgogICAgICAgICAgZWNobyBcIltQS0ddIEluamVjdGluZyBjdXN0b20gc291cmNlcyBpbnRvIHBhY2thZ2UvIGRpcmVjdG9yeS4uLlwiCiAgICAgICAgICBjcCAtcmYgL2lucHV0X3BhY2thZ2VzLyogcGFja2FnZS8KICAgICAgZmkKCiAgICAgICMgPT09IDMuIENPTkZJR1VSQVRJT04gPT09CiAgICAgIGVjaG8gXCJbQ09ORklHXSBHZW5lcmF0aW5nIC5jb25maWcuLi5cIgogICAgICBybSAtZiAuY29uZmlnCiAgICAgIAogICAgICAjINCR0LDQt9C+0LLQsNGPINC60L7QvdGE0LjQs9GD0YDQsNGG0LjRjyBUYXJnZXQKICAgICAgZWNobyBcIkNPTkZJR19UQVJHRVRfJCRTUkNfVEFSR0VUPXlcIiA+PiAuY29uZmlnCiAgICAgIGVjaG8gXCJDT05GSUdfVEFSR0VUXyQke1NSQ19UQVJHRVR9XyQke1NSQ19TVUJUQVJHRVR9PXlcIiA+PiAuY29uZmlnCiAgICAgIGVjaG8gXCJDT05GSUdfVEFSR0VUXyQke1NSQ19UQVJHRVR9XyQke1NSQ19TVUJUQVJHRVR9X0RFVklDRV8kJFRBUkdFVF9QUk9GSUxFPXlcIiA+PiAuY29uZmlnCiAgICAgIAogICAgICAjINCU0L7QsdCw0LLQu9GP0LXQvCDQv9C+0LvRjNC30L7QstCw0YLQtdC70YzRgdC60LjQtSDQv9Cw0LrQtdGC0Ysg0LjQtyBTUkNfUEFDS0FHRVMKICAgICAgZm9yIHBrZyBpbiAkJFNSQ19QQUNLQUdFUzsgZG8KICAgICAgICAgIGlmIFtbIFwiJCRwa2dcIiA9PSAtKiBdXTsgdGhlbgogICAgICAgICAgICAgIGNsZWFuX3BrZz1cIiQke3BrZyMtfVwiCiAgICAgICAgICAgICAgZWNobyBcIiMgQ09ORklHX1BBQ0tBR0VfJCRjbGVhbl9wa2cgaXMgbm90IHNldFwiID4+IC5jb25maWcKICAgICAgICAgIGVsc2UKICAgICAgICAgICAgICBlY2hvIFwiQ09ORklHX1BBQ0tBR0VfJCRwa2c9eVwiID4+IC5jb25maWcKICAgICAgICAgIGZpCiAgICAgIGRvbmUKICAgICAgCiAgICAgICMgQXBwbHkgTFVDSSBkZWZhdWx0ICjQtdGB0LvQuCDQv9C+0LvRjNC30L7QstCw0YLQtdC70Ywg0L3QtSDRg9C60LDQt9Cw0Lsg0LXQs9C+INGB0LDQvCkgICAgICAKICAgICAgaWYgISBncmVwIC1xIFwiQ09ORklHX1BBQ0tBR0VfbHVjaT15XCIgLmNvbmZpZzsgdGhlbgogICAgICAgICAgZWNobyBcIkNPTkZJR19QQUNLQUdFX2x1Y2k9eVwiID4+IC5jb25maWcKICAgICAgZmkKICAgICAgCiAgICAgICMgU2l6ZXMKICAgICAgaWYgWyAtbiBcIiQkUk9PVEZTX1NJWkVcIiBdOyB0aGVuCiAgICAgICAgZWNobyBcIkNPTkZJR19UQVJHRVRfUk9PVEZTX1BBUlRTSVpFPSQkUk9PVEZTX1NJWkVcIiA+PiAuY29uZmlnCiAgICAgIGZpCgogICAgICBpZiBbIC1uIFwiJCRLRVJORUxfU0laRVwiIF07IHRoZW4KICAgICAgICBlY2hvIFwiQ09ORklHX1RBUkdFVF9LRVJORUxfUEFSVFNJWkU9JCRLRVJORUxfU0laRVwiID4+IC5jb25maWcKICAgICAgZmkKCiAgICAgIGVjaG8gXCJbREVCVUddIFNob3dpbmcgZ2VuZXJhdGVkIFNFRUQgLmNvbmZpZzpcIgogICAgICBlY2hvIFwiLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLVwiCiAgICAgIGNhdCAuY29uZmlnCiAgICAgIGVjaG8gXCItLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tXCIKICAgICAgbWFrZSBkZWZjb25maWcKICAgICAgCiAgICAgICMgPT09IDQuIENVU1RPTSBGSUxFUyA9PT0KICAgICAgaWYgWyAtZCBcIi9vdmVybGF5X2ZpbGVzXCIgXSAmJiBbIFwiJCQobHMgLUEgL292ZXJsYXlfZmlsZXMpXCIgXTsgdGhlbgogICAgICAgICAgZWNobyBcIltGSUxFU10gQ29weWluZyBvdmVybGF5IGZpbGVzLi4uXCIKICAgICAgICAgIG1rZGlyIC1wIGZpbGVzCiAgICAgICAgICBjcCAtciAvb3ZlcmxheV9maWxlcy8qIGZpbGVzLwogICAgICBmaQogICAgICAKICAgICAgIyA9PT0gNS4gRE9XTkxPQUQgPT09CiAgICAgIGVjaG8gXCJbRE9XTkxPQURdIERvd25sb2FkaW5nIHNvdXJjZXMgdG8gY2FjaGUuLi5cIgogICAgICBta2RpciAtcCBkbCAgICAgIAogICAgICBtYWtlIGRvd25sb2FkIHx8IChlY2hvIFwiW0VSUk9SXSBEb3dubG9hZCBmYWlsZWQhIFJldHJ5aW5nIHdpdGggbG9nZ2luZy4uLlwiICYmIG1ha2UgZG93bmxvYWQgVj1zICYmIGV4aXQgMSkKICAgICAgCiAgICAgICMgPT09IDYuIEJVSUxEID09PQogICAgICBlY2hvIFwiW0JVSUxEXSBTdGFydGluZyBjb21waWxhdGlvbiAoSm9iczogJCQobnByb2MpKS4uLlwiICAgICAgCiAgICAgIG1ha2UgLWokJChucHJvYykgfHwgKGVjaG8gXCJbRVJST1JdIE11bHRpY29yZSBidWlsZCBmYWlsZWQuIFJldHJ5aW5nIHNpbmdsZSBjb3JlIFY9cy4uLlwiICYmIG1ha2UgLWoxIFY9cykKICAgICAgCiAgICAgICMgPT09IDcuIEFSVElGQUNUUyA9PT0KICAgICAgZWNobyBcIltTQVZFXSBTYXZpbmcgYXJ0aWZhY3RzLi4uXCIKICAgICAgVEFSR0VUX0RJUj1cIi9vdXRwdXQvJCRUSU1FU1RBTVBcIgogICAgICBta2RpciAtcCBcIiQkVEFSR0VUX0RJUlwiCiAgICAgIAogICAgICAjINCY0YnQtdC8INGE0LDQudC70Ysg0LIgYmluL3RhcmdldHMKICAgICAgZmluZCBiaW4vdGFyZ2V0cy8kJFNSQ19UQVJHRVQvJCRTUkNfU1VCVEFSR0VUIC10eXBlIGYgLW5vdCAtcGF0aCBcIiovcGFja2FnZXMvKlwiIC1leGVjIGNwIHt9IFwiJCRUQVJHRVRfRElSL1wiIFxcOwogICAgICAKICAgICAgIyDQodC+0YXRgNCw0L3Rj9C10Lwg0LjRgtC+0LPQvtCy0YvQuSDQutC+0L3RhNC40LMg0LTQu9GPINGB0L/RgNCw0LLQutC4CiAgICAgIGNwIC5jb25maWcgXCIkJFRBUkdFVF9ESVIvYnVpbGQuY29uZmlnXCIKICAgICAgCiAgICAgIEVORF9USU1FPSQkKGRhdGUgKyVzKQogICAgICBFTEFQU0VEPSQkKChFTkRfVElNRSAtIFNUQVJUX1RJTUUpKQogICAgICAKICAgICAgZWNobyBcIlwiCiAgICAgIGVjaG8gXCI9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT1cIgogICAgICBlY2hvIFwiPT09INCh0LHQvtGA0LrQsCAkJFBST0ZJTEVfTkFNRSDQt9Cw0LLQtdGA0YjQtdC90LAg0LfQsCAkJHtFTEFQU0VEfdGBLlwiCiAgICAgIGVjaG8gXCI9PT0g0J7QsdGA0LDQt9GLOiBmaXJtd2FyZV9vdXRwdXQvc291cmNlYnVpbGRlci8kJFBST0ZJTEVfSUQvJCRUSU1FU1RBTVBcIgogICAgICBlY2hvIFwiPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09XCIKICAgICAgRU9GCiAgICAgIAogICAgICBjaG1vZCAreCAvdG1wL2J1aWxkX3NjcmlwdC5zaAogICAgICBjaG93biBidWlsZDpidWlsZCAvdG1wL2J1aWxkX3NjcmlwdC5zaAogICAgICAKICAgICAgZWNobyAnW0VYRUNdIFN3aXRjaGluZyB0byB1c2VyIGJ1aWxkLi4uJwogICAgICBzdWRvIC1FIC11IGJ1aWxkIGJhc2ggL3RtcC9idWlsZF9zY3JpcHQuc2gKICAgICAgIgoKICBidWlsZGVyLXNyYy1vbGR3cnQ6CiAgICBidWlsZDoKICAgICAgY29udGV4dDogLgogICAgICBkb2NrZXJmaWxlOiBzcmMuZG9ja2VyZmlsZS5sZWdhY3kKICAgIHVzZXI6ICJyb290IgogICAgZW52aXJvbm1lbnQ6CiAgICAgIC0gQ09ORl9GSUxFPSR7U0VMRUNURURfQ09ORn0KICAgIHZvbHVtZXM6CiAgICAgIC0gc3JjLXdvcmtkaXI6L2hvbWUvYnVpbGQvb3BlbndydAogICAgICAtIHNyYy1kbC1jYWNoZTovaG9tZS9idWlsZC9vcGVud3J0L2RsCiAgICAgIC0gLi9wcm9maWxlczovcHJvZmlsZXMKICAgICAgLSAuL3NyY19wYWNrYWdlczovaW5wdXRfcGFja2FnZXMKICAgICAgLSAke0hPU1RfRklMRVNfRElSfTovb3ZlcmxheV9maWxlcwogICAgICAtICR7SE9TVF9PVVRQVVRfRElSfTovb3V0cHV0CiAgICAgIC0gLi9vcGVuc3NsLmNuZjovb3BlbnNzbC5jbmYKICAgIGNvbW1hbmQ6ICpzcmNfYnVpbGRfc2NyaXB0Cgp2b2x1bWVzOgogIHNyYy1kbC1jYWNoZToKICBzcmMtd29ya2RpcjoK
:: END_B64_ docker-compose-src.yaml

:: BEGIN_B64_ src.dockerfile
I2ZpbGU6IHNyY0J1aWxkZXIvc3JjLmRvY2tlcmZpbGUgdjEuMApGUk9NIHVidW50dToyMi4wNApFTlYgREVCSUFOX0ZST05URU5EPW5vbmludGVyYWN0aXZlClJVTiBhcHQtZ2V0IHVwZGF0ZSAmJiBhcHQtZ2V0IGluc3RhbGwgLXkgXAogICAgYnVpbGQtZXNzZW50aWFsIGNsYW5nIGZsZXggYmlzb24gZysrIGdhd2sgXAogICAgZ2NjLW11bHRpbGliIGcrKy1tdWx0aWxpYiBnZXR0ZXh0IGdpdCBsaWJuY3Vyc2VzLWRldiBcCiAgICBsaWJzc2wtZGV2IHB5dGhvbjMtZGlzdHV0aWxzIHB5dGhvbjMtc2V0dXB0b29scyBcCiAgICBweXRob24zLXB5ZWxmdG9vbHMgbGliZWxmLWRldiBcCiAgICByc3luYyB1bnppcCB6bGliMWctZGV2IGZpbGUgd2dldCB0aW1lIFwKICAgIHN3aWcgeHNsdHByb2MgXAogICAgY3VybCBjYS1jZXJ0aWZpY2F0ZXMgc3NsLWNlcnQgc3VkbyBcCiAgICAmJiBybSAtcmYgL3Zhci9saWIvYXB0L2xpc3RzLyoKUlVOIHVzZXJhZGQgLW0gLXUgMTAwMCAtcyAvYmluL2Jhc2ggYnVpbGQKV09SS0RJUiAvaG9tZS9idWlsZC9vcGVud3J0ClJVTiBta2RpciAtcCBkbCAmJiBjaG93biAtUiBidWlsZDpidWlsZCAvaG9tZS9idWlsZC9vcGVud3J0CkNPUFkgLS1jaG93bj1idWlsZDpidWlsZCBvcGVuc3NsLmNuZiAvaG9tZS9idWlsZC9vcGVuc3NsLmNuZgpFTlYgT1BFTlNTTF9DT05GPS9ob21lL2J1aWxkL29wZW5zc2wuY25mCg==
:: END_B64_ src.dockerfile

:: BEGIN_B64_ src.dockerfile.legacy
IyBmaWxlOiBzcmNCdWlsZGVyL3NyYy5kb2NrZXJmaWxlLmxlZ2FjeQpGUk9NIHVidW50dToxOC4wNApFTlYgREVCSUFOX0ZST05URU5EPW5vbmludGVyYWN0aXZlClJVTiBhcHQtZ2V0IHVwZGF0ZSAmJiBhcHQtZ2V0IGluc3RhbGwgLXkgXAogICAgYnVpbGQtZXNzZW50aWFsIGNjYWNoZSBlY2ogZmFzdGphciBmaWxlIGcrKyBnYXdrIFwKICAgIGdldHRleHQgZ2l0IGphdmEtcHJvcG9zZS1jbGFzc3BhdGggbGliZWxmLWRldiBsaWJuY3Vyc2VzNS1kZXYgXAogICAgbGlibmN1cnNlc3c1LWRldiBsaWJzc2wtZGV2IHB5dGhvbiBweXRob24yLjctZGV2IHB5dGhvbjMgdW56aXAgd2dldCBcCiAgICByc3luYyBzdWJ2ZXJzaW9uIHN3aWcgdGltZSB4c2x0cHJvYyB6bGliMWctZGV2IFwKICAgIGN1cmwgY2EtY2VydGlmaWNhdGVzIHNzbC1jZXJ0IHN1ZG8gXAogICAgJiYgcm0gLXJmIC92YXIvbGliL2FwdC9saXN0cy8qClJVTiB1c2VyYWRkIC1tIC11IDEwMDAgLXMgL2Jpbi9iYXNoIGJ1aWxkCldPUktESVIgL2hvbWUvYnVpbGQvb3BlbndydApSVU4gbWtkaXIgLXAgZGwgJiYgY2hvd24gLVIgYnVpbGQ6YnVpbGQgL2hvbWUvYnVpbGQvb3BlbndydApDT1BZIC0tY2hvd249YnVpbGQ6YnVpbGQgb3BlbnNzbC5jbmYgL2hvbWUvYnVpbGQvb3BlbnNzbC5jbmYKRU5WIE9QRU5TU0xfQ09ORj0vaG9tZS9idWlsZC9vcGVuc3NsLmNuZgo=
:: END_B64_ src.dockerfile.legacy

:: BEGIN_B64_ openssl.cnf
IyBmaWxlOiBvcGVuc3NsLmNuZgpvcGVuc3NsX2NvbmYgPSBkZWZhdWx0X2NvbmZfc2VjdGlvbgpbZGVmYXVsdF9jb25mX3NlY3Rpb25dCnNzbF9jb25mID0gc3NsX3NlY3QKW3NzbF9zZWN0XQpzeXN0ZW1fZGVmYXVsdCA9IHN5c3RlbV9kZWZhdWx0X3NlY3QKW3N5c3RlbV9kZWZhdWx0X3NlY3RdCk9wdGlvbnMgPSBVbnNhZmVMZWdhY3lSZW5lZ290aWF0aW9uCg==
:: END_B64_ openssl.cnf