@echo off
setlocal enabledelayedexpansion
cls
chcp 65001 >nul

:: === КОНФИГУРАЦИЯ ===
:: Режим по умолчанию: IMAGE
set "BUILD_MODE=IMAGE"

echo [INIT] Проверка окружения...

:: [AUDIT FIX] Проверка Docker
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker не обнаружен!
    echo Убедитесь, что Docker Desktop установлен и запущен.
    echo.
    pause
    exit /b
)

:: [AUDIT FIX] Проверка docker-compose
docker-compose --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] docker-compose не найден в PATH!
    pause
    exit /b
)

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
for %%I in (.) do set "DIR_NAME=%%~nxI"

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

echo =================================================================
echo  OpenWrt FW Builder v3.57 https://github.com/iqubik/routerFW
echo  Текущий режим: [%MODE_TITLE%]
echo =================================================================
echo.
echo Профили сборки:
echo.

:: === ЦИКЛ СКАНИРОВАНИЯ ===
for %%f in (profiles\*.conf) do (
    set /a count+=1
    set "profile[!count!]=%%~nxf"
    set "p_id=%%~nf"
    :: Создаем папку и права (Race condition исключен последовательным запуском)
    if not exist "custom_files\!p_id!" mkdir "custom_files\!p_id!"
    call :CREATE_PERMS_SCRIPT "!p_id!"
    echo    [!count!] %%~nxf
)

echo.
echo    [A] Собрать ВСЕ (Параллельно)
echo    [M] Переключить режим на %OPPOSITE_MODE%
echo    [C] CLEAN / MAINTENANCE (Очистка кэша)
if "%BUILD_MODE%"=="SOURCE" (
    echo    [K] MENUCONFIG (Настройка ядра/пакетов)
)
echo    [W] Profile Wizard (Создать профиль)
echo    [0] Выход
echo.
set "choice="
set /p choice="Ваш выбор: "

:: Если нажали Enter (пусто), просто обновляем меню
if "%choice%"=="" goto MENU
if /i "%choice%"=="0" exit /b
if /i "%choice%"=="R" goto MENU
if /i "%choice%"=="M" goto SWITCH_MODE
if /i "%choice%"=="W" goto WIZARD
if "%BUILD_MODE%"=="SOURCE" (
    if /i "%choice%"=="K" goto MENUCONFIG_SELECTION
)
if /i "%choice%"=="C" goto CLEAN_MENU
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
    pause
)
echo.
echo === МАССОВЫЙ ЗАПУСК [%BUILD_MODE%] ===
for /L %%i in (1,1,%count%) do (
    set "CURRENT_CONF=!profile[%%i]!"
    call :BUILD_ROUTINE "!CURRENT_CONF!"
)
echo === Процессы запущены ===
pause
goto MENU

:SWITCH_MODE
if "%BUILD_MODE%"=="IMAGE" (
    set "BUILD_MODE=SOURCE"
) else (
    set "BUILD_MODE=IMAGE"
)
goto MENU

:: =========================================================
::  NEW CLEANUP WIZARD (GRANULAR CONTROL)
:: =========================================================
:CLEAN_MENU
cls
color 0E
echo ==========================================================
echo  МЕНЮ ОЧИСТКИ И ОБСЛУЖИВАНИЯ [%BUILD_MODE%]
echo ==========================================================
echo.
echo  Выберите тип данных для очистки:
echo.

if "%BUILD_MODE%"=="SOURCE" goto VIEW_SRC_MENU

:VIEW_IMG_MENU
echo    [1] Очистить кэш ImageBuilder (SDK)
echo        (Архив с ядрами и пакетами от OpenWrt)
echo.
echo    [2] Очистить кэш пакетов (IPK)
echo        (Папка dl/ с загруженными пакетами)
echo.
echo    [3] FULL FACTORY RESET (Сброс проекта)
echo        (Удалить все кэши для выбранного профиля)
goto VIEW_COMMON

