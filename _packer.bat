@echo off
setlocal enabledelayedexpansion
cls
chcp 65001 >nul

:: Проверка аргумента для запуска рабочего потока (WORKER)
if "%~1"==":WORKER" goto :WORKER

:: =========================================================
::  Упаковщик общих ресурсов (Multi-Threaded Fixed)
::  v2.1 (Fix: Spaces in paths & Quoting)
:: =========================================================

cls
echo ========================================
echo  OpenWrt Universal Packer (v2.1 MT)
echo ========================================
echo.

:: === 1. Определяем список общих файлов ===
set "IDX=0"

:: Функция добавления в список
call :ADD_FILE "system/openssl.cnf"
call :ADD_FILE "system/docker-compose.yaml"
call :ADD_FILE "system/docker-compose-src.yaml"
call :ADD_FILE "system/ib_builder.sh"
call :ADD_FILE "system/src_builder.sh"
call :ADD_FILE "system/dockerfile"
call :ADD_FILE "system/dockerfile.legacy"
call :ADD_FILE "system/src.dockerfile"
call :ADD_FILE "system/src.dockerfile.legacy"
call :ADD_FILE "system/create_profile.ps1"
call :ADD_FILE "system/import_ipk.ps1"
call :ADD_FILE "scripts/show_pkgs.sh"
call :ADD_FILE "_Builder.bat"
call :ADD_FILE "README.md"
call :ADD_FILE "README.en.md"
call :ADD_FILE "docs\01-introduction.md"
call :ADD_FILE "docs\02-digital-twin.md"
call :ADD_FILE "docs\03-source-build.md"
call :ADD_FILE "docs\04-adv-source-build.md"
call :ADD_FILE "docs\index.md"
call :ADD_FILE "docs\01-introduction.en.md"
call :ADD_FILE "docs\02-digital-twin.en.md"
call :ADD_FILE "docs\03-source-build.en.md"
call :ADD_FILE "docs\04-adv-source-build.en.md"
call :ADD_FILE "docs\index.en.md"

:: --- ЗАЩИЩЕННЫЕ ОБЪЕКТЫ ---
call :ADD_FILE "scripts\etc\uci-defaults\99-permissions.sh"
call :ADD_FILE "scripts\diag.sh"
call :ADD_FILE "scripts\hooks.sh"
call :ADD_FILE "scripts\upgrade.sh"
call :ADD_FILE "scripts\packager.sh"
call :ADD_FILE "profiles\giga_24105_main_full.conf"
call :ADD_FILE "profiles\rax3000m_emmc_test_new.conf"
call :ADD_FILE "profiles\xiaomi_4a_gigabit_23056_full.conf"
call :ADD_FILE "profiles\tplink_841n_v9_190710_full.conf"
call :ADD_FILE "profiles\friendlyarm_nanopi_r3s_24105_ow_full.conf"
call :ADD_FILE "custom_files\rax3000m_emmc_test_new\hooks.sh"

:: Настройки путей (Используем абсолютные пути во избежание ошибок)
set "NEW_UNPACKER_FILE=_unpacker.bat.new"
set "TEMP_DIR_NAME=temp_packer_worker"
set "FULL_TEMP_DIR=%~dp0%TEMP_DIR_NAME%"

:: Очистка и подготовка
if exist "%NEW_UNPACKER_FILE%" del /f /q "%NEW_UNPACKER_FILE%"
if exist "%FULL_TEMP_DIR%" rd /s /q "%FULL_TEMP_DIR%"
md "%FULL_TEMP_DIR%"

:: === 2. Генерируем логическую часть _unpacker.bat ===
echo [PACKER] Создание логики распаковщика...

(
    echo @echo off
    echo setlocal enabledelayedexpansion    
    echo chcp 65001 ^>nul
    echo.
    echo :: =========================================================
    echo ::  Unpacker ^(Smart Edition v2.1^)
    echo :: =========================================================
    echo.
    echo echo [UNPACKER] Resource check...
    echo.
    echo :: Проверка флага первоначальной настройки
    echo set "SKIP_DEFAULTS=0"
    echo if exist "profiles\personal.flag" ^(
    echo     echo [INFO] Found personal.flag. Recovering protected files only.
    echo     set "SKIP_DEFAULTS=1"
    echo ^)
    echo.
) > "%NEW_UNPACKER_FILE%"

:: Генерируем вызовы функций
for /L %%i in (1,1,%IDX%) do (
    set "FNAME=!FILE_%%i!"
    set "IS_PROTECTED=0"
    
    echo "!FNAME!" | findstr /C:"profiles\\" >nul && set "IS_PROTECTED=1"
    echo "!FNAME!" | findstr /C:"firmware_output\\" >nul && set "IS_PROTECTED=1"
    echo "!FNAME!" | findstr /C:"scripts\\" >nul && set "IS_PROTECTED=1"
    
    if "!IS_PROTECTED!"=="1" (
        echo if "%%SKIP_DEFAULTS%%"=="0" call :DECODE_FILE "!FNAME!">> "%NEW_UNPACKER_FILE%"
    ) else (
        echo call :DECODE_FILE "!FNAME!">> "%NEW_UNPACKER_FILE%"
    )
)

