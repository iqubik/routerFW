@echo off
rem file: _Builder.bat

set "VER_NUM=4.01"

setlocal enabledelayedexpansion
:: Фиксируем размер окна: 120 символов в ширину, 40 в высоту
mode con: cols=120 lines=40
:: Отключаем мигающий курсор (через PowerShell, так как в Batch нет нативного способа)
powershell -command "$ind = [System.Console]::CursorVisible; if($ind){[System.Console]::CursorVisible=$false}" 2>nul
cls
chcp 65001 >nul
:: Настройка ANSI цветов
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "C_KEY=%ESC%[93m"
:: Bright Yellow (Ярко-желтый): Для клавиш [A], [W] и важных акцентов
set "C_LBL=%ESC%[36m"
:: Gray (Серый): Для меток и заголовков
set "C_GRY=%ESC%[90m"
:: Cyan (Бирюзовый): Для меток, заголовков и ссылок
set "C_VAL=%ESC%[92m"
set "C_OK=%ESC%[92m"
:: Bright Green (Ярко-зеленый): Для статусов "ОК", путей и активных значений
set "C_RST=%ESC%[0m"
:: Reset (Сброс): Возврат к стандартному цвету терминала
set "C_ERR=%ESC%[91m"
:: Bright Red (Ярко-красный): Для ошибок и предупреждений