:VIEW_SRC_MENU
echo    [1] SOFT CLEAN (make clean)
echo        (Очистка бинарников внутри контейнера.
echo         Сохраняет Toolchain, удаляет собранную прошивку)
echo.
echo    [2] HARD RESET (Удалить src-workdir)
echo        (Удаляет исходный код и Toolchain.
echo         Используйте, если сломался компилятор или git)
echo.
echo    [3] Очистить кэш исходников (dl)
echo        (Удаляет скачанные архивы исходного кода.
echo         Безопасно удалять, если нужно освободить много места)
echo.
echo    [4] Очистить CCACHE
echo        (Сброс кэша компилятора)
echo.
echo    [5] FULL FACTORY RESET (Сброс проекта)
echo        (Удаляет абсолютно все данные для профиля)

:VIEW_COMMON
echo.
echo    [9] Prune Docker (Глобальная очистка мусора Docker)
echo    [0] Назад в главное меню
echo.
set "clean_choice="
set /p clean_choice="Ваш выбор: "

if "%clean_choice%"=="" goto CLEAN_MENU
if "%clean_choice%"=="0" goto MENU
if "%clean_choice%"=="9" (
    echo.
    echo [DOCKER] Выполняю system prune...
    docker system prune -f
    pause
    goto CLEAN_MENU
)

:: --- НАСТРОЙКА ПАРАМЕТРОВ ОЧИСТКИ ---
set "CLEAN_TYPE="
set "CLEAN_DESC="

if "%BUILD_MODE%"=="IMAGE" (
    if "%clean_choice%"=="1" set "CLEAN_TYPE=IMG_SDK" & set "CLEAN_DESC=ImageBuilder Cache"
    if "%clean_choice%"=="2" set "CLEAN_TYPE=IMG_IPK" & set "CLEAN_DESC=IPK Cache"
    if "%clean_choice%"=="3" set "CLEAN_TYPE=IMG_ALL" & set "CLEAN_DESC=FULL RESET (Image)"
)

if "%BUILD_MODE%"=="SOURCE" (
    if "%clean_choice%"=="1" set "CLEAN_TYPE=SRC_SOFT" & set "CLEAN_DESC=Soft Clean (make clean)"
    if "%clean_choice%"=="2" set "CLEAN_TYPE=SRC_WORK" & set "CLEAN_DESC=Workdir (Toolchain)"
    if "%clean_choice%"=="3" set "CLEAN_TYPE=SRC_DL"   & set "CLEAN_DESC=DL Cache"
    if "%clean_choice%"=="4" set "CLEAN_TYPE=SRC_CCACHE" & set "CLEAN_DESC=CCache"
    if "%clean_choice%"=="5" set "CLEAN_TYPE=SRC_ALL"  & set "CLEAN_DESC=FULL RESET (Source)"
)

if "%CLEAN_TYPE%"=="" goto INVALID
goto SELECT_PROFILE_FOR_CLEAN

:: =========================================================
::  ВЫБОР ПРОФИЛЯ ДЛЯ ОЧИСТКИ
:: =========================================================
:SELECT_PROFILE_FOR_CLEAN
cls
echo ==========================================================
echo  ОЧИСТКА: %CLEAN_DESC%
echo ==========================================================
echo.
echo  Для какого профиля выполнить очистку?
echo.

:: Выводим список профилей (используем массив из главного меню)
for /L %%i in (1,1,%count%) do (
    echo    [%%i] !profile[%%i]!
)
echo.
echo    [A] ДЛЯ ВСЕХ ПРОФИЛЕЙ (Глобальная очистка)
echo    [0] Отмена
echo.

set "p_choice="
set /p p_choice="Выберите профиль или A: "

if "%p_choice%"=="" goto SELECT_PROFILE_FOR_CLEAN
if /i "%p_choice%"=="0" goto CLEAN_MENU
if /i "%p_choice%"=="A" (
    set "TARGET_PROFILE_ID=ALL"
    set "TARGET_PROFILE_NAME=ALL PROFILES"
    goto CONFIRM_CLEAN
)

:: Проверка ввода числа
set /a num_p_choice=%p_choice% 2>nul
if %num_p_choice% gtr %count% goto SELECT_PROFILE_FOR_CLEAN
if %num_p_choice% lss 1 goto SELECT_PROFILE_FOR_CLEAN

