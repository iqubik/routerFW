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
call :CHECK_DIR "custom_packages"
call :CHECK_DIR "custom_files"
call :CHECK_DIR "firmware_output"

:MENU
cls
echo ========================================
echo  OpenWrt IMAGE Builder v4.6 (iqubik)
echo ========================================
echo.
echo Обнаруженные профили:
echo.

set count=0
for %%f in (profiles\*.conf) do (
    set /a count+=1
    set "profile[!count!]=%%~nxf"
    set "p_id=%%~nf"
    
    :: Создаем папку профиля, если нет
    if not exist "custom_files\!p_id!" (
        mkdir "custom_files\!p_id!"
    )

    :: Вызываем безопасную функцию для создания скрипта прав
    call :CREATE_PERMS_SCRIPT "!p_id!"
    
    echo    [!count!] %%~nxf
)

echo.
echo    [A] Собрать ВСЕ профили (Параллельно)
echo    [S] Переключиться на SOURCE Builder
echo    [R] Обновить список профилей
echo    [0] Выход
echo.
set /p choice="Выберите опцию: "

if /i "%choice%"=="0" exit /b
if /i "%choice%"=="A" goto BUILD_ALL
if /i "%choice%"=="S" goto SWITCH_TO_SOURCE
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
echo Новые окна откроются автоматически...
echo.
for /L %%i in (1,1,%count%) do (
    set "CURRENT_CONF=!profile[%%i]!"
    call :BUILD_ROUTINE "!CURRENT_CONF!"
)
echo.
echo === ВСЕ ЗАДАЧИ ЗАПУЩЕНЫ ===
echo Не закрывайте это окно до завершения работы.
pause
goto MENU

:INVALID
echo Неверный выбор!
pause
goto MENU

