# file: tests/test_source_post_build_bat.ps1
# Regression: execute the real _Builder.bat SOURCE_POST_BUILD subroutine in
# isolated CMD fixtures. No Docker, firmware build, or repository writes.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$builderPath = Join-Path $repo '_Builder.bat'
$builder = [IO.File]::ReadAllText($builderPath)
$blockMatch = [regex]::Match(
    $builder,
    '(?ms)^:SOURCE_POST_BUILD\r?\n.*?(?=^::[ \t]*={3,}|^:[A-Z_][A-Z0-9_]*[ \t]*\r?$|\z)'
)
if (-not $blockMatch.Success -or $blockMatch.Value -notmatch '(?m)^exit /b 0\r?$') {
    throw 'Cannot extract the production SOURCE_POST_BUILD subroutine'
}
$productionBlock = $blockMatch.Value.TrimEnd([char[]]@([char]13, [char]10))
$utf8 = New-Object System.Text.UTF8Encoding($false)
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("routerfw post-build 'fixture' " + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tempRoot)

function Write-TestFile {
    param([string]$Path, [string]$Text)
    $parent = Split-Path -Parent $Path
    [void][IO.Directory]::CreateDirectory($parent)
    [IO.File]::WriteAllText($Path, $Text, $script:utf8)
}

function New-ResultDirectory {
    param(
        [string]$Root,
        [string]$Name,
        [object]$Config,
        [bool]$HasArchive
    )
    $outputDir = Join-Path (Join-Path $Root 'firmware_output') $Name
    [void][IO.Directory]::CreateDirectory($outputDir)
    if ($null -ne $Config) {
        Write-TestFile (Join-Path $outputDir 'build.config') ($Config + "`r`n")
    }
    if ($HasArchive) {
        Write-TestFile (Join-Path (Join-Path $outputDir 'nested') 'openwrt-imagebuilder-test.tar.zst') 'archive fixture'
    }
}

$cases = @(
    @{ Name='fresh_decline'; Before=@('old'); Results=@(@{Name='old'; Config='CONFIG_IB=y'; Archive=$true}, @{Name='new'; Config='CONFIG_IB=y'; Archive=$true}); Snapshot=$true; Answer='n'; Offer=$true; Update=$false; Expected='firmware_output/new/nested/openwrt-imagebuilder-test.tar.zst' },
    @{ Name='old_only'; Before=@('old'); Results=@(@{Name='old'; Config='CONFIG_IB=y'; Archive=$true}); Snapshot=$true; Answer='n'; Offer=$false; Update=$false },
    @{ Name='new_not_ib'; Before=@('old'); Results=@(@{Name='old'; Config='CONFIG_IB=y'; Archive=$true}, @{Name='new'; Config='# CONFIG_IB is not set'; Archive=$true}); Snapshot=$true; Answer='n'; Offer=$false; Update=$false },
    @{ Name='new_no_config'; Before=@(); Results=@(@{Name='new'; Config=$null; Archive=$true}); Snapshot=$true; Answer='n'; Offer=$false; Update=$false },
    @{ Name='new_no_archive'; Before=@(); Results=@(@{Name='new'; Config='CONFIG_IB=y'; Archive=$false}); Snapshot=$true; Answer='n'; Offer=$false; Update=$false },
    @{ Name='ambiguous_new_directories'; Before=@('old'); Results=@(@{Name='old'; Config='CONFIG_IB=y'; Archive=$true}, @{Name='new1'; Config='CONFIG_IB=y'; Archive=$true}, @{Name='new2'; Config='CONFIG_IB=y'; Archive=$true}); Snapshot=$true; Answer='n'; Offer=$false; Update=$false },
    @{ Name='missing_snapshot'; Before=@(); Results=@(@{Name='new'; Config='CONFIG_IB=y'; Archive=$true}); Snapshot=$false; Answer='n'; Offer=$false; Update=$false },
    @{ Name='fresh_accept'; Before=@('old'); Results=@(@{Name='old'; Config='CONFIG_IB=y'; Archive=$true}, @{Name='new'; Config='CONFIG_IB=y'; Archive=$true}); Snapshot=$true; Answer='y'; Offer=$true; Update=$true; Expected='firmware_output/new/nested/openwrt-imagebuilder-test.tar.zst' }
)

