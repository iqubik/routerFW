@echo off
setlocal enabledelayedexpansion
set "PACKER_VER=2.7MT"
cls
chcp 65001 >nul

:: Проверка аргумента для запуска рабочего потока (WORKER)
if "%~1"==":WORKER" goto :WORKER

if not defined ROUTERFW_TEST_MODE CALL _Builder.bat check-all
echo =========================================
if defined ROUTERFW_TEST_MODE (
    echo [INFO] Ready to start packing v%PACKER_VER% TEST MODE
) else (
    echo [INFO] Ready to start packing v%PACKER_VER% Press any key...
    pause
)

:: =========================================================
::  Упаковщик общих ресурсов (Multi-Threaded Fixed), v%PACKER_VER%
:: =========================================================

if not defined ROUTERFW_TEST_MODE cls
echo ========================================
echo  OpenWrt Universal Packer (v%PACKER_VER%)
echo ========================================
echo.

:: === 1. Определяем список общих файлов ===
set "IDX=0"

:: --- Основные файлы ---
call :ADD_FILE "system/openssl.cnf"
call :ADD_FILE "system/docker-compose.yaml"
call :ADD_FILE "system/docker-compose-src.yaml"
call :ADD_FILE "system/podman-compose.yaml"
call :ADD_FILE "system/podman-compose-src.yaml"
call :ADD_FILE "system/ib_builder.sh"
call :ADD_FILE "system/src_builder.sh"
call :ADD_FILE "system/overlay_permissions.sh"
call :ADD_FILE "system/dockerfile"
call :ADD_FILE "system/dockerfile.legacy"
call :ADD_FILE "system/src.dockerfile"
call :ADD_FILE "system/src.dockerfile.legacy"
call :ADD_FILE "system/create_profile.ps1"
call :ADD_FILE "system/import_ipk.ps1"
call :ADD_FILE "system/apk_scanner.ps1"
call :ADD_FILE "system/version.env"
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
call :ADD_FILE "docs\08-ib-apk-import-embed.md"
call :ADD_FILE "docs\08-ib-apk-import-embed.en.md"
call :ADD_FILE "docs\09-file-permissions.md"
call :ADD_FILE "docs\09-file-permissions.en.md"
call :ADD_FILE "docs\ARCHITECTURE_ru.md"
call :ADD_FILE "docs\ARCHITECTURE_en.md"
call :ADD_FILE "docs\ARCHITECTURE_diagram_ru.md"
call :ADD_FILE "docs\ARCHITECTURE_diagram_en.md"
call :ADD_FILE "docs\map.md"
call :ADD_FILE "docs\map.en.md"
call :ADD_FILE "docs\audit.md"
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

call :ADD_FILE "profiles\tplink_841n_v9_190710_full.conf"
call :ADD_FILE "profiles\friendlyarm_nanopi_r3s_24105_ow_full.conf"
call :ADD_FILE "custom_files\rax3000m_emmc_test_new\hooks.sh"

:: Настройки путей
set "NEW_UNPACKER_FILE=_unpacker.bat.new"
set "TEMP_DIR_NAME=temp_packer_worker_%RANDOM%_%RANDOM%"
set "FULL_TEMP_DIR=%~dp0%TEMP_DIR_NAME%"

:: Очистка и подготовка
if exist "%NEW_UNPACKER_FILE%" del /f /q "%NEW_UNPACKER_FILE%" >nul 2>&1
if exist "%NEW_UNPACKER_FILE%" goto PACK_STALE_NEW
if exist "%FULL_TEMP_DIR%" rd /s /q "%FULL_TEMP_DIR%"
md "%FULL_TEMP_DIR%"
if not exist "%FULL_TEMP_DIR%" goto PACK_TEMP_ERROR

