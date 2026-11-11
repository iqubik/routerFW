@echo off
rem file: capture_worktree_diff.bat
rem Создает diff.zip для независимого аудита изменений рабочей копии routerFW.
rem Включает tracked, staged, unstaged, untracked и бинарные изменения.
rem Запуск из любого каталога; путь к репозиторию определяется по расположению скрипта.
rem Требует Git for Windows и Windows PowerShell с модулем Microsoft.PowerShell.Archive.
rem Не меняет исходные файлы и реальный Git index; создает только служебные outputs.
rem Output: diff.zip и artifacts\worktree_diffs\<timestamp>\ (оба пути игнорируются Git).
rem WORKTREE_TREE.md lists workspace paths except root .git, including Git-ignored/generated paths.
rem Index-only: does not read contents, and never follows reparse-point directories.
setlocal EnableExtensions DisableDelayedExpansion

chcp 65001 >nul
cd /d "%~dp0" || (
    echo [ERROR] Не удалось перейти в каталог routerFW.
    exit /b 1
)
set "PROJECT_ROOT=%CD%"

where git >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Git не найден в PATH.
    exit /b 1
)

git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Каталог "%PROJECT_ROOT%" не является Git working tree.
    exit /b 1
)

set "GIT_PREFIX="
for /f "eol=| delims=" %%P in ('git rev-parse --show-prefix 2^>nul') do set "GIT_PREFIX=%%P"
if defined GIT_PREFIX (
    echo [ERROR] Поместите capture_worktree_diff.bat в корень репозитория.
    echo [ERROR] Текущий каталог не является корнем Git working tree.
    exit /b 1
)

set "HEAD_COMMIT="
for /f "delims=" %%H in ('git rev-parse HEAD 2^>nul') do set "HEAD_COMMIT=%%H"
if not defined HEAD_COMMIT (
    echo [ERROR] Не удалось определить HEAD. Проверьте, создан ли первый commit.
    exit /b 1
)

set "STAMP="
for /f "usebackq delims=" %%T in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Date -Format 'yyyyMMdd-HHmmss-fff'"`) do set "STAMP=%%T"
if not defined STAMP (
    echo [ERROR] Не удалось сформировать timestamp.
    exit /b 1
)

set "OUT_ROOT=%PROJECT_ROOT%\artifacts\worktree_diffs"
set "OUT_DIR=%OUT_ROOT%\%STAMP%"
set "LATEST_ARCHIVE=%PROJECT_ROOT%\diff.zip"
set "TEMP_ARCHIVE=%PROJECT_ROOT%\diff.new.zip"
set "GIT_WARNINGS=%OUT_DIR%\git-warnings.txt"
set "UNTRACKED_PATHS=%OUT_DIR%\untracked-paths.txt"
set "TREE_INDEX=%OUT_DIR%\WORKTREE_TREE.md"

mkdir "%OUT_DIR%" >nul 2>nul
if not exist "%OUT_DIR%" (
    echo [ERROR] Не удалось создать "%OUT_DIR%".
    exit /b 1
)

>"%OUT_DIR%\HEAD.txt" echo %HEAD_COMMIT%
git branch --show-current >"%OUT_DIR%\branch.txt" 2>>"%GIT_WARNINGS%"
git status --short --untracked-files=all >"%OUT_DIR%\status.txt" 2>>"%GIT_WARNINGS%"
if errorlevel 1 goto git_fail

git -c core.quotepath=false ls-files --others --exclude-standard >"%UNTRACKED_PATHS%" 2>>"%GIT_WARNINGS%"
if errorlevel 1 goto git_fail

set "WORKTREE_FILES=0"
for /f %%C in ('type "%OUT_DIR%\status.txt" ^| find /c /v ""') do set "WORKTREE_FILES=%%C"
set "UNTRACKED_FILES=0"
for /f %%C in ('type "%UNTRACKED_PATHS%" ^| find /c /v ""') do set "UNTRACKED_FILES=%%C"

if "%WORKTREE_FILES%"=="0" (
    echo [INFO] Рабочее дерево чистое. Изменений для новой упаковки нет.
    echo [INFO] Предыдущий diff.zip, если он существует, не изменен.
    rd /s /q "%OUT_DIR%" >nul 2>&1
    exit /b 0
)

if exist "%LATEST_ARCHIVE%" (
    echo.
    echo [WARN] Уже существует "%LATEST_ARCHIVE%".
    call :confirm_overwrite
    if errorlevel 1 (
        echo [INFO] Отменено. Предыдущий архив сохранен.
        rd /s /q "%OUT_DIR%" >nul 2>&1
        exit /b 0
    )
)

