@echo off
setlocal enabledelayedexpansion
cls
chcp 65001 >nul

:: =========================================================
::  Упаковщик общих ресурсов в _unpacker.bat
::  v1.5 (Skip existing files + New List)
:: =========================================================

cls
echo ========================================
echo  OpenWrt Universal Packer (v1.6)
echo ========================================
echo.

:: === 1. Определяем список общих файлов ===
:: Добавляем файлы по одному (безопасный метод)
set "COMMON_FILES="
set "COMMON_FILES=!COMMON_FILES! "openssl.cnf""
set "COMMON_FILES=!COMMON_FILES! "docker-compose.yaml""
set "COMMON_FILES=!COMMON_FILES! "docker-compose-src.yaml""
set "COMMON_FILES=!COMMON_FILES! "dockerfile""
set "COMMON_FILES=!COMMON_FILES! "dockerfile.841n""
set "COMMON_FILES=!COMMON_FILES! "src.dockerfile""
set "COMMON_FILES=!COMMON_FILES! "src.dockerfile.legacy""
set "COMMON_FILES=!COMMON_FILES! "profiles\giga_24105_main_full.conf""
set "COMMON_FILES=!COMMON_FILES! "profiles\giga_24105_rep_full.conf""
set "COMMON_FILES=!COMMON_FILES! "profiles\nanopi_r5c_full.conf""
set "COMMON_FILES=!COMMON_FILES! "profiles\tplink_841n_v9_190710_full.conf""
set "COMMON_FILES=!COMMON_FILES! "profiles\zbt_wr8305rt_22037_full.conf""
set "COMMON_FILES=!COMMON_FILES! "profiles\xiaomi_4a_gigabit_23056_full.conf""
set "COMMON_FILES=!COMMON_FILES! "profiles\rax3000m_i_24104_full.conf""
set "COMMON_FILES=!COMMON_FILES! "scripts\etc\uci-defaults\99-permissions.sh""
set "COMMON_FILES=!COMMON_FILES! "scripts\diag.sh""
set "COMMON_FILES=!COMMON_FILES! "scripts\hooks.sh""
set "COMMON_FILES=!COMMON_FILES! "scripts\upgrade.sh""
set "COMMON_FILES=!COMMON_FILES! "scripts\packager.sh""
set "COMMON_FILES=!COMMON_FILES! "_run_create_profile.bat""
set "COMMON_FILES=!COMMON_FILES! "create_profile.ps1""
set "COMMON_FILES=!COMMON_FILES! "_Source_Builder.bat""
set "COMMON_FILES=!COMMON_FILES! "_Image_Builder.bat""
set "COMMON_FILES=!COMMON_FILES! "README.md""

:: Временные файлы
set "NEW_UNPACKER_FILE=_unpacker.bat.new"
set "B64_BLOCK_FILE=b64_block.tmp"
set "CERTUTIL_OUT=cert_out.tmp"

:: Очистка
if exist "%NEW_UNPACKER_FILE%" del /f /q "%NEW_UNPACKER_FILE%"
if exist "%B64_BLOCK_FILE%" del /f /q "%B64_BLOCK_FILE%"
if exist "%CERTUTIL_OUT%" del /f /q "%CERTUTIL_OUT%"

:: === 2. Генерируем логическую часть _unpacker.bat ===
echo [PACKER] Создание логики распаковщика (с проверкой файлов)...

:: Пишем заголовок
echo @echo off> "%NEW_UNPACKER_FILE%"
echo setlocal enabledelayedexpansion>> "%NEW_UNPACKER_FILE%"
echo cls>> "%NEW_UNPACKER_FILE%"
echo chcp 65001 ^>nul>> "%NEW_UNPACKER_FILE%"
echo.>> "%NEW_UNPACKER_FILE%"
echo :: =========================================================>> "%NEW_UNPACKER_FILE%"
echo ::  Универсальный распаковщик общих ресурсов>> "%NEW_UNPACKER_FILE%"
echo ::  Generated v1.5>> "%NEW_UNPACKER_FILE%"
echo :: =========================================================>> "%NEW_UNPACKER_FILE%"
echo.>> "%NEW_UNPACKER_FILE%"
echo echo [UNPACKER] Проверка и распаковка ресурсов...>> "%NEW_UNPACKER_FILE%"
echo.>> "%NEW_UNPACKER_FILE%"

