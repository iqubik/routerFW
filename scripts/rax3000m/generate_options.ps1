# PowerShell-скрипт для преобразования файла manual_config в формат переменной SRC_EXTRA_CONFIG

# --- НАСТРОЙКИ ---
# Имя исходного файла
$sourceFile = "manual_config"
# Имя конечного файла
$outputFile = "profile_options"
# --- КОНЕЦ НАСТРОЕК ---

# Получаем абсолютный путь к директории, где запущен скрипт
$scriptDir = $PSScriptRoot

# Формируем полные пути к файлам
$sourcePath = Join-Path $scriptDir $sourceFile
$outputPath = Join-Path $scriptDir $outputFile

# Проверяем, существует ли исходный файл
if (-not (Test-Path $sourcePath)) {
    Write-Error "Ошибка: Исходный файл '$sourcePath' не найден."
    exit 1
}

# Читаем строки из исходного файла, фильтруем комментарии и пустые строки
try {
    $filteredLines = Get-Content $sourcePath | Where-Object { $_ -notmatch '^\s*#.*$' -and $_ -notmatch '^\s*$' }
}
catch {
    Write-Error "Ошибка при чтении или фильтрации файла '$sourcePath'."
    exit 1
}

# Проверяем, остались ли строки после фильтрации
if ($filteredLines.Count -eq 0) {
    Write-Host "В исходном файле не найдено строк для обработки (все строки пустые или закомментированы)."
    # Создаем пустой файл с корректной пустой переменной
    Set-Content -Path $outputPath -Value 'SRC_EXTRA_CONFIG=""'
    exit 0
}

# Собираем все строки в одну. Каждая строка, кроме последней, будет с ' \' в конце.
$linesWithContinuation = for ($i = 0; $i -lt $filteredLines.Length; $i++) {
    if ($i -lt $filteredLines.Length - 1) {
        # Для всех строк, кроме последней, добавляем ' \'
        "    " + $filteredLines[$i] + " \"
    }
    else {
        # Для последней строки ' \' не добавляем
        "    " + $filteredLines[$i]
    }
}

# Формируем итоговое содержимое для файла
$finalContent = "SRC_EXTRA_CONFIG=`"`n" + ($linesWithContinuation -join "`n") + "`""

# Записываем результат в выходной файл
try {
    Set-Content -Path $outputPath -Value $finalContent -Encoding UTF8
    Write-Host "Файл '$outputFile' успешно создан."
    Write-Host "Всего обработано и записано: $($filteredLines.Count) строк."
}
catch {
    Write-Error "Не удалось записать данные в файл '$outputPath'."
    exit 1
}
