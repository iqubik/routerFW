@echo off
setlocal enabledelayedexpansion

:: =========================================================
::  Упаковщик общих ресурсов в _unpacker.bat
::  v1.4 (Final - Subroutine Method)
:: =========================================================

cls
echo ========================================
echo  OpenWrt Universal Packer (Fixed v1.4)
echo ========================================
echo.

:: === 1. Определяем список общих файлов ===
:: Формируем список. Важно: используем += для надежности.
set "COMMON_FILES="
set "COMMON_FILES=!COMMON_FILES! "openssl.cnf""
set "COMMON_FILES=!COMMON_FILES! "profiles\giga_24105_main_full.conf""
set "COMMON_FILES=!COMMON_FILES! "profiles\giga_24105_rep_full.conf""
set "COMMON_FILES=!COMMON_FILES! "profiles\nanopi_r5c_full.conf""
set "COMMON_FILES=!COMMON_FILES! "profiles\tplink_841n_v9_190710_full.conf""
set "COMMON_FILES=!COMMON_FILES! "profiles\zbt_wr8305rt_22037_full.conf""
set "COMMON_FILES=!COMMON_FILES! "profiles\xiaomi_4a_gigabit_23056_full.conf""

:: Временные файлы
set "NEW_UNPACKER_FILE=_unpacker.bat.new"
set "B64_BLOCK_FILE=b64_block.tmp"
set "CERTUTIL_OUT=cert_out.tmp"

:: Очистка
if exist "%NEW_UNPACKER_FILE%" del /f /q "%NEW_UNPACKER_FILE%"
if exist "%B64_BLOCK_FILE%" del /f /q "%B64_BLOCK_FILE%"
if exist "%CERTUTIL_OUT%" del /f /q "%CERTUTIL_OUT%"

:: === 2. Генерируем "шапку" и вызовы ===
echo [PACKER] Создание логической части распаковщика...

:: Записываем заголовки
echo @echo off> "%NEW_UNPACKER_FILE%"
echo setlocal enabledelayedexpansion>> "%NEW_UNPACKER_FILE%"
echo.>> "%NEW_UNPACKER_FILE%"
echo :: =========================================================>> "%NEW_UNPACKER_FILE%"
echo ::  Универсальный распаковщик общих ресурсов>> "%NEW_UNPACKER_FILE%"
echo ::  Generated v1.4>> "%NEW_UNPACKER_FILE%"
echo :: =========================================================>> "%NEW_UNPACKER_FILE%"
echo.>> "%NEW_UNPACKER_FILE%"
echo echo [UNPACKER] Запуск распаковки...>> "%NEW_UNPACKER_FILE%"
echo.>> "%NEW_UNPACKER_FILE%"

:: Генерируем прямые вызовы функции для каждого файла
:: Это заменяет сложный цикл for и исключает ошибки синтаксиса
for %%F in (%COMMON_FILES%) do (
    echo call :DECODE_FILE "%%~F">> "%NEW_UNPACKER_FILE%"
)

:: Завершаем основной блок
echo.>> "%NEW_UNPACKER_FILE%"
echo echo [UNPACKER] Распаковка завершена.>> "%NEW_UNPACKER_FILE%"
echo exit /b>> "%NEW_UNPACKER_FILE%"
echo.>> "%NEW_UNPACKER_FILE%"

:: === 3. Добавляем функцию декодирования в скрипт ===
:: Эта функция будет встроена в _unpacker.bat
echo :DECODE_FILE>> "%NEW_UNPACKER_FILE%"
echo     set "TARGET_FILE=%%~1">> "%NEW_UNPACKER_FILE%"
echo     :: Создаем папку, если нужно>> "%NEW_UNPACKER_FILE%"
echo     if not exist "%%~dp1" md "%%~dp1" 2^>nul>> "%NEW_UNPACKER_FILE%"
echo.>> "%NEW_UNPACKER_FILE%"
echo     echo [UNPACKER] -^> %%TARGET_FILE%%>> "%NEW_UNPACKER_FILE%"
echo.>> "%NEW_UNPACKER_FILE%"
echo     :: Логика PowerShell (ищет Base64 блок по имени файла)>> "%NEW_UNPACKER_FILE%"
echo     powershell -Command "$ext = '%%~1'; $content = Get-Content '%%~f0'; $start = $false; $b64 = ''; foreach($line in $content){ if($line -match 'BEGIN_B64_ ' + [Regex]::Escape($ext)){ $start = $true; continue }; if($line -match 'END_B64_ ' + [Regex]::Escape($ext)){ $start = $false; break }; if($start){ $b64 += $line.Trim() } }; if($b64){ [IO.File]::WriteAllBytes($ext, [Convert]::FromBase64String($b64)) }">> "%NEW_UNPACKER_FILE%"
echo exit /b>> "%NEW_UNPACKER_FILE%"


:: === 4. Генерируем и дописываем Base64 блоки ===
echo.
echo [PACKER] Генерация Base64 блоков...

echo.>> "%B64_BLOCK_FILE%"
echo :: =========================================================>> "%B64_BLOCK_FILE%"
echo ::  СЕКЦИЯ ДЛЯ BASE64 КОДА>> "%B64_BLOCK_FILE%"
echo :: =========================================================>> "%B64_BLOCK_FILE%"

for %%F in (%COMMON_FILES%) do (
    set "CURRENT_FILE=%%~F"
    if exist "!CURRENT_FILE!" (
        echo   Processing '!CURRENT_FILE!'...
        
        rem Кодируем файл
        certutil -f -encode "!CURRENT_FILE!" "%CERTUTIL_OUT%" > nul
        
        echo.>> "%B64_BLOCK_FILE%"
        echo :: BEGIN_B64_ !CURRENT_FILE!>> "%B64_BLOCK_FILE%"
        
        rem Берем только тело Base64 (без -----BEGIN/END)
        for /f "tokens=*" %%L in ('findstr /v /c:"-----" "%CERTUTIL_OUT%"') do (
            echo %%L>> "%B64_BLOCK_FILE%"
        )
        
        echo :: END_B64_ !CURRENT_FILE!>> "%B64_BLOCK_FILE%"

    ) else (
        echo   [WARNING] Файл '!CURRENT_FILE!' не найден, пропуск.
    )
)

:: === 5. Сборка ===
echo.
echo [PACKER] Сборка финального файла _unpacker.bat...
type "%B64_BLOCK_FILE%" >> "%NEW_UNPACKER_FILE%"

move /Y "%NEW_UNPACKER_FILE%" "_unpacker.bat" > nul

:: === 6. Очистка ===
if exist "%B64_BLOCK_FILE%" del "%B64_BLOCK_FILE%"
if exist "%CERTUTIL_OUT%" del "%CERTUTIL_OUT%"

echo.
echo ========================================
echo  Готово!
echo ========================================
echo.
pause