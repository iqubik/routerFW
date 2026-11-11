@echo off
rem file: tester.bat v1.2
rem Автопроверка CLI _Builder.bat.
rem
rem Запуск без аргументов = все тесты.
rem Запуск с аргументами = только тесты с указанными метками.
rem Метки, содержащие пробелы, необходимо заключать в кавычки.
rem Пример: tester.bat "Localization Keys" help
rem
rem Доступные метки:
rem --- CLI (Коды выхода 0) ---
rem help, -h, --help, state, s, ib help, src help, image help, source help,
rem --lang=EN help, --lang=RU help, -l EN help, -l RU help, HELP
rem
rem --- CLI (Коды выхода 1) ---
rem build (no id), build spaces, build 999999, build no_such,
rem edit 999999, edit spaces, unknown -> profile not found,
rem --state -> profile not found, --lang=XX help, --lang help, -l help,
rem positional 999999, BUILD no id
rem
rem --- Health Checks (Проверки здоровья) ---
rem Localization Keys
rem BOM Signature
rem Shell CALL Arguments
rem

setlocal enabledelayedexpansion
cd /d "%~dp0"

set "BAT=_Builder.bat"
set "PASS=0"
set "FAIL=0"
set "ROUTERFW_NO_CLS=1"
set "ROUTERFW_TEST_MODE=1"
set "LOG=%~dp0tester_log_win.md"
set "TEMP_OUT=%~dp0tester_tmp_win_out.txt"
set "TASK_DIR=%TEMP%\routerfw-tester-bat-%RANDOM%-%RANDOM%"
mkdir "%TASK_DIR%" >nul 2>&1
set "TESTER_JOBS=%ROUTERFW_TEST_JOBS%"
if not defined TESTER_JOBS set "TESTER_JOBS=%NUMBER_OF_PROCESSORS%"
if not defined TESTER_JOBS set "TESTER_JOBS=4"
for /f "delims=0123456789" %%A in ("%TESTER_JOBS%") do set "TESTER_JOBS=4"
if %TESTER_JOBS% LSS 1 set "TESTER_JOBS=1"
if %TESTER_JOBS% GTR 8 set "TESTER_JOBS=8"
set "TASK_COUNT=0"
set "TASK_ACTIVE=0"
set "TASK_SEQ=0"

echo # tester.bat run %date% %time% > "%LOG%"
echo. >> "%LOG%"
echo Parallel jobs: %TESTER_JOBS% >> "%LOG%"

set "TEST_ARGS="
if not "%~1"=="" (
  set "TEST_ARGS=%*"
  echo Running filtered tests: %*
  echo.
)

set "TEE_LINE=" & call :tee
set "TEE_LINE=== routerFW Windows test suite ==="
call :tee
set "TEE_LINE=" & call :tee

rem --- Ожидание: exit 0 ---
call :run 0 "help" help
call :run 0 "-h" -h
call :run 0 "--help" --help
call :run 0 "state" state
call :run 0 "s" s
call :run 0 "ib help" ib help
call :run 0 "src help" src help
call :run 0 "image help" image help
call :run 0 "source help" source help
call :run 0 "--lang=EN help" --lang=EN help
call :run 0 "--lang=RU help" --lang=RU help
call :run 0 "-l EN help" -l EN help
call :run 0 "-l RU help" -l RU help
call :run 0 "--runtime=auto help" --runtime=auto help
call :run 0 "--runtime=docker help" --runtime=docker help
call :run 0 "--runtime=podman help" --runtime=podman help

rem --- Ожидание: exit 1 ---
call :run 1 "build (no id)" build
call :run 1 "build spaces" build "   "
call :run 1 "build 999999" build 999999
call :run 1 "build no_such" build no_such_profile_xyz
call :run 1 "edit 999999" edit 999999
call :run 1 "edit spaces" edit "   "
call :run 1 "unknown -> profile not found" unknown_cmd_xyz
call :run 1 "--state -> profile not found" --state
call :run 1 "--lang=XX help" --lang=XX help
call :run 1 "--lang help" --lang help
call :run 1 "-l help" -l help
call :run 1 "--runtime=bad help" --runtime=bad help
call :run 1 "--runtime help" --runtime help
call :run 1 "-r help" -r help
call :run 1 "positional 999999" 999999
call :run 1 "build path traversal" build ..\evil
call :run 1 "src menuconfig no id" src menuconfig
call :run 1 "ib menuconfig 1" ib menuconfig 1

