@echo off
setlocal enabledelayedexpansion

:: =========================================================
::  Упаковщик общих ресурсов в _unpacker.bat
::  v1.0, iqubik
:: =========================================================
::
::  Этот скрипт читает общие файлы, кодирует их в Base64
::  и перезаписывает _unpacker.bat, обновляя в нем
::  встроенные данные.
::

cls
echo ========================================
 echo  OpenWrt Universal Packer
 echo ========================================
 echo.

:: === 1. Определяем список общих файлов ===
set "COMMON_FILES=" ^
    "openssl.cnf" ^
    "profiles\giga_24105_main_full.conf" ^
    "profiles\giga_24105_rep_full.conf" ^
    "profiles\nanopi_r5c_full.conf" ^
    "profiles\tplink_841n_v9_190710_full.conf" ^
    "profiles\zbt_wr8305rt_22037_full.conf" ^
    "profiles\xiaomi_4a_gigabit_23056_full.conf"

:: Временные файлы
set "NEW_UNPACKER_FILE=_unpacker.bat.new"
set "B64_BLOCK_FILE=b64_block.tmp"
set "CERTUTIL_OUT=cert_out.tmp"

:: Удаляем временные файлы от предыдущих запусков
if exist "%NEW_UNPACKER_FILE%" del "%NEW_UNPACKER_FILE%"
if exist "%B64_BLOCK_FILE%" del "%B64_BLOCK_FILE%"

:: === 2. Генерируем "шапку" для _unpacker.bat ===
echo [PACKER] Создание логической части распаковщика...
(
    echo @echo off
    echo setlocal enabledelayedexpansion
    echo.
    echo :: =========================================================
    echo ::  Универсальный распаковщик общих ресурсов
    echo ::  v1.0, iqubik
    echo :: =========================================================
    echo ::
    echo ::  Этот скрипт вызывается из _Image_Builder.bat и _Source_Builder.bat
    echo ::  для извлечения ОБЩИХ файлов из секции Base64 ниже.
    echo ::
    echo.
    echo call :EXTRACT_COMMON_RESOURCES
    echo exit /b
    echo.
    echo.
    echo :EXTRACT_COMMON_RESOURCES
    echo echo [UNPACKER] Извлечение общих ресурсов...
    echo for %%%%F in (
) > "%NEW_UNPACKER_FILE%"

:: Добавляем список файлов в цикл for
for %%F in (%COMMON_FILES%) do (
    echo     "%%~F" ^
) >> "%NEW_UNPACKER_FILE%"

:: Добавляем остальную часть логики
(
    echo ) do (
    echo     if not exist "%%%%~F" (
    echo         echo [UNPACKER] -^> %%%%~F
    echo         powershell -Command "$ext = '%%%%~F'; $content = Get-Content '%%~f0'; $start = $false; $b64 = ''; foreach($line in $content){ if($line -match 'BEGIN_B64_ ' + [Regex]::Escape($ext)){ $start = $true; continue }; if($line -match 'END_B64_ ' + [Regex]::Escape($ext)){ $start = $false; break }; if($start){ $b64 += $line.Trim() } }; if($b64){ [IO.File]::WriteAllBytes($ext, [Convert]::FromBase64String($b64)) }"
    echo     )
    echo )
    echo exit /b
) >> "%NEW_UNPACKER_FILE%"


:: === 3. Генерируем секцию с Base64 ===
echo.
 echo [PACKER] Генерация Base64 блоков...
(
    echo.
    echo :: =========================================================
    echo ::  СЕКЦИЯ ДЛЯ BASE64 КОДА
    echo :: =========================================================
) >> "%B64_BLOCK_FILE%"

for %%F in (%COMMON_FILES%) do (
    set "CURRENT_FILE=%%~F"
    if exist "!CURRENT_FILE!" (
        echo   Processing '!CURRENT_FILE!'...
        
        rem Кодируем файл
        certutil -f -encode "!CURRENT_FILE!" "%CERTUTIL_OUT%" > nul
        
        rem Добавляем заголовок
        (
            echo.
            echo :: BEGIN_B64_ !CURRENT_FILE!
        ) >> "%B64_BLOCK_FILE%"
        
        rem Фильтруем вывод certutil, убирая его заголовки
        for /f "skip=1 tokens=*" %%L in ('findstr /v /c:"-----" "%CERTUTIL_OUT%"') do (
            echo %%L >> "%B64_BLOCK_FILE%"
        )
        
        rem Добавляем подвал
        (
            echo :: END_B64_ !CURRENT_FILE!
        ) >> "%B64_BLOCK_FILE%"

    ) else (
        echo   [WARNING] Файл '!CURRENT_FILE!' не найден, пропуск.
    )
)

:: === 4. Собираем финальный _unpacker.bat ===
echo.
 echo [PACKER] Сборка финального файла _unpacker.bat...
type "%B64_BLOCK_FILE%" >> "%NEW_UNPACKER_FILE%"

:: Заменяем старый файл новым
move /Y "%NEW_UNPACKER_FILE%" "_unpacker.bat" > nul

:: === 5. Очистка ===
if exist "%B64_BLOCK_FILE%" del "%B64_BLOCK_FILE%"
if exist "%CERTUTIL_OUT%" del "%CERTUTIL_OUT%"

echo.
 echo ========================================
 echo  Готово! _unpacker.bat был успешно обновлен.
 echo ========================================
 echo.
pause
