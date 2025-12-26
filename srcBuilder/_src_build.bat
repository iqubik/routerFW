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
call :CHECK_DIR "src_profiles"
call :CHECK_DIR "custom_files"
call :CHECK_DIR "firmware_output"
call :CHECK_DIR "custom_packages"

:: === 2. ПРОВЕРКА НАЛИЧИЯ ПРОФИЛЕЙ ===
if not exist "src_profiles\*.conf" (
    echo.
    echo [INIT] Папка 'src_profiles' пуста. Создаю пример профиля...
    call :CREATE_EXAMPLE_PROFILE
    echo [INFO] Файл 'src_profiles\example_source_mt7621.conf' создан.
)

:MENU
cls
echo ========================================
echo  OpenWrt SOURCE Builder v0.9 (iqubik)
echo ========================================
echo.
echo Обнаруженные Source-профили:
echo.

set count=0
for %%f in (src_profiles\*.conf) do (
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
for /f "usebackq tokens=2 delims==" %%a in (`type "src_profiles\%CONF_FILE%" ^| findstr "SRC_BRANCH"`) do (
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
set "FN=src_profiles\example_source_mt7621.conf"
(
    echo # === Example Source Profile for Xiaomi 4A Gigabit ===
    echo PROFILE_NAME="xiaomi_4a_src"
    echo # Repo Settings
    echo SRC_REPO="https://github.com/openwrt/openwrt.git"
    echo SRC_BRANCH="openwrt-23.05"
    echo # Target Settings ^(Look at OpenWrt Table of Hardware^)
    echo SRC_TARGET="ramips"
    echo SRC_SUBTARGET="mt7621"
    echo SRC_DEVICE="xiaomi_mi-router-4a-gigabit"
    echo # Packages ^(Space separated, -pkg to remove^)
    echo SRC_PACKAGES="luci uhttpd openssh-sftp-server htop"
    echo # Extra config options ^(optional^)
    echo SRC_ROOTFS_SIZE=""
    echo SRC_KERNEL_SIZE=""
) > "%FN%"
exit /b

:: СЕКЦИЯ ДЛЯ BASE64 КОДА
:: BEGIN_B64_ docker-compose-src.yaml

:: END_B64_ docker-compose-src.yaml

:: BEGIN_B64_ src.dockerfile

:: END_B64_ src.dockerfile

:: BEGIN_B64_ src.dockerfile.legacy

:: END_B64_ src.dockerfile.legacy

:: BEGIN_B64_ openssl.cnf

:: END_B64_ openssl.cnf