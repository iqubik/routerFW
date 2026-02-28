@echo off
setlocal enabledelayedexpansion
set "PACKER_VER=2.4"
cls
chcp 65001 >nul

:: Проверка аргумента для запуска рабочего потока (WORKER)
if "%~1"==":WORKER" goto :WORKER

:: =========================================================
::  Упаковщик общих ресурсов (Multi-Threaded Fixed), v%PACKER_VER%
:: =========================================================

cls
echo ========================================
echo  OpenWrt Universal Packer (v%PACKER_VER% MT)
echo ========================================
echo.

:: === 1. Определяем список общих файлов ===
set "IDX=0"

:: --- Основные файлы ---
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
call :ADD_FILE "system/lang/ru.env"
call :ADD_FILE "system/lang/en.env"
call :ADD_FILE "scripts/show_pkgs.sh"
call :ADD_FILE "_Builder.bat"
:: --- Документация ---
call :ADD_FILE "README.md"
call :ADD_FILE "README.en.md"
call :ADD_FILE "docs\01-introduction.md"
call :ADD_FILE "docs\01-introduction.en.md"
call :ADD_FILE "docs\02-digital-twin.md"
call :ADD_FILE "docs\02-digital-twin.en.md"
call :ADD_FILE "docs\03-source-build.md"
call :ADD_FILE "docs\03-source-build.en.md"
call :ADD_FILE "docs\04-adv-source-build.md"
call :ADD_FILE "docs\04-adv-source-build.en.md"
call :ADD_FILE "docs\05-patch-sys.md"
call :ADD_FILE "docs\05-patch-sys.en.md"
call :ADD_FILE "docs\06-rax3000m-emmc-flash.md"
call :ADD_FILE "docs\06-rax3000m-emmc-flash.en.md"
call :ADD_FILE "docs\07-troubleshooting-faq.md"
call :ADD_FILE "docs\07-troubleshooting-faq.en.md"
call :ADD_FILE "docs\index.md"
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
    echo ::  Unpacker ^(Smart Edition v%PACKER_VER%^)
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
    echo ^<nul set /p "=Initial setup done." ^> "profiles\personal.flag"
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
    echo     powershell -Command "$ext = '%%~1'; $content = Get-Content '%%~f0'; $start = $false; $b64 = ''; foreach($line in $content){ if($line -match 'BEGIN_B64_ ' + [Regex]::Escape($ext)){ $start = $true; continue }; if($line -match 'END_B64_ ' + [Regex]::Escape($ext)){ $start = $false; break }; if($start){ $b64 += $line.Trim() } }; if($b64){ [IO.File]::WriteAllBytes($ext, [Convert]::FromBase64String($b64)) }"
    echo     for /f "delims=" %%%%H in ^('powershell -NoProfile -Command "(Get-FileHash -Path '%%~1' -Algorithm MD5).Hash.ToLower()"'^) do set "file_hash=%%%%H"
    echo     if not defined file_hash set "file_hash=d41d8cd98f00b204e9800998ecf8427e"
    echo     echo [UNPACK] Recover: %%~1 - md5^(!file_hash!^)
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
echo  ГОТОВО (v%PACKER_VER%)
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
set "W_STAGED=%W_DIR%\%W_ID%.staged"
set "W_OUT=%W_DIR%\%W_ID%.chunk"
set "W_RDY=%W_DIR%\%W_ID%.ready"

rem 1. Подготовка staged: Удаляем старые хеши и лишние пустые строки
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$path='%W_FILE:\=\\%'; $staged='%W_STAGED:\=\\%'; $enc=[System.Text.UTF8Encoding]::new($false); $content=[IO.File]::ReadAllText($path,$enc).TrimEnd([char]13,[char]10); $eol=if($content -match \"`r`n\"){\"`r`n\"}else{\"`n\"}; $lines=@($content -split \"`r?`n\"); while($lines.Count -gt 0){$last=($lines[-1] -replace \"`r$\",''); if([string]::IsNullOrWhiteSpace($last)){$lines=$lines[0..($lines.Count-2)]}elseif($last -match '^\s*(::|#)?\s*checksum:MD5=[0-9a-fA-F]{32}\s*$'){$lines=$lines[0..($lines.Count-2)]; if($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace(($lines[-1] -replace \"`r$\",''))){$lines=$lines[0..($lines.Count-2)]}}else{break}}; $cleaned=($lines -join $eol)+$eol; [IO.File]::WriteAllText($staged,$cleaned,$enc)" >nul 2>&1

if not exist "%W_STAGED%" (
    echo :: ERROR_PACKING_FILE: %W_FILE% > "%W_OUT%"
    echo done > "%W_RDY%"
    exit
)

rem 2. Считаем MD5 от подготовленного файла
set "W_HASH="
for /f "skip=1 tokens=1" %%H in ('certutil -hashfile "%W_STAGED%" MD5 2^>nul') do set "W_HASH=%%H" & goto :HASH_DONE
:HASH_DONE
if not defined W_HASH set "W_HASH=d41d8cd98f00b204e9800998ecf8427e"

rem 3. Определяем префикс
set "W_PREFIX=#"
for %%F in ("%W_FILE%") do set "W_EXT=%%~xF"
if /i "%W_EXT%"==".bat" set "W_PREFIX=::"
if /i "%W_EXT%"==".cmd" set "W_PREFIX=::"

rem 4. Дописываем checksum
rem Важно: $eol в начале НЕ добавляем (чтобы не было пустой строки),
rem так как файл после шага 1 гарантированно заканчивается одним переносом.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$staged='%W_STAGED:\=\\%'; $enc=[System.Text.UTF8Encoding]::new($false); $txt=[IO.File]::ReadAllText($staged,$enc); $eol=if($txt -match \"`r`n\"){\"`r`n\"}else{\"`n\"}; $hash='%W_HASH%'.ToLower(); $prefix='%W_PREFIX%'; $line=$prefix+\" checksum:MD5=\"+$hash; [IO.File]::AppendAllText($staged,$line,$enc)" >nul 2>&1

rem 5. Кодируем и подчищаем
certutil -f -encode "%W_STAGED%" "%W_TMP%" >nul 2>&1
if not exist "%W_TMP%" (
    echo :: ERROR_PACKING_FILE: %W_FILE% > "%W_OUT%"
    del /q "%W_STAGED%" 2>nul
    echo done > "%W_RDY%"
    exit
)
(
    echo.
    echo :: BEGIN_B64_ %W_FILE%
    findstr /v /c:"-----" "%W_TMP%"
    echo :: END_B64_ %W_FILE%
) > "%W_OUT%"

del /q "%W_TMP%" 2>nul
del /q "%W_STAGED%" 2>nul
echo done > "%W_RDY%"
exit