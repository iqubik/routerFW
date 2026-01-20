@echo off
rem file: _Builder.bat

set "VER_NUM=4.2"

setlocal enabledelayedexpansion
:: Фиксируем размер окна: 120 символов в ширину, 40 в высоту
mode con: cols=120 lines=40
:: Отключаем мигающий курсор (через PowerShell, так как в Batch нет нативного способа)
powershell -command "$ind = [System.Console]::CursorVisible; if($ind){[System.Console]::CursorVisible=$false}" 2>nul
cls
chcp 65001 >nul
:: Настройка ANSI цветов
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"

:: Reset (Сброс): Возврат к стандартному цвету терминала
set "C_RST=%ESC%[0m"

:: Gray (Серый): Для меток и заголовков
set "C_LBL=%ESC%[36m"

:: Cyan (Бирюзовый): Для меток, заголовков и ссылок
set "C_GRY=%ESC%[90m"

:: Bright Red (Ярко-красный): Для ошибок и предупреждений
set "C_ERR=%ESC%[91m"

:: Bright Green (Ярко-зеленый): Для статусов "ОК", путей и активных значений
set "C_VAL=%ESC%[92m"

:: Bright Yellow (Ярко-желтый): Для клавиш [A], [W] и важных акцентов
set "C_KEY=%ESC%[93m"

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
if not errorlevel 1 echo   %C_GRY%-%C_RST% UI Language Registry  %C_VAL%RU%C_RST% [+3]
if errorlevel 1     echo   %C_GRY%-%C_RST% UI Language Registry  %C_ERR%EN%C_RST%
:: 2. Проверка реестра: Язык дистрибутива (2 балла)
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Nls\Language" /v InstallLanguage 2>nul | findstr /I "0419" >nul
if not errorlevel 1 set /a "ru_score+=2"
if not errorlevel 1 echo   %C_GRY%-%C_RST% OS Install Locale     %C_VAL%RU%C_RST% [+2]
if errorlevel 1     echo   %C_GRY%-%C_RST% OS Install Locale     %C_ERR%EN%C_RST%
:: 3. Проверка PowerShell: Культура и список языков (4 балла)
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "(Get-Culture).Name + (Get-WinUserLanguageList).LanguageTag" 2^>nul`) do set "PS_CHECK=%%a"
echo !PS_CHECK! | findstr /I "ru" >nul
if not errorlevel 1 set /a "ru_score+=4"
if not errorlevel 1 echo   %C_GRY%-%C_RST% Culture and Lang List %C_VAL%RU%C_RST% [+4]
if errorlevel 1     echo   %C_GRY%-%C_RST% Culture and Lang List %C_ERR%EN%C_RST%
:: 4. Проверка кодировки консоли (1 балл)
chcp | findstr "866" >nul
if not errorlevel 1 set /a "ru_score+=1"
if not errorlevel 1 echo   %C_GRY%-%C_RST% Console CP 866        %C_VAL%RU%C_RST% [+1]
:: Логика суждения
if %ru_score% GEQ 5 set "SYS_LANG=RU"
:: === ПРИНУДИТЕЛЬНЫЙ ПЕРЕКЛЮЧАТЕЛЬ (OVERRIDE) ===
if /i "%FORCE_LANG%"=="RU" set "SYS_LANG=RU"
if /i "%FORCE_LANG%"=="EN" set "SYS_LANG=EN"
:: === СЛОВАРЬ (DICTIONARY) ===
if "%SYS_LANG%"=="RU" (
    set "L_R_OK=%C_VAL%[OK]%C_RST%"
    set "L_R_ERR=%C_ERR%[ОШИБКА]%C_RST% (Заблокирован?)"
    set "L_R_NOTHING=%C_GRY%[ИНФО] Нет данных для очистки.%C_RST%"
    set "L_SRV_DOWN=%C_LBL%[COMPOSE]%C_RST% Остановка сервисов..."
    set "L_SRV_ALREADY_DOWN=%C_GRY%[ИНФО] Сервисы не запущены.%C_RST%"
    set "L_FINISHED=%C_VAL%Операция завершена.%C_RST%"
    set "L_K_MOVE_ASK=Обновить профиль %C_VAL%!PROFILE_ID!.conf%C_RST% данными из Menuconfig? [Y/n]"
    set "L_K_MOVE_OK=%C_VAL%[ГОТОВО]%C_RST% Переменная SRC_EXTRA_CONFIG в профиле обновлена."
    set "L_K_MOVE_ARCH=Временный файл переименован в _manual_config."
    set "L_EXIT_CONFIRM=%C_ERR%Выйти из программы? (Y/n):%C_RST% "
    set "L_EXIT_BYE=%C_VAL%До новых встреч!%C_RST%"
    set "H_PROF=Профиль"
    set "H_ARCH=Архитектура"
    set "H_RES=Ресурсы | Сборки"
    set "L_VERDICT=Вердикт"
    set "L_LANG_NAME=RU"
    set "L_INIT_ENV=%C_LBL%[СТАРТ]%C_RST% Проверка окружения..."
    set "L_ERR_DOCKER=%C_ERR%[ОШИБКА] Docker не обнаружен!%C_RST%"
    set "L_ERR_DOCKER_MSG=Убедитесь, что %C_VAL%Docker Desktop%C_RST% установлен и запущен."
    set "L_INIT_NET=%C_LBL%[СТАРТ]%C_RST% Очистка неиспользуемых сетей Docker..."
    set "L_INIT_UNPACK=%C_LBL%[СТАРТ]%C_RST% Проверка распаковщика..."
    set "L_MODE_IMG=%C_LBL%IMAGE BUILDER%C_RST% (%C_GRY%Быстрая сборка%C_RST%)"
    set "L_MODE_SRC=%C_ERR%SOURCE BUILDER%C_RST% (%C_GRY%Полная компиляция%C_RST%)"
    set "L_CUR_MODE=Текущий режим"
    set "L_PROFILES=Профили сборки"
    set "L_LEGEND_IND=%C_GRY%Индикаторы справа от профиля показывают состояние папок, файлов и результатов сборки%C_RST%"
    set "L_LEGEND_TEXT=Легенда: %C_GRY%F%C_RST%:Файлы %C_KEY%P%C_RST%:Пакеты %C_VAL%S%C_RST%:Исх %C_ERR%M%C_RST%:manual_config %C_LBL%H%C_RST%:hooks %C_GRY%|%C_RST% %C_GRY%Прошивки:%C_RST% %C_VAL%OI%C_RST%:Образ %C_VAL%OS%C_RST%:Сборка"
    set "L_BTN_ALL=Собрать ВСЕ"
    set "L_BTN_SWITCH=Режим на "
    set "L_BTN_EDIT=Редактор"
    set "L_BTN_CLEAN=Обслуживание"
    set "L_BTN_WIZ=Мастер профилей"
    set "L_BTN_EXIT=Выход"
    set "L_BTN_IPK=Импорт IPK"
    set "L_CHOICE=%C_LBL%Введите номер профиля для сборки или команду:%C_RST%"
    set "L_RUNNING=%C_VAL%Сборка запущена...%C_RST%"
    set "L_EDIT_TITLE=%C_VAL%МЕНЕДЖЕР РЕСУРСОВ И РЕДАКТОР ПРОФИЛЯ%C_RST%"
    set "L_SEL_PROF=%C_LBL%Выберите профиль для работы%C_RST%"
    set "L_BACK=%C_KEY%Назад%C_RST%"
    set "L_ANALYSIS=%C_LBL%[АНАЛИЗ СОСТОЯНИЯ ПРОФИЛЯ%C_RST%"
    set "L_MISSING=%C_ERR%Отсутствует%C_RST%"
    set "L_EMPTY=%C_GRY%Пусто%C_RST%"
    set "L_READY=%C_VAL%Готов%C_RST%"
    set "L_FOUND=%C_VAL%Найдено%C_RST%"
    set "L_ST_CONF=Конфигурация"
    set "L_ST_OVER=Overlay файлы"
    set "L_ST_IPK=Входящие IPK"
    set "L_ST_SRC=Исходники PKG"
    set "L_ST_OUTS=Выход Source"
    set "L_ST_OUTI=Выход Image"
    set "L_ACTION=ДЕЙСТВИЕ"
    set "L_OPEN_FILE=Открыть файл"
    set "L_OPEN_EXPL=Открыть также папки ресурсов в Проводнике?"
    set "L_START_EXPL=%C_LBL%[ИНФО]%C_RST% Запуск проводника..."    
    set "L_WARN_MASS=%C_ERR%[WARNING]%C_RST% Массовая компиляция из исходников! Это займет много времени."
    set "L_MASS_START=МАССОВЫЙ ЗАПУСК"
    set "L_IMPORT_IPK_TITLE=ИМПОРТ ПАКЕТОВ (IPK) ДЛЯ ПРОФИЛЯ"
    set "L_SEL_IMPORT=Выберите профиль для импорта пакетов"
    set "L_ERR_PS1_IPK=%C_ERR%[ОШИБКА]%C_RST% system/import_ipk.ps1 не найден!"
    set "L_CLEAN_TITLE=МЕНЮ ОЧИСТКИ И ОБСЛУЖИВАНИЯ"
    set "L_CLEAN_TYPE=Выберите тип данных для очистки"
    set "L_CLEAN_IMG_SDK=Очистить кэш %C_VAL%ImageBuilder (SDK)%C_RST% (Ядра и пакеты OpenWrt)"
    set "L_CLEAN_IMG_IPK=Очистить кэш %C_VAL%пакетов (IPK)%C_RST% (Папка dl/)"
    set "L_CLEAN_FULL=%C_ERR%FULL FACTORY RESET%C_RST% (Сброс проекта)"
    set "L_CLEAN_SRC_SOFT=%C_LBL%SOFT CLEAN%C_RST% (make clean) (%C_GRY%Очистка бинарников%C_RST%)"
    set "L_CLEAN_SRC_HARD=%C_ERR%HARD RESET%C_RST% (Удалить src-workdir) (%C_GRY%Сброс кода и тулчейна%C_RST%)"
    set "L_CLEAN_SRC_DL=Очистить кэш %C_VAL%исходников (dl)%C_RST% (Удалить архивы кода)"
    set "L_CLEAN_SRC_CC=Очистить %C_VAL%CCACHE%C_RST% (Кэш компилятора)"
    set "L_DOCKER_PRUNE=%C_LBL%Prune Docker%C_RST% (%C_GRY%Глобальная очистка мусора%C_RST%)"
    set "L_PRUNE_RUN=%C_LBL%[DOCKER]%C_RST% Выполняю system prune..."
    set "L_CLEAN_PROF_SEL=Для какого профиля выполнить очистку?"
    set "L_CLEAN_ALL_PROF=ДЛЯ ВСЕХ ПРОФИЛЕЙ (Глобальная очистка)"
    set "L_CONFIRM_YES=Введите %C_KEY%YES%C_RST% для подтверждения"
    set "L_CLEAN_RUN=%C_LBL%[ОЧИСТКА]%C_RST% Запуск процедуры..."
    set "L_K_TITLE=MENUCONFIG / SHELL / MC"
    set "L_K_DESC=Будет создан %C_VAL%manual_config%C_RST% в папке"
    set "L_K_SEL=Выберите профиль для настройки"
    set "L_K_WARN_EX=В папке профиля найден сохраненный конфиг: %C_VAL%manual_config%C_RST%"
    set "L_K_WARN_L1=1. Мы %C_VAL%ЗАГРУЗИМ%C_RST% его в редактор [вы продолжите настройку]."
    set "L_K_WARN_L2=2. После выхода из меню файл будет %C_ERR%ПЕРЕЗАПИСАН%C_RST% новыми данными."
    set "L_K_CONT=Продолжить? [Y/n]"
    set "L_K_SAVE=Фиксация конфигурации..."
    set "L_K_SAVED=Сохранено"
    set "L_K_STR=строк"
    set "L_K_EMPTY_DIFF=Дифф пуст, сохраняю полный конфиг."
    set "L_K_FINAL=Конфигурация сохранена в firmware_output"
    set "L_K_STAY=Остаться в контейнере для работы с файлами? [y/N]"
    set "L_K_SHELL_H1=[SHELL] Вход в консоль. Текущая папка"
    set "L_K_SHELL_H2=Подсказка: введите %C_KEY%mc%C_RST% для запуска файлового менеджера."
    set "L_K_SHELL_H3=Чтобы выйти в Windows и продолжить, введите %C_KEY%exit%C_RST%."
    set "L_K_LAUNCH=%C_LBL%[ИНФО]%C_RST% Запуск интерактивного Menuconfig..."
    set "L_WIZ_START=ЗАПУСК МАСТЕРА СОЗДАНИЯ ПРОФИЛЯ"
    set "L_ERR_WIZ=%C_ERR%[ОШИБКА]%C_RST% Файл create_profile.ps1 не найден!"
    set "L_ERR_INPUT=%C_ERR%Ошибка ввода.%C_RST%"    
    set "L_ERR_VAR_NF=не найден."
    set "L_ERR_SKIP=Возможно, этот профиль предназначен для другого режима."
    set "L_P_PROC=%C_LBL%[ЗАДАЧА]%C_RST%"
    set "L_P_MODE=%C_LBL%[РЕЖИМ]%C_RST%"
    set "L_P_SKIP=%C_GRY%[ПРОПУСК]%C_RST%"
    set "L_P_LAUNCH=%C_VAL%[ЗАПУСК]%C_RST%"
    set "L_P_TARGET=Цель"
    set "L_P_SERVICE=Сервис"
    set "L_BUILD_LAUNCHED=%C_VAL%Процессы запущены%C_RST%"
    set "L_BUILD_FATAL=%C_ERR%КРИТИЧЕСКАЯ ОШИБКА:%C_RST% Процесс Docker завершился неудачно."    
    set "L_CLEAN_CONFIRM_SEL=Выбор"
    set "L_CLEAN_CONFIRM_WARN=%C_ERR%ВНИМАНИЕ: Это удалит данные для ВСЕХ профилей!%C_RST%"
    set "L_VOL_SEARCH_ALL=Поиск всех томов с тегом:"
    set "L_VOL_DEL=Удаление:"
    set "L_VOL_SEARCH_PROF=Поиск тома для профиля:"
    set "L_VOL_DEL_EX=Удаление (если существует):"
    set "L_LOCK_REL_ALL=%C_LBL%[БЛОК]%C_RST% Освобождение всех контейнеров (удаление)..."
    set "L_LOCK_REL_PROF=%C_LBL%[БЛОК]%C_RST% Освобождение контейнера для профиля"
    set "L_CLEAN_SOFT_ALL_ERR=%C_ERR%[ОШИБКА] Soft Clean не поддерживается для режима ALL.%C_RST%"
    set "L_CLEAN_SOFT_ALL_HINT=Это занимает слишком много времени. Выполняйте по одному."
    set "L_CLEAN_START_CONTAINER=%C_LBL%[ОЧИСТКА]%C_RST% Запуск контейнера для make clean..."
    set "L_CLEAN_DONE_WORK=%C_LBL%[ИНФО]%C_RST% Рабочая директория очищена. Исходники (DL) сохранены."
    set "L_CLEAN_DONE_DL=%C_LBL%[ИНФО]%C_RST% Кэш исходников (DL) очищен."
    set "L_CLEAN_DONE_CC=%C_LBL%[ИНФО]%C_RST% Кэш компилятора очищен."
    set "L_CLEAN_FULL_RESET=%C_LBL%[ОЧИСТКА]%C_RST% Полный сброс для"
    set "L_CLEAN_FULL_DONE=%C_LBL%[ИНФО]%C_RST% Полная очистка завершена."
    set "L_CLEAN_DONE_SDK=%C_LBL%[ИНФО]%C_RST% Кэш SDK очищен."
    set "L_CLEAN_DONE_IPK=%C_LBL%[ИНФО]%C_RST% Кэш IPK очищен."
    set "L_K_SETUP=%C_LBL%[НАСТРОЙКА]%C_RST% Подготовка окружения для"
    set "L_K_CANCELLED=Отменено."
    set "L_K_SYNC=%C_LBL%[ПРОЦЕСС]%C_RST% Синхронизация данных и очистка профиля..."
    set "L_K_ARCHIVED=%C_LBL%[ИНФО]%C_RST% Архивировано в:"
    set "L_CLEAN_HEADER=%C_LBL%ОЧИСТКА%C_RST%"
    set "L_K_SYNC_TGT=%C_LBL%[СИНХР]%C_RST% Цель:"
    set "L_INFO=%C_LBL%[ИНФО]%C_RST%"
    set "L_SEPARATOR=----------------------------------------------------------"
    set "L_INIT_DOCKER_VER=Версия Docker"
    set "L_INIT_COMPOSE_VER=Версия Compose"
    set "L_INIT_ROOT=Корень проекта"
    set "L_INIT_SCAN=%C_LBL%[INIT]%C_RST% Сканирование профилей на отсутствие архитектуры..."
    set "L_BTN_MENUCONFIG=Menuconfig/mc"
    set "L_ST_SUFFIX_FILES=(файлы/)"
    set "L_ST_SUFFIX_IPK=(ipk/)"
    set "L_ST_SUFFIX_SRC=(make/)"
    set "L_ST_SUFFIX_OUT_S=(выход source/)"
    set "L_ST_SUFFIX_OUT_I=(выход image/)"    
) else (    
    set "L_R_OK=%C_VAL%[OK]%C_RST%"
    set "L_R_ERR=%C_ERR%[ERROR]%C_RST% (Locked?)"
    set "L_R_NOTHING=%C_GRY%[INFO] Nothing to clean.%C_RST%"
    set "L_SRV_DOWN=%C_LBL%[COMPOSE]%C_RST% Stopping services..."
    set "L_SRV_ALREADY_DOWN=%C_GRY%[INFO] Services already down.%C_RST%"
    set "L_FINISHED=%C_VAL%Операция завершена.%C_RST%"
    set "L_K_MOVE_ASK=Update %C_VAL%!PROFILE_ID!.conf%C_RST% profile with Menuconfig data? [Y/n]"
    set "L_K_MOVE_OK=%C_VAL%[DONE]%C_RST% SRC_EXTRA_CONFIG variable in profile updated."
    set "L_K_MOVE_ARCH=Temporary file renamed to %C_VAL%_manual_config%C_RST%."
    set "L_EXIT_CONFIRM=%C_ERR%Exit the program? (Y/n):%C_RST% "
    set "L_EXIT_BYE=%C_VAL%See you soon!%C_RST%"
    set "H_PROF=Profile"
    set "H_ARCH=Architecture"
    set "H_RES=Resources | Builds"
    set "L_VERDICT=Verdict"
    set "L_LANG_NAME=EN"
    set "L_INIT_ENV=%C_LBL%[INIT]%C_RST% Checking environment..."
    set "L_ERR_DOCKER=%C_ERR%[ERROR] Docker not found!%C_RST%"
    set "L_ERR_DOCKER_MSG=Make sure %C_VAL%Docker Desktop%C_RST% is installed and running."
    set "L_INIT_NET=%C_LBL%[INIT]%C_RST% Pruning unused Docker networks..."
    set "L_INIT_UNPACK=%C_LBL%[INIT]%C_RST% Checking unpacker..."
    set "L_MODE_IMG=%C_LBL%IMAGE BUILDER%C_RST% (%C_GRY%Fast Build%C_RST%)"
    set "L_MODE_SRC=%C_LBL%SOURCE BUILDER%C_RST% (%C_GRY%Full Compilation%C_RST%)"
    set "L_CUR_MODE=Current Mode"
    set "L_PROFILES=Build Profiles"
    set "L_LEGEND_IND=Indicators show the state of resources and build results."
    set "L_LEGEND_TEXT=Legend: %C_GRY%F%C_RST%:Files %C_KEY%P%C_RST%:Packages %C_VAL%S%C_RST%:Src %C_ERR%M%C_RST%:manual_config %C_LBL%H%C_RST%:hooks.sh | Firmwares: %C_VAL%OI%C_RST%:Image %C_VAL%OS%C_RST%:Build"
    set "L_BTN_ALL=Build ALL"
    set "L_BTN_SWITCH=Switch to"
    set "L_BTN_EDIT=Editor"
    set "L_BTN_CLEAN=Maintenance"
    set "L_BTN_WIZ=Profile Wizard"
    set "L_BTN_EXIT=Exit"
    set "L_BTN_IPK=Import IPK"
    set "L_CHOICE=%C_LBL%Select profile to build or command:%C_RST%"
    set "L_RUNNING=%C_VAL%Build started...%C_RST%"
    set "L_EDIT_TITLE=%C_VAL%RESOURCE MANAGER AND PROFILE EDITOR%C_RST%"
    set "L_SEL_PROF=%C_LBL%Select profile to work with%C_RST%"
    set "L_BACK=%C_KEY%Back%C_RST%"
    set "L_ANALYSIS=%C_LBL%[PROFILE STATE ANALYSIS%C_RST%"
    set "L_MISSING=%C_ERR%Missing%C_RST%"
    set "L_EMPTY=%C_GRY%Empty%C_RST%"
    set "L_READY=%C_VAL%Ready%C_RST%"
    set "L_FOUND=%C_VAL%Found%C_RST%"
    set "L_ST_CONF=Configuration"
    set "L_ST_OVER=Overlay files"
    set "L_ST_IPK=Inbound IPKs"
    set "L_ST_SRC=Source PKGs"
    set "L_ST_OUTS=Source Output"
    set "L_ST_OUTI=Image Output"
    set "L_ACTION=ACTION"
    set "L_OPEN_FILE=Open file"
    set "L_OPEN_EXPL=Open resource folders in Explorer too?"
    set "L_START_EXPL=%C_LBL%[INFO]%C_RST% Launching Explorer..."    
    set "L_WARN_MASS=%C_ERR%[WARNING]%C_RST% Massive source compilation! This will take a lot of time/CPU."
    set "L_MASS_START=MASSIVE LAUNCH"
    set "L_IMPORT_IPK_TITLE=PACKAGE IMPORT (IPK) FOR PROFILE"
    set "L_SEL_IMPORT=Select profile for package import"
    set "L_ERR_PS1_IPK=%C_ERR%[ERROR]%C_RST% system/import_ipk.ps1 not found!"
    set "L_CLEAN_TITLE=CLEANUP AND MAINTENANCE MENU"
    set "L_CLEAN_TYPE=Select data type to clean"
    set "L_CLEAN_IMG_SDK=Clean %C_VAL%ImageBuilder Cache (SDK)%C_RST% (OpenWrt kernels/pkgs)"
    set "L_CLEAN_IMG_IPK=Clean %C_VAL%Package Cache (IPK)%C_RST% (dl/ folder)"
    set "L_CLEAN_FULL=%C_ERR%FULL FACTORY RESET%C_RST% (Reset project)"
    set "L_CLEAN_SRC_SOFT=%C_LBL%SOFT CLEAN%C_RST% (make clean) (%C_GRY%Clean binaries%C_RST%)"
    set "L_CLEAN_SRC_HARD=%C_ERR%HARD RESET%C_RST% (Remove src-workdir) (%C_GRY%Reset code/toolchain%C_RST%)"
    set "L_CLEAN_SRC_DL=Clean %C_VAL%Source Cache (dl)%C_RST% (Remove source archives)"
    set "L_CLEAN_SRC_CC=Clean %C_VAL%CCACHE%C_RST% (Compiler cache)"
    set "L_DOCKER_PRUNE=%C_LBL%Prune Docker%C_RST% (%C_GRY%Global Docker cleanup%C_RST%)"
    set "L_PRUNE_RUN=%C_LBL%[DOCKER]%C_RST% Running system prune..."
    set "L_CLEAN_PROF_SEL=Which profile to clean?"
    set "L_CLEAN_ALL_PROF=FOR ALL PROFILES (Global cleanup)"
    set "L_CONFIRM_YES=Type %C_KEY%YES%C_RST% to confirm"
    set "L_CLEAN_RUN=%C_LBL%[CLEAN]%C_RST% Starting procedure..."
    set "L_K_TITLE=MENUCONFIG / SHELL / MC"
    set "L_K_DESC=%C_VAL%manual_config%C_RST% will be created in folder"
    set "L_K_SEL=Select profile to configure"
    set "L_K_WARN_EX=Found saved config in profile folder: %C_VAL%manual_config%C_RST%"
    set "L_K_WARN_L1=1. We will %C_VAL%LOAD%C_RST% it into editor [continue configuration]."
    set "L_K_WARN_L2=2. After exit, the file will be %C_ERR%OVERWRITTEN%C_RST% with new data."
    set "L_K_CONT=Continue? [Y/n]"
    set "L_K_SAVE=%C_LBL%[SAVE]%C_RST% Committing configuration..."
    set "L_K_SAVED=Saved"
    set "L_K_STR=lines"
    set "L_K_EMPTY_DIFF=Diff is empty, saving full config."
    set "L_K_FINAL=Configuration saved to firmware_output"
    set "L_K_STAY=Stay in container for file work? [y/N]"
    set "L_K_SHELL_H1=[SHELL] Entering console. Current folder"
    set "L_K_SHELL_H2=Tip: type %C_KEY%mc%C_RST% to launch file manager."
    set "L_K_SHELL_H3=To exit to Windows and continue, type %C_KEY%exit%C_RST%."
    set "L_K_LAUNCH=%C_LBL%[INFO]%C_RST% Launching Interactive Menuconfig..."
    set "L_WIZ_START=STARTING PROFILE WIZARD"
    set "L_ERR_WIZ=%C_ERR%[ERROR]%C_RST% create_profile.ps1 not found!"
    set "L_ERR_INPUT=%C_ERR%Input error.%C_RST%"    
    set "L_ERR_VAR_NF=not found."
    set "L_ERR_SKIP=Maybe this profile is for a different mode."
    set "L_P_PROC=%C_LBL%[TASK]%C_RST%"
    set "L_P_MODE=%C_LBL%[MODE]%C_RST%"
    set "L_P_SKIP=%C_GRY%[SKIP]%C_RST%"
    set "L_P_LAUNCH=%C_VAL%[LAUNCH]%C_RST%"
    set "L_P_TARGET=Target"
    set "L_P_SERVICE=Service"
    set "L_BUILD_LAUNCHED=%C_VAL%Processes launched%C_RST%"
    set "L_BUILD_FATAL=%C_ERR%FATAL ERROR:%C_RST% Docker process failed."    
    set "L_CLEAN_CONFIRM_SEL=Selection"
    set "L_CLEAN_CONFIRM_WARN=%C_ERR%WARNING: This will delete data for ALL profiles!%C_RST%"
    set "L_VOL_SEARCH_ALL=Searching all volumes with tag:"
    set "L_VOL_DEL=Deleting:"
    set "L_VOL_SEARCH_PROF=Searching volume for profile:"
    set "L_VOL_DEL_EX=Deleting (if exists):"
    set "L_LOCK_REL_ALL=%C_LBL%[LOCK]%C_RST% Releasing all containers (removing)..."
    set "L_LOCK_REL_PROF=%C_LBL%[LOCK]%C_RST% Releasing container for profile"
    set "L_CLEAN_SOFT_ALL_ERR=%C_ERR%[ERROR] Soft Clean is not supported for ALL mode.%C_RST%"
    set "L_CLEAN_SOFT_ALL_HINT=It takes too much time. Perform one by one."
    set "L_CLEAN_START_CONTAINER=%C_LBL%[CLEAN]%C_RST% Starting container for make clean..."
    set "L_CLEAN_DONE_WORK=%C_LBL%[INFO]%C_RST% Work directory cleaned. Sources (DL) preserved."
    set "L_CLEAN_DONE_DL=%C_LBL%[INFO]%C_RST% DL cache cleaned."
    set "L_CLEAN_DONE_CC=%C_LBL%[INFO]%C_RST% Compiler cache cleaned."
    set "L_CLEAN_FULL_RESET=%C_LBL%[CLEAN]%C_RST% Full reset for"
    set "L_CLEAN_FULL_DONE=%C_LBL%[INFO]%C_RST% Full cleanup completed."
    set "L_CLEAN_DONE_SDK=%C_LBL%[INFO]%C_RST% SDK cache cleaned."
    set "L_CLEAN_DONE_IPK=%C_LBL%[INFO]%C_RST% IPK cache cleaned."
    set "L_K_SETUP=%C_LBL%[SETUP]%C_RST% Preparing environment for"
    set "L_K_CANCELLED=Cancelled."
    set "L_K_SYNC=%C_LBL%[PROCESS]%C_RST% Syncing data and cleaning profile..."
    set "L_K_ARCHIVED=%C_LBL%[INFO]%C_RST% Archived to:"
    set "L_CLEAN_HEADER=%C_LBL%CLEAN%C_RST%"
    set "L_K_SYNC_TGT=%C_LBL%[SYNC]%C_RST% Target:"
    set "L_INFO=%C_LBL%[INFO]%C_RST%"
    set "L_SEPARATOR=----------------------------------------------------------"
    set "L_INIT_DOCKER_VER=Docker Version"
    set "L_INIT_COMPOSE_VER=Compose Version"
    set "L_INIT_ROOT=Project Root"
    set "L_INIT_SCAN=%C_LBL%[INIT]%C_RST% Scanning profiles for missing architecture tags..."
    set "L_BTN_MENUCONFIG=Menuconfig/mc"
    set "L_ST_SUFFIX_FILES=(files/)"
    set "L_ST_SUFFIX_IPK=(ipk/)"
    set "L_ST_SUFFIX_SRC=(make/)"
    set "L_ST_SUFFIX_OUT_S=(source output/)"
    set "L_ST_SUFFIX_OUT_I=(image output/)"    
)
:: Финальный вывод вердикта
if /i "%FORCE_LANG%"=="AUTO" (
    echo %C_LBL%[INIT]%C_RST% %L_VERDICT% %C_VAL%%L_LANG_NAME%%C_RST% (Score %ru_score%/10)
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
echo   %C_GRY%-%C_RST% !L_INIT_DOCKER_VER!: %C_VAL%%D_VER%%C_RST%

:: Вывод версии Compose
for /f "tokens=*" %%i in ('docker-compose --version 2^>nul') do set "C_VER=%%i"
echo   %C_GRY%-%C_RST% !L_INIT_COMPOSE_VER!: %C_VAL%%C_VER%%C_RST%

:: Вывод корня проекта
echo   %C_GRY%-%C_RST% !L_INIT_ROOT!: %C_VAL%%CD%%C_RST%

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
echo !L_INIT_SCAN!
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
echo    !C_GRY!────────────────────────────────────────────────────────────────────────────────────────────────────────────────!C_RST!

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
    :: Извлекаем имя БЕЗ расширения для отображения в меню
    set "fname_display=%%~nf"

    :: Извлечение архитектуры
    set "this_arch=--------"
    for /f "usebackq tokens=2 delims==" %%a in (`type "profiles\%%~nxf" ^| findstr "SRC_ARCH"`) do (
        set "VAL=%%a"
        set "VAL=!VAL:"=!"
        for /f "tokens=* delims= " %%b in ("!VAL!") do set "this_arch=%%b"
    )

    :: --- ХИРУРГИЧЕСКАЯ РАСКРАСКА РЕСУРСОВ (F P S M H) ---
    set "st_f=!C_GRY!·!C_RST!" & dir /a-d /b /s "custom_files\!p_id!" 2>nul | findstr "^" >nul && set "st_f=!C_GRY!F!C_RST!"
    set "st_p=!C_GRY!·!C_RST!" & dir /a-d /b /s "custom_packages\!p_id!" 2>nul | findstr "^" >nul && set "st_p=!C_KEY!P!C_RST!"
    set "st_s=!C_GRY!·!C_RST!" & dir /a-d /b /s "src_packages\!p_id!" 2>nul | findstr "^" >nul && set "st_s=!C_VAL!S!C_RST!"
    set "st_m=!C_GRY!·!C_RST!" & if exist "firmware_output\sourcebuilder\!p_id!\manual_config" set "st_m=!C_ERR!M!C_RST!"        
    set "st_h=!C_GRY!·!C_RST!" & if exist "custom_files\!p_id!\hooks.sh" set "st_h=!C_LBL!H!C_RST!"

    :: Состояние вывода (OI OS) - Реагирует на ЛЮБЫЕ файлы в любых подпапках
    set "st_oi=!C_GRY!··!C_RST!"
    dir /s /a-d /b "firmware_output\imagebuilder\!p_id!\*" 2>nul | findstr "^" >nul && set "st_oi=!C_VAL!OI!C_RST!"
    set "st_os=!C_GRY!··!C_RST!"
    dir /s /a-d /b "firmware_output\sourcebuilder\!p_id!\*" 2>nul | findstr "^" >nul && set "st_os=!C_VAL!OS!C_RST!"
    
    :: ВЫРАВНИВАНИЕ (Сохранено без изменений)
    set "id_pad=!count!"
    if !count! LSS 10 set "id_pad= !count!"
    set "fname_display=%%~nf"
    set "tmp_name=!fname_display!                                             "
    set "n_name=!tmp_name:~0,45!"
    set "tmp_arch=!this_arch!                    "
    set "n_arch=!tmp_arch:~0,20!"

    :: ВЫВОД СТРОКИ
    echo    !C_GRY![!C_KEY!!id_pad!!C_GRY!]!C_RST! !n_name! !C_LBL!!n_arch!!C_RST! !C_GRY![!st_f!!st_p!!st_s!!st_m!!st_h! !C_RST!^|!C_GRY! !st_oi! !st_os!]!C_RST!
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
    echo    !C_LBL![!C_KEY!K!C_LBL!] !L_BTN_MENUCONFIG!      !C_LBL![!C_KEY!I!C_LBL!] !L_BTN_IPK!!C_RST!
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
    set "exit_confirm=Y"
    :: Используем локализованный вопрос и красный цвет ошибки для привлечения внимания
    set /p "exit_confirm=!C_ERR!!L_EXIT_CONFIRM!!C_RST!"
    if /i "!exit_confirm!"=="Y" (
        echo.
        :: Используем локализованное прощание и зеленый цвет успеха
        echo !C_VAL!!L_EXIT_BYE!!C_RST!
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
:: Используем зеленый цвет (%C_VAL%) для заголовка
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
set /p e_choice=%C_VAL%%L_CHOICE%: %C_RST%
if "%e_choice%"=="0" goto MENU
set /a n_e=%e_choice% 2>nul
if %n_e% gtr %count% goto INVALID
if %n_e% lss 1 goto INVALID
set "SEL_CONF=!profile[%n_e%]!"
set "SEL_ID=!profile[%n_e%]:.conf=!"

:: --- БЛОК ОТЛАДКИ / СОСТОЯНИЯ (DEBUG INFO) ---
echo.
echo %C_VAL%%L_ANALYSIS%: !SEL_ID!]%C_RST%
echo !L_SEPARATOR!
:: Проверка наличия папок для отладки
set "S_FILES=%C_ERR%%L_MISSING%%C_RST%"
set "S_PACKS=%C_ERR%%L_MISSING%%C_RST%"
set "S_SRCS=%C_ERR%%L_MISSING%%C_RST%"
set "S_OUT_S=%C_ERR%%L_EMPTY%%C_RST%"
set "S_OUT_I=%C_ERR%%L_EMPTY%%C_RST%"
if exist "custom_files\!SEL_ID!" set "S_FILES=%C_VAL%%L_READY% !L_ST_SUFFIX_FILES!%C_RST%"
if exist "custom_packages\!SEL_ID!" set "S_PACKS=%C_VAL%%L_READY% !L_ST_SUFFIX_IPK!%C_RST%"
if exist "src_packages\!SEL_ID!" set "S_SRCS=%C_VAL%%L_READY% !L_ST_SUFFIX_SRC!%C_RST%"
if exist "firmware_output\sourcebuilder\!SEL_ID!" set "S_OUT_S=%C_VAL%%L_FOUND% !L_ST_SUFFIX_OUT_S!%C_RST%"
if exist "firmware_output\imagebuilder\!SEL_ID!" set "S_OUT_I=%C_VAL%%L_FOUND% !L_ST_SUFFIX_OUT_I!%C_RST%"
echo  - %L_ST_CONF%:  %C_VAL%profiles\!SEL_CONF!%C_RST%
echo  - %L_ST_OVER%: !S_FILES!
echo  - %L_ST_IPK%:  !S_PACKS!
echo  - %L_ST_SRC%: !S_SRCS!
echo  - %L_ST_OUTS%:  !S_OUT_S!
echo  - %L_ST_OUTI%:   !S_OUT_I!
echo !L_SEPARATOR!
echo.
set "open_f=N"
echo %C_VAL%[%L_ACTION%]%C_RST% %L_OPEN_FILE% %C_VAL%!SEL_CONF!%C_RST% in editor...
set /p open_f=%C_LBL%%L_OPEN_EXPL% [%C_KEY%y%C_LBL%/%C_KEY%N%C_LBL%]: %C_RST%

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

echo %L_FINISHED%
timeout /t 2 >nul
goto MENU

:BUILD_ALL
if "%BUILD_MODE%"=="SOURCE" (
    echo.
    echo !L_WARN_MASS!
    pause
)
echo.
echo === !L_MASS_START! [%BUILD_MODE%] ===
for /L %%i in (1,1,%count%) do (
    set "CURRENT_CONF=!profile[%%i]!"
    call :BUILD_ROUTINE "!CURRENT_CONF!"
)
echo !L_BUILD_LAUNCHED!
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
echo.
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
echo  !L_CLEAN_HEADER!: %CLEAN_DESC%
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
set /p p_choice="!L_CHOICE! [1-%count% / A]: "
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
echo !L_CLEAN_CONFIRM_SEL!: %CLEAN_DESC%
echo !L_P_TARGET!:    %TARGET_PROFILE_NAME%
echo.
if "%TARGET_PROFILE_ID%"=="ALL" echo !C_ERR!!L_CLEAN_CONFIRM_WARN!!C_RST!
echo.
set "confirm="
set /p confirm="!L_CONFIRM_YES!: "

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
::  ИСПОЛНИТЕЛЬНЫЕ БЛОКИ (EXECUTION) - REFACTORED
:: =========================================================

:: --- ХЕЛПЕР ДЛЯ УДАЛЕНИЯ ТОМОВ (SMART & VERBOSE) ---
:: %1 - Часть имени тома (например src-workdir) или тег
:: %2 - Профиль (или ALL)
:HELPER_DEL_VOLUME
set "V_TAG=%~1"
set "P_ID=%~2"
set "FOUND_ANY="

if "%P_ID%"=="ALL" (
    echo   !L_VOL_SEARCH_ALL! !C_VAL!%V_TAG%!C_RST!
    :: Ищем по регулярному выражению в конце имени
    for /f "tokens=*" %%v in ('docker volume ls -q ^| findstr /R /C:"_%V_TAG%$"') do (
        call :DO_DELETE_VOL "%%v"
        set "FOUND_ANY=1"
    )
) else (
    echo   !L_VOL_SEARCH_PROF! !C_VAL!%P_ID%!C_RST! ... %V_TAG%
    :: Формируем список потенциальных имен
    set "patterns=build_%P_ID%_%V_TAG% srcbuild_%P_ID%_%V_TAG%"
    for %%v in (!patterns!) do (
        :: Проверяем, существует ли том, перед попыткой удаления (чтобы не спамить ошибками)
        docker volume inspect %%v >nul 2>&1
        if not errorlevel 1 (
            call :DO_DELETE_VOL "%%v"
            set "FOUND_ANY=1"
        )
    )
)

if not defined FOUND_ANY (
    echo   !L_R_NOTHING!
)
exit /b

:DO_DELETE_VOL
set "vol_name=%~1"
echo   !L_VOL_DEL! !vol_name!
:: Удаляем без подавления ошибок (2>nul), чтобы видеть причину (Locked/In use)
docker volume rm !vol_name! >nul
if not errorlevel 1 (
    echo     - !L_R_OK!
) else (
    echo     - !L_R_ERR!
)
exit /b

:: --- ХЕЛПЕР ДЛЯ СНЯТИЯ БЛОКИРОВОК (Удаление контейнеров) ---
:HELPER_RELEASE_LOCKS
set "P_ID=%~1"

:: Настройка заглушек (нужны для корректной работы docker-compose команд)
set "SELECTED_CONF=dummy"
set "HOST_FILES_DIR=./custom_files"
set "HOST_OUTPUT_DIR=./firmware_output"

if "%P_ID%"=="ALL" goto REL_ALL
goto REL_SINGLE

:REL_ALL
echo   !L_LOCK_REL_ALL!
if "%BUILD_MODE%"=="IMAGE" (
    set "d_filter=name=^build_"
) else (
    set "d_filter=name=^srcbuild_"
)

set "c_found="
for /f "tokens=*" %%c in ('docker ps -aq --filter "!d_filter!"') do (
    echo   !C_ERR![KILL]!C_RST! Container: %%c
    docker rm -f %%c
    set "c_found=1"
)
if not defined c_found echo   !L_R_NOTHING!
exit /b

:REL_SINGLE
echo   !L_LOCK_REL_PROF! !C_VAL!%P_ID%!C_RST!
if "%BUILD_MODE%"=="IMAGE" (
    set "PROJ_NAME=build_%P_ID%"
    set "YAML_FILE=system/docker-compose.yaml"
    set "d_filter=name=^build_%P_ID%"
) else (
    set "PROJ_NAME=srcbuild_%P_ID%"
    set "YAML_FILE=system/docker-compose-src.yaml"
    set "d_filter=name=^srcbuild_%P_ID%"
)

:: 1. Сначала пробуем штатную остановку через Compose
docker ps -q --filter "name=%PROJ_NAME%" | findstr "^" >nul
if not errorlevel 1 (
    echo   !L_SRV_DOWN!
    docker-compose -f !YAML_FILE! -p !PROJ_NAME! down
) else (
    echo   !L_SRV_ALREADY_DOWN!
)

:: 2. АГРЕССИВНАЯ ЗАЧИСТКА (Fix для "volume is in use")
:: Ищем любые остатки контейнеров с этим именем, даже если Compose их не видит
for /f "tokens=*" %%c in ('docker ps -aq --filter "!d_filter!"') do (
    echo   !C_ERR![FORCE KILL]!C_RST! Orphan container: %%c
    docker rm -f %%c >nul 2>&1
)
exit /b

:: --- SOURCE ACTIONS ---
:EXEC_SRC_SOFT
if "%TARGET_PROFILE_ID%"=="ALL" (
    echo !C_ERR!!L_CLEAN_SOFT_ALL_ERR!!C_RST!
    echo !L_CLEAN_SOFT_ALL_HINT!
    pause
    goto CLEAN_MENU
)
echo !L_CLEAN_START_CONTAINER!
set "SELECTED_CONF=%TARGET_PROFILE_NAME%"
set "HOST_FILES_DIR=./custom_files/%TARGET_PROFILE_ID%"
set "HOST_OUTPUT_DIR=./firmware_output/sourcebuilder/%TARGET_PROFILE_ID%"
set "PROJ_NAME=srcbuild_%TARGET_PROFILE_ID%"

:: Запускаем make clean с полным выводом в консоль
docker-compose -f system/docker-compose-src.yaml -p %PROJ_NAME% run --rm builder-src-openwrt /bin/bash -c "cd /home/build/openwrt && if [ -f Makefile ]; then echo '[CMD] make clean'; make clean; echo '[DONE] Clean Completed'; else echo '[WARN] Makefile not found'; fi"
echo.
pause
goto CLEAN_MENU

:EXEC_SRC_WORK
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "src-workdir" "%TARGET_PROFILE_ID%"
echo !L_CLEAN_DONE_WORK!
pause
goto CLEAN_MENU

:EXEC_SRC_DL
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "src-dl-cache" "%TARGET_PROFILE_ID%"
echo !L_CLEAN_DONE_DL!
pause
goto CLEAN_MENU

:EXEC_SRC_CCACHE
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "src-ccache" "%TARGET_PROFILE_ID%"
echo !L_CLEAN_DONE_CC!
pause
goto CLEAN_MENU

:EXEC_SRC_ALL
echo !L_CLEAN_FULL_RESET! SourceBuilder for !C_VAL!%TARGET_PROFILE_ID%!C_RST!
if not "%TARGET_PROFILE_ID%"=="ALL" (
    set "PROJ_NAME=srcbuild_%TARGET_PROFILE_ID%"
    set "SELECTED_CONF=dummy"
    set "HOST_FILES_DIR=./custom_files"
    set "HOST_OUTPUT_DIR=./firmware_output"
    
    echo   !L_SRV_DOWN! (Full)...
    :: Показываем процесс удаления сетей и томов
    docker-compose -f system/docker-compose-src.yaml -p !PROJ_NAME! down -v
) else (
    call :HELPER_RELEASE_LOCKS "ALL"
)

:: Дочищаем специфические тома, если compose down пропустил (или для ALL режима)
call :HELPER_DEL_VOLUME "src-workdir" "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "src-dl-cache" "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "src-ccache" "%TARGET_PROFILE_ID%"
echo.
echo !L_CLEAN_FULL_DONE!
pause
goto CLEAN_MENU

:: --- IMAGE ACTIONS ---
:EXEC_IMG_SDK
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "imagebuilder-cache" "%TARGET_PROFILE_ID%"
echo !L_CLEAN_DONE_SDK!
pause
goto CLEAN_MENU

:EXEC_IMG_IPK
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "ipk-cache" "%TARGET_PROFILE_ID%"
echo !L_CLEAN_DONE_IPK!
pause
goto CLEAN_MENU

:EXEC_IMG_ALL
echo !L_CLEAN_FULL_RESET! ImageBuilder for !C_VAL!%TARGET_PROFILE_ID%!C_RST!
if not "%TARGET_PROFILE_ID%"=="ALL" (
    set "PROJ_NAME=build_%TARGET_PROFILE_ID%"
    set "SELECTED_CONF=dummy"
    set "HOST_FILES_DIR=./custom_files"
    set "HOST_OUTPUT_DIR=./firmware_output"
    
    echo   !L_SRV_DOWN! (Full)...
    docker-compose -f system/docker-compose.yaml -p !PROJ_NAME! down -v
) else (
    call :HELPER_RELEASE_LOCKS "ALL"
)
call :HELPER_DEL_VOLUME "imagebuilder-cache" "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "ipk-cache" "%TARGET_PROFILE_ID%"
echo.
echo !L_CLEAN_FULL_DONE!
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
    echo %L_FINISHED%
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
echo !L_K_SETUP! %PROFILE_ID%...

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
    set "overwrite=Y"
    set /p "overwrite=%L_K_CONT%: "
    if /i not "!overwrite!"=="Y" (
        echo !L_K_CANCELLED!
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
echo         printf "%%b\n" "$SRC_EXTRA_CONFIG" ^| tr -d '\r' ^| while IFS= read -r line; do [ -n "$line" ] ^&^& echo "$line" ^>^> .config; done >> "%RUNNER_SCRIPT%"
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
:: FIX: Добавлен флаг security-opt для совместимости с новыми ядрами (Ubuntu 24.04 WSL)
set "HOST_PKGS_DIR=./src_packages/%PROFILE_ID%" && docker-compose -f system/docker-compose-src.yaml -p %PROJ_NAME% run --build --rm -it %SERVICE_NAME% /bin/bash -c "chown -R build:build /home/build/openwrt && chown build:build /output && tr -d '\r' < /output/_menuconfig_runner.sh > /tmp/r.sh && chmod +x /tmp/r.sh && sudo -E -u build bash /tmp/r.sh"
:: --- БЛОК ПОСТ-ОБРАБОТКИ КОНФИГУРАЦИИ ---
if exist "%WIN_OUT_PATH%\manual_config" (
    echo.
    echo %C_KEY%----------------------------------------------------------%C_RST%
    
    :: Получаем метку времени
    for /f "usebackq" %%a in (`powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd_HHmmss'"`) do set "ts=%%a"
    
    :: Выводим информацию о целевом файле
    echo !L_K_SYNC_TGT! %C_VAL%%CONF_FILE%%C_RST%
    
    set "m_apply=Y"
    :: Используем переменную вопроса из словаря напрямую
    set /p "m_apply=%L_K_MOVE_ASK%: "
    
    if /i "!m_apply!"=="Y" (
        echo !L_K_SYNC!
        powershell -NoProfile -Command "$p='profiles\%CONF_FILE%'; $m='%WIN_OUT_PATH%\manual_config'; $n=Get-Content $m | Where-Object {$_.Trim() -ne ''} | ForEach-Object { $_.Trim() -replace [char]39, ([char]39+[char]92+[char]39+[char]39) }; if ($n) { $old=Get-Content $p -Raw; $v='SRC_EXTRA_CONFIG=' + [char]39 + ($n -join [char]10) + [char]39; $q=[char]39 + '|' + [char]34; $reg='(?ms)SRC_EXTRA_CONFIG\s*=\s*(' + $q + ').*?\1'; if ($old -match $reg) { $f=$old -replace $reg, $v } elseif ($old -match 'SRC_EXTRA_CONFIG=') { $f=$old -replace '(?ms)SRC_EXTRA_CONFIG=.*', $v } else { $f=$old.Trim() + [char]13 + [char]10 + [char]13 + [char]10 + $v + [char]13 + [char]10 }; [IO.File]::WriteAllText($p, $f, [System.Text.UTF8Encoding]::new($false)) }" && echo !L_K_MOVE_OK!
        :: Сохраняем архив примененных настроек
        set "applied_filename=applied_config_!ts!.bak"
        move /y "%WIN_OUT_PATH%\manual_config" "%WIN_OUT_PATH%\!applied_filename!" >nul
        echo !L_K_ARCHIVED! !applied_filename!
    ) else (
        :: Сохраняем архив отмененных настроек
        set "discarded_filename=discarded_config_!ts!.bak"
        move /y "%WIN_OUT_PATH%\manual_config" "%WIN_OUT_PATH%\!discarded_filename!" >nul
        echo !L_K_ARCHIVED! !discarded_filename!
    )
    echo %C_KEY%----------------------------------------------------------%C_RST%
)
if exist "%RUNNER_SCRIPT%" del "%RUNNER_SCRIPT%"
echo.
echo %L_FINISHED%
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
echo !L_P_PROC! %H_PROF%: %CONF_FILE%
echo !L_P_MODE!  %BUILD_MODE%

