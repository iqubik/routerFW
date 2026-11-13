@echo off
rem file: package_source_zip.bat
chcp 65001 >nul
rem Optional routerFW source-tree export. Requires the repository Python runtime.
rem Python handles [Y/n], ZIP verification, SOURCE_TREE_INDEX and green path.
setlocal EnableExtensions DisableDelayedExpansion

if not exist "%~dp0package_source_zip.py" (
    echo [ERROR] package_source_zip.py не найден рядом с BAT.
    exit /b 1
)

call "%~dp0scripts\python_runtime.bat"
if not defined ROUTERFW_PYTHON_EXE (
    echo [ERROR] Repository Python runtime is missing or invalid.
    exit /b 1
)
"%ROUTERFW_PYTHON_EXE%" -B -c "import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Repository Python runtime must be Python 3.10+.
    exit /b 1
)

"%ROUTERFW_PYTHON_EXE%" -B "%~dp0package_source_zip.py" --root "%~dp0." %*
exit /b %ERRORLEVEL%
