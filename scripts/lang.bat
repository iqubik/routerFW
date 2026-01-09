@echo off
setlocal enabledelayedexpansion

:: Веса: UI=4, Formats=2, UserLanguages=2, InstallLang=2
set RU_SCORE=0

:: 1. Язык интерфейса
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "(Get-UICulture).Name" 2^>nul') do set "UI_LANG=%%a"
echo %UI_LANG% | findstr /I "ru" >nul
if not errorlevel 1 set /a RU_SCORE+=4

:: 2. Региональные форматы
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "(Get-Culture).Name" 2^>nul') do set "FMT_LANG=%%a"
echo %FMT_LANG% | findstr /I "ru" >nul
if not errorlevel 1 set /a RU_SCORE+=2

:: 3. Список языков пользователя (раскладки)
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "(Get-WinUserLanguageList).LanguageTag" 2^>nul') do (
    echo %%a | findstr /I "ru" >nul
    if not errorlevel 1 set /a RU_SCORE+=2
)

:: 4. Язык самой установки Windows
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Nls\Language" /v InstallLanguage 2>nul | findstr /I "0419" >nul
if not errorlevel 1 set /a RU_SCORE+=2

:: Логика суждения:
:: Если набрано 3 и более баллов — считаем систему русской.
set "IS_RU=FALSE"
if %RU_SCORE% GEQ 3 set "IS_RU=TRUE"

:: ВЫВОД РЕЗУЛЬТАТА
echo ---------------------------------------
echo DETECTED: %UI_LANG% / %FMT_LANG%
echo RU_SCORE: %RU_SCORE%
echo IS_RUSSIAN: %IS_RU%
echo ---------------------------------------

:: Пример использования в коде
if "%IS_RU%"=="TRUE" (
    echo [OK] Используем русские настройки.
) else (
    echo [OK] Using English settings.
)

pause