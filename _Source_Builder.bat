@echo off
setlocal enabledelayedexpansion
cls
chcp 65001 >nul

echo [INIT] Очистка неиспользуемых сетей Docker...
docker network prune --force
echo.

:: === 0. РАСПАКОВКА ВСТРОЕННЫХ ФАЙЛОВ ===
call :EXTRACT_RESOURCES
if exist _unpacker.bat (
    echo [INIT] Обнаружен универсальный распаковщик...
    call _unpacker.bat
)

:: Запоминаем текущую папку
set "PROJECT_DIR=%CD%"

:: === 1. ИНИЦИАЛИЗАЦИЯ ПАПОК ===
call :CHECK_DIR "profiles"
call :CHECK_DIR "custom_files"
call :CHECK_DIR "firmware_output"
call :CHECK_DIR "src_packages"
call :CHECK_DIR "custom_packages"

:MENU
cls
echo ========================================
echo  OpenWrt SOURCE Builder v1.4 (iqubik)
echo ========================================
echo.
echo Обнаруженные Source-профили:
echo.

set count=0
for %%f in (profiles\*.conf) do (
    set /a count+=1
    set "profile[!count!]=%%~nxf"
    set "p_id=%%~nf"
    
    :: Создаем папку для кастомных файлов профиля, если нет
    if not exist "custom_files\!p_id!" (
        mkdir "custom_files\!p_id!"
    )
    :: Вызываем безопасную функцию для создания скрипта прав
    call :CREATE_PERMS_SCRIPT "!p_id!"    
    echo    [!count!] %%~nxf
)

echo.
echo    [A] Собрать ВСЕ профили (Параллельно)
echo    [S] Переключиться на IMAGE Builder
echo    [R] Обновить список профилей
echo    [0] Выход
echo.
set /p choice="Выберите опцию: "

if /i "%choice%"=="0" exit /b
if /i "%choice%"=="A" goto BUILD_ALL
if /i "%choice%"=="S" goto SWITCH_TO_IMAGE
if /i "%choice%"=="R" goto MENU

set /a num_choice=%choice% 2>nul
if "%num_choice%"=="0" if not "%choice%"=="0" goto INVALID
if %num_choice% gtr %count% goto INVALID
if %num_choice% lss 1 goto INVALID

:: === ОДИНОЧНАЯ СБОРКА ===
set "SELECTED_CONF=!profile[%choice%]!"
call :BUILD_ROUTINE "%SELECTED_CONF%"
echo Сборка завершена.
goto MENU

:BUILD_ALL
echo.
echo === ЗАПУСК ПАРАЛЛЕЛЬНОЙ СБОРКИ ===
echo ВНИМАНИЕ: Сборка из исходников требует много CPU/RAM!
echo.
for /L %%i in (1,1,%count%) do (
    set "CURRENT_CONF=!profile[%%i]!"
    call :BUILD_ROUTINE "!CURRENT_CONF!"
)
echo.
echo === ВСЕ ЗАДАЧИ ЗАПУЩЕНЫ ===
pause
goto MENU

:INVALID
echo Неверный выбор!
pause
goto MENU

:SWITCH_TO_IMAGE
if exist "_Image_Builder.bat" (
    start "" "_Image_Builder.bat"
    exit
) else (
    echo [ERROR] Файл _Image_Builder.bat не найден!
    pause
    goto MENU
)

:: =========================================================
::  ПОДПРОГРАММА СБОРКИ
:: =========================================================
:BUILD_ROUTINE
set "CONF_FILE=%~1"
set "PROFILE_ID=%~n1"

echo.
echo ----------------------------------------------------
echo [PROCESSING] Профиль: %CONF_FILE%
echo ----------------------------------------------------

set "SRC_BRANCH_VAL="
for /f "usebackq tokens=2 delims==" %%a in (`type "profiles\%CONF_FILE%" ^| findstr "SRC_BRANCH"`) do (
    set "VAL=%%a"
    set "VAL=!VAL:"=!"
    for /f "tokens=* delims= " %%b in ("!VAL!") do set "SRC_BRANCH_VAL=%%b"
)

if "%SRC_BRANCH_VAL%"=="" (
    echo [INFO] SRC_BRANCH не найден в %CONF_FILE%. Пропускается для SourceBuilder.
    exit /b
)

set "IS_LEGACY="
echo "!SRC_BRANCH_VAL!" | findstr /C:"19.07" >nul && set IS_LEGACY=1
echo "!SRC_BRANCH_VAL!" | findstr /C:"18.06" >nul && set IS_LEGACY=1

IF DEFINED IS_LEGACY (
    set "BUILDER_SERVICE=builder-src-oldwrt"
) ELSE (
    set "BUILDER_SERVICE=builder-src-openwrt"
)