:: 1. ИЗВЛЕЧЕНИЕ ПЕРЕМЕННОЙ
for /f "usebackq tokens=2 delims==" %%a in (`type "profiles\%CONF_FILE%" ^| findstr "%TARGET_VAR%"`) do (
    set "VAL=%%a"
    set "VAL=!VAL:"=!"
    for /f "tokens=* delims= " %%b in ("!VAL!") do set "TARGET_VAL=%%b"
)
if "%TARGET_VAL%"=="" (
    echo !L_P_SKIP! %TARGET_VAR% !L_ERR_VAR_NF!
    echo !L_ERR_SKIP!
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
echo !L_P_LAUNCH! %PROFILE_ID%
echo !L_INFO!   !L_P_TARGET!: !TARGET_VAL!
echo !L_INFO!   !L_P_SERVICE!: %SERVICE_NAME%

:: 4. ЗАПУСК (Используем уже вычисленные переменные путей)
START "%WINDOW_TITLE%" cmd /c ^"set "SELECTED_CONF=%CONF_FILE%" ^&^& set "HOST_FILES_DIR=./custom_files/%PROFILE_ID%" ^&^& set "HOST_PKGS_DIR=%HOST_PKGS_DIR%" ^&^& set "HOST_OUTPUT_DIR=%REL_OUT_PATH%" ^&^& (docker-compose %COMPOSE_ARG% -p %PROJ_NAME% up --build --force-recreate --remove-orphans %SERVICE_NAME% ^|^| echo !L_BUILD_FATAL!) ^&^& echo. ^&^& echo !L_FINISHED! ^&^& pause ^"
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