git -c core.quotepath=false diff --binary --full-index --find-renames --no-ext-diff HEAD -- . >"%OUT_DIR%\diff.patch" 2>>"%GIT_WARNINGS%"
if errorlevel 1 goto git_fail

git -c core.quotepath=false diff --stat HEAD -- . >"%OUT_DIR%\stat.txt" 2>>"%GIT_WARNINGS%"
if errorlevel 1 goto git_fail

rem Append untracked files as full binary patches. NUL is the Windows null device.
rem Delayed expansion is intentionally disabled so filenames containing ! remain intact.
for /f "usebackq eol=| delims=" %%F in ("%UNTRACKED_PATHS%") do (
    git -c core.quotepath=false diff --binary --full-index --no-ext-diff --no-index -- NUL "%%F" >>"%OUT_DIR%\diff.patch" 2>>"%GIT_WARNINGS%"
    if errorlevel 2 goto git_fail
    git -c core.quotepath=false diff --stat --no-index -- NUL "%%F" >>"%OUT_DIR%\stat.txt" 2>>"%GIT_WARNINGS%"
    if errorlevel 2 goto git_fail
)

rem Whitespace diagnostics are informational: do not discard a useful diff because of them.
set "CHECK_COMMAND_ERROR=0"
git -c core.quotepath=false -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol diff --check HEAD -- . >"%OUT_DIR%\diff-check.txt" 2>>"%GIT_WARNINGS%"
if errorlevel 2 set "CHECK_COMMAND_ERROR=1"

for /f "usebackq eol=| delims=" %%F in ("%UNTRACKED_PATHS%") do (
    git -c core.quotepath=false -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol diff --check --no-index -- NUL "%%F" >>"%OUT_DIR%\diff-check.txt" 2>>"%GIT_WARNINGS%"
    if errorlevel 2 set "CHECK_COMMAND_ERROR=1"
)

set "CHECK_WHITESPACE=0"
for %%F in ("%OUT_DIR%\diff-check.txt") do if %%~zF GTR 0 set "CHECK_WHITESPACE=1"
set "CHECK_RESULT=%CHECK_WHITESPACE%"
if "%CHECK_COMMAND_ERROR%"=="1" set "CHECK_RESULT=1"

rem The Markdown inventory is path-only and includes ignored, generated and private names.
rem Do not silently produce a truncated inventory or replace a valid previous diff.zip.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\scripts\write_worktree_tree.ps1" -Root "%PROJECT_ROOT%" -Output "%TREE_INDEX%"
if errorlevel 1 (
    echo [ERROR] Не удалось создать ПОЛНЫЙ индекс WORKTREE_TREE.md.
    echo [INFO] Предыдущий diff.zip не изменен.
    echo [INFO] Проверьте доступность каталогов или лимит списка путей.
    echo [INFO] Диагностика сохранена в "%OUT_DIR%".
    exit /b 1
)
if not exist "%TREE_INDEX%" (
    echo [ERROR] Индекс WORKTREE_TREE.md не создан. Архив не обновлен.
    exit /b 1
)

(
    echo routerFW worktree diff bundle
    echo.
    echo Baseline commit: %HEAD_COMMIT%
    echo Branch: see branch.txt
    echo.
    echo Included:
    echo - Tracked changes relative to HEAD, including staged and unstaged edits.
    echo - Untracked files that are not excluded by Git ignore rules.
    echo - Binary patch data where Git supports binary diffs.
    echo - Git status, statistics, whitespace diagnostics and warnings.
    echo - WORKTREE_TREE.md: full path-only tree of folders and files, including ignored/generated paths except root .git.
    echo.
    echo Not included:
    echo - Contents of Git-ignored/generated/private files; only their NAMES appear in WORKTREE_TREE.md.
    echo - Contents of nested submodule working trees; submodule pointer state may appear in the patch.
    echo - Git repository history and object database.
    echo - Large tracked Git LFS objects may be represented by pointer diffs; attach separately if needed.
    echo.
    echo The tree inventory is NOT an atomic filesystem snapshot; changing files can affect results.
    echo Review the patch, status and path inventory before sharing this archive.
    echo It may contain credentials, tokens, private profile values, local paths or other sensitive data.
    echo The script does not modify source files or the real Git index; it creates ignored output files only.
) >"%OUT_DIR%\README.txt"

if not exist "%GIT_WARNINGS%" type nul >"%GIT_WARNINGS%"