:: Создаем структуру папок для Source Builder
if not exist "firmware_output\sourcebuilder\%PROFILE_ID%" (
    if not exist "firmware_output\sourcebuilder" mkdir "firmware_output\sourcebuilder"
    mkdir "firmware_output\sourcebuilder\%PROFILE_ID%"
)

echo [LAUNCH] Запуск контейнера сборки для: %PROFILE_ID%...
echo [DEBUG] Ветка Git: !SRC_BRANCH_VAL! (Legacy: !IS_LEGACY!)

START "SrcBuild: %PROFILE_ID%" /D "%PROJECT_DIR%" cmd /c "set SELECTED_CONF=%CONF_FILE%&& set HOST_FILES_DIR=./custom_files/%PROFILE_ID%&& set HOST_OUTPUT_DIR=./firmware_output/sourcebuilder/%PROFILE_ID%&& docker-compose -f docker-compose-src.yaml -p srcbuild_%PROFILE_ID% up --build --force-recreate --remove-orphans %BUILDER_SERVICE% & echo. & echo === WORK FINISHED === & pause"

exit /b

:: =========================================================
::  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
:: =========================================================
:CREATE_PERMS_SCRIPT
set "P_ID=%~1"
set "PERM_FILE=custom_files\%P_ID%\etc\uci-defaults\99-permissions.sh"
if exist "%PERM_FILE%" exit /b
powershell -Command "[System.IO.Directory]::CreateDirectory('custom_files\%P_ID%\etc\uci-defaults')" >nul 2>&1
set "B64=IyEvYmluL3NoCiMgRml4IFNTSCBwZXJtaXNzaW9ucwpbIC1kIC9ldGMvZHJvcGJZYXIgXSAmJiBjaG1vZCA3MDAgL2V0Yy9kcm9wYmVhcgpbIC1mIC9ldGMvZHJvcGJZYXIvYXV0aG9yaXplZF9rZXlzIF0gJiYgY2htb2QgNjAwIC9ldGMvZHJvcGJZYXIvYXV0aG9yaXplZF9rZXlzCiMgRml4IFNoYWRvdwpbIC1mIC9ldGMvc2hhZG93IF0gJiYgY2htb2QgNjAwIC9ldGMvc2hhZG93CiMgRml4IHJvb3QgU1NIIGtleXMKWyAtZCAvcm9vdC8uc3NoIF0gJiYgY2htb2QgNzAwIC9yb290Ly5zc2gKWyAtZiAvcm9vdC8uc3NoL2lkX3JzYSBdICYmIGNobW9kIDYwMCAvcm9vdC8uc3NoL2lkX3JzYQpleGl0IDAK"
powershell -Command "[IO.File]::WriteAllBytes('%PERM_FILE%', [Convert]::FromBase64String('%B64%'))"
exit /b

:EXTRACT_RESOURCES
echo [INIT] Извлечение ресурсов SourceBuilder...
:: Создаем папку profiles заранее, чтобы PowerShell мог в нее писать
if not exist "profiles" mkdir "profiles"

for %%F in (
    "docker-compose-src.yaml"
    "src.dockerfile"
    "src.dockerfile.legacy"
) do (
    if not exist "%%~F" (
        echo [INIT] -> %%~F...
        powershell -Command "$ext = '%%~F'; $content = Get-Content '%~f0'; $start = $false; $b64 = ''; foreach($line in $content){ if($line -match 'BEGIN_B64_ ' + [Regex]::Escape($ext)){ $start = $true; continue }; if($line -match 'END_B64_ ' + [Regex]::Escape($ext)){ $start = $false; break }; if($start){ $b64 += $line.Trim() } }; if($b64){ [IO.File]::WriteAllBytes($ext, [Convert]::FromBase64String($b64)) }"
    )
)
exit /b

:CHECK_DIR
if not exist "%~1" mkdir "%~1"
exit /b

:: =========================================================
::  СЕКЦИЯ ДЛЯ BASE64 КОДА (ТОЛЬКО ДЛЯ SOURCE BUILDER)
:: =========================================================