:: === ЯЗЫКОВОЙ МОДУЛЬ ===
:: ТУМБЛЕR: AUTO (детект), RU (всегда рус), EN (всегда англ)
set "FORCE_LANG=AUTO"
set "SYS_LANG=EN"
set /a "ru_score=0"
:: Строки детектора (всегда на двух языках для процесса инициализации)
echo %C_LBL%[INIT]%C_RST% Language detector (Weighted Detection)...
:: 1. Проверка реестра: UI Язык (3 балла)
reg query "HKCU\Control Panel\Desktop" /v PreferredUILanguages 2>nul | findstr /I "ru-RU" >nul
if not errorlevel 1 set /a "ru_score+=3"
if not errorlevel 1 echo   %C_GRY%-%C_RST% UI Language Registry  %C_OK%RU%C_RST% [+3]
if errorlevel 1     echo   %C_GRY%-%C_RST% UI Language Registry  %C_ERR%EN%C_RST%
:: 2. Проверка реестра: Язык дистрибутива (2 балла)
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Nls\Language" /v InstallLanguage 2>nul | findstr /I "0419" >nul
if not errorlevel 1 set /a "ru_score+=2"
if not errorlevel 1 echo   %C_GRY%-%C_RST% OS Install Locale     %C_OK%RU%C_RST% [+2]
if errorlevel 1     echo   %C_GRY%-%C_RST% OS Install Locale     %C_ERR%EN%C_RST%
:: 3. Проверка PowerShell: Культура и список языков (4 балла)
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "(Get-Culture).Name + (Get-WinUserLanguageList).LanguageTag" 2^>nul`) do set "PS_CHECK=%%a"
echo !PS_CHECK! | findstr /I "ru" >nul
if not errorlevel 1 set /a "ru_score+=4"
if not errorlevel 1 echo   %C_GRY%-%C_RST% Culture and Lang List %C_OK%RU%C_RST% [+4]
if errorlevel 1     echo   %C_GRY%-%C_RST% Culture and Lang List %C_ERR%EN%C_RST%
:: 4. Проверка кодировки консоли (1 балл)
chcp | findstr "866" >nul
if not errorlevel 1 set /a "ru_score+=1"
if not errorlevel 1 echo   %C_GRY%-%C_RST% Console CP 866        %C_OK%RU%C_RST% [+1]
:: Логика суждения
if %ru_score% GEQ 5 set "SYS_LANG=RU"
:: === ПРИНУДИТЕЛЬНЫЙ ПЕРЕКЛЮЧАТЕЛЬ (OVERRIDE) ===
if /i "%FORCE_LANG%"=="RU" set "SYS_LANG=RU"
if /i "%FORCE_LANG%"=="EN" set "SYS_LANG=EN"
:: === СЛОВАРЬ (DICTIONARY) ===
if "%SYS_LANG%"=="RU" (
    set "L_K_MOVE_ASK=Обновить профиль %C_VAL%!PROFILE_ID!.conf%C_RST% данными из Menuconfig? [Y/N]"
    set "L_K_MOVE_OK=%C_OK%[DONE]%C_RST% Переменная SRC_EXTRA_CONFIG в профиле обновлена."
    set "L_K_MOVE_ARCH=Временный файл переименован в _manual_config."
    set "L_EXIT_CONFIRM=Выйти из программы? (Y/N): "
    set "L_EXIT_BYE=До новых встреч!"
    set "H_PROF=Профиль"
    set "H_ARCH=Архитектура"
    set "H_RES=Ресурсы | Сборки"
    set "L_VERDICT=Вердикт"
    set "L_LANG_NAME=РУССКИЙ"
    set "L_INIT_ENV=[INIT] Проверка окружения..."
    set "L_ERR_DOCKER=[ERROR] Docker не обнаружен!"
    set "L_ERR_DOCKER_MSG=Убедитесь, что Docker Desktop установлен и запущен."    
    set "L_INIT_NET=[INIT] Очистка неиспользуемых сетей Docker..."
    set "L_INIT_UNPACK=[INIT] Проверка распаковщика..."
    set "L_MODE_IMG=IMAGE BUILDER (Быстрая сборка)"
    set "L_MODE_SRC=SOURCE BUILDER (Полная компиляция)"
    set "L_CUR_MODE=Текущий режим"
    set "L_PROFILES=Профили сборки"
    set "L_LEGEND_IND=Индикаторы показывают состояние ресурсов и результатов сборки."
    set "L_LEGEND_TEXT=Легенда: F:Файлы P:Пакеты S:Исх | Прошивки: OI:Образ OS:Сборка"
    set "L_BTN_ALL=Собрать ВСЕ"
    set "L_BTN_SWITCH=Режим на "
    set "L_BTN_EDIT=Редактор"
    set "L_BTN_CLEAN=Обслуживание"
    set "L_BTN_WIZ=Мастер профилей"
    set "L_BTN_EXIT=Выход"
    set "L_BTN_IPK=Импорт IPK"
    set "L_CHOICE=Ваш выбор"
    set "L_RUNNING=Сборка запущена..."
    set "L_EDIT_TITLE=МЕНЕДЖЕР РЕСУРСОВ И РЕДАКТОР ПРОФИЛЯ"
    set "L_SEL_PROF=Выберите профиль для работы"
    set "L_BACK=Назад"
    set "L_ANALYSIS=[АНАЛИЗ СОСТОЯНИЯ ПРОФИЛЯ"
    set "L_MISSING=Отсутствует"
    set "L_EMPTY=Пусто"
    set "L_READY=Готов"
    set "L_FOUND=Найдено"
    set "L_ST_CONF=Конфигурация"
    set "L_ST_OVER=Overlay файлы"
    set "L_ST_IPK=Входящие IPK"
    set "L_ST_SRC=Исходники PKG"
    set "L_ST_OUTS=Выход Source"
    set "L_ST_OUTI=Выход Image"
    set "L_ACTION=ДЕЙСТВИЕ"
    set "L_OPEN_FILE=Открыть файл"
    set "L_OPEN_EXPL=Открыть также папки ресурсов в Проводнике?"
    set "L_START_EXPL=[INFO] Запуск проводника..."
    set "L_DONE_MENU=Готово. Переход в меню..."
    set "L_WARN_MASS=Массовая компиляция из исходников! Это займет много времени."
    set "L_MASS_START=МАССОВЫЙ ЗАПУСК"
    set "L_IMPORT_IPK_TITLE=ИМПОРТ ПАКЕТОВ (IPK) ДЛЯ ПРОФИЛЯ"
    set "L_SEL_IMPORT=Выберите профиль для импорта пакетов"
    set "L_ERR_PS1_IPK=[ERROR] system/import_ipk.ps1 не найден!"
    set "L_CLEAN_TITLE=МЕНЮ ОЧИСТКИ И ОБСЛУЖИВАНИЯ"
    set "L_CLEAN_TYPE=Выберите тип данных для очистки"
    set "L_CLEAN_IMG_SDK=Очистить кэш ImageBuilder (SDK) (Ядра и пакеты OpenWrt)"
    set "L_CLEAN_IMG_IPK=Очистить кэш пакетов (IPK) (Папка dl/)"
    set "L_CLEAN_FULL=FULL FACTORY RESET (Сброс проекта)"
    set "L_CLEAN_SRC_SOFT=SOFT CLEAN (make clean) (Очистка бинарников)"
    set "L_CLEAN_SRC_HARD=HARD RESET (Удалить src-workdir) (Сброс кода и тулчейна)"
    set "L_CLEAN_SRC_DL=Очистить кэш исходников (dl) (Удалить архивы кода)"
    set "L_CLEAN_SRC_CC=Очистить CCACHE (Кэш компилятора)"
    set "L_DOCKER_PRUNE=Prune Docker (Глобальная очистка мусора)"
    set "L_PRUNE_RUN=[DOCKER] Выполняю system prune..."
    set "L_CLEAN_PROF_SEL=Для какого профиля выполнить очистку?"
    set "L_CLEAN_ALL_PROF=ДЛЯ ВСЕХ ПРОФИЛЕЙ (Глобальная очистка)"
    set "L_CONFIRM_YES=Введите YES для подтверждения"
    set "L_CLEAN_RUN=[CLEAN] Запуск процедуры..."
    set "L_K_TITLE=MENUCONFIG ИНТЕРАКТИВ"
    set "L_K_DESC=Будет создан manual_config в папке"
    set "L_K_SEL=Выберите профиль для настройки"
    set "L_K_WARN_EX=В папке профиля найден сохраненный конфиг: manual_config"
    set "L_K_WARN_L1=1. Мы ЗАГРУЗИМ его в редактор [вы продолжите настройку]."
    set "L_K_WARN_L2=2. После выхода из меню файл будет ПЕРЕЗАПИСАН новыми данными."
    set "L_K_CONT=Продолжить? [Y/N]"
    set "L_K_SAVE=Фиксация конфигурации..."
    set "L_K_SAVED=Сохранено"
    set "L_K_STR=строк"
    set "L_K_EMPTY_DIFF=Дифф пуст, сохраняю полный конфиг."
    set "L_K_FINAL=Конфигурация сохранена в firmware_output"
    set "L_K_STAY=Остаться в контейнере для работы с файлами? [y/N]"
    set "L_K_SHELL_H1=[SHELL] Вход в консоль. Текущая папка"
    set "L_K_SHELL_H2=Подсказка: введите mc для запуска файлового менеджера."
    set "L_K_SHELL_H3=Чтобы выйти в Windows и продолжить, введите exit."
    set "L_K_LAUNCH=[INFO] Запуск интерактивного Menuconfig..."
    set "L_WIZ_START=ЗАПУСК МАСТЕРА СОЗДАНИЯ ПРОФИЛЯ"
    set "L_WIZ_DONE=Мастер завершил работу."
    set "L_ERR_WIZ=[ERROR] Файл create_profile.ps1 не найден!"
    set "L_ERR_INPUT=Ошибка ввода."
    set "L_PROC_PROF=Профиль"
    set "L_ERR_VAR_NF=не найден."
    set "L_ERR_SKIP=Возможно, этот профиль предназначен для другого режима."
) else (
    set "L_K_MOVE_ASK=Update %C_VAL%!PROFILE_ID!.conf%C_RST% profile with Menuconfig data? [Y/N]"
    set "L_K_MOVE_OK=%C_OK%[DONE]%C_RST% SRC_EXTRA_CONFIG variable in profile updated."
    set "L_K_MOVE_ARCH=Temporary file renamed to _manual_config."
    set "L_EXIT_CONFIRM=Exit the program? (Y/N): "
    set "L_EXIT_BYE=See you soon!"
    set "H_PROF=Profile"
    set "H_ARCH=Architecture"
    set "H_RES=Resources | Builds"    
    set "L_VERDICT=Verdict"
    set "L_LANG_NAME=ENGLISH"
    set "L_INIT_ENV=[INIT] Checking environment..."
    set "L_ERR_DOCKER=[ERROR] Docker not found!"
    set "L_ERR_DOCKER_MSG=Make sure Docker Desktop is installed and running."    
    set "L_INIT_NET=[INIT] Pruning unused Docker networks..."
    set "L_INIT_UNPACK=[INIT] Checking unpacker..."
    set "L_MODE_IMG=IMAGE BUILDER (Fast Build)"
    set "L_MODE_SRC=SOURCE BUILDER (Full Compilation)"
    set "L_CUR_MODE=Current Mode"
    set "L_PROFILES=Build Profiles"
    set "L_LEGEND_IND=Indicators show the state of resources and build results."
    set "L_LEGEND_TEXT=Legend: F:Files P:Packages S:Src | Firmwares: OI:Image OS:Build"
    set "L_BTN_ALL=Build ALL"
    set "L_BTN_SWITCH=Switch to"
    set "L_BTN_EDIT=Editor"
    set "L_BTN_CLEAN=Maintenance"
    set "L_BTN_WIZ=Profile Wizard"
    set "L_BTN_EXIT=Exit"
    set "L_BTN_IPK=Import IPK"
    set "L_CHOICE=Your choice"
    set "L_RUNNING=Build started..."
    set "L_EDIT_TITLE=RESOURCE MANAGER AND PROFILE EDITOR"
    set "L_SEL_PROF=Select profile to work with"
    set "L_BACK=Back"
    set "L_ANALYSIS=[PROFILE STATE ANALYSIS"
    set "L_MISSING=Missing"
    set "L_EMPTY=Empty"
    set "L_READY=Ready"
    set "L_FOUND=Found"
    set "L_ST_CONF=Configuration"
    set "L_ST_OVER=Overlay files"
    set "L_ST_IPK=Inbound IPKs"
    set "L_ST_SRC=Source PKGs"
    set "L_ST_OUTS=Source Output"
    set "L_ST_OUTI=Image Output"
    set "L_ACTION=ACTION"
    set "L_OPEN_FILE=Open file"
    set "L_OPEN_EXPL=Open resource folders in Explorer too?"
    set "L_START_EXPL=[INFO] Launching Explorer..."
    set "L_DONE_MENU=Done. Returning to menu..."
    set "L_WARN_MASS=Massive source compilation! This will take a lot of time/CPU."
    set "L_MASS_START=MASSIVE LAUNCH"
    set "L_IMPORT_IPK_TITLE=PACKAGE IMPORT (IPK) FOR PROFILE"
    set "L_SEL_IMPORT=Select profile for package import"
    set "L_ERR_PS1_IPK=[ERROR] system/import_ipk.ps1 not found!"
    set "L_CLEAN_TITLE=CLEANUP AND MAINTENANCE MENU"
    set "L_CLEAN_TYPE=Select data type to clean"
    set "L_CLEAN_IMG_SDK=Clean ImageBuilder Cache (SDK) (OpenWrt kernels/pkgs)"
    set "L_CLEAN_IMG_IPK=Clean Package Cache (IPK) (dl/ folder)"
    set "L_CLEAN_FULL=FULL FACTORY RESET (Reset project)"
    set "L_CLEAN_SRC_SOFT=SOFT CLEAN (make clean) (Clean binaries)"
    set "L_CLEAN_SRC_HARD=HARD RESET (Remove src-workdir) (Reset code/toolchain)"
    set "L_CLEAN_SRC_DL=Clean Source Cache (dl) (Remove source archives)"
    set "L_CLEAN_SRC_CC=Clean CCACHE (Compiler cache)"
    set "L_DOCKER_PRUNE=Prune Docker (Global Docker cleanup)"
    set "L_PRUNE_RUN=[DOCKER] Running system prune..."
    set "L_CLEAN_PROF_SEL=Which profile to clean?"
    set "L_CLEAN_ALL_PROF=FOR ALL PROFILES (Global cleanup)"
    set "L_CONFIRM_YES=Type YES to confirm"
    set "L_CLEAN_RUN=[CLEAN] Starting procedure..."
    set "L_K_TITLE=MENUCONFIG INTERACTIVE"
    set "L_K_DESC=manual_config will be created in folder"
    set "L_K_SEL=Select profile to configure"
    set "L_K_WARN_EX=Found saved config in profile folder: manual_config"
    set "L_K_WARN_L1=1. We will LOAD it into editor [continue configuration]."
    set "L_K_WARN_L2=2. After exit, the file will be OVERWRITTEN with new data."
    set "L_K_CONT=Continue? [Y/N]"
    set "L_K_SAVE=[SAVE] Committing configuration..."
    set "L_K_SAVED=Saved"
    set "L_K_STR=lines"
    set "L_K_EMPTY_DIFF=Diff is empty, saving full config."
    set "L_K_FINAL=Configuration saved to firmware_output"
    set "L_K_STAY=Stay in container for file work? [y/N]"
    set "L_K_SHELL_H1=[SHELL] Entering console. Current folder"
    set "L_K_SHELL_H2=Tip: type mc to launch file manager."
    set "L_K_SHELL_H3=To exit to Windows and continue, type exit."
    set "L_K_LAUNCH=[INFO] Launching Interactive Menuconfig..."
    set "L_WIZ_START=STARTING PROFILE WIZARD"
    set "L_WIZ_DONE=Wizard finished."
    set "L_ERR_WIZ=[ERROR] create_profile.ps1 not found!"
    set "L_ERR_INPUT=Input error."
    set "L_PROC_PROF=Profile"
    set "L_ERR_VAR_NF=not found."
    set "L_ERR_SKIP=Maybe this profile is for a different mode."
)
:: Финальный вывод вердикта
if /i "%FORCE_LANG%"=="AUTO" (
    echo %C_LBL%[INIT]%C_RST% %L_VERDICT% %C_OK%%L_LANG_NAME%%C_RST% (Score %ru_score%/10)
) else (
    echo %C_LBL%[INIT]%C_RST% Lang set: %C_VAL%FORCE %FORCE_LANG%%C_RST%
)
echo.

:: === КОНФИГУРАЦИЯ ===
:: Режим по умолчанию: IMAGE
set "BUILD_MODE=IMAGE"
echo %L_INIT_ENV%

:: Вывод версии Docker
for /f "tokens=*" %%i in ('docker --version 2^>nul') do set "D_VER=%%i"
if "%D_VER%"=="" (
    echo %L_ERR_DOCKER%
    echo %L_ERR_DOCKER_MSG%
    pause & exit /b
)
echo   %C_GRY%-%C_RST% %D_VER%

:: Вывод версии Compose
for /f "tokens=*" %%i in ('docker-compose --version 2^>nul') do set "C_VER=%%i"
echo   %C_GRY%-%C_RST% %C_VER%

:: Вывод корня проекта
echo   %C_GRY%-%C_RST% Root: %C_VAL%%CD%%C_RST%

echo %L_INIT_NET%
docker network prune --force >nul 2>&1
echo.
:: === 0. РАСПАКОВКА ===
if exist _unpacker.bat (
    echo %L_INIT_UNPACK%
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

:: === АВТО-ПАТЧИНГ АРХИТЕКТУРЫ (ADVANCED MAPPING v3.0) ===
echo %C_LBL%[INIT]%C_RST% Scanning profiles for missing architecture tags...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$profiles = Get-ChildItem 'profiles/*.conf';" ^
    "foreach ($p in $profiles) {" ^
    "    $content = Get-Content $p.FullName -Raw;" ^
    "    if ($content -notmatch 'SRC_ARCH=') {" ^
    "        $target = ''; $sub = '';" ^
    "        if ($content -match 'SRC_TARGET=[''^\"]([^''\"\r\n]+)') { $target = $matches[1] }" ^
    "        if ($content -match 'SRC_SUBTARGET=[''^\"]([^''\"\r\n]+)') { $sub = $matches[1] }" ^
    "        if ($content -match 'IMAGEBUILDER_URL=.*/targets/([^/]+)/([^/]+)/') { $target = $matches[1]; $sub = $matches[2] }" ^
    "        if ($target -eq '') { continue }" ^
    "        $arch = switch -Wildcard ($target) {" ^
    "            'ramips'   { 'mipsel_24kc' }" ^
    "            'ath79'    { 'mips_24kc' }" ^
    "            'ar71xx'   { 'mips_24kc' }" ^
    "            'lantiq'   { 'mips_24kc' }" ^
    "            'realtek'  { 'mips_24kc' }" ^
    "            'x86'      { if ($sub -eq '64') { 'x86_64' } else { 'i386_pentium4' } }" ^
    "            'mediatek' { " ^
    "                if ($sub -match 'mt798|mt7622|filogic') { 'aarch64_cortex-a53' } " ^
    "                elseif ($sub -eq 'mt7623') { 'arm_cortex-a7_neon-vfpv4' } " ^
    "                else { 'mipsel_24kc' } " ^
    "            }" ^
    "            'mvebu'    { " ^
    "                if ($sub -eq 'cortexa72') { 'aarch64_cortex-a72' } " ^
    "                else { 'arm_cortex-a9_vfpv3-d16' } " ^
    "            }" ^
    "            'ipq40xx'  { 'arm_cortex-a7_neon-vfpv4' }" ^
    "            'ipq806x'  { 'arm_cortex-a15_neon-vfpv4' }" ^
    "            'rockchip' { 'aarch64_generic' }" ^
    "            'bcm27xx'  { " ^
    "                if ($sub -eq 'bcm2711') { 'aarch64_cortex-a72' } " ^
    "                elseif ($sub -eq 'bcm2710') { 'aarch64_cortex-a53' } " ^
    "                else { 'arm_arm1176jzf-s_vfp' } " ^
    "            }" ^
    "            'sunxi'    { 'arm_cortex-a7_neon-vfpv4' }" ^
    "            'layerscape' { if ($sub -eq '64b') { 'aarch64_generic' } else { 'arm_cortex-a7_neon-vfpv4' } }" ^
    "            '*64*'     { 'aarch64_generic' }" ^
    "            default    { '' }" ^
    "        };" ^
    "        if ($arch -ne '') {" ^
    "            $content = $content.TrimEnd() + [char]13 + [char]10 + 'SRC_ARCH=\"' + $arch + '\"' + [char]13 + [char]10;" ^
    "            [System.IO.File]::WriteAllText($p.FullName, $content);" ^
    "            Write-Host ('  [PATCHED] ' + $p.Name + ' -> ' + $arch) -ForegroundColor Green" ^
    "        } else {" ^
    "            Write-Host ('  [WARN] No arch for ' + $p.Name + ' (' + $target + '/' + $sub + ')') -ForegroundColor Yellow" ^
    "        }" ^
    "    }" ^
    "}"
echo.

:MENU
cls
:: Очистка массива профилей
for /F "tokens=1 delims==" %%a in ('set profile[ 2^>nul') do set "%%a="
set "count=0"

:: 1. ЛОГИКА РЕЖИМА И ЯЗЫКА
if "%BUILD_MODE%"=="IMAGE" (
    color 0B
    set "MODE_TITLE=!L_MODE_IMG!"
    set "OPPOSITE_MODE=SOURCE"
    set "TARGET_VAR=IMAGEBUILDER_URL"
) else (
    color 0D
    set "MODE_TITLE=!L_MODE_SRC!"
    set "OPPOSITE_MODE= IMAGE"
    set "TARGET_VAR=SRC_BRANCH"
)

:: 2. ОТРИСОВКА ЗАГОЛОВКА
echo !C_GRY!┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐!C_RST!
echo   !C_VAL!OpenWrt FW Builder !VER_NUM!!C_RST! [!C_VAL!!SYS_LANG!!C_RST!]          !C_LBL!https://github.com/iqubik/routerFW!C_RST!
echo   !L_CUR_MODE!: [!C_VAL!!MODE_TITLE!!C_RST!]
echo !C_GRY!└────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘!C_RST!
echo.
echo    !C_GRY! ID   !H_PROF!                                      !H_ARCH!          !H_RES!!C_RST!
echo    !C_GRY!────────────────────────────────────────────────────────────────────────────────────────────────────────────!C_RST!

:: Очистка массива профилей
for /F "tokens=1 delims==" %%a in ('set profile[ 2^>nul') do set "%%a="
set "count=0"

:: 3. ЦИКЛ СКАНИРОВАНИЯ (С поддержкой словаря)
echo    !C_LBL!!L_PROFILES!:!C_RST!
echo.
for %%f in (profiles\*.conf) do (
    set /a count+=1
    set "profile[!count!]=%%~nxf"
    set "p_id=%%~nf"
    
    :: Авто-создание структуры
    if not exist "custom_files\!p_id!" mkdir "custom_files\!p_id!" >nul
    if not exist "custom_packages\!p_id!" mkdir "custom_packages\!p_id!" >nul
    if not exist "src_packages\!p_id!" mkdir "src_packages\!p_id!" >nul
    call :CREATE_PERMS_SCRIPT "!p_id!"
    rem call :CREATE_WIFI_ON_SCRIPT "!p_id!"
    :: Извлекаем имя БЕЗ расширения для отображения в меню
    set "fname_display=%%~nf"

    :: Извлечение архитектуры
    set "this_arch=--------"
    for /f "usebackq tokens=2 delims==" %%a in (`type "profiles\%%~nxf" ^| findstr "SRC_ARCH"`) do (
        set "VAL=%%a"
        set "VAL=!VAL:"=!"
        for /f "tokens=* delims= " %%b in ("!VAL!") do set "this_arch=%%b"
    )

    :: --- ХИРУРГИЧЕСКАЯ РАСКРАСКА РЕСУРСОВ (F-LBL, P-KEY, S-VAL) ---
    set "st_f=!C_GRY!·!C_RST!" & dir /a-d /b /s "custom_files\!p_id!" 2>nul | findstr "^" >nul && set "st_f=!C_LBL!F!C_RST!"
    set "st_p=!C_GRY!·!C_RST!" & dir /a-d /b /s "custom_packages\!p_id!" 2>nul | findstr "^" >nul && set "st_p=!C_KEY!P!C_RST!"
    set "st_s=!C_GRY!·!C_RST!" & dir /a-d /b /s "src_packages\!p_id!" 2>nul | findstr "^" >nul && set "st_s=!C_VAL!S!C_RST!"   

    :: Состояние вывода (OI OS)
    set "st_oi=!C_GRY!··!C_RST!"
    dir /s /a-d /b "firmware_output\imagebuilder\!p_id!\*.bin" "firmware_output\imagebuilder\!p_id!\*.img" 2>nul | findstr "^" >nul && set "st_oi=!C_VAL!OI!C_RST!"
    set "st_os=!C_GRY!··!C_RST!"
    dir /s /a-d /b "firmware_output\sourcebuilder\!p_id!\*.bin" "firmware_output\sourcebuilder\!p_id!\*.img" 2>nul | findstr "^" >nul && set "st_os=!C_VAL!OS!C_RST!"
    
    :: ВЫРАВНИВАНИЕ
    set "id_pad=!count!"
    if !count! LSS 10 set "id_pad= !count!"
    set "fname_display=%%~nf"
    set "tmp_name=!fname_display!                                             "
    set "n_name=!tmp_name:~0,45!"
    set "tmp_arch=!this_arch!                    "
    set "n_arch=!tmp_arch:~0,20!"

    :: ВЫВОД СТРОКИ (Серые скобки, Бирюзовая архитектура, Четкий разделитель)
    echo    !C_GRY![!C_KEY!!id_pad!!C_GRY!]!C_RST! !n_name! !C_LBL!!n_arch!!C_RST! !C_GRY![!st_f!!st_p!!st_s! !C_RST!^|!C_GRY! !st_oi!!st_os!]!C_RST!
)

:: 4. ПОДВАЛ
set "b_all=!L_BTN_ALL!                  " & set "b_all=!b_all:~0,18!"
set "b_clean=!L_BTN_CLEAN!              " & set "b_clean=!b_clean:~0,18!"
set "b_wiz=!L_BTN_WIZ!                  " & set "b_wiz=!b_wiz:~0,22!"

echo    !C_GRY!────────────────────────────────────────────────────────────────────────────────────────────────────────────!C_RST!
echo    !L_LEGEND_IND!
echo    !C_GRY!!L_LEGEND_TEXT!!C_RST!
echo.
echo    !C_LBL![!C_KEY!A!C_LBL!] !b_all! !C_LBL![!C_KEY!M!C_LBL!] !L_BTN_SWITCH! !C_VAL!!OPPOSITE_MODE!!C_RST!       !C_LBL![!C_KEY!E!C_LBL!] !L_BTN_EDIT!!C_RST!
echo    !C_LBL![!C_KEY!C!C_LBL!] !b_clean! !C_LBL![!C_KEY!W!C_LBL!] !b_wiz! !C_LBL![!C_KEY!0!C_LBL!] !L_BTN_EXIT!!C_RST!

if "%BUILD_MODE%"=="SOURCE" (
    echo    !C_LBL![!C_KEY!K!C_LBL!] Menuconfig/mc      !C_LBL![!C_KEY!I!C_LBL!] !L_BTN_IPK!!C_RST!
)
echo.
set "choice="
set /p choice=!C_LBL!!L_CHOICE!!C_VAL! ⚡ !C_RST!
:: === ПРОВЕРКА ВВОДА (FIX CRASH) ===
if not defined choice goto MENU
if "%choice%"=="" goto MENU

:: Если нажали 0 (Выход)
if /i "%choice%"=="0" (
    echo.
    :: Используем локализованный вопрос и красный цвет ошибки для привлечения внимания
    set /p "exit_confirm=!C_ERR!!L_EXIT_CONFIRM!!C_RST!"
    if /i "!exit_confirm!"=="Y" (
        echo.
        :: Используем локализованное прощание и зеленый цвет успеха
        echo !C_OK!!L_EXIT_BYE!!C_RST!
        timeout /t 2 >nul
        exit /b
    )
    goto MENU
)
if /i "%choice%"=="R" goto MENU
if /i "%choice%"=="M" goto SWITCH_MODE
if /i "%choice%"=="W" goto WIZARD
if /i "%choice%"=="E" goto EDIT_PROFILE
if "%BUILD_MODE%"=="SOURCE" (
    if /i "%choice%"=="K" goto MENUCONFIG_SELECTION
    if /i "%choice%"=="I" goto IMPORT_IPK
)
if /i "%choice%"=="C" goto CLEAN_MENU
if /i "%choice%"=="A" goto BUILD_ALL
:: Проверка на числовой ввод
set /a num_choice=%choice% 2>nul
if "%num_choice%"=="0" if not "%choice%"=="0" goto INVALID
if %num_choice% gtr %count% goto INVALID
if %num_choice% lss 1 goto INVALID

:: === ОДИНОЧНАЯ СБОРКА ===
set "SELECTED_CONF=!profile[%choice%]!"
call :BUILD_ROUTINE "%SELECTED_CONF%"
echo %L_RUNNING%
pause
goto MENU

:EDIT_PROFILE
cls
:: Используем зеленый цвет (%C_OK%) для заголовка
echo %C_KEY%==========================================================%C_RST%
echo  %C_VAL%%L_EDIT_TITLE%%C_RST%
echo %C_KEY%==========================================================%C_RST%
echo.
echo  %L_SEL_PROF%:
echo.
for /L %%i in (1,1,%count%) do (
    echo    %C_LBL%[%C_KEY%%%i%C_LBL%]%C_RST% !profile[%%i]:.conf=!
)
echo.
echo    %C_LBL%[%C_KEY%0%C_LBL%] %L_BACK%%C_RST%
echo.
set "e_choice="
set /p e_choice=%C_OK%%L_CHOICE%: %C_RST%
if "%e_choice%"=="0" goto MENU
set /a n_e=%e_choice% 2>nul
if %n_e% gtr %count% goto INVALID
if %n_e% lss 1 goto INVALID
set "SEL_CONF=!profile[%n_e%]!"
set "SEL_ID=!profile[%n_e%]:.conf=!"

:: --- БЛОК ОТЛАДКИ / СОСТОЯНИЯ (DEBUG INFO) ---
echo.
echo %C_OK%%L_ANALYSIS%: !SEL_ID!]%C_RST%
echo ----------------------------------------------------------
:: Проверка наличия папок для отладки
set "S_FILES=%C_ERR%%L_MISSING%%C_RST%"
set "S_PACKS=%C_ERR%%L_MISSING%%C_RST%"
set "S_SRCS=%C_ERR%%L_MISSING%%C_RST%"
set "S_OUT_S=%C_ERR%%L_EMPTY%%C_RST%"
set "S_OUT_I=%C_ERR%%L_EMPTY%%C_RST%"
if exist "custom_files\!SEL_ID!" set "S_FILES=%C_OK%%L_READY% (files/)%C_RST%"
if exist "custom_packages\!SEL_ID!" set "S_PACKS=%C_OK%%L_READY% (ipk/)%C_RST%"
if exist "src_packages\!SEL_ID!" set "S_SRCS=%C_OK%%L_READY% (make/)%C_RST%"
if exist "firmware_output\sourcebuilder\!SEL_ID!" set "S_OUT_S=%C_OK%%L_FOUND% (source/)%C_RST%"
if exist "firmware_output\imagebuilder\!SEL_ID!" set "S_OUT_I=%C_OK%%L_FOUND% (image/)%C_RST%"
echo  - %L_ST_CONF%:  %C_VAL%profiles\!SEL_CONF!%C_RST%
echo  - %L_ST_OVER%: !S_FILES!
echo  - %L_ST_IPK%:  !S_PACKS!
echo  - %L_ST_SRC%: !S_SRCS!
echo  - %L_ST_OUTS%:  !S_OUT_S!
echo  - %L_ST_OUTI%:   !S_OUT_I!
echo ----------------------------------------------------------
echo.
set "open_f="
echo %C_OK%[%L_ACTION%]%C_RST% %L_OPEN_FILE% %C_VAL%!SEL_CONF!%C_RST% in editor...
set /p open_f=%C_LBL%%L_OPEN_EXPL% [%C_KEY%Y%C_LBL%/%C_KEY%N%C_LBL%]: %C_RST%

:: 1. Открываем файл конфигурации (всегда)
start notepad "profiles\!SEL_CONF!"

:: 2. Открываем папки ресурсов (если Y)
if /i "!open_f!"=="Y" (
    echo %L_START_EXPL%
    if exist "custom_files\!SEL_ID!" start explorer "custom_files\!SEL_ID!"
    if exist "custom_packages\!SEL_ID!" start explorer "custom_packages\!SEL_ID!"
    if exist "src_packages\!SEL_ID!" start explorer "src_packages\!SEL_ID!"
    if exist "firmware_output\sourcebuilder\!SEL_ID!" start explorer "firmware_output\sourcebuilder\!SEL_ID!"
    if exist "firmware_output\imagebuilder\!SEL_ID!" start explorer "firmware_output\imagebuilder\!SEL_ID!"
)

echo %L_DONE_MENU%
timeout /t 2 >nul
goto MENU

:BUILD_ALL
if "%BUILD_MODE%"=="SOURCE" (
    echo.
    echo [WARNING] %L_WARN_MASS%
    pause
)
echo.
echo === %L_MASS_START% [%BUILD_MODE%] ===
for /L %%i in (1,1,%count%) do (
    set "CURRENT_CONF=!profile[%%i]!"
    call :BUILD_ROUTINE "!CURRENT_CONF!"
)
echo === Processes launched ===
pause
goto MENU

:SWITCH_MODE
if "%BUILD_MODE%"=="IMAGE" (
    set "BUILD_MODE=SOURCE"
) else (
    set "BUILD_MODE=IMAGE"
)
goto MENU

:: IMPORT IPK SECTION
:IMPORT_IPK
cls
echo %C_LBL%==========================================================%C_RST%
echo  %L_IMPORT_IPK_TITLE%
echo %C_LBL%==========================================================%C_RST%
echo.
echo  %L_SEL_IMPORT%:
echo.
for /L %%i in (1,1,%count%) do (
    set "fname_tmp=!profile[%%i]:.conf=!"    
    echo    %C_LBL%[%C_KEY%%%i%C_LBL%]%C_RST% !fname_tmp!
)
echo.
echo    %C_LBL%[%C_KEY%0%C_LBL%]%C_RST% %L_BACK%
echo.
set "i_choice="
set /p i_choice=%C_LBL%%L_CHOICE%: %C_RST%

if "%i_choice%"=="0" goto MENU
set /a n_i=%i_choice% 2>nul
if %n_i% gtr %count% goto INVALID
if %n_i% lss 1 goto INVALID

set "SEL_CONF=!profile[%n_i%]!"
set "SEL_ID=!profile[%n_i%]:.conf=!"

:: Извлекаем SRC_ARCH для строгой валидации
set "P_ARCH="
for /f "usebackq tokens=2 delims==" %%a in (`type "profiles\!SEL_CONF!" ^| findstr "SRC_ARCH"`) do (
    set "VAL=%%a"
    set "VAL=!VAL:"=!"
    for /f "tokens=* delims= " %%b in ("!VAL!") do set "P_ARCH=%%b"
)

echo.
if exist "system/import_ipk.ps1" (
    powershell -ExecutionPolicy Bypass -File "system/import_ipk.ps1" -ProfileID "!SEL_ID!" -TargetArch "!P_ARCH!"
    pause
) else (
    echo %C_KEY%%L_ERR_PS1_IPK%
    pause
)
goto MENU

:: =========================================================
::  NEW CLEANUP WIZARD (GRANULAR CONTROL)
:: =========================================================
:CLEAN_MENU
cls
color 0E
echo ==========================================================
echo  %L_CLEAN_TITLE% [%BUILD_MODE%]
echo ==========================================================
echo.
echo  %L_CLEAN_TYPE%:
echo.

if "%BUILD_MODE%"=="SOURCE" goto VIEW_SRC_MENU

:VIEW_IMG_MENU
echo    [1] %L_CLEAN_IMG_SDK%
echo.
echo    [2] %L_CLEAN_IMG_IPK%
echo.
echo    [3] %L_CLEAN_FULL%
goto VIEW_COMMON

:VIEW_SRC_MENU
echo    [1] %L_CLEAN_SRC_SOFT%
echo.
echo    [2] %L_CLEAN_SRC_HARD%
echo.
echo    [3] %L_CLEAN_SRC_DL%
echo.
echo    [4] %L_CLEAN_SRC_CC%
echo.
echo    [5] %L_CLEAN_FULL%

:VIEW_COMMON
echo.
echo    [9] %L_DOCKER_PRUNE%
echo    [0] %L_BACK%
echo.
set "clean_choice="
set /p clean_choice="%L_CHOICE%: "

if "%clean_choice%"=="" goto CLEAN_MENU
if "%clean_choice%"=="0" goto MENU
if "%clean_choice%"=="9" (
    echo.
    echo %L_PRUNE_RUN%
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
echo  CLEAN: %CLEAN_DESC%
echo ==========================================================
echo.
echo  %L_CLEAN_PROF_SEL%:
echo.

:: Выводим список профилей (используем массив из главного меню)
for /L %%i in (1,1,%count%) do (
    echo    [%%i] !profile[%%i]:.conf=!
)
echo.
echo    [A] %L_CLEAN_ALL_PROF%
echo    [0] %L_BACK%
echo.

set "p_choice="
set /p p_choice="%L_CHOICE% [1-%count% / A]: "
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
echo Selection: %CLEAN_DESC%
echo Target:    %TARGET_PROFILE_NAME%
echo.
if "%TARGET_PROFILE_ID%"=="ALL" echo WARNING: This will delete data for ALL profiles!
echo.
set "confirm="
set /p confirm="%L_CONFIRM_YES%: "

:: Если нажали Enter или ввели не YES - отмена
if /i not "!confirm!"=="YES" goto CLEAN_MENU
color 0E
echo.
echo %L_CLEAN_RUN%

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
    echo   Searching all volumes with tag: %V_TAG%
    for /f "tokens=*" %%v in ('docker volume ls -q -f "name=%V_TAG%"') do (
        echo   Deleting: %%v
        docker volume rm %%v >nul 2>&1
    )
) else (
    echo   Searching volume for profile: %P_ID% ... %V_TAG%
    :: Ищем том, который содержит И имя профиля, И тег типа
    for /f "tokens=*" %%v in ('docker volume ls -q ^| findstr "%P_ID%" ^| findstr "%V_TAG%"') do (
        echo   Deleting: %%v
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
echo   [LOCK] Releasing all containers (removing)...
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
echo   [LOCK] Releasing container for profile %P_ID%...
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
    echo [ERROR] Soft Clean is not supported for ALL mode.
    echo It takes too much time. Perform one by one.
    pause
    goto CLEAN_MENU
)
echo [CLEAN] Starting container %TARGET_PROFILE_ID% for make clean...
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
echo [INFO] Work directory cleaned. Sources (DL) preserved.
pause
goto CLEAN_MENU

:EXEC_SRC_DL
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "src-dl-cache" "%TARGET_PROFILE_ID%"
echo [INFO] DL cache cleaned.
pause
goto CLEAN_MENU

:EXEC_SRC_CCACHE
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "src-ccache" "%TARGET_PROFILE_ID%"
echo [INFO] Compiler cache cleaned.
pause
goto CLEAN_MENU

:EXEC_SRC_ALL
echo [CLEAN] Full SourceBuilder reset for %TARGET_PROFILE_ID%...
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
echo [INFO] Full cleanup completed.
pause
goto CLEAN_MENU

:: --- IMAGE ACTIONS ---
:EXEC_IMG_SDK
:: Сначала освобождаем контейнер, иначе том занят
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "imagebuilder-cache" "%TARGET_PROFILE_ID%"
echo [INFO] SDK cleaned.
pause
goto CLEAN_MENU

:EXEC_IMG_IPK
:: Сначала освобождаем контейнер
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "ipk-cache" "%TARGET_PROFILE_ID%"
echo [INFO] IPK cache cleaned.
pause
goto CLEAN_MENU

:EXEC_IMG_ALL
echo [CLEAN] Full ImageBuilder reset for %TARGET_PROFILE_ID%...
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
echo [INFO] Full cleanup completed.
pause
goto CLEAN_MENU

:WIZARD
cls
echo ==========================================
echo  %L_WIZ_START%
echo ==========================================
echo.
if exist "system/create_profile.ps1" (
    powershell -ExecutionPolicy Bypass -File "system/create_profile.ps1"
    echo.
    echo %L_WIZ_DONE%
    pause
) else (
    echo %L_ERR_WIZ%
    pause
)
goto MENU

:INVALID
echo %L_ERR_INPUT%
pause
goto MENU

:: =========================================================
::  MENUCONFIG SECTION
:: =========================================================
:MENUCONFIG_SELECTION
if not "%BUILD_MODE%"=="SOURCE" goto MENU
cls
echo ==========================================================
echo  %C_KEY%%L_K_TITLE%%C_RST%
echo ==========================================================
echo.
echo  %L_K_DESC%: %C_LBL%firmware_output\sourcebuilder\%C_VAL%[PROFILE_ID]%C_RST%
echo.
echo  %L_K_SEL%:
echo.

for /L %%i in (1,1,%count%) do (
    echo    [%%i] !profile[%%i]:.conf=!
)
echo.
echo    [0] %L_BACK%
echo.

set "k_choice="
set /p k_choice="%L_CHOICE%: "

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
echo [SETUP] Preparing environment for %PROFILE_ID%...

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
set "HOST_PKGS_DIR=./src_packages/%PROFILE_ID%"
set "HOST_OUTPUT_DIR=%REL_OUT_PATH%"
set "WIN_OUT_PATH=%REL_OUT_PATH:./=%"
set "WIN_OUT_PATH=%WIN_OUT_PATH:/=\%"

:: Создаем папку, если нет
if not exist "%WIN_OUT_PATH%" mkdir "%WIN_OUT_PATH%"

:: === ПРОВЕРКА НА ПЕРЕЗАПИСЬ ===
if exist "%WIN_OUT_PATH%\manual_config" (
    echo.
    echo %L_K_WARN_EX%
    echo.
    echo    %L_K_WARN_L1%
    echo    %L_K_WARN_L2%
    echo.
    set "overwrite="
    set /p "overwrite=%L_K_CONT%: "
    if /i not "!overwrite!"=="Y" (
        echo Cancelled.
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
echo sed 's/\r$//' "/profiles/$CONF_FILE" ^| sed '1s/^\xEF\xBB\xBF//' ^> /tmp/env.sh >> "%RUNNER_SCRIPT%"
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

echo # --- 2.5 Inject Custom Packages --- >> "%RUNNER_SCRIPT%"
echo if [ -d "/input_packages" ] ^&^& [ -n "$(ls -A /input_packages 2>/dev/null)" ]; then >> "%RUNNER_SCRIPT%"
echo     echo "[PKG] Injecting custom sources..." >> "%RUNNER_SCRIPT%"
echo     mkdir -p package/custom-imports >> "%RUNNER_SCRIPT%"
echo     cp -rf /input_packages/* package/custom-imports/ >> "%RUNNER_SCRIPT%"
echo     # Глубокая очистка индексов >> "%RUNNER_SCRIPT%"
echo     rm -rf tmp/.packageinfo >> "%RUNNER_SCRIPT%"
echo     rm -rf tmp/.targetinfo >> "%RUNNER_SCRIPT%"
echo     # Команда для переиндексации >> "%RUNNER_SCRIPT%"
echo     ./scripts/feeds install -a >> "%RUNNER_SCRIPT%"
echo fi >> "%RUNNER_SCRIPT%"

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
echo         echo "$SRC_EXTRA_CONFIG" ^>^> .config >> "%RUNNER_SCRIPT%"
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
echo echo "%L_K_SAVE%" >> "%RUNNER_SCRIPT%"
echo # Сначала чистим зависимости >> "%RUNNER_SCRIPT%"
echo make defconfig ^> /dev/null >> "%RUNNER_SCRIPT%"
echo # Генерируем дифф во временный файл >> "%RUNNER_SCRIPT%"
echo ./scripts/diffconfig.sh ^> /tmp/compact_config >> "%RUNNER_SCRIPT%"
echo. >> "%RUNNER_SCRIPT%"

echo # Проверка и сохранение >> "%RUNNER_SCRIPT%"
echo if [ -s /tmp/compact_config ]; then >> "%RUNNER_SCRIPT%"
echo     cp /tmp/compact_config /output/manual_config >> "%RUNNER_SCRIPT%"
echo     L_COUNT=$(cat /output/manual_config ^| wc -l) >> "%RUNNER_SCRIPT%"
echo     echo -e "\033[92m[SUCCESS]\033[0m %L_K_SAVED%: \033[93m$L_COUNT\033[0m %L_K_STR%." >> "%RUNNER_SCRIPT%"
echo else >> "%RUNNER_SCRIPT%"
echo     echo -e "\033[91m[WARNING]\033[0m %L_K_EMPTY_DIFF%" >> "%RUNNER_SCRIPT%"
echo     cp .config /output/manual_config >> "%RUNNER_SCRIPT%"
echo fi >> "%RUNNER_SCRIPT%"
echo. >> "%RUNNER_SCRIPT%"

echo # Права доступа >> "%RUNNER_SCRIPT%"
echo chmod 666 /output/manual_config >> "%RUNNER_SCRIPT%"
echo touch /output/manual_config >> "%RUNNER_SCRIPT%"
echo. >> "%RUNNER_SCRIPT%"
echo # --- 6. Interactive Shell Option --- >> "%RUNNER_SCRIPT%"
echo printf "\n\033[92m[SUCCESS]\033[0m %L_K_FINAL% \n" >> "%RUNNER_SCRIPT%"
echo read -p "%L_K_STAY% " stay >> "%RUNNER_SCRIPT%"
echo if [[ "$stay" =~ ^^[Yy]$ ]]; then >> "%RUNNER_SCRIPT%"
echo     echo -e "\n\033[92m%L_K_SHELL_H1%: $(pwd)\033[0m" >> "%RUNNER_SCRIPT%"
echo     echo -e "----------------------------------------------------------" >> "%RUNNER_SCRIPT%"
echo     echo -e "%L_K_SHELL_H2%" >> "%RUNNER_SCRIPT%"
echo     echo -e "%L_K_SHELL_H3%" >> "%RUNNER_SCRIPT%"
echo     echo -e "----------------------------------------------------------\n" >> "%RUNNER_SCRIPT%"
echo     /bin/bash >> "%RUNNER_SCRIPT%"
echo fi >> "%RUNNER_SCRIPT%"
echo %L_K_LAUNCH%
echo.
:: Важно: добавлена опция -it для интерактивного режима shell
set "HOST_PKGS_DIR=./src_packages/%PROFILE_ID%" && docker-compose -f system/docker-compose-src.yaml -p %PROJ_NAME% run --build --rm -it %SERVICE_NAME% /bin/bash -c "chown -R build:build /home/build/openwrt && chown build:build /output && tr -d '\r' < /output/_menuconfig_runner.sh > /tmp/r.sh && chmod +x /tmp/r.sh && sudo -E -u build bash /tmp/r.sh"
:: --- БЛОК ПОСТ-ОБРАБОТКИ КОНФИГУРАЦИИ ---
if exist "%WIN_OUT_PATH%\manual_config" (
    echo.
    echo %C_KEY%----------------------------------------------------------%C_RST%
    
    :: Получаем метку времени
    for /f "usebackq" %%a in (`powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd_HHmmss'"`) do set "ts=%%a"
    
    :: Выводим информацию о целевом файле
    echo %C_KEY%[SYNC]%C_RST% Target: %C_VAL%%CONF_FILE%%C_RST%
    
    set "m_apply="
    :: Используем переменную вопроса из словаря напрямую
    set /p "m_apply=%L_K_MOVE_ASK%: "
    
    if /i "!m_apply!"=="Y" (
        echo [PROCESS] Syncing data...
        powershell -NoProfile -Command ^
            "$confPath = 'profiles\%CONF_FILE%';" ^
            "$manualPath = '%WIN_OUT_PATH%\manual_config';" ^
            "$confLines = Get-Content $confPath;" ^
            "$manualLines = Get-Content $manualPath | Where-Object { $_.Trim() -ne '' };" ^
            "if ($manualLines) {" ^
            "    $cleanConf = $confLines | Where-Object { $_ -notmatch '^SRC_EXTRA_CONFIG=' };" ^
            "    $LF = [char]10;" ^
            "    $formatted = $manualLines -join $LF;" ^
            "    $newVar = 'SRC_EXTRA_CONFIG=\"' + $LF + $formatted + $LF + '\"';" ^
            "    $finalContent = ($cleanConf -join $LF).TrimEnd() + $LF + $LF + $newVar + $LF;" ^
            "    [System.IO.File]::WriteAllText($confPath, $finalContent, (New-Object System.Text.UTF8Encoding($false)));" ^
            "    Write-Host '%L_K_MOVE_OK%';" ^
            "}"
        :: Сохраняем архив примененных настроек
        move /y "%WIN_OUT_PATH%\manual_config" "%WIN_OUT_PATH%\applied_config_!ts!.bak" >nul
        echo [INFO] Archived to: applied_config_!ts!.bak
    ) else (
        :: Сохраняем архив отмененных настроек
        move /y "%WIN_OUT_PATH%\manual_config" "%WIN_OUT_PATH%\discarded_config_!ts!.bak" >nul
        echo [INFO] Archived to: discarded_config_!ts!.bak
    )
    echo %C_KEY%----------------------------------------------------------%C_RST%
)
if exist "%RUNNER_SCRIPT%" del "%RUNNER_SCRIPT%"
echo.
echo %L_DONE_MENU%
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
echo [PROCESSING] %L_PROC_PROF%: %CONF_FILE%
echo [MODE]       %BUILD_MODE%