rem --- Регистр ---
call :run 0 "HELP" HELP
call :run 1 "BUILD no id" BUILD
call :run_env 0 "build forced 0" 0
call :run_env 1 "build forced 1" 1
call :run_env 42 "build forced 42" 42
call :run_env 0 "build-all forced 0" 0 build-all
call :run_env 1 "build-all forced 1" 1 build-all

rem ========== НЕ ТЕСТИРУЕМ (раскомментировать для полного прогона) ==========
rem --- реальные сборки: долгие процессы, проверять вручную; N = существующий профиль ---
rem call :run 0 "build N" build 1
rem call :run 0 "b N" b 1
rem call :run 0 "build name" build myprofile
rem call :run 0 "build-all" build-all
rem call :run 0 "all" all
rem call :run 0 "a" a
rem call :run 0 "ib build N" ib build 1
rem call :run 0 "src build N" src build 1
rem call :run 0 "positional N" 1
rem --- menuconfig: требует id, в SOURCE открывает mc; в IB даёт SOURCE only ---
rem call :run 1 "menuconfig (no id)" menuconfig
rem call :run 1 "menuconfig 999999" menuconfig 999999
rem call :run 1 "ib menuconfig 1 (SOURCE only)" ib menuconfig 1
rem --- import: то же; wizard и clean — интерактивны или меняют систему ---
rem call :run 1 "import (no id)" import
rem call :run 1 "ib import 1 (SOURCE only)" ib import 1
rem --- wizard / profile wizard (запуск create_profile) ---
rem call :run 0 "wizard" wizard
rem call :run 0 "w" w
rem --- clean: очистка меняет кэши/контейнеры; global prune отключён ---
rem call :run 1 "clean 0 1" clean 0 1
rem call :run 1 "clean 7 1 (IMAGE)" clean 7 1
rem call :run 1 "clean 09 1" clean 09 1
rem call :run 1 "clean 4 1 (IMAGE, 4 only SOURCE)" clean 4 1
rem clean без аргументов → интерактивное меню (не проверяем автоматически)
rem clean 9 → global prune disabled (not executed)
rem clean 1 N, clean 2 N ... → реальная очистка (не проверяем)

rem --- Project Health Checks ---
call :wait_all
set "TEE_LINE=" & call :tee
set "TEE_LINE=== Project Health Checks ==="
call :tee
set "TEE_LINE=" & call :tee