:: BEGIN_B64_ docker-compose-src.yaml
IyBmaWxlOiBzcmNCdWlsZGVyXGRvY2tlci1jb21wb3NlLXNyYy55YW1sIHYxLjEKc2VydmljZXM6CiAgYnVpbGRlci1zcmMtb3BlbndydDoKICAgIGJ1aWxkOgogICAgICBjb250ZXh0OiAuCiAgICAgIGRvY2tlcmZpbGU6IHNyYy5kb2NrZXJmaWxlCiAgICB1c2VyOiAicm9vdCIKICAgIGVudmlyb25tZW50OgogICAgICAtIENPTkZfRklMRT0ke1NFTEVDVEVEX0NPTkZ9CiAgICB2b2x1bWVzOgogICAgICAtIHNyYy13b3JrZGlyOi9ob21lL2J1aWxkL29wZW53cnQKICAgICAgLSBzcmMtZGwtY2FjaGU6L2hvbWUvYnVpbGQvb3BlbndydC9kbAogICAgICAtIC4vcHJvZmlsZXM6L3Byb2ZpbGVzCiAgICAgIC0gLi9zcmNfcGFja2FnZXM6L2lucHV0X3BhY2thZ2VzCiAgICAgIC0gJHtIT1NUX0ZJTEVTX0RJUn06L292ZXJsYXlfZmlsZXMKICAgICAgLSAke0hPU1RfT1VUUFVUX0RJUn06L291dHB1dAogICAgICAtIC4vb3BlbnNzbC5jbmY6L29wZW5zc2wuY25mCiAgICBjb21tYW5kOiAmc3JjX2J1aWxkX3NjcmlwdCB8CiAgICAgIC9iaW4vYmFzaCAtYyAiCiAgICAgIHNldCAtZQogICAgICBlY2hvICdbSU5JVF0gQ2hlY2tpbmcgdm9sdW1lIHBlcm1pc3Npb25zLi4uJwogICAgICAjINCY0YHQv9C+0LvRjNC30YPQtdC8ICQkKC4uLikg0YfRgtC+0LHRiyBkb2NrZXItY29tcG9zZSDQvdC1INC/0YvRgtCw0LvRgdGPINC40L3RgtC10YDQv9GA0LXRgtC40YDQvtCy0LDRgtGMINC/0LXRgNC10LzQtdC90L3Rg9GOCiAgICAgIGlmIFsgXCIkJChzdGF0IC1jICclVScgL2hvbWUvYnVpbGQvb3BlbndydClcIiAhPSBcImJ1aWxkXCIgXTsgdGhlbgogICAgICAgICAgZWNobyBcIltJTklUXSBGaXJzdCBydW4gZGV0ZWN0ZWQ6IEZpeGluZyBvd25lcnNoaXAgb2Ygd29ya2Rpci4uLlwiCiAgICAgICAgICBjaG93biAtUiBidWlsZDpidWlsZCAvaG9tZS9idWlsZC9vcGVud3J0CiAgICAgIGZpCiAgICAgIAogICAgICAjINCh0L7Qt9C00LDQtdC8INGB0LrRgNC40L/RgiDRgdCx0L7RgNC60Lgg0LLQvdGD0YLRgNC4INC60L7QvdGC0LXQudC90LXRgNCwCiAgICAgIGNhdCA8PCAnRU9GJyA+IC90bXAvYnVpbGRfc2NyaXB0LnNoICAgICAgCiAgICAgIHNldCAtZQogICAgICBleHBvcnQgSE9NRT0vaG9tZS9idWlsZAogICAgICBQUk9GSUxFX0lEPSQkKGJhc2VuYW1lIFwiJCRDT05GX0ZJTEVcIiAuY29uZikKCiAgICAgICMgPT09IDAuIFNldHVwIEVudmlyb25tZW50ID09PQogICAgICBpZiBbICEgLWYgXCIvcHJvZmlsZXMvJCRDT05GX0ZJTEVcIiBdOyB0aGVuCiAgICAgICAgZWNobyBcIkZBVEFMOiBQcm9maWxlIC9wcm9maWxlcy8kJENPTkZfRklMRSBub3QgZm91bmQhXCIKICAgICAgICBleGl0IDEKICAgICAgZmkKICAgICAgCiAgICAgICMgPT09INCa0J7QndCS0JXQoNCi0JDQptCY0K8gQ1JMRiAtPiBMRiDQmCDQo9CU0JDQm9CV0J3QmNCVIEJPTSA9PT0KICAgICAgZWNobyBcIltJTklUXSBOb3JtYWxpemluZyBjb25maWcuLi5cIgogICAgICBjYXQgXCIv... [truncated]
:: END_B64_ docker-compose-src.yaml