:: === 2. Генерируем ШАПКУ _unpacker.bat ===
echo [PACKER] Создание структуры распаковщика...

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
    echo     echo [INFO] Personal installation detected. Preserving protected files; repairing core files only when ROUTERFW_REPAIR=1.
    echo     set "SKIP_DEFAULTS=1"
    echo ^)
    echo.
) > "%NEW_UNPACKER_FILE%"

:: === 3. МНОГОПОТОЧНАЯ ГЕНЕРАЦИЯ BASE64 ===
echo.
echo [PACKER] Запуск потоков кодирования (%IDX% файлов)...

set "ACTIVE_TASKS=0"
for /L %%i in (1,1,%IDX%) do (
    call :PROCESS_FILE "%%i"
    if errorlevel 1 goto PACK_ERROR
)

echo [PACKER] Ожидание завершения потоков...
set "WAIT_SECONDS=0"
set "WAIT_LIMIT=600"

:WAIT_LOOP
if exist "%FULL_TEMP_DIR%\*.failed" goto PACK_WORKER_FAILED
for /f %%C in ('dir /b /a-d "%FULL_TEMP_DIR%\*.ready" 2^>nul ^| find /c /v ""') do set "DONE_COUNT=%%C"
<nul set /p "=Progress: !DONE_COUNT! / !IDX!   " >con
<nul set /p "=                          " >con
if !DONE_COUNT! LSS !IDX! (
    powershell -NoProfile -Command "Start-Sleep -Seconds 1" >nul 2>&1
    set /a WAIT_SECONDS+=1
    if !WAIT_SECONDS! GEQ !WAIT_LIMIT! goto PACK_WORKER_TIMEOUT
    goto :WAIT_LOOP
)
echo.
echo [PACKER] Все потоки завершены. Финализация сборки...

:: === 4. Сборка финального файла ===
:: 4.1 Добавляем вызовы функций
for /L %%i in (1,1,%IDX%) do (
    set "FNAME=!FILE_%%i!"
    set "CHECK_NAME=!FNAME:/=\!"
    set "IS_PROTECTED=0"
    set "F_HASH=unknown"
    
    if exist "%FULL_TEMP_DIR%\%%i.md5" (
        for /f "usebackq tokens=*" %%H in ("%FULL_TEMP_DIR%\%%i.md5") do set "F_HASH=%%H"
    )

    echo "!CHECK_NAME!" | findstr /C:"profiles\\" >nul && set "IS_PROTECTED=1"
    echo "!CHECK_NAME!" | findstr /C:"firmware_output\\" >nul && set "IS_PROTECTED=1"
    if /i "!CHECK_NAME:~0,13!"=="custom_files\" set "IS_PROTECTED=1"
    echo "!CHECK_NAME!" | findstr /C:"scripts\\" >nul && set "IS_PROTECTED=1"

    if "!IS_PROTECTED!"=="1" (
        >> "%NEW_UNPACKER_FILE%" echo if "%%SKIP_DEFAULTS%%"=="0" ^(
        >> "%NEW_UNPACKER_FILE%" echo     call :DECODE_FILE "!FNAME!" "!F_HASH!" ^|^| exit /b 1
        >> "%NEW_UNPACKER_FILE%" echo ^)
    ) else (
        >> "%NEW_UNPACKER_FILE%" echo call :DECODE_FILE "!FNAME!" "!F_HASH!" ^|^| exit /b 1
    )
)

