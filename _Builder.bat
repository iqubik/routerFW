@echo off
setlocal enabledelayedexpansion
cls
chcp 65001 >nul

:: === КОНФИГУРАЦИЯ ===
:: Режим по умолчанию: IMAGE
set "BUILD_MODE=IMAGE"

echo [INIT] Очистка неиспользуемых сетей Docker...
docker network prune --force >nul 2>&1
echo.

:: === 0. РАСПАКОВКА ===
if exist _unpacker.bat (
    echo [INIT] Проверка распаковщика...
    call _unpacker.bat
)

:: Запоминаем корень проекта
set "PROJECT_DIR=%CD%"

:: === 1. ИНИЦИАЛИЗАЦИЯ ПАПОК ===
call :CHECK_DIR "profiles"
call :CHECK_DIR "custom_files"
call :CHECK_DIR "firmware_output"
call :CHECK_DIR "custom_packages"
call :CHECK_DIR "src_packages"

:MENU
cls
:: Очистка массива профилей
for /F "tokens=1 delims==" %%a in ('set profile[ 2^>nul') do set "%%a="
set "count=0"

:: Настройка интерфейса
if "%BUILD_MODE%"=="IMAGE" (
    color 0B
    set "MODE_TITLE=IMAGE BUILDER (Быстрая сборка)"
    set "OPPOSITE_MODE=SOURCE"
    set "TARGET_VAR=IMAGEBUILDER_URL"
) else (
    color 0D
    set "MODE_TITLE=SOURCE BUILDER (Полная компиляция)"
    set "OPPOSITE_MODE=IMAGE"
    set "TARGET_VAR=SRC_BRANCH"
)

echo ==========================================================
echo  OpenWrt UNIFIED Builder v5.6 (Complete)
echo  Текущий режим: [%MODE_TITLE%]
echo ==========================================================
echo.
echo Все обнаруженные профили:
echo.

:: Убраны все фильтры findstr, чтобы избежать ошибки "drive specified"
for %%f in (profiles\*.conf) do (
    set /a count+=1
    set "profile[!count!]=%%~nxf"
    set "p_id=%%~nf"
    
    :: Создаем папку
    if not exist "custom_files\!p_id!" mkdir "custom_files\!p_id!"
    call :CREATE_PERMS_SCRIPT "!p_id!"
    
    echo    [!count!] %%~nxf
)

echo.
echo    [A] Собрать ВСЕ (Параллельно)
echo    [M] Переключить режим на %OPPOSITE_MODE%
echo    [W] Profile Wizard (Создать профиль)
echo    [R] Обновить список
echo    [0] Выход
echo.
set /p choice="Ваш выбор: "

if /i "%choice%"=="0" exit /b
if /i "%choice%"=="R" goto MENU
if /i "%choice%"=="M" goto SWITCH_MODE
if /i "%choice%"=="W" goto WIZARD
if /i "%choice%"=="A" goto BUILD_ALL

set /a num_choice=%choice% 2>nul
if "%num_choice%"=="0" if not "%choice%"=="0" goto INVALID
if %num_choice% gtr %count% goto INVALID
if %num_choice% lss 1 goto INVALID

:: === ОДИНОЧНАЯ СБОРКА ===
set "SELECTED_CONF=!profile[%choice%]!"
call :BUILD_ROUTINE "%SELECTED_CONF%"
echo Сборка завершена.
pause
goto MENU

:BUILD_ALL
if "%BUILD_MODE%"=="SOURCE" (
    echo.
    echo [WARNING] Массовая компиляция из исходников!
    echo Это займет много времени и ресурсов CPU.
    echo.
    pause
)
echo.
echo === МАССОВЫЙ ЗАПУСК [%BUILD_MODE%] ===
for /L %%i in (1,1,%count%) do (
    set "CURRENT_CONF=!profile[%%i]!"
    call :BUILD_ROUTINE "!CURRENT_CONF!"
)
echo === Окна запущены ===
pause
goto MENU

:SWITCH_MODE
if "%BUILD_MODE%"=="IMAGE" (
    set "BUILD_MODE=SOURCE"
) else (
    set "BUILD_MODE=IMAGE"
)
goto MENU

:WIZARD
cls
echo ==========================================
echo  ЗАПУСК МАСТЕРА СОЗДАНИЯ ПРОФИЛЯ
echo ==========================================
echo.
if exist "create_profile.ps1" (
    powershell -ExecutionPolicy Bypass -File "create_profile.ps1"
    echo.
    echo Мастер завершил работу.
    pause
) else (
    echo [ERROR] Файл create_profile.ps1 не найден!
    pause
)
goto MENU

:INVALID
echo Ошибка ввода.
pause
goto MENU

:: =========================================================
::  CORE BUILDER LOGIC (ОРИГИНАЛЬНАЯ РЕАЛИЗАЦИЯ)
:: =========================================================
:BUILD_ROUTINE
set "CONF_FILE=%~1"
set "PROFILE_ID=%~n1"
set "TARGET_VAL="
set "IS_LEGACY="

echo.
echo ----------------------------------------------------
echo [PROCESSING] Профиль: %CONF_FILE%
echo [MODE]       %BUILD_MODE%
echo ----------------------------------------------------