:SWITCH_TO_SOURCE
if exist "_Source_Builder.bat" (
    start "" "_Source_Builder.bat"
    exit
) else (
    echo [ERROR] Файл _Source_Builder.bat не найден!
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

set "URL_CLEAN="
for /f "usebackq tokens=2 delims==" %%a in (`type "profiles\%CONF_FILE%" ^| findstr "IMAGEBUILDER_URL"`) do (
    set "VAL=%%a"
    set "VAL=!VAL:"=!"
    for /f "tokens=* delims= " %%b in ("!VAL!") do set "URL_CLEAN=%%b"
)

if "%URL_CLEAN%"=="" (
    echo [INFO] IMAGEBUILDER_URL не найден в %CONF_FILE%. Пропускается для ImageBuilder.
    exit /b
)

set "IS_LEGACY="
echo "!URL_CLEAN!" | findstr /C:"/19." >nul && set IS_LEGACY=1
echo "!URL_CLEAN!" | findstr /C:"/18." >nul && set IS_LEGACY=1
echo "!URL_CLEAN!" | findstr /C:"/17." >nul && set IS_LEGACY=1

IF DEFINED IS_LEGACY (
    set "BUILDER_SERVICE=builder-oldwrt"
) ELSE (
    set "BUILDER_SERVICE=builder-openwrt"
)

:: Создаем структуру папок: firmware_output -> imagebuilder -> имя_профиля
if not exist "firmware_output\imagebuilder\%PROFILE_ID%" (
    if not exist "firmware_output\imagebuilder" mkdir "firmware_output\imagebuilder"
    mkdir "firmware_output\imagebuilder\%PROFILE_ID%"
)

echo [LAUNCH] Запуск окна для: %PROFILE_ID%...
echo [DEBUG] URL определен как: !URL_CLEAN!

START "Build: %PROFILE_ID%" /D "%PROJECT_DIR%" cmd /c "set SELECTED_CONF=%CONF_FILE%&& set HOST_FILES_DIR=./custom_files/%PROFILE_ID%&& set HOST_OUTPUT_DIR=./firmware_output/imagebuilder/%PROFILE_ID%&& docker-compose -p build_%PROFILE_ID% up --build --force-recreate --remove-orphans %BUILDER_SERVICE% & echo. & echo === WORK FINISHED === & pause"

exit /b

:: =========================================================
::  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
:: =========================================================

:EXTRACT_RESOURCES
echo [INIT] Извлечение ресурсов ImageBuilder...
:: Создаем папку profiles заранее
if not exist "profiles" mkdir "profiles"

for %%F in (
    "docker-compose.yaml"
    "dockerfile"
    "dockerfile.841n"
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

:CREATE_PERMS_SCRIPT
set "P_ID=%~1"
set "PERM_FILE=custom_files\%P_ID%\etc\uci-defaults\99-permissions.sh"
if exist "%PERM_FILE%" exit /b
powershell -Command "[System.IO.Directory]::CreateDirectory('custom_files\%P_ID%\etc\uci-defaults')" >nul 2>&1
set "B64=IyEvYmluL3NoCiMgRml4IFNTSCBwZXJtaXNzaW9ucwpbIC1kIC9ldGMvZHJvcGJZYXIgXSAmJiBjaG1vZCA3MDAgL2V0Yy9kcm9wYmVhcgpbIC1mIC9ldGMvZHJvcGJZYXIvYXV0aG9yaXplZF9rZXlzIF0gJiYgY2htb2QgNjAwIC9ldGMvZHJvcGJZYXIvYXV0aG9yaXplZF9rZXlzCiMgRml4IFNoYWRvdwpbIC1mIC9ldGMvc2hhZG93IF0gJiYgY2htb2QgNjAwIC9ldGMvc2hhZG93CiMgRml4IHJvb3QgU1NIIGtleXMKWyAtZCAvcm9vdC8uc3NoIF0gJiYgY2htb2QgNzAwIC9yb290Ly5zc2gKWyAtZiAvcm9vdC8uc3NoL2lkX3JzYSBdICYmIGNobW9kIDYwMCAvcm9vdC8uc3NoL2lkX3JzYQpleGl0IDAK"
powershell -Command "[IO.File]::WriteAllBytes('%PERM_FILE%', [Convert]::FromBase64String('%B64%'))"
exit /b

:: =========================================================
::  СЕКЦИЯ ДЛЯ BASE64 КОДА (ТОЛЬКО ДЛЯ IMAGE BUILDER)
:: =========================================================

:: BEGIN_B64_ docker-compose.yaml
IyBmaWxlOiBkb2NrZXItY29tcG9zZS55YW1sIFYxLjEKc2VydmljZXM6CiAgYnVpbGRlci1vcGVud3J0OgogICAgYnVpbGQ6IC4KICAgIGVudmlyb25tZW50OgogICAgICAtIENPTkZfRklMRT0ke1NFTEVDVEVEX0NPTkZ9CiAgICB2b2x1bWVzOgogICAgICAtIGltYWdlYnVpbGRlci1jYWNoZTovY2FjaGUKICAgICAgLSBpcGstY2FjaGU6L2J1aWxkZXJfd29ya3NwYWNlL2RsCiAgICAgIC0gLi9jdXN0b21fcGFja2FnZXM6L2lucHV0X3BhY2thZ2VzCiAgICAgIC0gJHtIT1NUX0ZJTEVTX0RJUn06L292ZXJsYXlfZmlsZXMKICAgICAgLSAke0hPU1RfT1VUUFVUX0RJUn06L291dHB1dAogICAgICAtIC4vcHJvZmlsZXM6L3Byb2ZpbGVzCiAgICAgIC0gLi9vcGVuc3NsLmNuZjovb3BlbnNzbC5jbmYKICAgIGNvbW1hbmQ6ICZidWlsZF9zY3JpcHQgfAogICAgICAvYmluL2Jhc2ggLWMgIgogICAgICBzZXQgLWUKICAgICAgaWYgWyAhIC1mIFwiL3Byb2ZpbGVzLyQkQ09ORl9GSUxFXCIgXTsgdGhlbgogICAgICAgIGVjaG8gXCJGQVRBTDogUHJvZmlsZSAvcHJvZmlsZXMvJCRDT05GX0ZJTEUgbm90IGZvdW5kIVwiCiAgICAgICAgZXhpdCAxCiAgICAgIGZpCiAgICAgICMgPT09INCa0J7QndCS0JXQoNCi0JDQptCY0K8gQ1JMRiAtPiBMRiDQmCDQo9CU0JDQm9CV0J3QmNCVIEJPTSA9PT0KICAgICAgZWNobyBcIltJTklUXSBOb3JtYWxpemluZyBjb25maWcuLi5cIgogICAgICAjINCY0YHQv9C+0LvRjNC30YPQtdC8INC00LLQvtC50L3Ri9C1INGB0LvRjdGI0LggXFx4RUYsINGH0YLQvtCx0YsgWUFNTCDQuCBCYXNoINC/0LXRgNC10LTQsNC70Lgg0LjRhSDQsiBzZWQg0LrQvtGA0YDQtdC60YLQvdC+CiAgICAgIGNhdCBcIi9wcm9maWxlcy8kJENPTkZfRklMRVwiIHwgc2VkICcxcy9eXFx4RUZcXHhCQlxceEJGLy8nIHwgdHIgLWQgJ1xccicgPiAvdG1wL2NsZWFuX2NvbmZpZy5lbnYKICAgICAgc291cmNlIC90bXAvY2xlYW5fY29uZmlnLmVudgoKICAgICAgIyDQn9GA0L7QstC10YDQutCwINC90LAg0L7RiNC40LHQutC4INC/0LDRgNGB0LjQvdCz0LAKICAgICAgaWYgWyAteiBcIiQkSU1BR0VCVUlMREVSX1VSTFwiIF07IHRoZW4KICAgICAgICAgZWNobyBcIltFUlJPUl0gSU1BR0VCVUlMREVSX1VSTCBpcyBlbXB0eSEgQ29uZmlnIHdhcyBub3QgcGFyc2VkIGNvcnJlY3RseS5cIgogICAgICAgICBleGl0IDEKICAgICAgZmkKICAgICAgIyA9PT0g0JfQkNCh0JXQmtCQ0JXQnCDQktCg0JXQnNCvID09PQogICAgICBTVEFSVF9USU1FPSQkKGRhdGUgKyVzKQogICAgICBUSU1FU1RBTVA9JCQoVFo9J1VUQy0zJyBkYXRlICslZCVtJXktJUglTSVTKQogICAgICAjIC0tLSAxLiDQmtCt0KjQmNCg0J7QktCQ0J3QmNCVIC0tLQogICAgICBBUkNISVZFX05BTUU9JCQoYmFzZW5hbWUgXCIkJElNQUdFQlVJTERFUl9VUkxcIikKICAgICAgQ0FDSEVfRklMRT1cIi9jYWNoZS8kJEFSQ0hJVkVfTkFNRVwiCiAgICAgIGlmIFsgISAtZiBcIiQkQ0FDSEVfRklM... [truncated]
:: END_B64_ docker-compose.yaml

:: BEGIN_B64_ dockerfile
IyBmaWxlIGRvY2tlcmZpbGUKRlJPTSB1YnVudHU6MjIuMDQKRU5WIERFQklBTl9GUk9OVEVORD1ub25pbnRlcmFjdGl2ZQpSVU4gYXB0LWdldCB1cGRhdGUgJiYgYXB0LWdldCBpbnN0YWxsIC15IFwKCWJ1aWxkLWVzc2VudGlhbCBnaXQgbGlibmN1cnNlczUtZGV2IHpsaWIxZy1kZXYgc3VidmVyc2lvbiBtZXJjdXJpYWwgYXV0b2NvbmYgbGlidG9vbCBsaWJzc2wtZGV2IGxpYmdsaWIyLjAtZGV2IGxpYmdtcC1kZXYgbGlibXBjLWRldiBsaWJtcGZyLWRldiB0ZXhpbmZvIGdhd2sgcHl0aG9uMy1kaXN0dXRpbHMgcHl0aG9uMy1zZXR1cHRvb2xzIHJzeW5jIHVuemlwIHdnZXQgZmlsZSB6c3RkIFwKCSYmIHJtIC1yZiAvdmFyL2xpYi9hcHQvbGlzdHMvKgpDT1BZIG9wZW5zc2wuY25mIC9ldGMvc3NsL29wZW5zc2wuY25mCldPUktESVIgL2J1aWxkZXJfd29ya3NwYWNlCg==
:: END_B64_ dockerfile

:: BEGIN_B64_ dockerfile.841n
IyBmaWxlIGRvY2tlcmZpbGUuODQxbgpGUk9NIHVidW50dToxOC4wNApFTlYgREVCSUFOX0ZST05URU5EPW5vbmludGVyYWN0aXZlClJVTiBhcHQtZ2V0IHVwZGF0ZSAmJiBhcHQtZ2V0IGluc3RhbGwgLXkgXAoJcHl0aG9uMyBidWlsZC1lc3NlbnRpYWwgcHl0aG9uMi43IGxpYm5jdXJzZXM1LWRldiBsaWJuY3Vyc2VzdzUtZGV2IHpsaWIxZy1kZXYgZ2F3ayBnaXQgZ2V0dGV4dCBsaWJzc2wtZGV2IHhzbHRwcm9jIHdnZXQgdW56aXAgeHotdXRpbHMgY2EtY2VydGlmaWNhdGVzIFwKCSYmIHVwZGF0ZS1jYS1jZXJ0aWZpY2F0ZXMgXAoJJiYgbG4gLXNmIC91c3IvYmluL3B5dGhvbjIuNyAvdXNyL2Jpbi9weXRob24gXAoJJiYgcm0gLXJmIC92YXIvbGliL2FwdC9saXN0cy8qCkNPUFkgb3BlbnNzbC5jbmYgL2V0Yy9zc2wvb3BlbnNzbC5jbmYKV09SS0RJUiAvYnVpbGRlcl93b3Jrc3BhY2UK
:: END_B64_ dockerfile.841n