if exist "%TEMP_ARCHIVE%" del /q "%TEMP_ARCHIVE%" >nul 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $items = @(Get-ChildItem -LiteralPath $env:OUT_DIR -Force | ForEach-Object { $_.FullName }); if ($items.Count -eq 0) { throw 'Diff bundle is empty' }; Compress-Archive -LiteralPath $items -DestinationPath $env:TEMP_ARCHIVE -CompressionLevel Optimal -Force"
if errorlevel 1 (
    echo [ERROR] Данные собраны, но не удалось создать временный ZIP.
    echo [INFO] Предыдущий diff.zip не изменен.
    echo [INFO] Диагностические файлы сохранены в "%OUT_DIR%".
    if exist "%TEMP_ARCHIVE%" del /q "%TEMP_ARCHIVE%" >nul 2>nul
    exit /b 1
)
rem Verify the contract inside the new ZIP BEFORE replacing the previous good archive.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Add-Type -AssemblyName System.IO.Compression.FileSystem; $archive=[IO.Compression.ZipFile]::OpenRead($env:TEMP_ARCHIVE); try { $entry=$archive.GetEntry('WORKTREE_TREE.md'); if ($null -eq $entry -or $entry.Length -lt 64) { throw 'WORKTREE_TREE.md is missing or empty in temporary diff ZIP' } } finally { $archive.Dispose() }"
if errorlevel 1 (
    echo [ERROR] Созданный ZIP не содержит полного индекса WORKTREE_TREE.md.
    echo [INFO] Предыдущий diff.zip сохранен без изменений.
    echo [INFO] Временный ZIP оставлен для диагностики: "%TEMP_ARCHIVE%".
    exit /b 1
)
move /y "%TEMP_ARCHIVE%" "%LATEST_ARCHIVE%" >nul
if errorlevel 1 (
    echo [ERROR] Не удалось заменить "%LATEST_ARCHIVE%".
    echo [INFO] Предыдущий архив, если он был, сохранен.
    echo [INFO] Новый архив находится в "%TEMP_ARCHIVE%".
    exit /b 1
)

set "DIFF_BYTES=0"
for %%F in ("%OUT_DIR%\diff.patch") do set "DIFF_BYTES=%%~zF"
set "ARCHIVE_BYTES=0"
for %%F in ("%LATEST_ARCHIVE%") do set "ARCHIVE_BYTES=%%~zF"

echo.
echo ========================================
echo  routerFW worktree diff готов
echo ========================================
echo HEAD: %HEAD_COMMIT%
echo Branch: see "%OUT_DIR%\branch.txt"
echo Измененных путей: %WORKTREE_FILES%
echo Untracked файлов: %UNTRACKED_FILES%
echo Размер patch: %DIFF_BYTES% bytes
echo Размер ZIP: %ARCHIVE_BYTES% bytes
echo Папка с диагностикой: %OUT_DIR%
echo Полное дерево путей: WORKTREE_TREE.md (внутри diff.zip)
rem PowerShell already required for archiving; Write-Host highlights the handoff artifact on Windows.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Host ('Архив для отправки: ' + $env:LATEST_ARCHIVE) -ForegroundColor Green"
if "%CHECK_RESULT%"=="0" (
    echo git diff --check: PASS
) else (
    if "%CHECK_WHITESPACE%"=="1" (
        echo [WARN] git diff --check: обнаружены пробелы или другие whitespace-ошибки:
        powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content -LiteralPath (Join-Path $env:OUT_DIR 'diff-check.txt') -TotalCount 10 | ForEach-Object { Write-Host ('  ' + $_) }"
        echo [INFO] Все замечания: "%OUT_DIR%\diff-check.txt"
    )
    if "%CHECK_COMMAND_ERROR%"=="1" echo [WARN] Один из вызовов git diff --check завершился ошибкой.
)
for %%W in ("%GIT_WARNINGS%") do if %%~zW GTR 0 echo [WARN] Git warnings: "%GIT_WARNINGS%"
echo.
echo Перед отправкой diff.zip проверьте его на секреты и приватные данные.
echo [INFO] Индекс содержит имена путей, включая приватные и generated каталоги; корневой .git исключен.
echo Реальный Git index не изменялся.
exit /b 0

:git_fail
set "RESULT=%ERRORLEVEL%"
if "%RESULT%"=="0" set "RESULT=1"
echo [ERROR] Git-команда завершилась с кодом %RESULT%.
echo [INFO] Частичные диагностические файлы сохранены в "%OUT_DIR%".
exit /b %RESULT%

:confirm_overwrite
rem Empty Enter keeps the default Y; only an explicit N cancels.
set "OVERWRITE_REPLY=Y"
set /p "OVERWRITE_REPLY=Перезаписать предыдущий diff.zip? [Y/n]: "
if /i "%OVERWRITE_REPLY%"=="Y" exit /b 0
if /i "%OVERWRITE_REPLY%"=="N" exit /b 1
echo [WARN] Введите Y или N. Enter = Y.
goto :confirm_overwrite