:: Генерируем вызовы функций
for %%F in (%COMMON_FILES%) do (
    echo call :DECODE_FILE "%%~F">> "%NEW_UNPACKER_FILE%"
)

:: Завершение работы распаковщика
echo.>> "%NEW_UNPACKER_FILE%"
echo echo [UNPACKER] Готово.>> "%NEW_UNPACKER_FILE%"
echo exit /b>> "%NEW_UNPACKER_FILE%"
echo.>> "%NEW_UNPACKER_FILE%"

:: === 3. Добавляем функцию декодирования (С ПОДРОБНЫМ ЛОГОМ) ===
echo :DECODE_FILE>> "%NEW_UNPACKER_FILE%"
echo     :: 1. Проверяем, существует ли файл>> "%NEW_UNPACKER_FILE%"
echo     if exist "%%~1" (>> "%NEW_UNPACKER_FILE%"
echo         echo [INFO]  Файл уже существует, пропуск: %%~nx1>> "%NEW_UNPACKER_FILE%"
echo         exit /b>> "%NEW_UNPACKER_FILE%"
echo     )>> "%NEW_UNPACKER_FILE%"
echo.>> "%NEW_UNPACKER_FILE%"
echo     :: 2. Создаем папку, если нужно>> "%NEW_UNPACKER_FILE%"
echo     if not exist "%%~dp1" (>> "%NEW_UNPACKER_FILE%"
echo         echo [DEBUG] Папка отсутствует. Создаем: %%~dp1>> "%NEW_UNPACKER_FILE%"
echo         md "%%~dp1" 2^>nul>> "%NEW_UNPACKER_FILE%"
echo     )>> "%NEW_UNPACKER_FILE%"
echo.>> "%NEW_UNPACKER_FILE%"
echo     :: 3. Распаковка>> "%NEW_UNPACKER_FILE%"
echo     echo [DEBUG] Распаковка файла: %%~1>> "%NEW_UNPACKER_FILE%"
echo     powershell -Command "$ext = '%%~1'; $content = Get-Content '%%~f0'; $start = $false; $b64 = ''; foreach($line in $content){ if($line -match 'BEGIN_B64_ ' + [Regex]::Escape($ext)){ $start = $true; continue }; if($line -match 'END_B64_ ' + [Regex]::Escape($ext)){ $start = $false; break }; if($start){ $b64 += $line.Trim() } }; if($b64){ [IO.File]::WriteAllBytes($ext, [Convert]::FromBase64String($b64)) }">> "%NEW_UNPACKER_FILE%"
echo.>> "%NEW_UNPACKER_FILE%"
echo     :: 4. Проверка результата>> "%NEW_UNPACKER_FILE%"
echo     if exist "%%~1" ( echo [OK]   Успешно записан: %%~nx1 ) else ( echo [ERR]  Не удалось создать: %%~nx1 )>> "%NEW_UNPACKER_FILE%"
echo exit /b>> "%NEW_UNPACKER_FILE%"


:: === 4. Генерируем Base64 блоки ===
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
        
        rem Берем тело Base64
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

:: === 7. Создание ZIP архива ===
echo.
echo [PACKER] Создание резервной копии в ZIP...

:: Получаем дату через PowerShell (формат ДД-ММ-ГГГГ_ЧЧ-ММ)
:: Это работает надежнее, чем %DATE%, так как не зависит от региональных настроек
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "Get-Date -Format 'dd-MM-yyyy_HH-mm'"`) do set "ZIP_DATE=%%D"

set "ZIP_NAME=_unpacker_!ZIP_DATE!.zip"

:: Упаковываем _unpacker.bat в zip
powershell -NoProfile -Command "Compress-Archive -Path '_unpacker.bat' -DestinationPath '!ZIP_NAME!' -Force"

echo.
echo ========================================
echo  Файл обновлен: _unpacker.bat
echo  Архив создан:  !ZIP_NAME!
echo ========================================
echo.
pause