@echo off
setlocal
cd /d "%~dp0"

rem Override the default WSL distribution (Debian) with ROUTERFW_TESTGATE_WSL_DISTRO.

call "%~dp0scripts\python_runtime.bat"
if not defined ROUTERFW_PYTHON_EXE (
    echo [FAIL] Repository Python runtime is missing or invalid.
    exit /b 1
)
"%ROUTERFW_PYTHON_EXE%" -B "%~dp0testgate.py"
exit /b %ERRORLEVEL%