:: BEGIN_B64_ src.dockerfile
I2ZpbGU6IHNyY0J1aWxkZXIvc3JjLmRvY2tlcmZpbGUgdjEuMApGUk9NIHVidW50dToyMi4wNApFTlYgREVCSUFOX0ZST05URU5EPW5vbmludGVyYWN0aXZlClJVTiBhcHQtZ2V0IHVwZGF0ZSAmJiBhcHQtZ2V0IGluc3RhbGwgLXkgXCAgICAKICAgIGJ1aWxkLWVzc2VudGlhbCBjbGFuZyBmbGV4IGJpc29uIGcrKyBnYXdrIGdjYy1tdWx0aWxpYiBnKystbXVsdGlsaWIgXAogICAgZ2V0dGV4dCBnaXQgcGF0Y2ggc3dpZyB0aW1lIHJzeW5jIHVuemlwIGZpbGUgd2dldCBjdXJsIFwgICAgCiAgICBsaWJuY3Vyc2VzLWRldiBsaWJzc2wtZGV2IHpsaWIxZy1kZXYgbGliZWxmLWRldiBsaWJ6c3RkLWRldiBcICAgIAogICAgcHl0aG9uMy1kZXYgcHl0aG9uMy1kaXN0dXRpbHMgcHl0aG9uMy1zZXR1cHRvb2xzIHB5dGhvbjMtcHllbGZ0b29scyBcICAgIAogICAgeHNsdHByb2MgenN0ZCBjYS1jZXJ0aWZpY2F0ZXMgc3NsLWNlcnQgc3VkbyBcCiAgICAmJiBybSAtcmYgL3Zhci9saWIvYXB0L2xpc3RzLyoKUlVOIHVzZXJhZGQgLW0gLXUgMTAwMCAtcyAvYmluL2Jhc2ggYnVpbGQKV09SS0RJUiAvaG9tZS9idWlsZC9vcGVud3J0ClJVTiBta2RpciAtcCBkbCAmJiBjaG93biAtUiBidWlsZDpidWlsZCAvaG9tZS9idWlsZC9vcGVud3J0CkNPUFkgLS1jaG93bj1idWlsZDpidWlsZCBvcGVuc3NsLmNuZiAvaG9tZS9idWlsZC9vcGVuc3NsLmNuZgpFTlYgT1BFTlNTTF9DT05GPS9ob21lL2J1aWxkL29wZW5zc2wuY25mCg==
:: END_B64_ src.dockerfile

:: BEGIN_B64_ src.dockerfile.legacy
IyBmaWxlOiBzcmNCdWlsZGVyL3NyYy5kb2NrZXJmaWxlLmxlZ2FjeQpGUk9NIHVidW50dToxOC4wNApFTlYgREVCSUFOX0ZST05URU5EPW5vbmludGVyYWN0aXZlClJVTiBhcHQtZ2V0IHVwZGF0ZSAmJiBhcHQtZ2V0IGluc3RhbGwgLXkgXAogICAgYnVpbGQtZXNzZW50aWFsIHBhdGNoIGJ6aXAyIGZsZXggYmlzb24gZysrIGdhd2sgXAogICAgZ2V0dGV4dCBnaXQgc3VidmVyc2lvbiByc3luYyB1bnppcCB3Z2V0IGN1cmwgZmlsZSBcCiAgICBjY2FjaGUgZWNqIGZhc3RqYXIgamF2YS1wcm9wb3NlLWNsYXNzcGF0aCBcCiAgICBsaWJlbGYtZGV2IGxpYm5jdXJzZXM1LWRldiBsaWJuY3Vyc2VzdzUtZGV2IGxpYnNzbC1kZXYgemxpYjFnLWRldiBcCiAgICBsaWJnbGliMi4wLWRldiBcCiAgICBweXRob24gcHl0aG9uMi43LWRldiBweXRob24tc2V0dXB0b29scyBcCiAgICBweXRob24zIHB5dGhvbjMtc2V0dXB0b29scyBweXRob24zLWRpc3R1dGlscyBcCiAgICBzd2lnIHRpbWUgeHNsdHByb2MgXAogICAgY2EtY2VydGlmaWNhdGVzIHNzbC1jZXJ0IHN1ZG8gXAogICAgJiYgcm0gLXJmIC92YXIvbGliL2FwdC9saXN0cy8qClJVTiB1c2VyYWRkIC1tIC11IDEwMDAgLXMgL2Jpbi9iYXNoIGJ1aWxkCldPUktESVIgL2hvbWUvYnVpbGQvb3BlbndydApSVU4gbWtkaXIgLXAgZGwgJiYgY2hvd24gLVIgYnVpbGQ6YnVpbGQgL2hvbWUvYnVpbGQvb3BlbndydApDT1BZIC0tY2hvd249YnVpbGQ6YnVpbGQgb3BlbnNzbC5jbmYgL2hvbWUvYnVpbGQvb3BlbnNzbC5jbmYKRU5WIE9QRU5TU0xfQ09ORj0vaG9tZS9idWlsZC9vcGVuc3NsLmNuZgo=
:: END_B64_ src.dockerfile.legacy