:: Завершение логической части
(
    echo.
    echo :: Создаем флаг ^(если папки нет - создаем^)
    echo if not exist "profiles" md "profiles" 2^>nul
    echo if not exist "profiles\personal.flag" ^(
    echo     echo Initial setup done ^> "profiles\personal.flag"
    echo     echo [INFO] Created flag profiles\personal.flag
    echo ^)
    echo.
    echo echo [UNPACKER] Complete.
    echo echo ===================================
    echo echo Run _Builder.bat
    echo echo ===================================
    echo exit /b
    echo.
    echo :DECODE_FILE
    echo     if exist "%%~1" exit /b
    echo     if not exist "%%~dp1" md "%%~dp1" 2^>nul
    echo     echo [UNPACK] Recover: %%~1
    echo     powershell -Command "$ext = '%%~1'; $content = Get-Content '%%~f0'; $start = $false; $b64 = ''; foreach($line in $content){ if($line -match 'BEGIN_B64_ ' + [Regex]::Escape($ext)){ $start = $true; continue }; if($line -match 'END_B64_ ' + [Regex]::Escape($ext)){ $start = $false; break }; if($start){ $b64 += $line.Trim() } }; if($b64){ [IO.File]::WriteAllBytes($ext, [Convert]::FromBase64String($b64)) }"
    echo exit /b
    echo.
    echo :: =========================================================
    echo ::  BASE64
    echo :: =========================================================
) >> "%NEW_UNPACKER_FILE%"

:: === 3. МНОГОПОТОЧНАЯ ГЕНЕРАЦИЯ BASE64 ===
echo.
echo [PACKER] Запуск потоков кодирования (%IDX% файлов)...

set "ACTIVE_TASKS=0"
for /L %%i in (1,1,%IDX%) do (
    set "CURRENT_FILE=!FILE_%%i!"
    
    if exist "!CURRENT_FILE!" (
        rem Используем тройные кавычки для cmd /c, чтобы правильно передать путь к скрипту с пробелами
        start "" /b cmd /c "call "%~f0" :WORKER "!CURRENT_FILE!" "%%i" "!FULL_TEMP_DIR!""
        set /a ACTIVE_TASKS+=1
    ) else (
        echo   [SKIP] Файл '!CURRENT_FILE!' не найден.
        rem Создаем заглушку
        echo. > "%FULL_TEMP_DIR%\%%i.ready"
    )
)

echo [PACKER] Ожидание завершения потоков...

:WAIT_LOOP
rem Проверяем количество готовых файлов (.ready)
set "DONE_COUNT=0"
for %%A in ("%FULL_TEMP_DIR%\*.ready") do set /a DONE_COUNT+=1

rem Визуализация
<nul set /p "=Progress: !DONE_COUNT! / !IDX!   " >con
<nul set /p "=                          " >con

if !DONE_COUNT! LSS !IDX! (
    timeout /t 1 >nul
    goto :WAIT_LOOP
)
echo.
echo [PACKER] Все потоки завершены. Сборка...

:: === 4. Сборка финального файла ===
for /L %%i in (1,1,%IDX%) do (
    if exist "%FULL_TEMP_DIR%\%%i.chunk" (
        type "%FULL_TEMP_DIR%\%%i.chunk" >> "%NEW_UNPACKER_FILE%"
    )
)

move /Y "%NEW_UNPACKER_FILE%" "_unpacker.bat" > nul

:: === 5. Очистка ===
rd /s /q "%FULL_TEMP_DIR%"

:: === 6. Создание ZIP архива ===
echo.
echo [PACKER] Создание резервной копии в ZIP...
:: Получаем дату через PowerShell (формат ДД.ММ.ГГГГ_ЧЧ-ММ)
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "Get-Date -Format 'dd.MM.yyyy_HH-mm'"`) do set "ZIP_DATE=%%D"
:: Формируем имя по шаблону
set "ZIP_NAME=routerFW_WinDockerBuilder_v!ZIP_DATE!.zip"
:: Упаковываем _unpacker.bat в zip
powershell -NoProfile -Command "Compress-Archive -Path '_unpacker.bat' -DestinationPath '!ZIP_NAME!' -Force"

echo.
echo ========================================
echo  Файл обновлен: _unpacker.bat
echo  Архив создан:  !ZIP_NAME!
echo  ГОТОВО (v2.1 Fixed)
echo ========================================
echo.
exit /b

:: =========================================================
::  ФУНКЦИИ И РАБОЧИЕ ПОТОКИ
:: =========================================================

:ADD_FILE
set /a IDX+=1
set "FILE_%IDX%=%~1"
exit /b

:WORKER
rem %2 = Имя файла
rem %3 = Индекс (ID)
rem %4 = Temp папка (Абсолютный путь)
set "W_FILE=%~2"
set "W_ID=%~3"
set "W_DIR=%~4"
set "W_TMP=%W_DIR%\%W_ID%.tmp"
set "W_OUT=%W_DIR%\%W_ID%.chunk"
set "W_RDY=%W_DIR%\%W_ID%.ready"

rem Кодируем certutil (ошибки в nul, чтобы не спамить в консоль)
certutil -f -encode "%W_FILE%" "%W_TMP%" >nul 2>&1

rem Если certutil не создал файл (например, файл занят или 0 байт), создаем пустой чанк
if not exist "%W_TMP%" (
    echo :: ERROR_PACKING_FILE: %W_FILE% > "%W_OUT%"
    echo done > "%W_RDY%"
    exit
)

rem Формируем блок
(
    echo.
    echo :: BEGIN_B64_ %W_FILE%
    findstr /v /c:"-----" "%W_TMP%"
    echo :: END_B64_ %W_FILE%
) > "%W_OUT%"

rem Удаляем временный файл certutil
del /q "%W_TMP%"

rem Создаем файл-флаг готовности
echo done > "%W_RDY%"
exit