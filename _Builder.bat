@echo off
rem file: _Builder.bat
rem CLI: --lang=RU|EN или -l RU|EN — язык. [ib|src] — режим. build[b], build-all[a|all], edit[e], menuconfig[k], import[i], wizard[w], clean[c], help[-h|--help]. Примеры: --lang=EN build 1, ib build 1.

set "VER_NUM=4.50"

setlocal enabledelayedexpansion
:: Фиксируем размер окна: 120 символов в ширину, 40 в высоту (пропуск при ROUTERFW_NO_CLS — тестер)
if not defined ROUTERFW_NO_CLS mode con: cols=120 lines=40
:: Отключаем мигающий курсор (через PowerShell, так как в Batch нет нативного способа)
rem powershell -command "$ind = [System.Console]::CursorVisible; if($ind){[System.Console]::CursorVisible=$false}" 2>nul
if not defined ROUTERFW_NO_CLS cls
chcp 65001 >nul
:: Кодовая страница UTF-8 нужна для корректного вывода строк из system/lang/*.env (тестер задаёт ROUTERFW_NO_CLS, но вывод должен быть читаемым)
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

:: Alias (псевдоним C_VAL): Для успешных операций
set "C_OK=%C_VAL%"

:: === CLI: ключ языка в любой позиции; вырезаем его и собираем эффективный список аргументов ===
:: Только ключ языка (без других аргументов) = меню с принудительным языком. Иначе = CLI, ключ вырезается.
set "la1=%~1"
set "la2=%~2"
set "la3=%~3"
set "la4=%~4"
set "la5=%~5"
set "la6=%~6"
set "la7=%~7"
set "la8=%~8"
set "la9=%~9"
set "skip1=0" & set "skip2=0" & set "skip3=0" & set "skip4=0" & set "skip5=0" & set "skip6=0" & set "skip7=0" & set "skip8=0" & set "skip9=0"
for %%P in (1 2 3 4 5 6 7 8 9) do (
    set "lat=!la%%P!"
    if "!lat:~0,7!"=="--lang=" (
        set "skip%%P=1"
        if /i "!lat:~7!"=="RU" set "FORCE_LANG=RU"
        if /i "!lat:~7!"=="EN" set "FORCE_LANG=EN"
        if /i not "!lat:~7!"=="RU" if /i not "!lat:~7!"=="EN" set "CLI_LANG_ERROR=1"
    )
)
call :cli_lang_skip 1 2
call :cli_lang_skip 2 3
call :cli_lang_skip 3 4
call :cli_lang_skip 4 5
call :cli_lang_skip 5 6
call :cli_lang_skip 6 7
call :cli_lang_skip 7 8
call :cli_lang_skip 8 9
goto :cli_lang_done
:cli_lang_skip
set "curr=!la%1!"
set "next=!la%2!"
if /i "!curr!"=="--lang" if /i "!next!"=="RU" set "FORCE_LANG=RU" & set "skip%1=1" & set "skip%2=1"
if /i "!curr!"=="--lang" if /i "!next!"=="EN" set "FORCE_LANG=EN" & set "skip%1=1" & set "skip%2=1"
if /i "!curr!"=="-l"     if /i "!next!"=="RU" set "FORCE_LANG=RU" & set "skip%1=1" & set "skip%2=1"
if /i "!curr!"=="-l"     if /i "!next!"=="EN" set "FORCE_LANG=EN" & set "skip%1=1" & set "skip%2=1"
if /i "!curr!"=="--lang" if "!next!"=="" set "skip%1=1" & set "CLI_LANG_ERROR=1"
if /i "!curr!"=="--lang" if not "!next!"=="" if /i not "!next!"=="RU" if /i not "!next!"=="EN" set "skip%1=1" & set "skip%2=1" & set "CLI_LANG_ERROR=1"
if /i "!curr!"=="-l"     if "!next!"=="" set "skip%1=1" & set "CLI_LANG_ERROR=1"
if /i "!curr!"=="-l"     if not "!next!"=="" if /i not "!next!"=="RU" if /i not "!next!"=="EN" set "skip%1=1" & set "skip%2=1" & set "CLI_LANG_ERROR=1"
goto :eof
:cli_lang_done

:: === ЯЗЫКОВОЙ МОДУЛЬ ===
:: ТУМБЛЕR: AUTO (детект), RU (всегда рус), EN (всегда англ)
if not defined FORCE_LANG set "FORCE_LANG=AUTO"
set "SYS_LANG=EN"
set /a "ru_score=0"
:: Bootstrap — dict not yet available; hardcoded strings are intentional
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
:: 3. Проверка PowerShell: системная локаль (4 балла) — Get-WinSystemLocale, как в sh/WSL, надёжнее чем Get-Culture+Get-WinUserLanguageList
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "(Get-WinSystemLocale).Name" 2^>nul`) do set "PS_CHECK=%%a"
echo !PS_CHECK! | findstr /I "ru" >nul
if not errorlevel 1 set /a "ru_score+=4"
if not errorlevel 1 echo   %C_GRY%-%C_RST% System Locale (PS)   %C_VAL%RU%C_RST% [+4]
if errorlevel 1     echo   %C_GRY%-%C_RST% System Locale (PS)   %C_ERR%EN%C_RST%
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
set "LANG_FILE=system\lang\%SYS_LANG%.env"
if not exist "%LANG_FILE%" set "LANG_FILE=system\lang\en.env"
for /f "usebackq eol=# tokens=1,* delims==" %%k in ("%LANG_FILE%") do (
    set "_v=%%l"
    set "_v=!_v:{C_VAL}=%C_VAL%!"
    set "_v=!_v:{C_RST}=%C_RST%!"
    set "_v=!_v:{C_ERR}=%C_ERR%!"
    set "_v=!_v:{C_GRY}=%C_GRY%!"
    set "_v=!_v:{C_LBL}=%C_LBL%!"
    set "_v=!_v:{C_KEY}=%C_KEY%!"
    set "_v=!_v:{C_OK}=%C_OK%!"
    set "%%k=!_v!"
)
if defined CLI_LANG_ERROR echo !L_CLI_ERR_LANG! & exit /b 1
:: Финальный вывод вердикта
if /i "%FORCE_LANG%"=="AUTO" (
    echo %C_LBL%[INIT]%C_RST% %L_VERDICT% %C_VAL%%L_LANG_NAME%%C_RST% (Score %ru_score%/10^)
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
call :CHECK_DIR "custom_patches"
call :CHECK_DIR "firmware_output"
call :CHECK_DIR "firmware_output\imagebuilder"
call :CHECK_DIR "firmware_output\sourcebuilder"
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

:: === CLI: эффективный список аргументов (без ключа языка); префикс режима (ib/src), команда ===
set "p1=" & set "p2=" & set "p3=" & set "p4=" & set "p5="
set "idx=0"
for %%P in (1 2 3 4 5 6 7 8 9) do (
    if "!skip%%P!"=="0" (
        set /a idx+=1
        set "p!idx!=!la%%P!"
    )
)
if not "!p1!"=="" (
    set "mode_shift=0"
    if /i "!p1!"=="ib"     set "BUILD_MODE=IMAGE"  & set "mode_shift=1"
    if /i "!p1!"=="image"  set "BUILD_MODE=IMAGE"  & set "mode_shift=1"
    if /i "!p1!"=="src"    set "BUILD_MODE=SOURCE" & set "mode_shift=1"
    if /i "!p1!"=="source" set "BUILD_MODE=SOURCE" & set "mode_shift=1"
    if !mode_shift!==1 (
        set "c1=!p2!"
        set "c2=!p3!"
        set "c3=!p4!"
    ) else (
        set "c1=!p1!"
        set "c2=!p2!"
        set "c3=!p3!"
    )
    if /i "!c1!"=="build"     set "CLI_CMD=BUILD"     & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="b"         set "CLI_CMD=BUILD"     & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="build-all" set "CLI_CMD=BUILD_ALL" & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="all"       set "CLI_CMD=BUILD_ALL" & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="a"         set "CLI_CMD=BUILD_ALL" & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="edit"       set "CLI_CMD=EDIT"      & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="e"         set "CLI_CMD=EDIT"      & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="menuconfig" set "CLI_CMD=MENUCONFIG" & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="k"         set "CLI_CMD=MENUCONFIG" & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="import"     set "CLI_CMD=IMPORT"    & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="i"         set "CLI_CMD=IMPORT"    & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="wizard"     set "CLI_CMD=WIZARD"    & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="w"         set "CLI_CMD=WIZARD"    & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="clean"      set "CLI_CMD=CLEAN"     & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="c"         set "CLI_CMD=CLEAN"     & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="state"      set "CLI_CMD=STATE"    & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="s"         set "CLI_CMD=STATE"    & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="check-all"  set "CLI_CMD=CHECKSUM_ALL" & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="check-clear" set "CLI_CMD=CHECKSUM_CLEAR" & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="check"      set "CLI_CMD=CHECKSUM"     & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="help"       set "CLI_CMD=HELP"     & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="-h"         set "CLI_CMD=HELP"     & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if /i "!c1!"=="--help"     set "CLI_CMD=HELP"     & set "CLI_ARG1=!c2!" & set "CLI_ARG2=!c3!"
    if not defined CLI_CMD set "CLI_CMD=BUILD" & set "CLI_ARG1=!c1!" & set "CLI_ARG2=!c2!"
)

:MENU
if not defined ROUTERFW_NO_CLS cls
:: Очистка массива профилей
for /F "tokens=1 delims==" %%a in ('set profile[ 2^>nul') do set "%%a="
set "count=0"

:: 1. ЛОГИКА РЕЖИМА И ЯЗЫКА
if "%BUILD_MODE%"=="IMAGE" (
    if not defined ROUTERFW_NO_CLS color 0B
    set "MODE_TITLE=!L_MODE_IMG!"
    set "OPPOSITE_MODE=SOURCE"
    set "TARGET_VAR=IMAGEBUILDER_URL"
) else (
    if not defined ROUTERFW_NO_CLS color 0D
    set "MODE_TITLE=!L_MODE_SRC!"
    set "OPPOSITE_MODE= IMAGE"
    set "TARGET_VAR=SRC_BRANCH"
)

:: 2. ОТРИСОВКА ЗАГОЛОВКА (в CLI не выводим)
if not defined CLI_CMD (
echo !C_GRY!┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐!C_RST!
echo   !C_VAL!OpenWrt FW Builder !VER_NUM!!C_RST! [!C_VAL!!SYS_LANG!!C_RST!]          !C_LBL!https://github.com/iqubik/routerFW!C_RST!
echo   !L_CUR_MODE!: [!C_VAL!!MODE_TITLE!!C_RST!]
echo !C_GRY!└────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘!C_RST!
echo.
echo    !C_GRY! ID   !H_PROF!                                      !H_ARCH!          !H_RES!!C_RST!
echo    !C_GRY!────────────────────────────────────────────────────────────────────────────────────────────────────────────────!C_RST!
)

:: Очистка массива профилей
for /F "tokens=1 delims==" %%a in ('set profile[ 2^>nul') do set "%%a="
set "count=0"

:: === PROFILE MIGRATION (Idempotent) ===
:: Переименовывает PKGS -> IMAGE_PKGS и EXTRA_IMAGE_NAME -> IMAGE_EXTRA_NAME
:: во всех профилях. Запускается при каждом сканировании, безопасно (без изменений если уже мигрировано).
powershell -NoProfile -Command "Get-ChildItem 'profiles\*.conf' | ForEach-Object { $f=$_.FullName; $c=[IO.File]::ReadAllText($f); $changed=$false; if(($c -match '(?m)^PKGS=' -or $c -match '(?m)^#\s*PKGS=') -and $c -notmatch '(?m)^#?\s*IMAGE_PKGS='){ $c=$c -replace '(?m)^PKGS=','IMAGE_PKGS='; $c=$c -replace '(?m)^(#\s*)PKGS=','\${1}IMAGE_PKGS='; $c=$c -replace '\$PKGS\b','`$IMAGE_PKGS'; $changed=$true }; if(($c -match '(?m)^EXTRA_IMAGE_NAME=' -or $c -match '(?m)^#\s*EXTRA_IMAGE_NAME=') -and $c -notmatch '(?m)^#?\s*IMAGE_EXTRA_NAME='){ $c=$c -replace '(?m)^EXTRA_IMAGE_NAME=','IMAGE_EXTRA_NAME='; $c=$c -replace '(?m)^(#\s*)EXTRA_IMAGE_NAME=','\${1}IMAGE_EXTRA_NAME='; $changed=$true }; if($changed){ [IO.File]::WriteAllText($f,$c,[Text.UTF8Encoding]::new($false)) } }"

:: 3. ЦИКЛ СКАНИРОВАНИЯ (С поддержкой словаря)
if not defined CLI_CMD (
echo    !C_LBL!!L_PROFILES!:!C_RST!
echo.
)
for %%f in (profiles\*.conf) do (
    set /a count+=1
    set "profile[!count!]=%%~nxf"
    set "p_id=%%~nf"
    
    :: Авто-создание структуры (паритет с _Builder.sh: firmware_output/imagebuilder, firmware_output/sourcebuilder)
    if not exist "custom_files\!p_id!" mkdir "custom_files\!p_id!" >nul
    if not exist "custom_patches\!p_id!" mkdir "custom_patches\!p_id!" >nul
    if not exist "custom_packages\!p_id!" mkdir "custom_packages\!p_id!" >nul
    if not exist "src_packages\!p_id!" mkdir "src_packages\!p_id!" >nul
    if not exist "firmware_output\imagebuilder\!p_id!" mkdir "firmware_output\imagebuilder\!p_id!" >nul
    if not exist "firmware_output\sourcebuilder\!p_id!" mkdir "firmware_output\sourcebuilder\!p_id!" >nul
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
    set "st_pt=!C_GRY!·!C_RST!" & dir /a-d /b /s "custom_patches\!p_id!" 2>nul | findstr "^" >nul && set "st_pt=!C_GRY!X!C_RST!"

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

    :: ВЫВОД СТРОКИ (в CLI режиме таблицу не рисуем)
    if not defined CLI_CMD echo    !C_GRY![!C_KEY!!id_pad!!C_GRY!]!C_RST! !n_name! !C_LBL!!n_arch!!C_RST! !C_GRY![!st_f!!st_p!!st_s!!st_m!!st_h!!st_pt! !C_RST!^|!C_GRY! !st_oi! !st_os!]!C_RST!
)

if defined CLI_CMD goto CLI_DISPATCH

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
if /i "%choice%"=="F" (
    call :CLI_CHECKSUM_ALL
    pause
    goto MENU
)
if /i "%choice%"=="P" (
    if exist "_packer.bat" (
        start "" "_packer.bat"
    )
    goto MENU
)
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
if not defined ROUTERFW_NO_CLS cls
:: Используем зеленый цвет (%C_VAL%) для заголовка
echo !C_KEY!!L_SEPARATOR!!C_RST!
echo  %C_VAL%%L_EDIT_TITLE%%C_RST%
echo !C_KEY!!L_SEPARATOR!!C_RST!
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

:EDIT_OPEN
:: --- БЛОК ОТЛАДКИ / СОСТОЯНИЯ (DEBUG INFO) ---
echo.
echo %C_VAL%[%L_ANALYSIS%: !SEL_ID!]%C_RST%
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
set "enter_c=N"
echo %C_VAL%[%L_ACTION%]%C_RST% %L_OPEN_FILE% %C_VAL%!SEL_CONF!%C_RST% !L_IN_EDITOR!
set /p open_f=%C_LBL%%L_OPEN_EXPL% [%C_KEY%y%C_LBL%/%C_KEY%N%C_LBL%]: %C_RST%
set /p enter_c=%C_LBL%%L_ENTER_CONTAINER% !C_VAL!!SEL_ID!%C_RST%^?[%C_KEY%y%C_LBL%/%C_KEY%N%C_LBL%]: %C_RST%


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

:: 3. Вход в контейнер (перепрыгиваем логику, если ответ N)
if /i not "!enter_c!"=="Y" goto EDIT_DONE

set "TARGET_VAL="
set "IS_LEGACY="
for /f "usebackq tokens=2 delims==" %%a in (`type "profiles\!SEL_CONF!" ^| findstr "!TARGET_VAR!"`) do (
    set "VAL=%%a"
    set "VAL=!VAL:"=!"
    for /f "tokens=* delims= " %%b in ("!VAL!") do set "TARGET_VAL=%%b"
)

:: Безопасная проверка версии без конвейеров
if not "!TARGET_VAL:/19.=!" == "!TARGET_VAL!" set "IS_LEGACY=1"
if not "!TARGET_VAL:/18.=!" == "!TARGET_VAL!" set "IS_LEGACY=1"
if not "!TARGET_VAL:/17.=!" == "!TARGET_VAL!" set "IS_LEGACY=1"
if not "!TARGET_VAL:19.07=!" == "!TARGET_VAL!" set "IS_LEGACY=1"
if not "!TARGET_VAL:18.06=!" == "!TARGET_VAL!" set "IS_LEGACY=1"

:: Задаем обязательные переменные окружения, чтобы docker-compose смог смонтировать папки
set "SELECTED_CONF=!SEL_CONF!"
set "HOST_FILES_DIR=./custom_files/!SEL_ID!"

if "!BUILD_MODE!"=="SOURCE" (
    set "PROJ_NAME=srcbuild_!SEL_ID!"
    set "COMPOSE_ARG=-f system/docker-compose-src.yaml"
    if DEFINED IS_LEGACY (set "SERVICE_NAME=builder-src-oldwrt") else (set "SERVICE_NAME=builder-src-openwrt")
    set "HOST_OUTPUT_DIR=./firmware_output/sourcebuilder/!SEL_ID!"
    set "HOST_PKGS_DIR=./src_packages/!SEL_ID!"
    set "HOST_PATCHES_DIR=./custom_patches/!SEL_ID!"
) else (
    set "PROJ_NAME=build_!SEL_ID!"
    set "COMPOSE_ARG=-f system/docker-compose.yaml"
    if DEFINED IS_LEGACY (set "SERVICE_NAME=builder-oldwrt") else (set "SERVICE_NAME=builder-openwrt")
    set "HOST_OUTPUT_DIR=./firmware_output/imagebuilder/!SEL_ID!"
    set "HOST_PKGS_DIR=./custom_packages/!SEL_ID!"
)

echo.
echo !L_INFO! Entering container for %C_VAL%!PROJ_NAME!%C_RST% [%C_LBL%!SERVICE_NAME!%C_RST%]...
echo   !C_GRY!💡 Tip: Type !C_KEY!mc!C_GRY! inside to launch Midnight Commander!C_RST!

:: Разделяем логику входа. Для SOURCE полностью имитируем окружение из src_builder.sh
if "!BUILD_MODE!"=="SOURCE" (
    docker-compose !COMPOSE_ARG! -p !PROJ_NAME! run --rm -it !SERVICE_NAME! /bin/bash -c "if [ -d /home/build/openwrt/.git ] && [ x$(stat -c %%U /ccache 2>/dev/null) = xbuild ]; then echo '[INIT] Permissions OK'; else echo '[INIT] Fixing permissions...'; chown -R build:build /home/build/openwrt /ccache 2>/dev/null || true; fi && sudo -E -u build bash -c 'export HOME=/home/build; git config --global --add safe.directory \"*\"; cd /home/build/openwrt 2>/dev/null || cd /home/build; exec bash'"
) else (
    docker-compose !COMPOSE_ARG! -p !PROJ_NAME! run --rm -it !SERVICE_NAME! /bin/bash
)

:EDIT_DONE
echo %L_FINISHED%
timeout /t 2 >nul
if defined CLI_CMD exit /b 0
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
    timeout /t 1 >nul
)
echo !L_BUILD_LAUNCHED!
pause
if defined CLI_CMD exit /b 0
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
if not defined ROUTERFW_NO_CLS cls
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
if not defined ROUTERFW_NO_CLS cls
if not defined ROUTERFW_NO_CLS color 0E
set "MENU_SEP============================================================"
echo %C_KEY%!MENU_SEP!%C_RST%
echo  !L_CLEAN_TITLE! [%BUILD_MODE%]
echo %C_KEY%!MENU_SEP!%C_RST%
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
echo    [5] %L_CLEAN_SRC_TMP%
echo.
echo    [6] %L_CLEAN_FULL%

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
    if "%clean_choice%"=="5" set "CLEAN_TYPE=SRC_TMP"    & set "CLEAN_DESC=Package Index (tmp)"
    if "%clean_choice%"=="6" set "CLEAN_TYPE=SRC_ALL"    & set "CLEAN_DESC=FULL RESET (Source)"
)

if "%CLEAN_TYPE%"=="" goto INVALID
goto SELECT_PROFILE_FOR_CLEAN

:: =========================================================
::  ВЫБОР ПРОФИЛЯ ДЛЯ ОЧИСТКИ
:: =========================================================
:SELECT_PROFILE_FOR_CLEAN
if not defined ROUTERFW_NO_CLS cls
set "MENU_SEP============================================================"
echo %C_KEY%!MENU_SEP!%C_RST%
echo  !L_CLEAN_HEADER!: %CLEAN_DESC%
echo %C_KEY%!MENU_SEP!%C_RST%
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
if "%TARGET_PROFILE_ID%"=="ALL" if not defined ROUTERFW_NO_CLS color 0C
echo !L_CLEAN_CONFIRM_SEL!: %CLEAN_DESC%
echo !L_P_TARGET!:    %TARGET_PROFILE_NAME%
echo.
if "%TARGET_PROFILE_ID%"=="ALL" echo !C_ERR!!L_CLEAN_CONFIRM_WARN!!C_RST!
echo.
if defined CLI_CLEAN_YES (
    set "confirm=YES"
) else (
    set "confirm="
    set /p confirm="!L_CONFIRM_YES!: "
)

:: Если нажали Enter или ввели не YES - отмена
if /i not "!confirm!"=="YES" goto CLEAN_MENU
if not defined ROUTERFW_NO_CLS color 0E
echo.
echo %L_CLEAN_RUN%

:: === МАРШРУТИЗАЦИЯ ВЫПОЛНЕНИЯ ===
if "%CLEAN_TYPE%"=="SRC_SOFT" goto EXEC_SRC_SOFT
if "%CLEAN_TYPE%"=="SRC_WORK" goto EXEC_SRC_WORK
if "%CLEAN_TYPE%"=="SRC_DL"   goto EXEC_SRC_DL
if "%CLEAN_TYPE%"=="SRC_CCACHE" goto EXEC_SRC_CCACHE
if "%CLEAN_TYPE%"=="SRC_TMP"    goto EXEC_SRC_TMP
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
    rem Ищем по регулярному выражению в конце имени
    for /f "tokens=*" %%v in ('docker volume ls -q ^| findstr /R /C:"_%V_TAG%$"') do (
        call :DO_DELETE_VOL "%%v"
        set "FOUND_ANY=1"
    )
) else (
    echo   !L_VOL_SEARCH_PROF! !C_VAL!%P_ID%!C_RST! ... %V_TAG%
    rem Формируем список потенциальных имен
    set "patterns=build_%P_ID%_%V_TAG% srcbuild_%P_ID%_%V_TAG%"
    for %%v in (!patterns!) do (
        rem Проверяем, существует ли том, перед попыткой удаления (чтобы не спамить ошибками)
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
    echo   !L_KILL_CONTAINER! %%c
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
    echo   !L_KILL_ORPHAN! %%c
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
if defined CLI_CLEAN_YES exit /b 0
goto CLEAN_MENU

:EXEC_SRC_WORK
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "src-workdir" "%TARGET_PROFILE_ID%"
echo !L_CLEAN_DONE_WORK!
pause
if defined CLI_CLEAN_YES exit /b 0
goto CLEAN_MENU

:EXEC_SRC_DL
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "src-dl-cache" "%TARGET_PROFILE_ID%"
echo !L_CLEAN_DONE_DL!
pause
if defined CLI_CLEAN_YES exit /b 0
goto CLEAN_MENU

:EXEC_SRC_CCACHE
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "src-ccache" "%TARGET_PROFILE_ID%"
echo !L_CLEAN_DONE_CC!
pause
if defined CLI_CLEAN_YES exit /b 0
goto CLEAN_MENU

:EXEC_SRC_TMP
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

:: Запускаем удаление tmp внутри контейнера
docker-compose -f system/docker-compose-src.yaml -p %PROJ_NAME% run --rm builder-src-openwrt /bin/bash -c "cd /home/build/openwrt && echo '[CMD] rm -rf tmp/' && rm -rf tmp/ && echo '[DONE] Index/Tmp cleaned'"
echo.
pause
if defined CLI_CLEAN_YES exit /b 0
goto CLEAN_MENU

:EXEC_SRC_ALL
echo !L_CLEAN_FULL_RESET! SourceBuilder for !C_VAL!%TARGET_PROFILE_ID%!C_RST!
if not "%TARGET_PROFILE_ID%"=="ALL" (
    set "PROJ_NAME=srcbuild_%TARGET_PROFILE_ID%"
    set "SELECTED_CONF=dummy"
    set "HOST_FILES_DIR=./custom_files"
    set "HOST_OUTPUT_DIR=./firmware_output"

    echo   !L_SRV_DOWN! (Full)...
    rem Показываем процесс удаления сетей и томов
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
if defined CLI_CLEAN_YES exit /b 0
goto CLEAN_MENU

:: --- IMAGE ACTIONS ---
:EXEC_IMG_SDK
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "imagebuilder-cache" "%TARGET_PROFILE_ID%"
echo !L_CLEAN_DONE_SDK!
pause
if defined CLI_CLEAN_YES exit /b 0
goto CLEAN_MENU

:EXEC_IMG_IPK
call :HELPER_RELEASE_LOCKS "%TARGET_PROFILE_ID%"
call :HELPER_DEL_VOLUME "ipk-cache" "%TARGET_PROFILE_ID%"
echo !L_CLEAN_DONE_IPK!
pause
if defined CLI_CLEAN_YES exit /b 0
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
if defined CLI_CLEAN_YES exit /b 0
goto CLEAN_MENU

:WIZARD
if not defined ROUTERFW_NO_CLS cls
set "MENU_SEP============================================================"
echo %C_KEY%!MENU_SEP!%C_RST%
echo  !L_WIZ_START!
echo %C_KEY%!MENU_SEP!%C_RST%
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
if defined CLI_CMD exit /b 0
goto MENU

:INVALID
echo %L_ERR_INPUT%
pause
goto MENU

:: =========================================================
::  CLI DISPATCH (command-line mode)
:: =========================================================
:CLI_DISPATCH
if "%CLI_CMD%"=="HELP" goto CLI_HELP
if "%CLI_CMD%"=="STATE" goto CLI_STATE
if "%CLI_CMD%"=="WIZARD" goto WIZARD
if "%CLI_CMD%"=="BUILD_ALL" goto BUILD_ALL
if "%CLI_CMD%"=="BUILD" goto CLI_BUILD
if "%CLI_CMD%"=="EDIT" goto CLI_EDIT
if "%CLI_CMD%"=="MENUCONFIG" goto CLI_MENUCONFIG
if "%CLI_CMD%"=="IMPORT" goto CLI_IMPORT
if "%CLI_CMD%"=="CLEAN" goto CLI_CLEAN
if "%CLI_CMD%"=="CHECKSUM_ALL" goto CLI_CHECKSUM_ALL
if "%CLI_CMD%"=="CHECKSUM" goto CLI_CHECKSUM
if "%CLI_CMD%"=="CHECKSUM_CLEAR" goto CLI_CHECKSUM_CLEAR
echo !L_CLI_ERR_UNKNOWN_CMD!!CLI_CMD!!C_RST!
exit /b 1

:CLI_HELP
echo.
echo !C_LBL!!L_CLI_HELP_VER!!VER_NUM! !L_CLI_HELP_HEAD!!C_RST!
echo.
echo !C_GRY!!L_CLI_LANG_KEY!!C_RST!
echo !C_GRY!!L_CLI_MODE_PREFIX!!C_RST!
echo.
echo   build, b              ^<id^>                 %L_CLI_DESC_BUILD%
echo   build-all, a, all                          %L_CLI_DESC_BUILD_ALL%
echo   edit, e               [id]                 %L_CLI_DESC_EDIT%
echo   menuconfig, k         ^<id^>                 %L_CLI_DESC_MENUCONFIG%
echo   import, i             ^<id^>                 %L_CLI_DESC_IMPORT%
echo   wizard, w                                  %L_CLI_DESC_WIZARD%
echo   clean, c              [1-6/1-3] [id/A]     %L_CLI_DESC_CLEAN%
echo   state, s                                   %L_CLI_DESC_STATE%
echo   check-all                                  %L_CLI_DESC_CHKSUM_ALL%
echo   check-clear           ^<id^> / all           %L_CLI_DESC_CHKSUM_CLEAR%
echo   check                 ^<id^>                 %L_CLI_DESC_CHKSUM%
echo   help, -h, --help                           %L_CLI_DESC_HELP%
echo.
echo !C_GRY!!L_CLI_HELP_FOOT!!C_RST!
echo !C_GRY!!L_CLI_USAGE_HEAD!!C_RST!
echo %L_CLI_USAGE_1%
echo %L_CLI_USAGE_2%
echo %L_CLI_USAGE_3%
echo %L_CLI_USAGE_4%
echo %L_CLI_USAGE_5%
echo !L_CLI_IB_SRC_HEAD!
echo   %L_CLI_IB_SRC_1%
echo   %L_CLI_IB_SRC_2%
echo   %L_CLI_IB_SRC_3%
echo   %L_CLI_IB_SRC_4%
echo.
exit /b 0

:CLI_STATE
echo.
echo !C_LBL!!L_ANALYSIS!!C_RST!
echo.
for /L %%i in (1,1,%count%) do (
    set "p_id=!profile[%%i]:.conf=!"
    set "this_arch=--------"
    for /f "usebackq tokens=2 delims==" %%a in (`type "profiles\!profile[%%i]!" ^| findstr "SRC_ARCH"`) do (
        set "VAL=%%a"
        set "VAL=!VAL:"=!"
        for /f "tokens=* delims= " %%b in ("!VAL!") do set "this_arch=%%b"
    )
    set "st_f=!C_GRY!·!C_RST!" & dir /a-d /b /s "custom_files\!p_id!" 2>nul | findstr "^" >nul && set "st_f=!C_GRY!F!C_RST!"
    set "st_p=!C_GRY!·!C_RST!" & dir /a-d /b /s "custom_packages\!p_id!" 2>nul | findstr "^" >nul && set "st_p=!C_KEY!P!C_RST!"
    set "st_s=!C_GRY!·!C_RST!" & dir /a-d /b /s "src_packages\!p_id!" 2>nul | findstr "^" >nul && set "st_s=!C_VAL!S!C_RST!"
    set "st_m=!C_GRY!·!C_RST!" & if exist "firmware_output\sourcebuilder\!p_id!\manual_config" set "st_m=!C_ERR!M!C_RST!"
    set "st_h=!C_GRY!·!C_RST!" & if exist "custom_files\!p_id!\hooks.sh" set "st_h=!C_LBL!H!C_RST!"
    set "st_pt=!C_GRY!·!C_RST!" & dir /a-d /b /s "custom_patches\!p_id!" 2>nul | findstr "^" >nul && set "st_pt=!C_GRY!X!C_RST!"
    set "st_oi=!C_GRY!··!C_RST!" & dir /s /a-d /b "firmware_output\imagebuilder\!p_id!\*" 2>nul | findstr "^" >nul && set "st_oi=!C_VAL!OI!C_RST!"
    set "st_os=!C_GRY!··!C_RST!" & dir /s /a-d /b "firmware_output\sourcebuilder\!p_id!\*" 2>nul | findstr "^" >nul && set "st_os=!C_VAL!OS!C_RST!"
    set "id_pad=%%i" & if %%i LSS 10 set "id_pad= %%i"
    set "tmp_name=!p_id!                                             " & set "n_name=!tmp_name:~0,45!"
    set "tmp_arch=!this_arch!                    " & set "n_arch=!tmp_arch:~0,20!"
    echo    !C_GRY![!C_KEY!!id_pad!!C_GRY!]!C_RST! !n_name! !C_LBL!!n_arch!!C_RST! !C_GRY![!st_f!!st_p!!st_s!!st_m!!st_h!!st_pt! !C_RST!^|!C_GRY! !st_oi! !st_os!]!C_RST!
)
echo    !C_GRY!────────────────────────────────────────────────────────────────────────────────────────────────────────────!C_RST!
echo    !L_LEGEND_IND!
echo    !C_GRY!!L_LEGEND_TEXT!!C_RST!
echo.
exit /b 0

:: --- Checksum (MD5) — формат как в unpacker ---
:ADD_CHECKSUM_TO_FILE
set "CHK_FILE=%~1"
if not exist "!CHK_FILE!" exit /b 1
set "WAS_CHANGED=0"

:: Файлы для временных операций
set "CHK_STAGED=%TEMP%\builder_chk_new_%RANDOM%.tmp"
set "CHK_OLD_VAL=%TEMP%\builder_chk_old_%RANDOM%.tmp"

set "CHK_PATH=!CHK_FILE:\=\\!"

:: PowerShell делает всю грязную работу:
:: 1. Читает файл.
:: 2. Ищет старый хэш (RegEx) и сохраняет его в CHK_OLD_VAL.
:: 3. Чистит контент от строки с хэшем и сохраняет в CHK_STAGED.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$path='!CHK_PATH!'; $staged='!CHK_STAGED:\=\\!'; $oldValFile='!CHK_OLD_VAL:\=\\!'; $isPs1=[bool]($path -match '\.ps1$'); $enc=[System.Text.UTF8Encoding]::new($isPs1); $content=[IO.File]::ReadAllText($path,$enc).TrimEnd([char]13,[char]10); $eol=if($isPs1 -or $content -match \"`r`n\"){\"`r`n\"}else{\"`n\"}; $lines=@($content -split \"`r?`n\"); $oldHash=''; while($lines.Count -gt 0){$last=($lines[-1] -replace \"`r$\",''); if([string]::IsNullOrWhiteSpace($last)){$lines=$lines[0..($lines.Count-2)]}elseif($last -match 'checksum:MD5=([0-9a-fA-F]{32})'){$oldHash=$matches[1]; $lines=$lines[0..($lines.Count-2)]; if($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace(($lines[-1] -replace \"`r$\",''))){$lines=$lines[0..($lines.Count-2)]}}else{break}}; if($oldHash){[IO.File]::WriteAllText($oldValFile, $oldHash.ToLower().Trim())}; $cleaned=($lines -join $eol)+$eol; [IO.File]::WriteAllText($staged,$cleaned,$enc)" >nul 2>&1

if not exist "!CHK_STAGED!" exit /b 1

:: 1. Читаем СТАРЫЙ хэш (если PowerShell его нашел)
set "OLD_HASH="
if exist "!CHK_OLD_VAL!" (
    set /p OLD_HASH=<"!CHK_OLD_VAL!"
    del /q "!CHK_OLD_VAL!" 2>nul
)

:: 2. Считаем НОВЫЙ хэш (через certutil)
set "CHK_HASH="
for /f "skip=1 tokens=*" %%H in ('certutil -hashfile "!CHK_STAGED!" MD5 2^>nul') do (
    if not defined CHK_HASH set "CHK_HASH=%%H"
)
:: Чистим пробелы (Certutil иногда выдает "ab cd 12..." или пробелы в конце)
set "CHK_HASH=!CHK_HASH: =!"
:: Приводим к нижнему регистру для сравнения (трюк через subs)
for %%L in ("a=a" "b=b" "c=c" "d=d" "e=e" "f=f" "A=a" "B=b" "C=c" "D=d" "E=e" "F=f") do set "CHK_HASH=!CHK_HASH:%%~L!"

:: Защита от сбоя certutil
if not defined CHK_HASH set "CHK_HASH=d41d8cd98f00b204e9800998ecf8427e"

:: 3. СРАВНЕНИЕ
set "STATUS_MSG="
if defined OLD_HASH (
    if not "!OLD_HASH!"=="!CHK_HASH!" (
        set "STATUS_MSG= %C_VAL%(CHANGED)%C_RST%"
        set "WAS_CHANGED=1"
    )
) else (
    :: Если хэша раньше не было, считаем это изменением (или новым добавлением)
    set "STATUS_MSG= %C_KEY%(NEW)%C_RST%"
    set "WAS_CHANGED=1"
)

:: 4. Запись в файл
set "CHK_PREFIX=#"
for %%F in ("!CHK_FILE!") do set "CHK_EXT=%%~xF"
if /i "!CHK_EXT!"==".bat" set "CHK_PREFIX=::"
if /i "!CHK_EXT!"==".cmd" set "CHK_PREFIX=::"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$staged='!CHK_STAGED:\=\\!'; $enc=[System.Text.UTF8Encoding]::new($false); $hash='!CHK_HASH!'; $prefix='!CHK_PREFIX!'; $line=$prefix+\" checksum:MD5=\"+$hash; [IO.File]::AppendAllText($staged,$line,$enc)" >nul 2>&1

copy /y "!CHK_STAGED!" "!CHK_FILE!" >nul 2>&1
del /q "!CHK_STAGED!" 2>nul

echo   %C_GRY%-%C_RST% File: %C_VAL%!CHK_FILE!%C_RST% %C_GRY%MD5=%C_KEY%!CHK_HASH!%C_RST%!STATUS_MSG!
exit /b 0

:CLEAR_CHECKSUM_FROM_FILE
set "CHK_FILE=%~1"
if not exist "!CHK_FILE!" exit /b 1
set "CHK_STAGED=%TEMP%\builder_chksum_clear_%RANDOM%.tmp"
set "CHK_PATH=!CHK_FILE:\=\\!"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$path='!CHK_PATH!'; $staged='!CHK_STAGED:\=\\!'; $isPs1=[bool]($path -match '\.ps1$'); $enc=[System.Text.UTF8Encoding]::new($isPs1); $content=[IO.File]::ReadAllText($path,$enc).TrimEnd([char]13,[char]10); $eol=if($isPs1 -or $content -match \"`r`n\"){\"`r`n\"}else{\"`n\"}; $lines=@($content -split \"`r?`n\"); while($lines.Count -gt 0){$last=($lines[-1] -replace \"`r$\",''); if([string]::IsNullOrWhiteSpace($last)){$lines=$lines[0..($lines.Count-2)]}elseif($last -match '^\s*#?\s*checksum:MD5=[0-9a-fA-F]{32}\s*$'){$lines=$lines[0..($lines.Count-2)]; if($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace(($lines[-1] -replace \"`r$\",''))){$lines=$lines[0..($lines.Count-2)]}}else{break}}; $cleaned=($lines -join $eol)+$eol; [IO.File]::WriteAllText($staged,$cleaned,$enc)" >nul 2>&1
if not exist "!CHK_STAGED!" exit /b 1
copy /y "!CHK_STAGED!" "!CHK_FILE!" >nul 2>&1
del /q "!CHK_STAGED!" 2>nul
echo   %C_GRY%-%C_RST% File: %C_VAL%!CHK_FILE!%C_RST% %C_GRY%MD5=%C_ERR%CLEARED%C_RST%
exit /b 0

:CLI_CHECKSUM_ALL
if not exist "_unpacker.bat" (
    echo !C_ERR!!L_CHKSUM_ERR_NO_UNPACKER!!C_RST!
    exit /b 1
)
set "CHK_N=0"
set "CHK_C=0"
echo %C_LBL%[CHECKSUM]%C_RST% %L_CHKSUM_ALL_START%
for /f "tokens=*" %%F in ('findstr "BEGIN_B64_" _unpacker.bat 2^>nul') do (
    set "line=%%F"
    set "line=!line:*BEGIN_B64_ =!"
    for /f "tokens=* delims= " %%a in ("!line!") do set "line=%%a"
    if exist "!line!" (
        call :ADD_CHECKSUM_TO_FILE "!line!"
        if not errorlevel 1 (
            set /a CHK_N+=1
            if "!WAS_CHANGED!"=="1" set /a CHK_C+=1
        )
    )
)
echo !C_OK!!L_CHKSUM_DONE! !CHK_N! !C_LBL!Changed: !CHK_C!!C_RST!
exit /b 0

:CLI_CHECKSUM
if "!CLI_ARG1!"=="" echo !L_CLI_ERR_PROFILE_REQUIRED! & exit /b 1
set "cli_trim=!CLI_ARG1: =!"
if "!cli_trim!"=="" echo !L_CLI_ERR_PROFILE_REQUIRED! & exit /b 1
call :CLI_RESOLVE_PROFILE
if not defined SELECTED_CONF exit /b 1
set "CHK_TARGET=profiles\!SELECTED_CONF!"
if not exist "!CHK_TARGET!" (
    echo !C_ERR!!L_CHKSUM_ERR_FILE! !CHK_TARGET!!C_RST!
    exit /b 1
)
call :ADD_CHECKSUM_TO_FILE "!CHK_TARGET!"
set "CHK_HASH="
for /f "tokens=*" %%a in ('findstr "checksum:MD5=" "!CHK_TARGET!" 2^>nul') do set "CHK_HASH=%%a"
set "CHK_HASH=!CHK_HASH:*checksum:MD5=!"
echo !C_OK!!L_CHKSUM_PROFILE_OK!!C_RST! !C_VAL!!CHK_TARGET!!C_RST! !C_GRY!MD5=!CHK_HASH!!C_RST!
exit /b 0

:CLI_CHECKSUM_CLEAR
:: Если аргумент "all" или пустой — очищаем всё
if /i "!CLI_ARG1!"=="all" goto CLI_CHECKSUM_CLEAR_ALL
if "!CLI_ARG1!"=="" goto CLI_CHECKSUM_CLEAR_ALL

:: Если же указан конкретный ID, очищаем только его
set "cli_trim=!CLI_ARG1: =!"
call :CLI_RESOLVE_PROFILE
if not defined SELECTED_CONF exit /b 1
set "CHK_TARGET=profiles\!SELECTED_CONF!"
if not exist "!CHK_TARGET!" (
    echo !C_ERR!!L_CHKSUM_ERR_FILE! !CHK_TARGET!!C_RST!
    exit /b 1
)
call :CLEAR_CHECKSUM_FROM_FILE "!CHK_TARGET!"
echo !C_OK![CLEARED]!C_RST! !C_VAL!!CHK_TARGET!!C_RST!
exit /b 0

:CLI_CHECKSUM_CLEAR_ALL
if not exist "_unpacker.bat" (
    echo !C_ERR!!L_CHKSUM_ERR_NO_UNPACKER!!C_RST!
    exit /b 1
)
set "CHK_N=0"
echo %C_LBL%[CHECKSUM CLEAR]%C_RST% Starting global hash clearance...
:: Очищаем сам распаковщик
call :CLEAR_CHECKSUM_FROM_FILE "_unpacker.bat"
set /a CHK_N+=1

:: Очищаем все файлы, зарегистрированные в проекте
for /f "tokens=*" %%F in ('findstr "BEGIN_B64_" _unpacker.bat 2^>nul') do (
    set "line=%%F"
    set "line=!line:*BEGIN_B64_ =!"
    for /f "tokens=* delims= " %%a in ("!line!") do set "line=%%a"
    if exist "!line!" (
        call :CLEAR_CHECKSUM_FROM_FILE "!line!"
        if not errorlevel 1 set /a CHK_N+=1
    )
)
echo !C_OK!Global clearance done! Processed files: !CHK_N!!C_RST!
exit /b 0

:CLI_RESOLVE_PROFILE
set "SELECTED_CONF="
if "!CLI_ARG1!"=="" echo !L_CLI_ERR_PROFILE_REQUIRED! & exit /b 1
set "cli_trim=!CLI_ARG1: =!"
if "!cli_trim!"=="" echo !L_CLI_ERR_PROFILE_REQUIRED! & exit /b 1
set "cli_n=0"
set /a "cli_n=!CLI_ARG1!" 2>nul
if !cli_n! geq 1 if !cli_n! leq %count% (
    for /L %%i in (1,1,%count%) do if %%i==!cli_n! set "SELECTED_CONF=!profile[%%i]!"
)
if not defined SELECTED_CONF for /L %%i in (1,1,%count%) do (
    set "pbase=!profile[%%i]:.conf=!"
    if /i "!pbase!"=="!CLI_ARG1!" set "SELECTED_CONF=!profile[%%i]!"
)
if not defined SELECTED_CONF (
    echo !L_CLI_ERR_PROFILE! !CLI_ARG1!!C_RST!
    exit /b 1
)
exit /b 0

:CLI_BUILD
if "!CLI_ARG1!"=="" echo !L_CLI_ERR_BUILD_NO_ID! & exit /b 1
set "cli_trim=!CLI_ARG1: =!"
if "!cli_trim!"=="" echo !L_CLI_ERR_BUILD_NO_ID! & exit /b 1
call :CLI_RESOLVE_PROFILE
if not defined SELECTED_CONF exit /b 1
call :BUILD_ROUTINE "!SELECTED_CONF!"
echo !L_RUNNING!
exit /b 0

:CLI_EDIT
if not defined CLI_ARG1 echo !L_CLI_ERR_PROFILE_REQUIRED! & exit /b 1
set "cli_trim=!CLI_ARG1: =!"
if "!cli_trim!"=="" echo !L_CLI_ERR_PROFILE_REQUIRED! & exit /b 1
call :CLI_RESOLVE_PROFILE
if not defined SELECTED_CONF exit /b 1
set "e_choice=1"
for /L %%i in (1,1,%count%) do if "!profile[%%i]!"=="!SELECTED_CONF!" set "e_choice=%%i"
set "SEL_CONF=!SELECTED_CONF!"
set "SEL_ID=!SELECTED_CONF:.conf=!"
goto EDIT_OPEN

:CLI_MENUCONFIG
if not "%BUILD_MODE%"=="SOURCE" (
    echo !L_CLI_ERR_SOURCE_ONLY!
    exit /b 1
)
call :CLI_RESOLVE_PROFILE
if not defined SELECTED_CONF exit /b 1
call :EXEC_MENUCONFIG "!SELECTED_CONF!"
exit /b 0

:CLI_IMPORT
if not "%BUILD_MODE%"=="SOURCE" (
    echo !L_CLI_ERR_SOURCE_ONLY!
    exit /b 1
)
call :CLI_RESOLVE_PROFILE
if not defined SELECTED_CONF exit /b 1
set "SEL_CONF=!SELECTED_CONF!"
set "SEL_ID=!SELECTED_CONF:.conf=!"
set "P_ARCH="
for /f "usebackq tokens=2 delims==" %%a in (`type "profiles\!SEL_CONF!" ^| findstr "SRC_ARCH"`) do (
    set "VAL=%%a"
    set "VAL=!VAL:"=!"
    for /f "tokens=* delims= " %%b in ("!VAL!") do set "P_ARCH=%%b"
)
if exist "system/import_ipk.ps1" (
    powershell -ExecutionPolicy Bypass -File "system/import_ipk.ps1" -ProfileID "!SEL_ID!" -TargetArch "!P_ARCH!"
) else (
    echo !C_KEY!!L_ERR_PS1_IPK!
)
exit /b 0

:CLI_CLEAN
if not defined CLI_ARG1 goto CLEAN_MENU
set "clean_choice=!CLI_ARG1!"
if "!clean_choice!"=="9" (
    echo !L_PRUNE_RUN!
    docker system prune -f
    exit /b 0
)
if not defined CLI_ARG2 goto CLEAN_MENU
set "p_choice=!CLI_ARG2!"
if /i "!p_choice!"=="A" (
    set "TARGET_PROFILE_ID=ALL"
    set "TARGET_PROFILE_NAME=ALL PROFILES"
) else (
    set "CLI_ARG1_SAVE=!CLI_ARG1!"
    set "CLI_ARG1=!CLI_ARG2!"
    call :CLI_RESOLVE_PROFILE
    set "CLI_ARG1=!CLI_ARG1_SAVE!"
    if not defined SELECTED_CONF exit /b 1
    set "TARGET_PROFILE_NAME=!SELECTED_CONF!"
    set "TARGET_PROFILE_ID=!SELECTED_CONF:.conf=!"
)
if "%BUILD_MODE%"=="IMAGE" (
    if "!clean_choice!"=="1" set "CLEAN_TYPE=IMG_SDK" & set "CLEAN_DESC=ImageBuilder Cache"
    if "!clean_choice!"=="2" set "CLEAN_TYPE=IMG_IPK" & set "CLEAN_DESC=IPK Cache"
    if "!clean_choice!"=="3" set "CLEAN_TYPE=IMG_ALL" & set "CLEAN_DESC=FULL RESET (Image)"
)
if "%BUILD_MODE%"=="SOURCE" (
    if "!clean_choice!"=="1" set "CLEAN_TYPE=SRC_SOFT" & set "CLEAN_DESC=Soft Clean"
    if "!clean_choice!"=="2" set "CLEAN_TYPE=SRC_WORK" & set "CLEAN_DESC=Workdir"
    if "!clean_choice!"=="3" set "CLEAN_TYPE=SRC_DL" & set "CLEAN_DESC=DL Cache"
    if "!clean_choice!"=="4" set "CLEAN_TYPE=SRC_CCACHE" & set "CLEAN_DESC=CCache"
    if "!clean_choice!"=="5" set "CLEAN_TYPE=SRC_TMP" & set "CLEAN_DESC=Package Index"
    if "!clean_choice!"=="6" set "CLEAN_TYPE=SRC_ALL" & set "CLEAN_DESC=FULL RESET (Source)"
)
if not defined CLEAN_TYPE (
    echo !L_CLI_ERR_INVALID_CLEAN_TYPE!!clean_choice!!L_CLI_ERR_CLEAN_TYPE_HINT!!C_RST!
    exit /b 1
)
set "CLI_CLEAN_YES=1"
goto CONFIRM_CLEAN

:: =========================================================
::  MENUCONFIG SECTION
:: =========================================================
:MENUCONFIG_SELECTION
if not "%BUILD_MODE%"=="SOURCE" goto MENU
if not defined ROUTERFW_NO_CLS cls
set "MENU_SEP============================================================"
echo %C_KEY%!MENU_SEP!%C_RST%
echo  %C_KEY%!L_K_TITLE!%C_RST%
echo %C_KEY%!MENU_SEP!%C_RST%
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
echo. >> "%RUNNER_SCRIPT%"
echo     # FIX: Check if DEVICE is already set in SRC_EXTRA_CONFIG to avoid conflict >> "%RUNNER_SCRIPT%"
echo     if echo "$SRC_EXTRA_CONFIG" ^| grep -q "CONFIG_TARGET_.*_DEVICE_"; then >> "%RUNNER_SCRIPT%"
echo         echo "[CONFIG] Device explicitly set in EXTRA_CONFIG. Skipping auto-detection." >> "%RUNNER_SCRIPT%"
echo     else >> "%RUNNER_SCRIPT%"
echo         # Use TARGET_PROFILE as-is: OpenWrt Kconfig device IDs use hyphens >> "%RUNNER_SCRIPT%"
echo         echo "CONFIG_TARGET_${SRC_TARGET}_${SRC_SUBTARGET}_DEVICE_$TARGET_PROFILE=y" ^>^> .config >> "%RUNNER_SCRIPT%"
echo     fi >> "%RUNNER_SCRIPT%"
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
echo         printf "%%s\n" "$SRC_EXTRA_CONFIG" ^| sed 's/\r$//' ^>^> .config >> "%RUNNER_SCRIPT%"
echo     fi >> "%RUNNER_SCRIPT%"
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
rem echo chmod 666 /output/manual_config >> "%RUNNER_SCRIPT%"
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
:: FIX: Smart Chown (оптимизация запуска) + Security Opt
set "HOST_PKGS_DIR=./src_packages/%PROFILE_ID%" && docker-compose -f system/docker-compose-src.yaml -p %PROJ_NAME% run --build --rm -it %SERVICE_NAME% /bin/bash -c "if [ -d /home/build/openwrt/.git ] && [ x$(stat -c %%U /ccache 2>/dev/null) = xbuild ]; then echo '[INIT] Permissions OK'; else echo '[INIT] Fixing permissions (Slow)...'; chown -R build:build /home/build/openwrt /ccache; fi && chown build:build /output && tr -d '\r' < /output/_menuconfig_runner.sh > /tmp/r.sh && chmod +x /tmp/r.sh && sudo -E -u build bash /tmp/r.sh"
:: --- БЛОК ПОСТ-ОБРАБОТКИ КОНФИГУРАЦИИ ---
if exist "%WIN_OUT_PATH%\manual_config" (
    echo.
    echo %C_KEY%!L_SEPARATOR!%C_RST%
    
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
    echo %C_KEY%!L_SEPARATOR!%C_RST%
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
echo !L_SEPARATOR!
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
    if not exist "custom_patches\%PROFILE_ID%" mkdir "custom_patches\%PROFILE_ID%"
    set "HOST_PATCHES_DIR=./custom_patches/%PROFILE_ID%"
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
:: Запуск в отдельном окне (с поддержкой интерактивного входа для SOURCE режима и обновления профиля)
START "%WINDOW_TITLE%" cmd /v:on /c ^"set "SELECTED_CONF=%CONF_FILE%" ^&^& set "HOST_FILES_DIR=./custom_files/%PROFILE_ID%" ^&^& set "HOST_PKGS_DIR=%HOST_PKGS_DIR%" ^&^& set "HOST_PATCHES_DIR=%HOST_PATCHES_DIR%" ^&^& set "HOST_OUTPUT_DIR=%REL_OUT_PATH%" ^&^& (docker-compose %COMPOSE_ARG% -p %PROJ_NAME% up --build --force-recreate --remove-orphans %SERVICE_NAME% ^|^| echo !L_BUILD_FATAL!) ^&^& echo. ^&^& echo !L_FINISHED! ^&^& (if "%BUILD_MODE%"=="SOURCE" ( powershell -NoProfile -ExecutionPolicy Bypass -Command "$out='%REL_OUT_PATH%'; $conf='!SELECTED_CONF!'; Write-Host '--- DEBUG INFO ---' -ForegroundColor Yellow; if([string]::IsNullOrWhiteSpace($out)){ $out='./firmware_output/sourcebuilder/%PROFILE_ID%' }; Write-Host ('[DEBUG] Output Dir: ' + $out); $cleanOut = $out.Replace('./',''); if(Test-Path $cleanOut){ $files = Get-ChildItem -Path $cleanOut -Filter '*imagebuilder*.tar.zst' -Recurse; Write-Host ('[DEBUG] Files found: ' + $files.Count); $best = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1; if($best){ $u = (Resolve-Path -Path $best.FullName -Relative).Replace('.\','').Replace('\','/'); Write-Host ('[DEBUG] Found IB: ' + $u) -ForegroundColor Yellow; Write-Host ''; Write-Host '!L_IB_UPDATE_ASK!' -ForegroundColor Cyan; $r = Read-Host '!L_IB_UPDATE_PROMPT!'; if($r -eq 'y'){ $pf='profiles/' + $conf; if(Test-Path $pf){ $lines = Get-Content $pf -Encoding UTF8; $newLine = 'IMAGEBUILDER_URL=' + [char]34 + $u + [char]34; $activeIndex = $null; $commentIndex = $null; for ($i = 0; $i -lt $lines.Count; $i++) { $trimmed = $lines[$i].Trim(); if ($trimmed -like 'IMAGEBUILDER_URL=*') { $activeIndex = $i } elseif ($trimmed -like '#*IMAGEBUILDER_URL=*') { $commentIndex = $i } }; if ($activeIndex -ne $null) { $lines[$activeIndex] = '#' + $lines[$activeIndex]; $lines = $lines[0..$activeIndex] + $newLine + $lines[($activeIndex+1)..($lines.Count-1)] } elseif ($commentIndex -ne $null) { $lines += $newLine } else { $lines += $newLine }; [System.IO.File]::WriteAllLines($pf, $lines, [System.Text.UTF8Encoding]::new($false)); Write-Host '!L_IB_UPDATE_OK!' -ForegroundColor Green } } } else { Write-Host '[DEBUG] Archive *imagebuilder*.tar.zst not found in folder.' -ForegroundColor Red } } else { Write-Host ('[DEBUG] Directory not found: ' + $cleanOut) -ForegroundColor Red }; Write-Host '------------------' -ForegroundColor Yellow " ) ) ^&^& (if "%BUILD_MODE%"=="SOURCE" ( powershell -NoProfile -Command "$Host.UI.RawUI.FlushInputBuffer()" ) ) ^&^& (if "%BUILD_MODE%"=="SOURCE" (set /p "stay=!L_K_STAY! " ^& if /i "^!stay^!"=="y" (echo. ^& echo !L_K_SHELL_H1! ^& echo !L_K_SHELL_H2! ^& echo !L_K_SHELL_H3! ^& docker-compose %COMPOSE_ARG% -p %PROJ_NAME% run --rm -it %SERVICE_NAME% /bin/bash))) ^&^& pause ^"
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
set "B64=IyEvYmluL3NoCiMgRml4IFNTSCBwZXJtaXNzaW9ucwpbIC1kIC9ldGMvZHJvcGJlYXIgXSAmJiBjaG1vZCA3MDAgL2V0Yy9kcm9wYmVhcgpbIC1mIC9ldGMvZHJvcGJlYXIvYXV0aG9yaXplZF9rZXlzIF0gJiYgY2htb2QgNjAwIC9ldGMvZHJvcGJlYXIvYXV0aG9yaXplZF9rZXlzCiMgRml4IFNoYWRvdwpbIC1mIC9ldGMvc2hhZG93IF0gJiYgY2htb2QgNjAwIC9ldGMvc2hhZG93CiMgRml4IHJvb3QgU1NIIGtleXMKWyAtZCAvcm9vdC8uc3NoIF0gJiYgY2htb2QgNzAwIC9yb290Ly5zc2gKWyAtZiAvcm9vdC8uc3NoL2lkX3JzYSBdICYmIGNobW9kIDYwMCAvcm9vdC8uc3NoL2lkX3JzYQpleGl0IDAK"
powershell -Command "[IO.File]::WriteAllBytes('custom_files\%~1\etc\uci-defaults\99-permissions.sh', [Convert]::FromBase64String('%B64%'))" >nul 2>&1
exit /b
:: checksum:MD5=e3f2b9c25f470b7301579863bce72681