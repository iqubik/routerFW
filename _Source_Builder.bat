@echo off
setlocal enabledelayedexpansion
cls
chcp 65001 >nul

echo [INIT] Очистка неиспользуемых сетей Docker...
docker network prune --force
echo.

:: === 0. РАСПАКОВКА ВСТРОЕННЫХ ФАЙЛОВ ===
if exist _unpacker.bat (
    echo [INIT] Обнаружен универсальный распаковщик...
    call _unpacker.bat
)

:: Запоминаем текущую папку
set "PROJECT_DIR=%CD%"

:: === 1. ИНИЦИАЛИЗАЦИЯ ПАПОК ===
call :CHECK_DIR "profiles"
call :CHECK_DIR "custom_files"
call :CHECK_DIR "firmware_output"
call :CHECK_DIR "src_packages"
call :CHECK_DIR "custom_packages"

:MENU
cls
echo ========================================
echo  OpenWrt SOURCE Builder v1.5 (iqubik)
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
    call :CREATE_PERMS_SCRIPT "!p_id!"    
    echo    [!count!] %%~nxf
)

echo.
echo    [A] Собрать ВСЕ профили (Параллельно)
echo    [S] Переключиться на IMAGE Builder
echo    [R] Обновить список профилей
echo    [0] Выход
echo.
set /p choice="Выберите опцию: "

if /i "%choice%"=="0" exit /b
if /i "%choice%"=="A" goto BUILD_ALL
if /i "%choice%"=="S" goto SWITCH_TO_IMAGE
if /i "%choice%"=="R" goto MENU

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

:SWITCH_TO_IMAGE
if exist "_Image_Builder.bat" (
    start "" "_Image_Builder.bat"
    exit
) else (
    echo [ERROR] Файл _Image_Builder.bat не найден!
    pause
    goto MENU
)

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
    echo [INFO] SRC_BRANCH не найден в %CONF_FILE%. Пропускается для SourceBuilder.
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
    if not exist "firmware_output\sourcebuilder" mkdir "firmware_output\sourcebuilder"
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
powershell -Command "[System.IO.Directory]::CreateDirectory('custom_files\%P_ID%\etc\uci-defaults')" >nul 2>&1
set "B64=IyEvYmluL3NoCiMgRml4IFNTSCBwZXJtaXNzaW9ucwpbIC1kIC9ldGMvZHJvcGJZYXIgXSAmJiBjaG1vZCA3MDAgL2V0Yy9kcm9wYmVhcgpbIC1mIC9ldGMvZHJvcGJZYXIvYXV0aG9yaXplZF9rZXlzIF0gJiYgY2htb2QgNjAwIC9ldGMvZHJvcGJZYXIvYXV0aG9yaXplZF9rZXlzCiMgRml4IFNoYWRvdwpbIC1mIC9ldGMvc2hhZG93IF0gJiYgY2htb2QgNjAwIC9ldGMvc2hhZG93CiMgRml4IHJvb3QgU1NIIGtleXMKWyAtZCAvcm9vdC8uc3NoIF0gJiYgY2htb2QgNzAwIC9yb290Ly5zc2gKWyAtZiAvcm9vdC8uc3NoL2lkX3JzYSBdICYmIGNobW9kIDYwMCAvcm9vdC8uc3NoL2lkX3JzYQpleGl0IDAK"
powershell -Command "[IO.File]::WriteAllBytes('%PERM_FILE%', [Convert]::FromBase64String('%B64%'))"
exit /b

:CHECK_DIR
if not exist "%~1" mkdir "%~1"
exit /b