$runnerHeader = @'
@echo off
setlocal EnableDelayedExpansion
set "HOST_OUTPUT_DIR=%CD%\firmware_output"
set "SOURCE_OUTPUT_SNAPSHOT=%CD%\before.txt"
set "L_IB_UPDATE_ASK=ROUTERFW_POSTBUILD_OFFER"
set "L_IB_UPDATE_PROMPT=Update ImageBuilder? "
set "L_IB_UPDATE_OK=ROUTERFW_POSTBUILD_UPDATED"
call :SOURCE_POST_BUILD "fixture.conf" "%HOST_OUTPUT_DIR%" "fixture" "%SOURCE_OUTPUT_SNAPSHOT%"
exit /b %errorlevel%
'@

try {
    foreach ($case in $cases) {
        $caseRoot = Join-Path $tempRoot $case.Name
        [void][IO.Directory]::CreateDirectory($caseRoot)
        [void][IO.Directory]::CreateDirectory((Join-Path $caseRoot 'firmware_output'))
        $profilePath = Join-Path (Join-Path $caseRoot 'profiles') 'fixture.conf'
        # Intentionally keep IMAGEBUILDER_URL last: the original BAT profile
        # insertion bug duplicated the tail of this file.
        $originalProfile = "# source profile fixture`r`nIMAGEBUILDER_URL=`"previous-url`"`r`n"
        Write-TestFile $profilePath $originalProfile
        $beforeBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($profilePath))

        foreach ($item in $case.Results) {
            New-ResultDirectory -Root $caseRoot -Name $item.Name -Config $item.Config -HasArchive $item.Archive
        }
        $snapshotPath = Join-Path $caseRoot 'before.txt'
        if ($case.Snapshot) {
            [IO.File]::WriteAllLines($snapshotPath, [string[]]$case.Before, $utf8)
        }
        Write-TestFile (Join-Path $caseRoot 'input.txt') ($case.Answer + "`r`n")
        Write-TestFile (Join-Path $caseRoot 'runner.cmd') ($runnerHeader + "`r`n" + $productionBlock + "`r`n")

        Push-Location -LiteralPath $caseRoot
        try {
            $output = (& $env:ComSpec /d /c 'call runner.cmd < input.txt' 2>&1 | Out-String)
            $result = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        if ($result -ne 0) {
            throw "[$($case.Name)] CMD returned $result`: $output"
        }
        $offered = $output.Contains('ROUTERFW_POSTBUILD_OFFER')
        $updated = $output.Contains('ROUTERFW_POSTBUILD_UPDATED')
        if ($offered -ne $case.Offer -or $updated -ne $case.Update) {
            throw "[$($case.Name)] offer=$offered (expected $($case.Offer)), update=$updated (expected $($case.Update)): $output"
        }
        if (Test-Path -LiteralPath $snapshotPath) {
            throw "[$($case.Name)] Source output snapshot was not cleaned up"
        }
        $actualProfile = [IO.File]::ReadAllText($profilePath)
        if ($case.Update) {
            $expectedLine = 'IMAGEBUILDER_URL="' + $case.Expected + '"'
            $lines = @($actualProfile -split '\r?\n' | Where-Object { $_ -ne '' })
            if (@($lines | Where-Object { $_ -ceq $expectedLine }).Count -ne 1 -or
                @($lines | Where-Object { $_ -ceq '#IMAGEBUILDER_URL="previous-url"' }).Count -ne 1 -or
                @($lines | Where-Object { $_ -ceq '# source profile fixture' }).Count -ne 1 -or
                $lines.Count -ne 3) {
                throw "[$($case.Name)] Incorrect profile update: $actualProfile"
            }
        } else {
            $afterBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($profilePath))
            if ($afterBytes -cne $beforeBytes) {
                throw "[$($case.Name)] Profile was unexpectedly modified"
            }
        }
        if ($case.Offer -and -not $output.Contains($case.Expected)) {
            throw "[$($case.Name)] Offered archive was not the new output: $output"
        }
        Write-Host "[OK] $($case.Name)"
    }
    Write-Host "Source post-build discovery: $($cases.Count) native CMD scenarios passed"
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