rem ВНИМАНИЕ: Ниже исправленные регулярки (одна ^ вместо двух ^^) и полные имена команд PS
call :run_ps 0 "Localization Keys" "$ProgressPreference='SilentlyContinue'; if ( (Compare-Object (gc system/lang/ru.env | Where-Object { $_ -match '^(L_|H_)' } | ForEach-Object { if ($_ -match '^([^=]+)=') { $Matches[1] } }) (gc system/lang/en.env | Where-Object { $_ -match '^(L_|H_)' } | ForEach-Object { if ($_ -match '^([^=]+)=') { $Matches[1] } })).Length -eq 0) { exit 0 } else { exit 1 }"
call :run_ps 0 "BOM Signature" "$BOM_EXPECTED = @('system/create_profile.ps1', 'system/import_ipk.ps1'); $NO_BOM_EXPECTED = @('_Builder.sh', 'system/lang/ru.env', 'README.md'); $errors = 0; function Test-BOM($path) { $bytes = gc $path -Enc Byte -Total 3; return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF); }; foreach ($f in $BOM_EXPECTED) { if (-not (Test-BOM $f)) { Write-Error ('BOM missing in ' + $f); $errors++; } }; foreach ($f in $NO_BOM_EXPECTED) { if (Test-BOM $f) { Write-Error ('Unexpected BOM in ' + $f); $errors++; } }; exit $errors"
call :run_ps 0 "Source Tree Packager" "$ErrorActionPreference='Stop'; $found=$false; if(Get-Command py -ErrorAction SilentlyContinue){ & py -3 -c 'import sys; sys.exit(sys.version_info < (3,10))' 2>$null; if($LASTEXITCODE -eq 0){ & py -3 -m unittest discover -s tests -p test_*.py -q; exit $LASTEXITCODE } }; foreach($exe in @('python','python3')){ if(Get-Command $exe -ErrorAction SilentlyContinue){ & $exe -c 'import sys; sys.exit(sys.version_info < (3,10))' 2>$null; if($LASTEXITCODE -eq 0){ & $exe -m unittest discover -s tests -p test_*.py -q; exit $LASTEXITCODE } } }; if($env:CI){throw 'CI requires Python 3.10+ for source exporter regressions'}; Write-Host '[SKIP] Optional Python 3.10+ unavailable; source packaging tests not run'; exit 0"
rem Real CALL sites and routing, with container execution replaced by the compose capture hook.
call :run_ps 0 "Shell CALL Arguments" "$ErrorActionPreference='Stop'; $repo=(Get-Location).Path; $q=[char]34; $builder=[IO.File]::ReadAllText((Join-Path $repo '_Builder.bat')); $routing=[regex]::Match($builder,'(?ms)^:RUN_COMPOSE\r?\n.*?(?=^:SET_COMPOSE_FILE_ARGS\r?$)').Value; if(-not $routing){throw 'Compose routing not found'}; $cases=@(); foreach($file in (git ls-files -- '*.bat')){if($file -like '_unpacker*'){continue}; $n=0; foreach($line in [IO.File]::ReadAllLines((Join-Path $repo $file))){$n++; if($line -match '(?i)^\s*(rem\b|::)'){continue}; if($line -match '(?i)\bcall\s+:RUN_COMPOSE\b.*?/bin/(?:bash|sh)\s+-c\s+\x22(.*)\x22\s*$'){$cases+=@{Site=$file+':'+$n; Line=$line; Shell=$Matches[1]}}}}; if(-not $cases.Count){throw 'No inline shell CALL sites found'}; $root=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()); $tmp=Join-Path $root ('routerfw-shell-test-'+[guid]::NewGuid().ToString('N')); [void](New-Item -ItemType Directory -Path $tmp); try{$count=0; foreach($case in $cases){foreach($runtime in @('docker','podman')){foreach($plugin in @('0','1')){$log=Join-Path $tmp 'compose.log'; $script=Join-Path $tmp 'test.bat'; Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue; $vars=@('PROFILE_ID=sample','PROJ_NAME=srcbuild_sample','SERVICE_NAME=builder-src-openwrt','COMPOSE_BASE_FILE=system/docker-compose-src.yaml',('CONTAINER_EXE='+$runtime),('COMPOSE_EXE='+$runtime+'-compose'),('COMPOSE_IS_PLUGIN='+$plugin),('ROUTERFW_TEST_COMPOSE_LOG='+$log)); $prefix=@('@echo off','setlocal EnableDelayedExpansion')+@($vars | ForEach-Object {'set '+$q+$_+$q}); $body=($prefix+@($case.Line,'exit /b',$routing)) -join [Environment]::NewLine; [IO.File]::WriteAllText($script,$body,[Text.UTF8Encoding]::new($false)); & $env:ComSpec /d /c ($q+$script+$q); if($LASTEXITCODE -ne 0){throw ('CALL failed: '+$case.Site)}; $actual=[IO.File]::ReadAllText($log).TrimEnd([char]13,[char]10); if($actual -notmatch '/bin/(?:bash|sh) -c \x22(.*)\x22$'){throw ('Shell command lost: '+$case.Site)}; $actualShell=$Matches[1]; $expected=$case.Shell -replace '\x25+',[string][char]37; if($actualShell -cne $expected){throw ('Shell command corrupted: '+$case.Site+' ('+$runtime+', plugin='+$plugin+')'+[Environment]::NewLine+'Expected: '+$expected+[Environment]::NewLine+'Actual: '+$actualShell)}; $count++}}}; Write-Host ('Shell CALL arguments: '+$count+' checks passed across '+$cases.Count+' call sites.')}finally{if(-not ([IO.Path]::GetFullPath($tmp)).StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'Test cleanup path escaped the temporary directory'}; Remove-Item -LiteralPath $tmp -Recurse -Force}"
call :run_ps 0 "Version Sync" "$ver=((Get-Content system/version.env | Where-Object { $_ -match '^ROUTERFW_VERSION=' }) -replace '^ROUTERFW_VERSION=','').Trim(); $checks = @((Select-String -Path _Builder.sh -SimpleMatch ('VER_NUM=' + [char]34 + $ver + [char]34)), (Select-String -Path _Builder.bat -SimpleMatch ('set ' + [char]34 + 'VER_NUM=' + $ver + [char]34)), (Select-String -Path README.md -SimpleMatch ('v' + $ver + '+')), (Select-String -Path README.en.md -SimpleMatch ('v' + $ver + '+')), (Select-String -Path docs\\ARCHITECTURE_en.md -SimpleMatch ('Version: ' + $ver + '.')), (Select-String -Path docs\\ARCHITECTURE_ru.md -SimpleMatch ('Версия: ' + $ver + '.'))); if(($checks | Where-Object { $_ }).Count -eq 6){exit 0}else{exit 1}"
call :run_ps 0 "No Global Docker Prune" "$paths = @('_Builder.sh','_Builder.bat','tester.sh','tester.bat') + (Get-ChildItem system -Filter *.sh | ForEach-Object FullName) + (Get-ChildItem system -Filter *.ps1 | ForEach-Object FullName); $pattern = ('(docker(\.exe)?|podman) (network|volume|system) pr' + 'une|run_container .* (network|volume|system) pr' + 'une|\$C_EXE .*system pr' + 'une|%%CONTAINER_EXE%% system pr' + 'une'); $matches = Select-String -Path $paths -Pattern $pattern; if($matches){$matches | ForEach-Object { $_.Path + ': ' + $_.Line }; exit 1} else {exit 0}"
call :run_ps 0 "Runtime Env Override" "$out = cmd /v:on /c 'set ROUTERFW_RUNTIME=podman&& call _Builder.bat help' 2>&1; if(($out -join [Environment]::NewLine) -match 'podman \(TEST MODE\)'){exit 0}else{exit 1}"
call :run_ps 0 "Runtime Explicit Failure" "$tmp = Join-Path $env:TEMP ('routerfw-test-' + [guid]::NewGuid()); New-Item -ItemType Directory -Path $tmp | Out-Null; try { @('@echo off','exit /b 1') | Set-Content -LiteralPath (Join-Path $tmp 'docker.cmd') -Encoding Ascii; $cmd = 'set ROUTERFW_TEST_MODE=&& set PATH=' + $tmp + ';%PATH%&& call _Builder.bat --runtime=docker help >nul 2>&1'; cmd /v:on /c $cmd; if($LASTEXITCODE -eq 1){exit 0}else{exit 1} } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }"
call :run_ps 0 "Compose Wrapper Docker" "$log = Join-Path $env:TEMP ('routerfw-compose-' + [guid]::NewGuid() + '.log'); try { $cmd = 'set ROUTERFW_TEST_MODE=1&& set ROUTERFW_NO_CLS=1&& set ROUTERFW_TEST_COMPOSE_BASE=system/docker-compose.yaml&& set ROUTERFW_TEST_COMPOSE_ARGS=-p audit up builder-openwrt&& set ROUTERFW_TEST_COMPOSE_LOG=' + $log + '&& call _Builder.bat help >nul 2>&1'; cmd /v:on /c $cmd; if($LASTEXITCODE -ne 0){exit 1}; $line = Get-Content -LiteralPath $log -ErrorAction Stop | Select-Object -First 1; if(($line -match '^docker compose -f system/docker-compose\.yaml -p audit up builder-openwrt$') -and ($line -notmatch 'docker-compose\.yaml .*docker-compose\.yaml')){exit 0}else{exit 1} } finally { Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue }"
call :run_ps 0 "Compose Wrapper Podman" "$log = Join-Path $env:TEMP ('routerfw-compose-' + [guid]::NewGuid() + '.log'); try { $cmd = 'set ROUTERFW_TEST_MODE=1&& set ROUTERFW_NO_CLS=1&& set ROUTERFW_RUNTIME=podman&& set ROUTERFW_TEST_COMPOSE_BASE=system/docker-compose.yaml&& set ROUTERFW_TEST_COMPOSE_ARGS=-p audit up builder-openwrt&& set ROUTERFW_TEST_COMPOSE_LOG=' + $log + '&& call _Builder.bat help >nul 2>&1'; cmd /v:on /c $cmd; if($LASTEXITCODE -ne 0){exit 1}; $line = Get-Content -LiteralPath $log -ErrorAction Stop | Select-Object -First 1; if(($line -match '^podman-compose -f system/docker-compose\.yaml -f system/podman-compose\.yaml -p audit up builder-openwrt$') -and ($line -notmatch 'docker-compose\.yaml .*docker-compose\.yaml')){exit 0}else{exit 1} } finally { Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue }"
call :run_ps 0 "Compose Wrapper Docker Standalone" "$log = Join-Path $env:TEMP ('routerfw-compose-' + [guid]::NewGuid() + '.log'); try { $cmd = 'set ROUTERFW_TEST_MODE=1&& set ROUTERFW_NO_CLS=1&& set ROUTERFW_TEST_COMPOSE_PROVIDER=standalone&& set ROUTERFW_TEST_COMPOSE_BASE=system/docker-compose.yaml&& set ROUTERFW_TEST_COMPOSE_ARGS=-p audit up builder-openwrt&& set ROUTERFW_TEST_COMPOSE_LOG=' + $log + '&& call _Builder.bat help >nul 2>&1'; cmd /v:on /c $cmd; if($LASTEXITCODE -ne 0){exit 1}; $line = Get-Content -LiteralPath $log -ErrorAction Stop | Select-Object -First 1; if($line -match '^docker-compose -f system/docker-compose\.yaml -p audit up builder-openwrt$'){exit 0}else{exit 1} } finally { Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue }"
call :run_ps 0 "Compose Wrapper Podman Standalone" "$log = Join-Path $env:TEMP ('routerfw-compose-' + [guid]::NewGuid() + '.log'); try { $cmd = 'set ROUTERFW_TEST_MODE=1&& set ROUTERFW_NO_CLS=1&& set ROUTERFW_RUNTIME=podman&& set ROUTERFW_TEST_COMPOSE_PROVIDER=standalone&& set ROUTERFW_TEST_COMPOSE_BASE=system/docker-compose.yaml&& set ROUTERFW_TEST_COMPOSE_ARGS=-p audit up builder-openwrt&& set ROUTERFW_TEST_COMPOSE_LOG=' + $log + '&& call _Builder.bat help >nul 2>&1'; cmd /v:on /c $cmd; if($LASTEXITCODE -ne 0){exit 1}; $line = Get-Content -LiteralPath $log -ErrorAction Stop | Select-Object -First 1; if($line -match '^podman-compose -f system/docker-compose\.yaml -f system/podman-compose\.yaml -p audit up builder-openwrt$'){exit 0}else{exit 1} } finally { Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue }"
call :run_ps 0 "Build Window Title" "$text = Get-Content -LiteralPath '_Builder.bat' -Raw; if($text -match 'title RouterFW Builder v%VER_NUM%' -and $text -match 'set ""CHILD_WINDOW_TITLE=%WINDOW_TITLE%""' -and $text -match 'if defined CHILD_WINDOW_TITLE title !CHILD_WINDOW_TITLE!'){exit 0}else{exit 1}"
call :run_ps 0 "Worktree Diff Helper Diagnostics" "$ErrorActionPreference='Stop'; $t=Get-Content -LiteralPath 'capture_worktree_diff.bat' -Raw; if($t -notmatch 'Write-Host .*?-ForegroundColor Green'){throw 'Green artifact path output missing'}; if($t -notmatch 'Get-Content -LiteralPath .*?diff-check\.txt.*?-TotalCount 10'){throw 'Whitespace diagnostics preview missing'}; if($t -notmatch 'CHECK_COMMAND_ERROR'){throw 'Git command errors must remain visible'}; exit 0"
call :run_ps 0 "Worktree Diff Helper ZIP Extension" "$ErrorActionPreference='Stop'; $helper=Get-Content -LiteralPath 'capture_worktree_diff.bat' -Raw; foreach($eol in @([string][char]10,([string][char]13+[char]10))){$fixture=($helper -replace '\r?\n',$eol); $m=[regex]::Match($fixture,'(?im)^\s*set \x22TEMP_ARCHIVE=(?<path>[^\x22\r\n]+)\x22\r?$'); if(-not $m.Success){throw 'TEMP_ARCHIVE setting not found'}; if([IO.Path]::GetExtension($m.Groups['path'].Value) -ne '.zip'){throw 'TEMP_ARCHIVE must end in .zip'}}; if($helper -notmatch '(?is)Compress-Archive.*?-DestinationPath\s+\$env:TEMP_ARCHIVE'){throw 'Compress-Archive destination mismatch'}; git check-ignore -q diff.new.zip; if($LASTEXITCODE -ne 0){throw 'diff.new.zip is not ignored'}; $tmp=Join-Path $env:TEMP ('routerfw-diff-zip-test-'+[guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $tmp | Out-Null; try{$src=Join-Path $tmp 'probe.txt'; [IO.File]::WriteAllText($src,'routerFW'); $dst=Join-Path $tmp 'probe.new.zip'; Compress-Archive -LiteralPath $src -DestinationPath $dst -CompressionLevel Optimal -Force; if(-not(Test-Path -LiteralPath $dst)){throw 'Compress-Archive ZIP smoke failed'}} finally{Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue}; exit 0"
call :run_ps 0 "Worktree Diff Default Yes" "$t=Get-Content -LiteralPath 'capture_worktree_diff.bat' -Raw; if($t -notmatch '(?m)^    call :confirm_overwrite\r?$'){throw 'Prompt subroutine is not called'}; if($t -notmatch '(?ms)^:confirm_overwrite\r?\nrem .*?\r?\nset .OVERWRITE_REPLY=Y.\r?\nset /p .OVERWRITE_REPLY=.*?\[Y/n\]: '){throw 'Enter must default to Yes'}; if($t -notmatch '(?m)^if /i .*==.Y. exit /b 0\r?$'){throw 'Yes must continue'}; if($t -notmatch '(?m)^if /i .*==.N. exit /b 1\r?$'){throw 'No must cancel'}; exit 0"
set "TEE_LINE=" & call :tee
set "TEE_LINE=== Итого: !PASS! OK, !FAIL! FAIL ==="
call :tee
set "TEE_LINE=" & call :tee
if exist "%TEMP_OUT%" del "%TEMP_OUT%"
if exist "%TASK_DIR%" rd /s /q "%TASK_DIR%" >nul 2>&1
if not "%FAIL%"=="0" exit /b 1
exit /b 0

