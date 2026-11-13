# file: system/profile_state.ps1
# Read-only, bat-state-only scanner: emits profile-id|arch|F P S M H X OI OS bits.
# One PowerShell invocation instead of O(profiles * checks) CMD subprocesses.
param([Parameter(Mandatory=$true)][string]$Root)
$ErrorActionPreference = 'Stop'
$clock = [Diagnostics.Stopwatch]::StartNew()
$profileEnabled = $env:ROUTERFW_STATE_PROFILE -eq '1'

function Get-AnyEntry([string]$path) {
    if (-not [IO.Directory]::Exists($path)) { return $false }
    try {
        # Match the existing BAT 'dir /a-d /b /s': directories alone do not count.
        $iterator = [IO.Directory]::EnumerateFiles($path, '*', [IO.SearchOption]::AllDirectories).GetEnumerator()
        try { return $iterator.MoveNext() } finally { $iterator.Dispose() }
    } catch [IO.IOException] { return $false } catch [UnauthorizedAccessException] { return $false }
}

$profilesDir = [IO.Path]::Combine($Root, 'profiles')
if (-not [IO.Directory]::Exists($profilesDir)) { throw "Missing profiles directory: $profilesDir" }
$profiles = [string[]][IO.Directory]::GetFiles($profilesDir, '*.conf')
[Array]::Sort($profiles, [StringComparer]::Ordinal)
foreach ($file in $profiles) {
    $rowStart = $clock.Elapsed.TotalMilliseconds
    $id = [IO.Path]::GetFileNameWithoutExtension($file)
    # Match _Builder.bat :IS_SAFE_PROFILE_TOKEN; invalid profiles are skipped
    # by the host during enumeration and must not shift its numbered rows.
    if ($id -notmatch '^[A-Za-z0-9._-]+$' -or $id.Contains('..')) { continue }
    $arch = '--------'
    foreach ($line in [IO.File]::ReadLines($file)) {
        if ($line.Contains('SRC_ARCH=')) {
            $quote = [regex]::Match($line, 'SRC_ARCH="([^"]*)"')
            if ($quote.Success) { $arch = $quote.Groups[1].Value.Trim() }
        }
    }
    $archMs = $clock.Elapsed.TotalMilliseconds
    # F/P/S/X: any *file* recursively; M/H: exact file; OI/OS: any file.
    $flagPaths = @('custom_files', 'custom_packages', 'src_packages')
    $bits = ''
    foreach ($prefix in $flagPaths) {
        $path = [IO.Path]::Combine($Root, $prefix, $id)
        $bits += $(if (Get-AnyEntry $path) { '1' } else { '0' })
    }
    $bits += $(if ([IO.File]::Exists([IO.Path]::Combine($Root,'firmware_output','sourcebuilder',$id,'manual_config'))) { '1' } else { '0' })
    $bits += $(if ([IO.File]::Exists([IO.Path]::Combine($Root,'custom_files',$id,'hooks.sh'))) { '1' } else { '0' })
    $bits += $(if (Get-AnyEntry ([IO.Path]::Combine($Root,'custom_patches',$id))) { '1' } else { '0' })
    $inputMs = $clock.Elapsed.TotalMilliseconds
    $bits += $(if (Get-AnyEntry ([IO.Path]::Combine($Root,'firmware_output','imagebuilder',$id))) { '1' } else { '0' })
    $bits += $(if (Get-AnyEntry ([IO.Path]::Combine($Root,'firmware_output','sourcebuilder',$id))) { '1' } else { '0' })
    $outputMs = $clock.Elapsed.TotalMilliseconds
    # Delimiter is safe: profile IDs never contain '|'; arch '|' is sanitized.
    $arch = $arch.Replace('|','/')
    [Console]::Out.WriteLine("$id|$arch|$bits")
    if ($profileEnabled) {
        [Console]::Error.WriteLine(('[STATE-PROFILE] {0} arch={1:N1}ms inputs={2:N1}ms outputs={3:N1}ms total={4:N1}ms' -f $id, ($archMs-$rowStart), ($inputMs-$archMs), ($outputMs-$inputMs), ($outputMs-$rowStart)))
    }
}
if ($profileEnabled) {
    [Console]::Error.WriteLine(('[STATE-PROFILE] scan-total={0:N1}ms profiles={1}' -f $clock.Elapsed.TotalMilliseconds, $profiles.Length))
}
# checksum:MD5=a8f2ac43164c8669d5685ddbb1483726