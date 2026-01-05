@echo off
rem Этот батник запускает PowerShell-скрипт для генерации файла с опциями.

rem Определяем путь к PowerShell-скрипту (в той же папке, что и этот батник)
set "SCRIPT_PATH=%~dp0generate_options.ps1"

echo "Запуск PowerShell скрипта..."
echo "Путь: %SCRIPT_PATH%"

rem Запускаем PowerShell с обходом политики выполнения только для этого запуска
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"

echo.
echo "Работа скрипта завершена."
pause