:: 1. ИЗВЛЕЧЕНИЕ ПЕРЕМЕННОЙ
for /f "usebackq tokens=2 delims==" %%a in (`type "profiles\%CONF_FILE%" ^| findstr "%TARGET_VAR%"`) do (
    set "VAL=%%a"
    set "VAL=!VAL:"=!"
    for /f "tokens=* delims= " %%b in ("!VAL!") do set "TARGET_VAL=%%b"
)
if "%TARGET_VAL%"=="" (
    echo [SKIP] %TARGET_VAR% %L_ERR_VAR_NF%
    echo %L_ERR_SKIP%
    exit /b
)

:: 2. ПРОВЕРКА ВЕРСИИ (Legacy)
echo "!TARGET_VAL!" | findstr /C:"/19." >nul && set IS_LEGACY=1
echo "!TARGET_VAL!" | findstr /C:"/18." >nul && set IS_LEGACY=1
echo "!TARGET_VAL!" | findstr /C:"/17." >nul && set IS_LEGACY=1
echo "!TARGET_VAL!" | findstr /C:"19.07" >nul && set IS_LEGACY=1
echo "!TARGET_VAL!" | findstr /C:"18.06" >nul && set IS_LEGACY=1

:: 3. НАСТРОЙКА ПУТЕЙ И DOCKER
if "%BUILD_MODE%"=="IMAGE" (
    :: --- ПУТИ ДЛЯ IMAGE BUILDER ---
    set "REL_OUT_PATH=./firmware_output/imagebuilder/%PROFILE_ID%"
    set "HOST_PKGS_DIR=./custom_packages/%PROFILE_ID%"
    set "PROJ_NAME=build_%PROFILE_ID%"
    set "COMPOSE_ARG=-f system/docker-compose.yaml"
    set "WINDOW_TITLE=I: %PROFILE_ID%"
    if DEFINED IS_LEGACY (set "SERVICE_NAME=builder-oldwrt") else (set "SERVICE_NAME=builder-openwrt")
) else (
    :: --- ПУТИ ДЛЯ SOURCE BUILDER ---
    set "REL_OUT_PATH=./firmware_output/sourcebuilder/%PROFILE_ID%"
    set "HOST_PKGS_DIR=./src_packages/%PROFILE_ID%"
    set "PROJ_NAME=srcbuild_%PROFILE_ID%"
    set "COMPOSE_ARG=-f system/docker-compose-src.yaml"
    set "WINDOW_TITLE=S: %PROFILE_ID%"
    if DEFINED IS_LEGACY (set "SERVICE_NAME=builder-src-oldwrt") else (set "SERVICE_NAME=builder-src-openwrt")
)

