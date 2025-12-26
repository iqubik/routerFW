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
echo  OpenWrt SOURCE Builder v1.0 (iqubik)
echo ========================================
echo.
echo Обнаруженные Source-профили:
echo.

set count=0
for %%f in (profiles\*.conf) do (
    set /a count+=1
    set "profile[!count!]=%%~nxf"
    set "p_id=%%~nf"
    
    if not exist "custom_files\!p_id!" (
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
IyBmaWxlOiBzcmNCdWlsZGVyXGRvY2tlci1jb21wb3NlLXNyYy55YW1sIHYxLjEKc2VydmljZXM6CiAgYnVpbGRlci1zcmMtb3BlbndydDoKICAgIGJ1aWxkOgogICAgICBjb250ZXh0OiAuCiAgICAgIGRvY2tlcmZpbGU6IHNyYy5kb2NrZXJmaWxlCiAgICB1c2VyOiAicm9vdCIKICAgIGVudmlyb25tZW50OgogICAgICAtIENPTkZfRklMRT0ke1NFTEVDVEVEX0NPTkZ9CiAgICB2b2x1bWVzOgogICAgICAtIHNyYy13b3JrZGlyOi9ob21lL2J1aWxkL29wZW53cnQKICAgICAgLSBzcmMtZGwtY2FjaGU6L2hvbWUvYnVpbGQvb3BlbndydC9kbAogICAgICAtIC4vc3JjX3Byb2ZpbGVzOi9wcm9maWxlcwogICAgICAtIC4vc3JjX3BhY2thZ2VzOi9pbnB1dF9wYWNrYWdlcwogICAgICAtICR7SE9TVF9GSUxFU19ESVJ9Oi9vdmVybGF5X2ZpbGVzCiAgICAgIC0gJHtIT1NUX09VVFBVVF9ESVJ9Oi9vdXRwdXQKICAgICAgLSAuL29wZW5zc2wuY25mOi9vcGVuc3NsLmNuZgogICAgY29tbWFuZDogJnNyY19idWlsZF9zY3JpcHQgfAogICAgICAvYmluL2Jhc2ggLWMgIgogICAgICBzZXQgLWUKICAgICAgZWNobyAnW0lOSVRdIENoZWNraW5nIHZvbHVtZSBwZXJtaXNzaW9ucy4uLicKICAgICAgIyDQmNGB0L/QvtC70YzQt9GD0LXQvCAkJCguLi4pINGH0YLQvtCx0YsgZG9ja2VyLWNvbXBvc2Ug0L3QtSDQv9GL0YLQsNC70YHRjyDQuNC90YLQtdGA0L/RgNC10YLQuNGA0L7QstCw0YLRjCDQv9C10YDQtdC80LXQvdC90YPRjgogICAgICBpZiBbIFwiJCQoc3RhdCAtYyAnJVUnIC9ob21lL2J1aWxkL29wZW53cnQpXCIgIT0gXCJidWlsZFwiIF07IHRoZW4KICAgICAgICAgIGVjaG8gXCJbSU5JVF0gRmlyc3QgcnVuIGRldGVjdGVkOiBGaXhpbmcgb3duZXJzaGlwIG9mIHdvcmtkaXIuLi5cIgogICAgICAgICAgY2hvd24gLVIgYnVpbGQ6YnVpbGQgL2hvbWUvYnVpbGQvb3BlbndydAogICAgICBmaQogICAgICAKICAgICAgIyDQodC+0LfQtNCw0LXQvCDRgdC60YDQuNC/0YIg0YHQsdC+0YDQutC4INCy0L3Rg9GC0YDQuCDQutC+0L3RgtC10LnQvdC10YDQsAogICAgICBjYXQgPDwgJ0VPRicgPiAvdG1wL2J1aWxkX3NjcmlwdC5zaCAgICAgIAogICAgICBzZXQgLWUKICAgICAgZXhwb3J0IEhPTUU9L2hvbWUvYnVpbGQKICAgICAgUFJPRklMRV9JRD0kJChiYXNlbmFtZSBcIiQkQ09ORl9GSUxFXCIgLmNvbmYpCgogICAgICAjID09PSAwLiBTZXR1cCBFbnZpcm9ubWVudCA9PT0KICAgICAgaWYgWyAhIC1mIFwiL3Byb2ZpbGVzLyQkQ09ORl9GSUxFXCIgXTsgdGhlbgogICAgICAgIGVjaG8gXCJGQVRBTDogUHJvZmlsZSAvcHJvZmlsZXMvJCRDT05GX0ZJTEUgbm90IGZvdW5kIVwiCiAgICAgICAgZXhpdCAxCiAgICAgIGZpCiAgICAgIAogICAgICAjIEZpeCBDUkxGCiAgICAgIHRyIC1kICdcXHInIDwgXCIvcHJvZmlsZXMvJCRDT05GX0ZJTEVcIiA+IC90bXAvY2xlYW5fY29uZmlnLmVudgogICAgICBzb3VyY2UgL3RtcC9jbGVhbl9jb25maWcuZW52CiAgICAgIAogICAgICBlY2hvIFwiPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT1cIgogICAgICBlY2hvIFwiICAgT3BlbldydCBTT1VSQ0UgQnVpbGRlciBmb3IgJCRQUk9GSUxFX05BTUVcIgogICAgICBlY2hvIFwiPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT1cIgogICAgICAKICAgICAgU1RBUlRfVElNRT0kJChkYXRlICslcykKICAgICAgVElNRVNUQU1QPSQkKFRaPSdVVEMtMycgZGF0ZSArJWQlbSV5LSVIJU0lUykKICAgICAgCiAgICAgICMgPT09IDEuIEdJVCBTRVRVUCA9PT0KICAgICAgaWYgWyAhIC1kIFwiLmdpdFwiIF07IHRoZW4KICAgICAgICAgIGVjaG8gXCJbR0lUXSBJbml0aWFsaXppbmcgcmVwbyBpbiBub24tZW1wdHkgZGlyLi4uXCIKICAgICAgICAgICMg0KPQsdC40YDQsNC10Lwg0L3QsNC00L7QtdC00LvQuNCy0L7QtSDQv9GA0LXQtNGD0L/RgNC10LbQtNC10L3QuNC1INC+INCy0LXRgtC60LUgbWFzdGVyL21haW4KICAgICAgICAgIGdpdCBjb25maWcgLS1nbG9iYWwgaW5pdC5kZWZhdWx0QnJhbmNoIG1hc3RlcgogICAgICAgICAgZ2l0IGluaXQKICAgICAgICAgIGdpdCByZW1vdGUgYWRkIG9yaWdpbiBcIiQkU1JDX1JFUE9cIgogICAgICBmaQogICAgICAKICAgICAgZWNobyBcIltHSVRdIEZldGNoaW5nICQkU1JDX0JSQU5DSC4uLlwiCiAgICAgIGdpdCBmZXRjaCBvcmlnaW4gXCIkJFNSQ19CUkFOQ0hcIgogICAgICAKICAgICAgZWNobyBcIltHSVRdIENoZWNrb3V0L1Jlc2V0IHRvICQkU1JDX0JSQU5DSC4uLlwiICAgICAgCiAgICAgIGdpdCBjb25maWcgLS1nbG9iYWwgYWR2aWNlLmRldGFjaGVkSGVhZCBmYWxzZQogICAgICBnaXQgY2hlY2tvdXQgLWYgXCJGRVRDSF9IRUFEXCIKICAgICAgZ2l0IHJlc2V0IC0taGFyZCBcIkZFVENIX0hFQURcIgoKICAgICAgIyA9PT0gU1dJVENIIFRPIEdJVEhVQiBNSVJST1JTID09PSAgICAgIAogICAgICBpZiBbIC1mIGZlZWRzLmNvbmYuZGVmYXVsdCBdOyB0aGVuCiAgICAgICAgICBlY2hvIFwiW0ZJWF0gU3dpdGNoaW5nIGZlZWRzIHRvIEdpdEh1YiBtaXJyb3JzLi4uXCIKICAgICAgICAgIHNlZCAtaSAnc3xodHRwczovL2dpdC5vcGVud3J0Lm9yZy9mZWVkL3xodHRwczovL2dpdGh1Yi5jb20vb3BlbndydC98ZycgZmVlZHMuY29uZi5kZWZhdWx0CiAgICAgICAgICBzZWQgLWkgJ3N8aHR0cHM6Ly9naXQub3BlbndydC5vcmcvcHJvamVjdC98aHR0cHM6Ly9naXRodWIuY29tL29wZW53cnQvfGcnIGZlZWRzLmNvbmYuZGVmYXVsdAogICAgICBmaQoKICAgICAgIyA9PT0gMi4gRkVFRFMgPT09CiAgICAgIGVjaG8gXCJbRkVFRFNdIFVwZGF0aW5nIGFuZCBJbnN0YWxsaW5nIGZlZWRzLi4uXCIKICAgICAgLi9zY3JpcHRzL2ZlZWRzIHVwZGF0ZSAtYQogICAgICAuL3NjcmlwdHMvZmVlZHMgaW5zdGFsbCAtYQoKICAgICAgIyA9PT0gQ1VTVE9NIFNPVVJDRVMgPT09CiAgICAgICMg0JLQkNCW0J3Qnjog0KHRjtC00LAg0L3Rg9C20L3QviDQutC70LDRgdGC0Ywg0J/QkNCf0JrQmCDRgSDQuNGB0YXQvtC00L3QuNC60LDQvNC4IChNYWtlZmlsZSksINCwINC90LUgLmlwayDRhNCw0LnQu9GLIQogICAgICBpZiBbIC1kIFwiL2lucHV0X3BhY2thZ2VzXCIgXSAmJiBbIFwiJCQobHMgLUEgL2lucHV0X3BhY2thZ2VzKVwiIF07IHRoZW4KICAgICAgICAgIGVjaG8gXCJbUEtHXSBJbmplY3RpbmcgY3VzdG9tIHNvdXJjZXMgaW50byBwYWNrYWdlLyBkaXJlY3RvcnkuLi5cIgogICAgICAgICAgY3AgLXJmIC9pbnB1dF9wYWNrYWdlcy8qIHBhY2thZ2UvCiAgICAgIGZpCgogICAgICAjID09PSAzLiBDT05GSUdVUkFUSU9OID09PQogICAgICBlY2hvIFwiW0NPTkZJR10gR2VuZXJhdGluZyAuY29uZmlnLi4uXCIKICAgICAgcm0gLWYgLmNvbmZpZwogICAgICAKICAgICAgIyDQkdCw0LfQvtCy0LDRjyDQutC+0L3RhNC40LPRg9GA0LDRhtC40Y8gVGFyZ2V0CiAgICAgIGVjaG8gXCJDT05GSUdfVEFSR0VUXyQkU1JDX1RBUkdFVD15XCIgPj4gLmNvbmZpZwogICAgICBlY2hvIFwiQ09ORklHX1RBUkdFVF8kJHtTUkNfVEFSR0VUfV8kJHtTUkNfU1VCVEFSR0VUfT15XCIgPj4gLmNvbmZpZwogICAgICBlY2hvIFwiQ09ORklHX1RBUkdFVF8kJHtTUkNfVEFSR0VUfV8kJHtTUkNfU1VCVEFSR0VUfV9ERVZJQ0VfJCRUQVJHRVRfUFJPRklMRT15XCIgPj4gLmNvbmZpZwogICAgICAKICAgICAgIyDQlNC+0LHQsNCy0LvRj9C10Lwg0L/QvtC70YzQt9C+0LLQsNGC0LXQu9GM0YHQutC40LUg0L/QsNC60LXRgtGLINC40LcgU1JDX1BBQ0tBR0VTCiAgICAgIGZvciBwa2cgaW4gJCRTUkNfUEFDS0FHRVM7IGRvCiAgICAgICAgICBpZiBbWyBcIiQkcGtnXCIgPT0gLSogXV07IHRoZW4KICAgICAgICAgICAgICBjbGVhbl9wa2c9XCIkJHtwa2cjLX1cIgogICAgICAgICAgICAgIGVjaG8gXCIjIENPTkZJR19QQUNLQUdFXyQkY2xlYW5fcGtnIGlzIG5vdCBzZXRcIiA+PiAuY29uZmlnCiAgICAgICAgICBlbHNlCiAgICAgICAgICAgICAgZWNobyBcIkNPTkZJR19QQUNLQUdFXyQkcGtnPXlcIiA+PiAuY29uZmlnCiAgICAgICAgICBmaQogICAgICBkb25lCiAgICAgIAogICAgICAjIEFwcGx5IExVQ0kgZGVmYXVsdCAo0LXRgdC70Lgg0L/QvtC70YzQt9C+0LLQsNGC0LXQu9GMINC90LUg0YPQutCw0LfQsNC7INC10LPQviDRgdCw0LwpICAgICAgCiAgICAgIGlmICEgZ3JlcCAtcSBcIkNPTkZJR19QQUNLQUdFX2x1Y2k9eVwiIC5jb25maWc7IHRoZW4KICAgICAgICAgIGVjaG8gXCJDT05GSUdfUEFDS0FHRV9sdWNpPXlcIiA+PiAuY29uZmlnCiAgICAgIGZpCiAgICAgIAogICAgICAjIFNpemVzCiAgICAgIGlmIFsgLW4gXCIkJFJPT1RGU19TSVpFXCIgXTsgdGhlbgogICAgICAgIGVjaG8gXCJDT05GSUdfVEFSR0VUX1JPT1RGU19QQVJUU0laRT0kJFJPT1RGU19TSVpFXCIgPj4gLmNvbmZpZwogICAgICBmaQoKICAgICAgaWYgWyAtbiBcIiQkS0VSTkVMX1NJWkVcIiBdOyB0aGVuCiAgICAgICAgZWNobyBcIkNPTkZJR19UQVJHRVRfS0VSTkVMX1BBUlRTSVpFPSQkS0VSTkVMX1NJWkVcIiA+PiAuY29uZmlnCiAgICAgIGZpCgogICAgICBlY2hvIFwiW0RFQlVHXSBTaG93aW5nIGdlbmVyYXRlZCBTRUVEIC5jb25maWc6XCIKICAgICAgZWNobyBcIi0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS1cIgogICAgICBjYXQgLmNvbmZpZwogICAgICBlY2hvIFwiLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLVwiCiAgICAgIG1ha2UgZGVmY29uZmlnCiAgICAgIAogICAgICAjID09PSA0LiBDVVNUT00gRklMRVMgPT09CiAgICAgIGlmIFsgLWQgXCIvb3ZlcmxheV9maWxlc1wiIF0gJiYgWyBcIiQkKGxzIC1BIC9vdmVybGF5X2ZpbGVzKVwiIF07IHRoZW4KICAgICAgICAgIGVjaG8gXCJbRklMRVNdIENvcHlpbmcgb3ZlcmxheSBmaWxlcy4uLlwiCiAgICAgICAgICBta2RpciAtcCBmaWxlcwogICAgICAgICAgY3AgLXIgL292ZXJsYXlfZmlsZXMvKiBmaWxlcy8KICAgICAgZmkKICAgICAgCiAgICAgICMgPT09IDUuIERPV05MT0FEID09PQogICAgICBlY2hvIFwiW0RPV05MT0FEXSBEb3dubG9hZGluZyBzb3VyY2VzIHRvIGNhY2hlLi4uXCIKICAgICAgbWtkaXIgLXAgZGwgICAgICAKICAgICAgbWFrZSBkb3dubG9hZCB8fCAoZWNobyBcIltFUlJPUl0gRG93bmxvYWQgZmFpbGVkISBSZXRyeWluZyB3aXRoIGxvZ2dpbmcuLi5cIiAmJiBtYWtlIGRvd25sb2FkIFY9cyAmJiBleGl0IDEpCiAgICAgIAogICAgICAjID09PSA2LiBCVUlMRCA9PT0KICAgICAgZWNobyBcIltCVUlMRF0gU3RhcnRpbmcgY29tcGlsYXRpb24gKEpvYnM6ICQkKG5wcm9jKSkuLi5cIiAgICAgIAogICAgICBtYWtlIC1qJCQobnByb2MpIHx8IChlY2hvIFwiW0VSUk9SXSBNdWx0aWNvcmUgYnVpbGQgZmFpbGVkLiBSZXRyeWluZyBzaW5nbGUgY29yZSBWPXMuLi5cIiAmJiBtYWtlIC1qMSBWPXMpCiAgICAgIAogICAgICAjID09PSA3LiBBUlRJRkFDVFMgPT09CiAgICAgIGVjaG8gXCJbU0FWRV0gU2F2aW5nIGFydGlmYWN0cy4uLlwiCiAgICAgIFRBUkdFVF9ESVI9XCIvb3V0cHV0LyQkVElNRVNUQU1QXCIKICAgICAgbWtkaXIgLXAgXCIkJFRBUkdFVF9ESVJcIgogICAgICAKICAgICAgIyDQmNGJ0LXQvCDRhNCw0LnQu9GLINCyIGJpbi90YXJnZXRzCiAgICAgIGZpbmQgYmluL3RhcmdldHMvJCRTUkNfVEFSR0VULyQkU1JDX1NVQlRBUkdFVCAtdHlwZSBmIC1ub3QgLXBhdGggXCIqL3BhY2thZ2VzLypcIiAtZXhlYyBjcCB7fSBcIiQkVEFSR0VUX0RJUi9cIiBcXDsKICAgICAgCiAgICAgICMg0KHQvtGF0YDQsNC90Y/QtdC8INC40YLQvtCz0L7QstGL0Lkg0LrQvtC90YTQuNCzINC00LvRjyDRgdC/0YDQsNCy0LrQuAogICAgICBjcCAuY29uZmlnIFwiJCRUQVJHRVRfRElSL2J1aWxkLmNvbmZpZ1wiCiAgICAgIAogICAgICBFTkRfVElNRT0kJChkYXRlICslcykKICAgICAgRUxBUFNFRD0kJCgoRU5EX1RJTUUgLSBTVEFSVF9USU1FKSkKICAgICAgCiAgICAgIGVjaG8gXCJcIgogICAgICBlY2hvIFwiPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09XCIKICAgICAgZWNobyBcIj09PSDQodCx0L7RgNC60LAgJCRQUk9GSUxFX05BTUUg0LfQsNCy0LXRgNGI0LXQvdCwINC30LAgJCR7RUxBUFNFRH3RgS5cIgogICAgICBlY2hvIFwiPT09INCe0LHRgNCw0LfRizogZmlybXdhcmVfb3V0cHV0L3NvdXJjZWJ1aWxkZXIvJCRQUk9GSUxFX0lELyQkVElNRVNUQU1QXCIKICAgICAgZWNobyBcIj09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PVwiCiAgICAgIEVPRgogICAgICAKICAgICAgY2htb2QgK3ggL3RtcC9idWlsZF9zY3JpcHQuc2gKICAgICAgY2hvd24gYnVpbGQ6YnVpbGQgL3RtcC9idWlsZF9zY3JpcHQuc2gKICAgICAgCiAgICAgIGVjaG8gJ1tFWEVDXSBTd2l0Y2hpbmcgdG8gdXNlciBidWlsZC4uLicKICAgICAgc3VkbyAtRSAtdSBidWlsZCBiYXNoIC90bXAvYnVpbGRfc2NyaXB0LnNoCiAgICAgICIKCiAgYnVpbGRlci1zcmMtb2xkd3J0OgogICAgYnVpbGQ6CiAgICAgIGNvbnRleHQ6IC4KICAgICAgZG9ja2VyZmlsZTogc3JjLmRvY2tlcmZpbGUubGVnYWN5CiAgICB1c2VyOiAicm9vdCIKICAgIGVudmlyb25tZW50OgogICAgICAtIENPTkZfRklMRT0ke1NFTEVDVEVEX0NPTkZ9CiAgICB2b2x1bWVzOgogICAgICAtIHNyYy13b3JrZGlyOi9ob21lL2J1aWxkL29wZW53cnQKICAgICAgLSBzcmMtZGwtY2FjaGU6L2hvbWUvYnVpbGQvb3BlbndydC9kbAogICAgICAtIC4vc3JjX3Byb2ZpbGVzOi9wcm9maWxlcwogICAgICAtIC4vc3JjX3BhY2thZ2VzOi9pbnB1dF9wYWNrYWdlcwogICAgICAtICR7SE9TVF9GSUxFU19ESVJ9Oi9vdmVybGF5X2ZpbGVzCiAgICAgIC0gJHtIT1NUX09VVFBVVF9ESVJ9Oi9vdXRwdXQKICAgICAgLSAuL29wZW5zc2wuY25mOi9vcGVuc3NsLmNuZgogICAgY29tbWFuZDogKnNyY19idWlsZF9zY3JpcHQKCnZvbHVtZXM6CiAgc3JjLWRsLWNhY2hlOgogIHNyYy13b3JrZGlyOgo=
:: END_B64_ docker-compose-src.yaml

:: BEGIN_B64_ src.dockerfile
I2ZpbGU6IHNyY0J1aWxkZXIvc3JjLmRvY2tlcmZpbGUgdjEuMApGUk9NIHVidW50dToyMi4wNApFTlYgREVCSUFOX0ZST05URU5EPW5vbmludGVyYWN0aXZlClJVTiBhcHQtZ2V0IHVwZGF0ZSAmJiBhcHQtZ2V0IGluc3RhbGwgLXkgXAogICAgYnVpbGQtZXNzZW50aWFsIGNsYW5nIGZsZXggYmlzb24gZysrIGdhd2sgXAogICAgZ2NjLW11bHRpbGliIGcrKy1tdWx0aWxpYiBnZXR0ZXh0IGdpdCBsaWJuY3Vyc2VzLWRldiBcCiAgICBsaWJzc2wtZGV2IHB5dGhvbjMtZGlzdHV0aWxzIHB5dGhvbjMtc2V0dXB0b29scyBcCiAgICByc3luYyB1bnppcCB6bGliMWctZGV2IGZpbGUgd2dldCB0aW1lIFwKICAgIHN3aWcgeHNsdHByb2MgXAogICAgY3VybCBjYS1jZXJ0aWZpY2F0ZXMgc3NsLWNlcnQgc3VkbyBcCiAgICAmJiBybSAtcmYgL3Zhci9saWIvYXB0L2xpc3RzLyoKUlVOIHVzZXJhZGQgLW0gLXUgMTAwMCAtcyAvYmluL2Jhc2ggYnVpbGQKV09SS0RJUiAvaG9tZS9idWlsZC9vcGVud3J0ClJVTiBta2RpciAtcCBkbCAmJiBjaG93biAtUiBidWlsZDpidWlsZCAvaG9tZS9idWlsZC9vcGVud3J0CkNPUFkgLS1jaG93bj1idWlsZDpidWlsZCBvcGVuc3NsLmNuZiAvaG9tZS9idWlsZC9vcGVuc3NsLmNuZgpFTlYgT1BFTlNTTF9DT05GPS9ob21lL2J1aWxkL29wZW5zc2wuY25mCg==
:: END_B64_ src.dockerfile

:: BEGIN_B64_ src.dockerfile.legacy
IyBmaWxlOiBzcmNCdWlsZGVyL3NyYy5kb2NrZXJmaWxlLmxlZ2FjeQpGUk9NIHVidW50dToxOC4wNApFTlYgREVCSUFOX0ZST05URU5EPW5vbmludGVyYWN0aXZlClJVTiBhcHQtZ2V0IHVwZGF0ZSAmJiBhcHQtZ2V0IGluc3RhbGwgLXkgXAogICAgYnVpbGQtZXNzZW50aWFsIGNjYWNoZSBlY2ogZmFzdGphciBmaWxlIGcrKyBnYXdrIFwKICAgIGdldHRleHQgZ2l0IGphdmEtcHJvcG9zZS1jbGFzc3BhdGggbGliZWxmLWRldiBsaWJuY3Vyc2VzNS1kZXYgXAogICAgbGlibmN1cnNlc3c1LWRldiBsaWJzc2wtZGV2IHB5dGhvbiBweXRob24yLjctZGV2IHB5dGhvbjMgdW56aXAgd2dldCBcCiAgICByc3luYyBzdWJ2ZXJzaW9uIHN3aWcgdGltZSB4c2x0cHJvYyB6bGliMWctZGV2IFwKICAgIGN1cmwgY2EtY2VydGlmaWNhdGVzIHNzbC1jZXJ0IHN1ZG8gXAogICAgJiYgcm0gLXJmIC92YXIvbGliL2FwdC9saXN0cy8qClJVTiB1c2VyYWRkIC1tIC11IDEwMDAgLXMgL2Jpbi9iYXNoIGJ1aWxkCldPUktESVIgL2hvbWUvYnVpbGQvb3BlbndydApSVU4gbWtkaXIgLXAgZGwgJiYgY2hvd24gLVIgYnVpbGQ6YnVpbGQgL2hvbWUvYnVpbGQvb3BlbndydApDT1BZIC0tY2hvd249YnVpbGQ6YnVpbGQgb3BlbnNzbC5jbmYgL2hvbWUvYnVpbGQvb3BlbnNzbC5jbmYKRU5WIE9QRU5TU0xfQ09ORj0vaG9tZS9idWlsZC9vcGVuc3NsLmNuZgo=
:: END_B64_ src.dockerfile.legacy

:: BEGIN_B64_ openssl.cnf
IyBmaWxlOiBvcGVuc3NsLmNuZgpvcGVuc3NsX2NvbmYgPSBkZWZhdWx0X2NvbmZfc2VjdGlvbgpbZGVmYXVsdF9jb25mX3NlY3Rpb25dCnNzbF9jb25mID0gc3NsX3NlY3QKW3NzbF9zZWN0XQpzeXN0ZW1fZGVmYXVsdCA9IHN5c3RlbV9kZWZhdWx0X3NlY3QKW3N5c3RlbV9kZWZhdWx0X3NlY3RdCk9wdGlvbnMgPSBVbnNhZmVMZWdhY3lSZW5lZ290aWF0aW9uCg==
:: END_B64_ openssl.cnf