:run
set "EXPECT=%~1"
set "LABEL=%~2"
if defined TEST_ARGS (
  set "SHOULD_RUN=0"
  set "LABEL_NO_QUOTES=!LABEL:"=!"
  for %%T in (!TEST_ARGS!) do (
    set "CLEAN_T=%%~T"
    if /i "!CLEAN_T!"=="!LABEL_NO_QUOTES!" set "SHOULD_RUN=1"
  )
  if "!SHOULD_RUN!"=="0" exit /b 0
)
call :enqueue_run "%EXPECT%" "%LABEL%" %~3 %~4 %~5 %~6 %~7 %~8 %~9
exit /b 0

:run_ps
set "EXPECT=%~1"
set "LABEL=%~2"
call :wait_all
if defined TEST_ARGS (
  set "SHOULD_RUN=0"
  set "LABEL_NO_QUOTES=!LABEL:"=!"
  for %%T in (!TEST_ARGS!) do (
    set "CLEAN_T=%%~T"
    if /i "!CLEAN_T!"=="!LABEL_NO_QUOTES!" set "SHOULD_RUN=1"
  )
  if "!SHOULD_RUN!"=="0" exit /b 0
)
set "CMD=%~3"
set "TEE_LINE=" & call :tee
rem УБРАЛИ !CMD! ИЗ ВЫВОДА
set "TEE_LINE=--- Check: !LABEL! ---" & call :tee
powershell -Command "%~3" > "%TEMP_OUT%" 2>&1
set "GOT=!errorlevel!"
type "%TEMP_OUT%"
type "%TEMP_OUT%" >> "%LOG%"
set "TEE_LINE=" & call :tee
if "!EXPECT!"=="!GOT!" (
  set "TEE_LINE=[OK] !LABEL!" & call :tee
  set /a PASS+=1
) else (
  set "LABEL_ECHO=!LABEL:>=^>!"
  set "LABEL_ECHO=!LABEL_ECHO:<=^<!"
  set "TEE_LINE=[FAIL] !LABEL_ECHO! ^(expected exit !EXPECT!, got !GOT!^)" & call :tee
  set /a FAIL+=1
)
exit /b 0

