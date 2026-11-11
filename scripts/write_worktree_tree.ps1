# file: scripts/write_worktree_tree.ps1
# Build a complete, PATHS-ONLY Markdown tree for capture_worktree_diff.bat.
# Includes ignored/generated/private names except root .git; never reads file payloads.
# Rejects inaccessible paths or excessive trees rather than presenting a partial index.
# PowerShell 5.1 compatible. Directory reparse points are listed but never followed.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Output,
    [ValidateRange(1, 10000000)][int]$MaxEntries = 500000
)

$ErrorActionPreference = 'Stop'
$writer = $null
$script:EntryCount = 0
$script:DirectoryCount = 0
$script:FileCount = 0
$script:LinkCount = 0

function Write-WorktreeDirectory {
    param([string]$Directory, [string]$Prefix)

    # Sort ordinally for reproducibility regardless of the machine locale.
    [string[]]$entries = @([System.IO.Directory]::GetFileSystemEntries($Directory))
    if ($Directory -eq $script:RootPath) {
        $entries = @($entries | Where-Object { [System.IO.Path]::GetFileName($_) -ne '.git' })
    }
    [Array]::Sort($entries, [System.StringComparer]::Ordinal)

    for ($i = 0; $i -lt $entries.Length; $i++) {
        $path = $entries[$i]
        $name = [System.IO.Path]::GetFileName($path)
        $attributes = [System.IO.File]::GetAttributes($path)
        $isDirectory = ($attributes -band [System.IO.FileAttributes]::Directory) -ne 0
        $isLink = ($attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0

        $script:EntryCount++
        if ($script:EntryCount -gt $MaxEntries) {
            throw "Слишком много путей (больше $MaxEntries). Полный индекс не сформирован."
        }
        if ($isDirectory) { $script:DirectoryCount++ } else { $script:FileCount++ }
        if ($isLink) { $script:LinkCount++ }

        $isLast = ($i -eq $entries.Length - 1)
        if ($isLast) {
            $branch = '└── '
            $nextPrefix = $Prefix + '    '
        } else {
            $branch = '├── '
            $nextPrefix = $Prefix + '│   '
        }
        $suffix = if ($isDirectory) { '/' } else { '' }
        if ($isLink) { $suffix += ' [link: not traversed]' }
        $writer.WriteLine($Prefix + $branch + $name + $suffix)

        # Never follow symlinks/junctions, including directory reparse points.
        if ($isDirectory -and -not $isLink) {
            Write-WorktreeDirectory -Directory $path -Prefix $nextPrefix
        }
    }
}

try {
    $resolvedRoot = [System.IO.Path]::GetFullPath($Root)
    if (-not [System.IO.Directory]::Exists($resolvedRoot)) {
        throw "Каталог проекта не найден: $resolvedRoot"
    }
    $script:RootPath = $resolvedRoot
    $resolvedOutput = [System.IO.Path]::GetFullPath($Output)
    $parent = [System.IO.Path]::GetDirectoryName($resolvedOutput)
    if (-not [System.IO.Directory]::Exists($parent)) {
        throw "Каталог для индекса не найден: $parent"
    }
    $writer = [System.IO.StreamWriter]::new($resolvedOutput, $false, [System.Text.UTF8Encoding]::new($false))
    $writer.WriteLine('# routerFW — полное дерево путей')
    $writer.WriteLine('')
    $writer.WriteLine('Только имена каталогов и файлов относительно корня routerFW, включая скрытые, Git-ignored и generated пути, кроме корневого .git.')
    $writer.WriteLine('Содержимое файлов не читается и не включается. Символические ссылки и junction показаны, но их цели не обходятся.')
    $writer.WriteLine('ВНИМАНИЕ: имена в приватных каталогах могут раскрывать информацию. Проверяйте индекс перед отправкой.')
    $writer.WriteLine('Обход не атомарен: дерево могло измениться во время формирования списка.')
    $writer.WriteLine('')
    $writer.WriteLine('```text')
    $writer.WriteLine('routerFW/')
    Write-WorktreeDirectory -Directory $resolvedRoot -Prefix ''
    $writer.WriteLine('```')
    $writer.WriteLine('')
    $writer.WriteLine(('Всего: {0} путей ({1} каталогов, {2} файлов, {3} ссылок).' -f $script:EntryCount, $script:DirectoryCount, $script:FileCount, $script:LinkCount))
    $writer.Flush()
} catch {
    if ($null -ne $writer) { $writer.Dispose(); $writer = $null }
    if ($null -ne $resolvedOutput -and [System.IO.File]::Exists($resolvedOutput)) {
        try { [System.IO.File]::Delete($resolvedOutput) } catch { }
    }
    [Console]::Error.WriteLine('[ERROR] WORKTREE_TREE.md: ' + $_.Exception.Message)
    exit 1
} finally {
    if ($null -ne $writer) { $writer.Dispose() }
}