:: 4.2 Дописываем логику распаковки (FOOTER)
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
    echo echo Now you will Run _Builder.bat
    echo echo ===================================
    echo exit /b 0
    echo.
    echo :DECODE_FILE
    echo     powershell -NoProfile -ExecutionPolicy Bypass -Command "function Md5($p){ $m=[Security.Cryptography.MD5]::Create(); $s=[IO.File]::OpenRead($p); try { $bytes=$m.ComputeHash($s) } finally { $s.Dispose(); $m.Dispose() }; $sb=New-Object Text.StringBuilder; foreach($b in $bytes){ [void]$sb.Append($b.ToString('x2')) }; $sb.ToString() }; $ext='%%~1'; $hash='%%~2'.Trim().ToLowerInvariant(); $self='%%~f0'; if(Test-Path -LiteralPath $ext){ if($hash -and $hash -ne 'unknown'){ $existing=Md5 $ext; if($existing -eq $hash){ exit 0 }; if($env:ROUTERFW_REPAIR -ne '1'){ Write-Host ('[WARN] Modified file preserved: ' + $ext); exit 0 }; Write-Host ('[WARN] Existing checksum mismatch, repairing: ' + $ext); Copy-Item -LiteralPath $ext -Destination ($ext + '.routerfw.bak') -Force -ErrorAction Stop } else { exit 0 } }; Write-Host ('[UNPACK] Recover: ' + $ext + ' - md5( ' + $hash + ' )'); $content=Get-Content -LiteralPath $self; $start=$false; $b64=''; foreach($line in $content){ if($line -eq (':: BEGIN_B64_ ' + $ext)){ $start=$true; continue }; if($line -eq (':: END_B64_ ' + $ext)){ $start=$false; break }; if($start){ $b64 += $line.Trim() } }; if(-not $b64){ Write-Error ('Missing payload: ' + $ext); exit 1 }; $tmp=[IO.Path]::GetTempFileName(); try { [IO.File]::WriteAllBytes($tmp,[Convert]::FromBase64String($b64)); if($hash -and $hash -ne 'unknown'){ $actual=Md5 $tmp; if($actual -ne $hash){ Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue; Write-Error ('Checksum mismatch: ' + $ext + ' expected ' + $hash + ' actual ' + $actual); exit 1 } }; $dir=Split-Path -Parent $ext; if($dir){ [void](New-Item -ItemType Directory -Force -Path $dir) }; Move-Item -LiteralPath $tmp -Destination $ext -Force; exit 0 } catch { if(Test-Path -LiteralPath $tmp){ Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }; Write-Error $_.Exception.Message; exit 1 }"
    echo     if errorlevel 1 exit /b 1
    echo exit /b
    echo.
    echo :: =========================================================
    echo ::  BASE64
    echo :: =========================================================
) >> "%NEW_UNPACKER_FILE%"

:: 4.3 Прикрепляем данные
for /L %%i in (1,1,%IDX%) do (
    if exist "%FULL_TEMP_DIR%\%%i.chunk" (
        type "%FULL_TEMP_DIR%\%%i.chunk" >> "%NEW_UNPACKER_FILE%"
    )
)

echo [PACKER] Замена итогового _unpacker.bat...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Move-Item -LiteralPath '%NEW_UNPACKER_FILE%' -Destination '_unpacker.bat' -Force -ErrorAction Stop; exit 0 } catch { Write-Error $_.Exception.Message; exit 1 }"
if errorlevel 1 goto PACK_MOVE_ERROR
if exist "%NEW_UNPACKER_FILE%" goto PACK_MOVE_LEFTOVER

:: === 5. Очистка и создание ZIP ===
rd /s /q "%FULL_TEMP_DIR%"