set "TARGET_PROFILE_NAME=!profile[%p_choice%]!"
set "TARGET_PROFILE_ID=!profile[%p_choice%]:.conf=!"

:CONFIRM_CLEAN
echo.
if "%TARGET_PROFILE_ID%"=="ALL" color 0C
echo Выбрано: %CLEAN_DESC%
echo Цель:    %TARGET_PROFILE_NAME%
echo.
if "%TARGET_PROFILE_ID%"=="ALL" echo ВНИМАНИЕ: Это удалит данные для ВСЕХ профилей!
echo.
set "confirm="
set /p confirm="Введите YES для подтверждения: "

:: Если нажали Enter или ввели не YES - отмена
if /i not "!confirm!"=="YES" goto CLEAN_MENU

color 0E
echo.
echo [CLEAN] Запуск процедуры...

:: === МАРШРУТИЗАЦИЯ ВЫПОЛНЕНИЯ ===
if "%CLEAN_TYPE%"=="SRC_SOFT" goto EXEC_SRC_SOFT
if "%CLEAN_TYPE%"=="SRC_WORK" goto EXEC_SRC_WORK
if "%CLEAN_TYPE%"=="SRC_DL"   goto EXEC_SRC_DL
if "%CLEAN_TYPE%"=="SRC_CCACHE" goto EXEC_SRC_CCACHE
if "%CLEAN_TYPE%"=="SRC_ALL"  goto EXEC_SRC_ALL

if "%CLEAN_TYPE%"=="IMG_SDK"  goto EXEC_IMG_SDK
if "%CLEAN_TYPE%"=="IMG_IPK"  goto EXEC_IMG_IPK
if "%CLEAN_TYPE%"=="IMG_ALL"  goto EXEC_IMG_ALL

goto CLEAN_MENU

:: =========================================================
::  ИСПОЛНИТЕЛЬНЫЕ БЛОКИ (EXECUTION)
:: =========================================================

:: --- ХЕЛПЕР ДЛЯ УДАЛЕНИЯ ТОМОВ ---
:: %1 - Часть имени тома (например src-workdir)
:: %2 - Профиль (или ALL)
:HELPER_DEL_VOLUME
set "V_TAG=%~1"
set "P_ID=%~2"

if "%P_ID%"=="ALL" (
    echo   Поиск всех томов с меткой: %V_TAG%
    for /f "tokens=*" %%v in ('docker volume ls -q -f "name=%V_TAG%"') do (
        echo   Удаление: %%v
        docker volume rm %%v >nul 2>&1
    )
) else (
    echo   Поиск тома для профиля: %P_ID% ... %V_TAG%
    :: Ищем том, который содержит И имя профиля, И тег типа
    for /f "tokens=*" %%v in ('docker volume ls -q ^| findstr "%P_ID%" ^| findstr "%V_TAG%"') do (
        echo   Удаление: %%v
        docker volume rm %%v
    )
)
exit /b

:: --- ХЕЛПЕР ДЛЯ СНЯТИЯ БЛОКИРОВОК (Удаление контейнеров) ---
:HELPER_RELEASE_LOCKS
set "P_ID=%~1"

:: Настройка заглушек для docker-compose
set "SELECTED_CONF=dummy"
set "HOST_FILES_DIR=./custom_files"
set "HOST_OUTPUT_DIR=./firmware_output"

if "%P_ID%"=="ALL" goto REL_ALL
goto REL_SINGLE

:REL_ALL
echo   [LOCK] Снятие блокировок со всех контейнеров (удаление)...
if "%BUILD_MODE%"=="IMAGE" goto REL_ALL_IMG
goto REL_ALL_SRC

:REL_ALL_IMG
for /f "tokens=*" %%c in ('docker ps -aq -f "name=builder-openwrt"') do docker rm -f %%c >nul 2>&1
for /f "tokens=*" %%c in ('docker ps -aq -f "name=builder-oldwrt"') do docker rm -f %%c >nul 2>&1
exit /b