:: Создаем папку
if not exist "%REL_OUT_PATH%" mkdir "%REL_OUT_PATH%"
echo [LAUNCH] Starting: %PROFILE_ID%
echo [INFO]   Target: !TARGET_VAL!
echo [INFO]   Service: %SERVICE_NAME%

:: 4. ЗАПУСК (Используем уже вычисленные переменные путей)
START "%WINDOW_TITLE%" cmd /c ^"set "SELECTED_CONF=%CONF_FILE%" ^&^& set "HOST_FILES_DIR=./custom_files/%PROFILE_ID%" ^&^& set "HOST_PKGS_DIR=%HOST_PKGS_DIR%" ^&^& set "HOST_OUTPUT_DIR=%REL_OUT_PATH%" ^&^& (docker-compose %COMPOSE_ARG% -p %PROJ_NAME% up --build --force-recreate --remove-orphans %SERVICE_NAME% ^|^| echo %C_ERR%[FATAL ERROR] Docker process failed.%C_RST%) ^&^& echo. ^&^& echo %C_OK%=== WORK FINISHED ===%C_RST% ^&^& pause ^"
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

:CREATE_WIFI_ON_SCRIPT
:: Создает uci-default скрипт для включения Wi-Fi
if exist "custom_files\%~1\etc\uci-defaults\10-enable-wifi" exit /b
if not exist "custom_files\%~1\etc\uci-defaults" mkdir "custom_files\%~1\etc\uci-defaults" >nul 2>&1
(
    echo #!/bin/sh
    echo uci set wireless.radio0.disabled='0'
    echo uci set wireless.radio1.disabled='0'
    echo uci commit wireless
    echo wifi reload
    echo exit 0
) > "custom_files\%~1\etc\uci-defaults\10-enable-wifi"
exit /b