echo.
echo [PACKER] Создание резервной копии в ZIP...
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "Get-Date -Format 'dd.MM.yyyy_HH-mm'"`) do set "ZIP_DATE=%%D"
set "ZIP_NAME=routerFW_WinDockerBuilder_v!ZIP_DATE!.zip"
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

:PACK_STALE_NEW
echo [ERROR] Не удалось удалить старый файл %NEW_UNPACKER_FILE%.
goto PACK_ERROR

:PACK_TEMP_ERROR
echo [ERROR] Не удалось создать временную папку %FULL_TEMP_DIR%.
goto PACK_ERROR

:PACK_WORKER_START_ERROR
echo [ERROR] Не удалось запустить worker для "%PACK_ERROR_FILE%".
goto PACK_ERROR

:PACK_WORKER_FAILED
echo.
echo [ERROR] Один или несколько worker-процессов завершились с ошибкой.
goto PACK_ERROR

:PACK_WORKER_TIMEOUT
echo.
echo [ERROR] Таймаут ожидания worker-процессов.
goto PACK_ERROR

:PACK_MOVE_ERROR
echo.
echo [ERROR] Не удалось заменить _unpacker.bat.
echo [ERROR] Возможно, файл открыт, запущен, заблокирован антивирусом или защищён от записи.
goto PACK_ERROR

:PACK_MOVE_LEFTOVER
echo [ERROR] Временный файл %NEW_UNPACKER_FILE% не был перемещён.
goto PACK_ERROR

:PACK_ERROR
echo.
echo [ERROR] Упаковка прервана.
if exist "%FULL_TEMP_DIR%" rd /s /q "%FULL_TEMP_DIR%" >nul 2>&1
if exist "%NEW_UNPACKER_FILE%" del /f /q "%NEW_UNPACKER_FILE%" >nul 2>&1
exit /b 1

:ADD_FILE
set /a IDX+=1
set "FILE_%IDX%=%~1"
exit /b

:PROCESS_FILE
set "CURRENT_ID=%~1"
set "CURRENT_FILE=!FILE_%CURRENT_ID%!"
if not exist "%CURRENT_FILE%" (
    echo [ERROR] Обязательный файл "%CURRENT_FILE%" не найден.
    > "%FULL_TEMP_DIR%\%CURRENT_ID%.failed" echo Required packer input not found: %CURRENT_FILE%
    > "%FULL_TEMP_DIR%\%CURRENT_ID%.ready" echo done
    exit /b 1
)

set "PACK_ERROR_FILE=%CURRENT_FILE%"
if defined ROUTERFW_TEST_MODE (
    call :RUN_WORKER_SYNC "%CURRENT_FILE%" "%CURRENT_ID%" "%FULL_TEMP_DIR%"
    exit /b !errorlevel!
)

call :START_WORKER "%CURRENT_FILE%" "%CURRENT_ID%" "%FULL_TEMP_DIR%"
if errorlevel 1 exit /b 1
set /a ACTIVE_TASKS+=1
exit /b 0

:START_WORKER
start "" /b powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0system\packer_worker.ps1" -FilePath "%~1" -Id "%~2" -TempDir "%~3"
exit /b

:RUN_WORKER_SYNC
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0system\packer_worker.ps1" -FilePath "%~1" -Id "%~2" -TempDir "%~3"
exit /b %errorlevel%

:WORKER
rem Supports both direct label call and recursive file call with :WORKER as %1.
set "W_FILE=%~1"
set "W_ID=%~2"
set "W_DIR=%~3"
if /i "%~1"==":WORKER" (
    set "W_FILE=%~2"
    set "W_ID=%~3"
    set "W_DIR=%~4"
)
set "W_TMP=%W_DIR%\%W_ID%.tmp"
set "W_STAGED=%W_DIR%\%W_ID%.staged"
set "W_OUT=%W_DIR%\%W_ID%.chunk"
set "W_RDY=%W_DIR%\%W_ID%.ready"
if not exist "%W_DIR%" md "%W_DIR%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "system\packer_worker.ps1" -FilePath "%W_FILE%" -Id "%W_ID%" -TempDir "%W_DIR%"
set "W_RC=%errorlevel%"
if not "%W_RC%"=="0" (
    if not exist "%W_DIR%\%W_ID%.failed" (
        > "%W_DIR%\%W_ID%.failed" echo Worker exited with code %W_RC%
    )
)
if not exist "%W_DIR%\%W_ID%.ready" (
    > "%W_DIR%\%W_ID%.ready" echo done
)
exit /b %W_RC%
:: checksum:MD5=66e4829f23089ae9eff8f5b3a14fac1a