:run_env
set "EXPECT=%~1"
set "LABEL=%~2"
set "FORCED_STATUS=%~3"
set "RUN_CMD=%~4"
if not defined RUN_CMD set "RUN_CMD=build 1"
if defined TEST_ARGS (
  set "SHOULD_RUN=0"
  set "LABEL_NO_QUOTES=!LABEL:"=!"
  for %%T in (!TEST_ARGS!) do (
    set "CLEAN_T=%%~T"
    if /i "!CLEAN_T!"=="!LABEL_NO_QUOTES!" set "SHOULD_RUN=1"
  )
  if "!SHOULD_RUN!"=="0" exit /b 0
)
call :enqueue_env "%EXPECT%" "%LABEL%" "%FORCED_STATUS%" "!RUN_CMD!"
exit /b 0

:tee
if "!TEE_LINE!"=="" (echo. & echo. >> "%LOG%") else (echo !TEE_LINE! & echo !TEE_LINE! >> "%LOG%")
exit /b 0

:enqueue_run
if !TASK_ACTIVE! GEQ %TESTER_JOBS% call :wait_all
set /a TASK_COUNT+=1
set /a TASK_SEQ+=1
set /a TASK_ACTIVE+=1
set "TASK_EXPECT[!TASK_COUNT!]=%~1"
set "TASK_LABEL[!TASK_COUNT!]=%~2"
set "TASK_KIND[!TASK_COUNT!]=Test"
set "OUT_FILE=%TASK_DIR%\!TASK_SEQ!.out"
set "RC_FILE=%TASK_DIR%\!TASK_SEQ!.rc"
set "DONE_FILE=%TASK_DIR%\!TASK_SEQ!.done"
set "TASK_SCRIPT=%TASK_DIR%\!TASK_SEQ!.cmd"
set "TASK_OUT[!TASK_COUNT!]=!OUT_FILE!"
set "TASK_RC[!TASK_COUNT!]=!RC_FILE!"
set "TASK_DONE[!TASK_COUNT!]=!DONE_FILE!"
(
  echo @echo off
  echo setlocal
  echo cd /d "%~dp0"
  echo set "ROUTERFW_NO_CLS=1"
  echo set "ROUTERFW_TEST_MODE=1"
  echo call "%~dp0%BAT%" %~3 %~4 %~5 %~6 %~7 %~8 %~9 ^> "!OUT_FILE!" 2^>^&1
  echo set "GOT=%%ERRORLEVEL%%"
  echo ^> "!RC_FILE!" echo %%GOT%%
  echo ^> "!DONE_FILE!" echo done
) > "!TASK_SCRIPT!"
start "" /b "%ComSpec%" /c ""!TASK_SCRIPT!""
exit /b 0

