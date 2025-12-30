@echo off
setlocal enabledelayedexpansion
cls
chcp 65001 >nul

:: === КОНФИГУРАЦИЯ ПО УМОЛЧАНИЮ ===
:: Режимы: IMAGE или SOURCE
set "BUILD_MODE=IMAGE"

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

:: === 1. ИНИЦИАЛИЗАЦИЯ ВСЕХ ПАПОК ===
call :CHECK_DIR "profiles"
call :CHECK_DIR "custom_files"
call :CHECK_DIR "firmware_output"
call :CHECK_DIR "custom_packages"
:: Создаем папку src, даже если мы в Image режиме (на будущее)
call :CHECK_DIR "src_packages"

:MENU
cls
:: Настройка переменных интерфейса в зависимости от режима
if "%BUILD_MODE%"=="IMAGE" (
    set "MODE_TITLE=IMAGE BUILDER (Быстрая сборка)"
    set "MODE_COLOR=92"
    set "OPPOSITE_MODE=SOURCE"
    set "TARGET_VAR=IMAGEBUILDER_URL"
) else (
    set "MODE_TITLE=SOURCE BUILDER (Компиляция)"
    set "MODE_COLOR=96"
    set "OPPOSITE_MODE=IMAGE"
    set "TARGET_VAR=SRC_BRANCH"
)

:: Меняем цвет консоли для визуального отличия (опционально)
:: color %MODE_COLOR% 

echo ==========================================================
echo  OpenWrt UNIFIED Builder v5.0 (iqubik)
echo  Текущий режим: [%MODE_TITLE%]
echo ==========================================================
echo.
echo Обнаруженные профили для режима %BUILD_MODE%:
echo.

set count=0
:: Сброс массива профилей перед сканированием
for /F "tokens=1 delims==" %%a in ('set profile[ 2^>nul') do set "%%a="

for %%f in (profiles\*.conf) do (
    set "show_profile=0"
    
    :: Проверяем, подходит ли профиль для текущего режима
    findstr /C:"%TARGET_VAR%" "%%f" >nul && set "show_profile=1"
    
    if "!show_profile!"=="1" (
        set /a count+=1
        set "profile[!count!]=%%~nxf"
        set "p_id=%%~nf"
        
        :: Создаем структуру и права для всех профилей сразу
        if not exist "custom_files\!p_id!" mkdir "custom_files\!p_id!"
        call :CREATE_PERMS_SCRIPT "!p_id!"
        
        echo    [!count!] %%~nxf
    )
)

if %count%==0 echo    [INFO] Нет профилей с параметром %TARGET_VAR%
echo.
echo    [A] Собрать ВСЕ видимые профили
echo    [M] Переключить режим на %OPPOSITE_MODE%
echo    [R] Обновить список
echo    [0] Выход
echo.
set /p choice="Выберите опцию: "

if /i "%choice%"=="0" exit /b
if /i "%choice%"=="R" goto MENU
if /i "%choice%"=="M" goto SWITCH_MODE
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
    echo [WARNING] Вы запускаете массовую компиляцию из исходников.
    echo Это может занять несколько часов и загрузить CPU на 100%%.
    echo.
    pause
)
echo.
echo === ЗАПУСК ПАРАЛЛЕЛЬНОЙ СБОРКИ [%BUILD_MODE%] ===
for /L %%i in (1,1,%count%) do (
    set "CURRENT_CONF=!profile[%%i]!"
    call :BUILD_ROUTINE "!CURRENT_CONF!"
)
echo.
echo === ВСЕ ЗАДАЧИ ЗАПУЩЕНЫ ===
pause
goto MENU

:SWITCH_MODE
if "%BUILD_MODE%"=="IMAGE" (
    set "BUILD_MODE=SOURCE"
) else (
    set "BUILD_MODE=IMAGE"
)
goto MENU

:INVALID
echo Неверный выбор!
pause
goto MENU

:: =========================================================
::  УНИВЕРСАЛЬНАЯ ПОДПРОГРАММА СБОРКИ
:: =========================================================
:BUILD_ROUTINE
set "CONF_FILE=%~1"
set "PROFILE_ID=%~n1"

echo.
echo ----------------------------------------------------
echo [PROCESSING] Профиль: %CONF_FILE%
echo [MODE]       %BUILD_MODE%
echo ----------------------------------------------------

:: 1. Чтение целевой переменной в зависимости от режима
set "TARGET_VAL="
for /f "usebackq tokens=2 delims==" %%a in (`type "profiles\%CONF_FILE%" ^| findstr "%TARGET_VAR%"`) do (
    set "VAL=%%a"
    set "VAL=!VAL:"=!"
    for /f "tokens=* delims= " %%b in ("!VAL!") do set "TARGET_VAL=%%b"
)

if "%TARGET_VAL%"=="" (
    echo [ERROR] Переменная %TARGET_VAR% не найдена или пуста!
    exit /b
)

:: 2. Определение Legacy версий (Объединенная логика)
set "IS_LEGACY="
:: Общие проверки для версий 17, 18, 19
echo "!TARGET_VAL!" | findstr /C:"19." >nul && set IS_LEGACY=1
echo "!TARGET_VAL!" | findstr /C:"18." >nul && set IS_LEGACY=1
echo "!TARGET_VAL!" | findstr /C:"17." >nul && set IS_LEGACY=1

:: 3. Настройка параметров Docker в зависимости от режима
if "%BUILD_MODE%"=="IMAGE" (
    :: --- Настройки Image Builder ---
    set "OUT_DIR=firmware_output\imagebuilder\%PROFILE_ID%"
    set "COMPOSE_ARG="  
    :: ^ Пусто, используется дефолтный docker-compose.yml
    
    if DEFINED IS_LEGACY (
        set "SERVICE_NAME=builder-oldwrt"
    ) else (
        set "SERVICE_NAME=builder-openwrt"
    )
    set "PROJ_NAME=build_%PROFILE_ID%"
    
) else (
    :: --- Настройки Source Builder ---
    set "OUT_DIR=firmware_output\sourcebuilder\%PROFILE_ID%"
    set "COMPOSE_ARG=-f docker-compose-src.yaml"
    
    if DEFINED IS_LEGACY (
        set "SERVICE_NAME=builder-src-oldwrt"
    ) else (
        set "SERVICE_NAME=builder-src-openwrt"
    )
    set "PROJ_NAME=srcbuild_%PROFILE_ID%"
)

:: Создаем выходную папку
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

echo [LAUNCH] Запуск контейнера для: %PROFILE_ID%
echo [DEBUG] Target: !TARGET_VAL! (Legacy: !IS_LEGACY!)
echo [DEBUG] Service: %SERVICE_NAME%

:: Запуск Docker
START "Builder: %PROFILE_ID% [%BUILD_MODE%]" /D "%PROJECT_DIR%" cmd /c "set SELECTED_CONF=%CONF_FILE%&& set HOST_FILES_DIR=./custom_files/%PROFILE_ID%&& set HOST_OUTPUT_DIR=./%OUT_DIR:.=/%&& docker-compose %COMPOSE_ARG% -p %PROJ_NAME% up --build --force-recreate --remove-orphans %SERVICE_NAME% & echo. & echo === WORK FINISHED === & pause"

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