:REL_ALL_SRC
for /f "tokens=*" %%c in ('docker ps -aq -f "name=builder-src"') do docker rm -f %%c >nul 2>&1
exit /b

:REL_SINGLE
echo   [LOCK] Освобождение контейнера профиля %P_ID%...
if "%BUILD_MODE%"=="IMAGE" goto REL_SINGLE_IMG
goto REL_SINGLE_SRC

:REL_SINGLE_IMG
set "PROJ_NAME=build_%P_ID%"
:: Используем !PROJ_NAME! так как enabledelayedexpansion включено
docker-compose -f system/docker-compose.yaml -p !PROJ_NAME! down >nul 2>&1
exit /b

:REL_SINGLE_SRC
set "PROJ_NAME=srcbuild_%P_ID%"
docker-compose -f system/docker-compose-src.yaml -p !PROJ_NAME! down >nul 2>&1
exit /b

:: --- SOURCE ACTIONS ---

:EXEC_SRC_SOFT
:: Soft Clean требует наличия контейнера, поэтому здесь мы НЕ вызываем RELEASE_LOCKS
if "%TARGET_PROFILE_ID%"=="ALL" (
    echo [ERROR] Soft Clean не поддерживается для режима ALL.
    echo Это займет слишком много времени. Выполняйте по одному.
    pause
    goto CLEAN_MENU
)
echo [CLEAN] Запуск контейнера %TARGET_PROFILE_ID% для make clean...
:: Настраиваем переменные для docker-compose
set "SELECTED_CONF=%TARGET_PROFILE_NAME%"
set "HOST_FILES_DIR=./custom_files/%TARGET_PROFILE_ID%"
set "HOST_OUTPUT_DIR=./firmware_output/sourcebuilder/%TARGET_PROFILE_ID%"
set "PROJ_NAME=srcbuild_%TARGET_PROFILE_ID%"

:: Запускаем (добавляем CCACHE_DIR=dummy на всякий случай, если он не задан в yaml по умолчанию)
docker-compose -f system/docker-compose-src.yaml -p %PROJ_NAME% run --rm builder-src-openwrt /bin/bash -c "cd /home/build/openwrt && if [ -f Makefile ]; then make clean; echo 'Make Clean Completed'; else echo 'Makefile not found'; fi"
pause
goto CLEAN_MENU

:EXEC_SRC_WORK
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "src-workdir" "%TARGET_PROFILE_ID%"
echo [INFO] Рабочая директория очищена. Исходники (DL) сохранены.
pause
goto CLEAN_MENU

:EXEC_SRC_DL
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "src-dl-cache" "%TARGET_PROFILE_ID%"
echo [INFO] Кэш загрузок очищен.
pause
goto CLEAN_MENU

:EXEC_SRC_CCACHE
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "src-ccache" "%TARGET_PROFILE_ID%"
echo [INFO] Кэш компилятора очищен.
pause
goto CLEAN_MENU

:EXEC_SRC_ALL
echo [CLEAN] Полный сброс SourceBuilder для %TARGET_PROFILE_ID%...
:: Здесь используем down -v (или принудительное удаление), так как чистим всё
if not "%TARGET_PROFILE_ID%"=="ALL" (
    set "PROJ_NAME=srcbuild_%TARGET_PROFILE_ID%"
    :: Переменные-заглушки
    set "SELECTED_CONF=dummy"
    set "HOST_FILES_DIR=./custom_files" 
    set "HOST_OUTPUT_DIR=./firmware_output"
    docker-compose -f system/docker-compose-src.yaml -p !PROJ_NAME! down -v >nul 2>&1
) else (
    :: Сначала убиваем контейнеры
    call :HELPER_RELEASE_LOCKS "ALL"
)

:: Дочищаем тома, если что-то осталось
call :HELPER_DEL_VOLUME "src-workdir" "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "src-dl-cache" "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "src-ccache" "%TARGET_PROFILE_ID%"
echo [INFO] Полная очистка завершена.
pause
goto CLEAN_MENU

:: --- IMAGE ACTIONS ---