:enqueue_env
if !TASK_ACTIVE! GEQ %TESTER_JOBS% call :wait_all
set /a TASK_COUNT+=1
set /a TASK_SEQ+=1
set /a TASK_ACTIVE+=1
set "TASK_EXPECT[!TASK_COUNT!]=%~1"
set "TASK_LABEL[!TASK_COUNT!]=%~2"
set "TASK_KIND[!TASK_COUNT!]=Test"
set "OUT_FILE=%TASK_DIR%\!TASK_SEQ!.out"
set "RC_FILE=%TASK_DIR%\!TASK_SEQ!.rc"
set "DONE_FILE=%TASK_DIR%\!TASK_SEQ!.done"
set "TASK_SCRIPT=%TASK_DIR%\!TASK_SEQ!.cmd"
set "TASK_OUT[!TASK_COUNT!]=!OUT_FILE!"
set "TASK_RC[!TASK_COUNT!]=!RC_FILE!"
set "TASK_DONE[!TASK_COUNT!]=!DONE_FILE!"
(
  echo @echo off
  echo setlocal
  echo cd /d "%~dp0"
  echo set "ROUTERFW_NO_CLS=1"
  echo set "ROUTERFW_TEST_MODE=1"
  echo set "ROUTERFW_TEST_BUILD_STATUS=%~3"
  echo call "%~dp0%BAT%" %~4 ^> "!OUT_FILE!" 2^>^&1
  echo set "GOT=%%ERRORLEVEL%%"
  echo ^> "!RC_FILE!" echo %%GOT%%
  echo ^> "!DONE_FILE!" echo done
) > "!TASK_SCRIPT!"
start "" /b "%ComSpec%" /c ""!TASK_SCRIPT!""
exit /b 0

