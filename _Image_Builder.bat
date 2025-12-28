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
call :CHECK_DIR "custom_packages"
call :CHECK_DIR "custom_files"
call :CHECK_DIR "firmware_output"

:MENU
rem cls
echo ========================================
echo  OpenWrt IMAGE Builder v5.0 (iqubik)
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
echo    [S] Переключиться на SOURCE Builder
echo    [R] Обновить список профилей
echo    [0] Выход
echo.
set /p choice="Выберите опцию: "

if /i "%choice%"=="0" exit /b
if /i "%choice%"=="A" goto BUILD_ALL
if /i "%choice%"=="S" goto SWITCH_TO_SOURCE
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

:SWITCH_TO_SOURCE
if exist "_Source_Builder.bat" (
    start "" "_Source_Builder.bat"
    exit
) else (
    echo [ERROR] Файл _Source_Builder.bat не найден!
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

set "URL_CLEAN="
for /f "usebackq tokens=2 delims==" %%a in (`type "profiles\%CONF_FILE%" ^| findstr "IMAGEBUILDER_URL"`) do (
    set "VAL=%%a"
    set "VAL=!VAL:"=!"
    for /f "tokens=* delims= " %%b in ("!VAL!") do set "URL_CLEAN=%%b"
)

if "%URL_CLEAN%"=="" (
    echo [INFO] IMAGEBUILDER_URL не найден в %CONF_FILE%. Пропускается для ImageBuilder.
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

:: Создаем структуру папок: firmware_output -> imagebuilder -> имя_профиля
if not exist "firmware_output\imagebuilder\%PROFILE_ID%" (
    if not exist "firmware_output\imagebuilder" mkdir "firmware_output\imagebuilder"
    mkdir "firmware_output\imagebuilder\%PROFILE_ID%"
)

echo [LAUNCH] Запуск окна для: %PROFILE_ID%...
echo [DEBUG] URL определен как: !URL_CLEAN!

START "Build: %PROFILE_ID%" /D "%PROJECT_DIR%" cmd /c "set SELECTED_CONF=%CONF_FILE%&& set HOST_FILES_DIR=./custom_files/%PROFILE_ID%&& set HOST_OUTPUT_DIR=./firmware_output/imagebuilder/%PROFILE_ID%&& docker-compose -p build_%PROFILE_ID% up --build --force-recreate --remove-orphans %BUILDER_SERVICE% & echo. & echo === WORK FINISHED === & pause"

exit /b

:: =========================================================
::  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
:: =========================================================
:CHECK_DIR
if not exist "%~1" mkdir "%~1"
exit /b

:CREATE_PERMS_SCRIPT
set "P_ID=%~1"
set "PERM_FILE=custom_files\%P_ID%\etc\uci-defaults\99-permissions.sh"
if exist "%PERM_FILE%" exit /b
powershell -Command "[System.IO.Directory]::CreateDirectory('custom_files\%P_ID%\etc\uci-defaults')" >nul 2>&1
set "B64=IyEvYmluL3NoCiMgRml4IFNTSCBwZXJtaXNzaW9ucwpbIC1kIC9ldGMvZHJvcGJZYXIgXSAmJiBjaG1vZCA3MDAgL2V0Yy9kcm9wYmVhcgpbIC1mIC9ldGMvZHJvcGJZYXIvYXV0aG9yaXplZF9rZXlzIF0gJiYgY2htb2QgNjAwIC9ldGMvZHJvcGJZYXIvYXV0aG9yaXplZF9rZXlzCiMgRml4IFNoYWRvdwpbIC1mIC9ldGMvc2hhZG93IF0gJiYgY2htb2QgNjAwIC9ldGMvc2hhZG93CiMgRml4IHJvb3QgU1NIIGtleXMKWyAtZCAvcm9vdC8uc3NoIF0gJiYgY2htb2QgNzAwIC9yb290Ly5zc2gKWyAtZiAvcm9vdC8uc3NoL2lkX3JzYSBdICYmIGNobW9kIDYwMCAvcm9vdC8uc3NoL2lkX3JzYQpleGl0IDAK"
powershell -Command "[IO.File]::WriteAllBytes('%PERM_FILE%', [Convert]::FromBase64String('%B64%'))"
exit /b