:EXEC_IMG_SDK
:: Сначала освобождаем контейнер, иначе том занят
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "imagebuilder-cache" "%TARGET_PROFILE_ID%"
echo [INFO] SDK очищен.
pause
goto CLEAN_MENU

:EXEC_IMG_IPK
:: Сначала освобождаем контейнер
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "ipk-cache" "%TARGET_PROFILE_ID%"
echo [INFO] Кэш IPK пакетов очищен.
pause
goto CLEAN_MENU

:EXEC_IMG_ALL
echo [CLEAN] Полный сброс ImageBuilder для %TARGET_PROFILE_ID%...
if not "%TARGET_PROFILE_ID%"=="ALL" (
    set "PROJ_NAME=build_%TARGET_PROFILE_ID%"
    set "SELECTED_CONF=dummy"
    set "HOST_FILES_DIR=./custom_files"
    set "HOST_OUTPUT_DIR=./firmware_output"
    docker-compose -f system/docker-compose.yaml -p !PROJ_NAME! down -v >nul 2>&1
) else (
    call :HELPER_RELEASE_LOCKS "ALL"
)

call :HELPER_DEL_VOLUME "imagebuilder-cache" "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "ipk-cache" "%TARGET_PROFILE_ID%"
echo [INFO] Полная очистка завершена.
pause
goto CLEAN_MENU

