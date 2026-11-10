@echo off
chcp 65001 >nul
rem file: package_source_zip.bat
rem Optional routerFW source-tree export. Requires Python 3.10+; builders do not.
rem Python handles [Y/n], ZIP verification, SOURCE_TREE_INDEX and green path.
setlocal EnableExtensions DisableDelayedExpansion

if not exist "%~dp0package_source_zip.py" (
    echo [ERROR] package_source_zip.py не найден рядом с BAT.
    exit /b 1
)

rem Prefer Windows Python launcher; avoid Microsoft Store aliases with no runtime.
where py >nul 2>&1
if not errorlevel 1 (
    py -3 -c "import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)" >nul 2>&1
    if not errorlevel 1 goto :use_py
)
where python >nul 2>&1
if not errorlevel 1 (
    python -c "import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)" >nul 2>&1
    if not errorlevel 1 goto :use_python
)
where python3 >nul 2>&1
if not errorlevel 1 (
    python3 -c "import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)" >nul 2>&1
    if not errorlevel 1 goto :use_python3
)

echo [ERROR] Нужен Python 3.10+ ^(py -3 или python^) для упаковки исходников.
echo [INFO] Это необязательный инструмент, сборщики routerFW Python не требуют.
exit /b 1

:use_py
py -3 "%~dp0package_source_zip.py" --root "%~dp0." %*
exit /b %errorlevel%

:use_python
python "%~dp0package_source_zip.py" --root "%~dp0." %*
exit /b %errorlevel%

:use_python3
python3 "%~dp0package_source_zip.py" --root "%~dp0." %*
exit /b %errorlevel%