:wait_all
if "%TASK_COUNT%"=="0" exit /b 0
:wait_loop
set "DONE_COUNT=0"
for /L %%I in (1,1,%TASK_COUNT%) do (
  if exist "!TASK_DONE[%%I]!" set /a DONE_COUNT+=1
)
if not "!DONE_COUNT!"=="%TASK_COUNT%" (
  >nul 2>&1 timeout /t 1 /nobreak
  goto wait_loop
)
for /L %%I in (1,1,%TASK_COUNT%) do (
  set "LABEL=!TASK_LABEL[%%I]!"
  set "EXPECT=!TASK_EXPECT[%%I]!"
  set "OUT=!TASK_OUT[%%I]!"
  set "RC=!TASK_RC[%%I]!"
  set "GOT=255"
  if exist "!RC!" set /p "GOT="<"!RC!"
  set "TEE_LINE=" & call :tee
  set "TEE_LINE=--- !TASK_KIND[%%I]!: !LABEL! ---" & call :tee
  if exist "!OUT!" type "!OUT!"
  if exist "!OUT!" type "!OUT!" >> "%LOG%"
  set "TEE_LINE=" & call :tee
  if "!EXPECT!"=="!GOT!" (
    set "TEE_LINE=[OK] !LABEL!" & call :tee
    set /a PASS+=1
  ) else (
    set "LABEL_ECHO=!LABEL:>=^>!"
    set "LABEL_ECHO=!LABEL_ECHO:<=^<!"
    set "TEE_LINE=[FAIL] !LABEL_ECHO! ^(expected exit !EXPECT!, got !GOT!^)" & call :tee
    set /a FAIL+=1
  )
)
for /L %%I in (1,1,%TASK_COUNT%) do (
  set "TASK_EXPECT[%%I]="
  set "TASK_LABEL[%%I]="
  set "TASK_KIND[%%I]="
  set "TASK_OUT[%%I]="
  set "TASK_RC[%%I]="
  set "TASK_DONE[%%I]="
)
set "TASK_COUNT=0"
set "TASK_ACTIVE=0"
exit /b 0