:WIZARD
cls
echo ==========================================
echo  ЗАПУСК МАСТЕРА СОЗДАНИЯ ПРОФИЛЯ
echo ==========================================
echo.
if exist "system/create_profile.ps1" (
    powershell -ExecutionPolicy Bypass -File "system/create_profile.ps1"
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
::  MENUCONFIG SECTION
:: =========================================================
:MENUCONFIG_SELECTION
if not "%BUILD_MODE%"=="SOURCE" goto MENU
cls
echo ==========================================================
echo  MENUCONFIG INTERACTIVE
echo ==========================================================
echo.
echo  Внимание: Menuconfig сработает, только если исходники уже
echo  были скачаны (вы запускали сборку этого профиля ранее).
echo.
echo  Выберите профиль для настройки:
echo.

for /L %%i in (1,1,%count%) do (
    echo    [%%i] !profile[%%i]!
)
echo.
echo    [0] Отмена
echo.

set "k_choice="
set /p k_choice="Ваш выбор: "

if "%k_choice%"=="" goto MENUCONFIG_SELECTION
if "%k_choice%"=="0" goto MENU

set /a num_k_choice=%k_choice% 2>nul
if %num_k_choice% gtr %count% goto MENUCONFIG_SELECTION
if %num_k_choice% lss 1 goto MENUCONFIG_SELECTION

call :EXEC_MENUCONFIG "!profile[%k_choice%]!"
goto MENU

:EXEC_MENUCONFIG
set "CONF_FILE=%~1"
set "PROFILE_ID=%~n1"
set "TARGET_VAL="
set "IS_LEGACY="
set "SELECTED_CONF=%CONF_FILE%"

echo.
echo [SETUP] Подготовка окружения для %PROFILE_ID%...

:: 1. Определение версии
for /f "usebackq tokens=2 delims==" %%a in (`type "profiles\%CONF_FILE%" ^| findstr "%TARGET_VAR%"`) do (
    set "VAL=%%a"
    set "VAL=!VAL:"=!"
    for /f "tokens=* delims= " %%b in ("!VAL!") do set "TARGET_VAL=%%b"
)
echo "!TARGET_VAL!" | findstr /C:"/19." >nul && set IS_LEGACY=1
echo "!TARGET_VAL!" | findstr /C:"/18." >nul && set IS_LEGACY=1
echo "!TARGET_VAL!" | findstr /C:"/17." >nul && set IS_LEGACY=1
echo "!TARGET_VAL!" | findstr /C:"19.07" >nul && set IS_LEGACY=1

:: 2. Настройка переменных
set "REL_OUT_PATH=./firmware_output/sourcebuilder/%PROFILE_ID%"
set "PROJ_NAME=srcbuild_%PROFILE_ID%"
set "HOST_FILES_DIR=./custom_files/%PROFILE_ID%"
set "HOST_OUTPUT_DIR=%REL_OUT_PATH%"
set "WIN_OUT_PATH=%REL_OUT_PATH:./=%"
set "WIN_OUT_PATH=%WIN_OUT_PATH:/=\%"

:: Создаем папку, если нет
if not exist "%WIN_OUT_PATH%" mkdir "%WIN_OUT_PATH%"

:: === ПРОВЕРКА НА ПЕРЕЗАПИСЬ ===
if exist "%WIN_OUT_PATH%\manual_config" (
    echo.
    echo [WARNING] В папке профиля найден сохраненный конфиг: manual_config
    echo.
    echo    1. Мы ЗАГРУЗИМ его в редактор [вы продолжите настройку].
    echo    2. После выхода из меню файл будет ПЕРЕЗАПИСАН новыми данными.
    echo.
    set "overwrite="
    :: FIX: Используем [Y/N] вместо (Y/N), чтобы скобка не закрывала блок IF раньше времени
    set /p "overwrite=Продолжить? [Y/N]: "
    if /i not "!overwrite!"=="Y" (
        echo Отмена операции.
        pause
        goto MENU
    )
)

if DEFINED IS_LEGACY (
    set "SERVICE_NAME=builder-src-oldwrt"
) else (
    set "SERVICE_NAME=builder-src-openwrt"
)

:: === ГЕНЕРАЦИЯ СКРИПТА ===
set "RUNNER_SCRIPT=%WIN_OUT_PATH%\_menuconfig_runner.sh"

echo #^!/bin/bash > "%RUNNER_SCRIPT%"
echo set -e >> "%RUNNER_SCRIPT%"
echo export HOME=/home/build >> "%RUNNER_SCRIPT%"
echo cd /home/build/openwrt >> "%RUNNER_SCRIPT%"
echo. >> "%RUNNER_SCRIPT%"
echo # --- DEBUG INFO --- >> "%RUNNER_SCRIPT%"
echo echo "[DEBUG] User: $(whoami)" >> "%RUNNER_SCRIPT%"
echo echo "[DEBUG] Dir: $(pwd)" >> "%RUNNER_SCRIPT%"
echo. >> "%RUNNER_SCRIPT%"
echo # --- 1. Load Environment --- >> "%RUNNER_SCRIPT%"
echo echo [INIT] Loading profile vars from: $CONF_FILE >> "%RUNNER_SCRIPT%"
echo cat "/profiles/$CONF_FILE" ^| sed '1s/^\xEF\xBB\xBF//' ^| tr -d '\r' ^> /tmp/env.sh >> "%RUNNER_SCRIPT%"
echo source /tmp/env.sh >> "%RUNNER_SCRIPT%"
echo. >> "%RUNNER_SCRIPT%"
echo # --- 2. Check Git State --- >> "%RUNNER_SCRIPT%"
echo if [ -f "Makefile" ]; then >> "%RUNNER_SCRIPT%"
echo     echo "[INFO] Makefile found. Skipping download." >> "%RUNNER_SCRIPT%"
echo else >> "%RUNNER_SCRIPT%"
echo     echo "[AUTO] Makefile missing. Cleaning up..." >> "%RUNNER_SCRIPT%"
echo     rm -rf .git >> "%RUNNER_SCRIPT%"
echo     echo "Repo: $SRC_REPO" >> "%RUNNER_SCRIPT%"
echo     echo "Branch: $SRC_BRANCH" >> "%RUNNER_SCRIPT%"
echo     git config --global --add safe.directory /home/build/openwrt >> "%RUNNER_SCRIPT%"
echo     echo "[GIT] Initializing..." >> "%RUNNER_SCRIPT%"
echo     git init >> "%RUNNER_SCRIPT%"
echo     git remote add origin "$SRC_REPO" >> "%RUNNER_SCRIPT%"
echo     echo "[GIT] Fetching..." >> "%RUNNER_SCRIPT%"
echo     git fetch origin "$SRC_BRANCH" >> "%RUNNER_SCRIPT%"
echo     echo "[GIT] Resetting..." >> "%RUNNER_SCRIPT%"
echo     git checkout -f "FETCH_HEAD" >> "%RUNNER_SCRIPT%"
echo     git reset --hard "FETCH_HEAD" >> "%RUNNER_SCRIPT%"
echo     echo "[FEEDS] Installing..." >> "%RUNNER_SCRIPT%"
echo     ./scripts/feeds update -a >> "%RUNNER_SCRIPT%"
echo     ./scripts/feeds install -a >> "%RUNNER_SCRIPT%"
echo fi >> "%RUNNER_SCRIPT%"
echo. >> "%RUNNER_SCRIPT%"
echo # --- 3. Prepare Configuration --- >> "%RUNNER_SCRIPT%"
echo echo "[CONFIG] Preparing .config..." >> "%RUNNER_SCRIPT%"
echo rm -f .config >> "%RUNNER_SCRIPT%"
echo. >> "%RUNNER_SCRIPT%"
echo # STRATEGY: Load manual_config IF exists, ELSE generate from profile >> "%RUNNER_SCRIPT%"
echo if [ -f "/output/manual_config" ]; then >> "%RUNNER_SCRIPT%"
echo     echo "[CONFIG] !!! Found manual_config. Restoring previous state... !!!" >> "%RUNNER_SCRIPT%"
echo     cp /output/manual_config .config >> "%RUNNER_SCRIPT%"
echo     # Force update symbols in case feeds changed >> "%RUNNER_SCRIPT%"
echo     make defconfig >> "%RUNNER_SCRIPT%"
echo else >> "%RUNNER_SCRIPT%"
echo     echo "[CONFIG] No manual_config found. Generating from profile..." >> "%RUNNER_SCRIPT%"
echo     echo "CONFIG_TARGET_$SRC_TARGET=y" ^> .config >> "%RUNNER_SCRIPT%"
echo     echo "CONFIG_TARGET_${SRC_TARGET}_${SRC_SUBTARGET}=y" ^>^> .config >> "%RUNNER_SCRIPT%"
echo     echo "CONFIG_TARGET_${SRC_TARGET}_${SRC_SUBTARGET}_DEVICE_$TARGET_PROFILE=y" ^>^> .config >> "%RUNNER_SCRIPT%"
echo. >> "%RUNNER_SCRIPT%"
echo     for pkg in $SRC_PACKAGES; do >> "%RUNNER_SCRIPT%"
echo         if [[ "$pkg" == -* ]]; then >> "%RUNNER_SCRIPT%"
echo             clean_pkg="${pkg#-}" >> "%RUNNER_SCRIPT%"
echo             echo "# CONFIG_PACKAGE_$clean_pkg is not set" ^>^> .config >> "%RUNNER_SCRIPT%"
echo         else >> "%RUNNER_SCRIPT%"
echo             echo "CONFIG_PACKAGE_$pkg=y" ^>^> .config >> "%RUNNER_SCRIPT%"
echo         fi >> "%RUNNER_SCRIPT%"
echo     done >> "%RUNNER_SCRIPT%"
echo. >> "%RUNNER_SCRIPT%"
echo     if [ -n "$ROOTFS_SIZE" ]; then echo "CONFIG_TARGET_ROOTFS_PARTSIZE=$ROOTFS_SIZE" ^>^> .config; fi >> "%RUNNER_SCRIPT%"
echo     if [ -n "$KERNEL_SIZE" ]; then echo "CONFIG_TARGET_KERNEL_PARTSIZE=$KERNEL_SIZE" ^>^> .config; fi >> "%RUNNER_SCRIPT%"
echo. >> "%RUNNER_SCRIPT%"
echo     if [ -n "$SRC_EXTRA_CONFIG" ]; then >> "%RUNNER_SCRIPT%"
echo         for opt in $SRC_EXTRA_CONFIG; do >> "%RUNNER_SCRIPT%"
echo             echo "$opt" ^>^> .config >> "%RUNNER_SCRIPT%"
echo         done >> "%RUNNER_SCRIPT%"
echo     fi >> "%RUNNER_SCRIPT%"
echo. >> "%RUNNER_SCRIPT%"
echo     make defconfig >> "%RUNNER_SCRIPT%"
echo fi >> "%RUNNER_SCRIPT%"
echo. >> "%RUNNER_SCRIPT%"
echo # --- 4. Menuconfig --- >> "%RUNNER_SCRIPT%"
echo echo [START] Launching Menuconfig UI... >> "%RUNNER_SCRIPT%"
echo make menuconfig >> "%RUNNER_SCRIPT%"
echo. >> "%RUNNER_SCRIPT%"
echo # --- 5. Save --- >> "%RUNNER_SCRIPT%"
echo echo [SAVE] Saving configuration... >> "%RUNNER_SCRIPT%"
echo cp .config /output/manual_config >> "%RUNNER_SCRIPT%"
echo echo [DONE] Saved to manual_config >> "%RUNNER_SCRIPT%"

echo [INFO] Запуск интерактивного Menuconfig...
echo.

:: Запуск
docker-compose -f system/docker-compose-src.yaml -p %PROJ_NAME% run --rm %SERVICE_NAME% /bin/bash -c "chown -R build:build /home/build/openwrt && chown build:build /output && tr -d '\r' < /output/_menuconfig_runner.sh > /tmp/r.sh && chmod +x /tmp/r.sh && sudo -E -u build bash /tmp/r.sh"

if exist "%RUNNER_SCRIPT%" del "%RUNNER_SCRIPT%"

echo.
echo Процедура завершена.
pause
exit /b

:: =========================================================
::  CORE BUILDER LOGIC
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

:: Внутри процедуры одиночный findstr работает стабильно
:: 1. ИЗВЛЕЧЕНИЕ ПЕРЕМЕННОЙ
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

:: 2. ПРОВЕРКА ВЕРСИИ (Legacy)
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
    
    :: БЫЛО: set "COMPOSE_ARG=" (Docker искал файл в корне)
    :: СТАЛО: Указываем путь к файлу в папке system
    set "COMPOSE_ARG=-f system/docker-compose.yaml"
    
    set "WINDOW_TITLE=I: %PROFILE_ID%"
    if DEFINED IS_LEGACY (set "SERVICE_NAME=builder-oldwrt") else (set "SERVICE_NAME=builder-openwrt")
) else (
    :: --- SOURCE BUILDER ---
    set "REL_OUT_PATH=./firmware_output/sourcebuilder/%PROFILE_ID%"
    set "PROJ_NAME=srcbuild_%PROFILE_ID%"
    
    :: БЫЛО: set "COMPOSE_ARG=-f docker-compose-src.yaml"
    :: СТАЛО: Добавляем system/ перед именем файла
    set "COMPOSE_ARG=-f system/docker-compose-src.yaml"
    
    set "WINDOW_TITLE=S: %PROFILE_ID%"
    if DEFINED IS_LEGACY (set "SERVICE_NAME=builder-src-oldwrt") else (set "SERVICE_NAME=builder-src-openwrt")
)

:: Создаем папку физически
set "WIN_OUT_PATH=%REL_OUT_PATH:./=%"
set "WIN_OUT_PATH=%WIN_OUT_PATH:/=\%"
if not exist "%WIN_OUT_PATH%" mkdir "%WIN_OUT_PATH%"

echo [LAUNCH] Запуск: %PROFILE_ID%
echo [INFO]   Target: !TARGET_VAL!
echo [INFO]   Service: %SERVICE_NAME%

:: Запуск Docker
:: Мы подставляем переменную "%WINDOW_TITLE%" в первые кавычки
START "%WINDOW_TITLE%" /D "%PROJECT_DIR%" cmd /c "set SELECTED_CONF=%CONF_FILE%&& set HOST_FILES_DIR=./custom_files/%PROFILE_ID%&& set HOST_OUTPUT_DIR=%REL_OUT_PATH%&& docker-compose %COMPOSE_ARG% -p %PROJ_NAME% up --build --force-recreate --remove-orphans %SERVICE_NAME% & echo. & echo === WORK FINISHED === & pause"

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