:: 1. ИЗВЛЕЧЕНИЕ ПЕРЕМЕННОЙ (ОРИГИНАЛЬНЫЙ МЕТОД)
:: Внутри процедуры одиночный findstr работает стабильно
for /f "usebackq tokens=2 delims==" %%a in (`type "profiles\%CONF_FILE%" ^| findstr "%TARGET_VAR%"`) do (
    set "VAL=%%a"
    set "VAL=!VAL:"=!"
    for /f "tokens=* delims= " %%b in ("!VAL!") do set "TARGET_VAL=%%b"
)

if "%TARGET_VAL%"=="" (
    echo [SKIP] %TARGET_VAR% не найден.
    echo Возможно, этот профиль предназначен для другого режима.
    exit /b
)

:: 2. ПРОВЕРКА ВЕРСИИ
echo "!TARGET_VAL!" | findstr /C:"/19." >nul && set IS_LEGACY=1
echo "!TARGET_VAL!" | findstr /C:"/18." >nul && set IS_LEGACY=1
echo "!TARGET_VAL!" | findstr /C:"/17." >nul && set IS_LEGACY=1
echo "!TARGET_VAL!" | findstr /C:"19.07" >nul && set IS_LEGACY=1
echo "!TARGET_VAL!" | findstr /C:"18.06" >nul && set IS_LEGACY=1

:: 3. НАСТРОЙКА DOCKER
if "%BUILD_MODE%"=="IMAGE" (
    :: --- IMAGE BUILDER ---
    set "REL_OUT_PATH=./firmware_output/imagebuilder/%PROFILE_ID%"
    set "PROJ_NAME=build_%PROFILE_ID%"
    set "COMPOSE_ARG="
    
    if DEFINED IS_LEGACY (
        set "SERVICE_NAME=builder-oldwrt"
    ) else (
        set "SERVICE_NAME=builder-openwrt"
    )
) else (
    :: --- SOURCE BUILDER ---
    set "REL_OUT_PATH=./firmware_output/sourcebuilder/%PROFILE_ID%"
    set "PROJ_NAME=srcbuild_%PROFILE_ID%"
    set "COMPOSE_ARG=-f docker-compose-src.yaml"
    
    if DEFINED IS_LEGACY (
        set "SERVICE_NAME=builder-src-oldwrt"
    ) else (
        set "SERVICE_NAME=builder-src-openwrt"
    )
)

:: Создаем папку физически (для Windows нужны обратные слеши)
set "WIN_OUT_PATH=%REL_OUT_PATH:./=%"
set "WIN_OUT_PATH=%WIN_OUT_PATH:/=\%"
if not exist "%WIN_OUT_PATH%" mkdir "%WIN_OUT_PATH%"

echo [LAUNCH] Запуск: %PROFILE_ID%
echo [INFO]   Target: !TARGET_VAL!
echo [INFO]   Service: %SERVICE_NAME%

:: Запуск Docker (Используем оригинальные аргументы и пути с точкой ./)
START "Build: %PROFILE_ID%" /D "%PROJECT_DIR%" cmd /c "set SELECTED_CONF=%CONF_FILE%&& set HOST_FILES_DIR=./custom_files/%PROFILE_ID%&& set HOST_OUTPUT_DIR=%REL_OUT_PATH%&& docker-compose %COMPOSE_ARG% -p %PROJ_NAME% up --build --force-recreate --remove-orphans %SERVICE_NAME% & echo. & echo === WORK FINISHED === & pause"

exit /b

:: =========================================================
::  HELPERS
:: =========================================================
:CHECK_DIR
if not exist "%~1" mkdir "%~1"
exit /b

:CREATE_PERMS_SCRIPT
:: Безопасная версия создания скрипта прав (с проверкой существования)
if exist "custom_files\%~1\etc\uci-defaults\99-permissions.sh" exit /b
if not exist "custom_files\%~1\etc\uci-defaults" mkdir "custom_files\%~1\etc\uci-defaults" >nul 2>&1
set "B64=IyEvYmluL3NoCiMgRml4IFNTSCBwZXJtaXNzaW9ucwpbIC1kIC9ldGMvZHJvcGJZYXIgXSAmJiBjaG1vZCA3MDAgL2V0Yy9kcm9wYmVhcgpbIC1mIC9ldGMvZHJvcGJZYXIvYXV0aG9yaXplZF9rZXlzIF0gJiYgY2htb2QgNjAwIC9ldGMvZHJvcGJZYXIvYXV0aG9yaXplZF9rZXlzCiMgRml4IFNoYWRvdwpbIC1mIC9ldGMvc2hhZG93IF0gJiYgY2htb2QgNjAwIC9ldGMvc2hhZG93CiMgRml4IHJvb3QgU1NIIGtleXMKWyAtZCAvcm9vdC8uc3NoIF0gJiYgY2htb2QgNzAwIC9yb290Ly5zc2gKWyAtZiAvcm9vdC8uc3NoL2lkX3JzYSBdICYmIGNobW9kIDYwMCAvcm9vdC8uc3NoL2lkX3JzYQpleGl0IDAK"
powershell -Command "[IO.File]::WriteAllBytes('custom_files\%~1\etc\uci-defaults\99-permissions.sh', [Convert]::FromBase64String('%B64%'))" >nul 2>&1
exit /b