@echo off
rem Use the repository-local embeddable CPython when it is available.
set "PYTHONUTF8=1"
rem Prefer the bundled runtime, but honor an explicit caller override.
rem An invalid override must fail closed, not silently choose another Python.
if not defined ROUTERFW_PYTHON_EXE (
    for %%P in ("%~dp0..\tools\runtime\python313\python.exe") do if exist "%%~fP" set "ROUTERFW_PYTHON_EXE=%%~fP"
)
if defined ROUTERFW_PYTHON_EXE (
    "%ROUTERFW_PYTHON_EXE%" -B -c "import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)" >nul 2>&1
    if errorlevel 1 set "ROUTERFW_PYTHON_EXE="
)
exit /b 0
