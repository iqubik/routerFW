@echo off
setlocal
cd /d "%~dp0"

rem Override the default WSL distribution (Debian) with ROUTERFW_TESTGATE_WSL_DISTRO.

where py >nul 2>&1
if errorlevel 1 (
  echo [FAIL] Python launcher "py" is required to run testgate.py.
  exit /b 1
)

py -3 "%~dp0testgate.py"
exit /b %ERRORLEVEL%
