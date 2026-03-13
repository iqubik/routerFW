Проблема в PowerShell-версии заключается в нескольких моментах: некорректная склейка строк после Docker (массив превращается в строку без сохранения структуры), слишком жесткое регулярное выражение для YAML-блоков и отсутствие специфической логики добавления переносов строк после `default_postinst`, которая есть в Bash.

Вот точечные правки. Замени соответствующие блоки в твоем `system/import_ipk.ps1`.

### 1. Исправление получения вывода Docker (Блок 2a)

В PowerShell `Invoke-Expression` возвращает массив строк. Нам нужно гарантировать правильные переносы строк для работы регулярных выражений.

**На что заменить:**

```powershell
        try {
            # Используем оператор вызова и Out-String для сохранения структуры текста
            $adbdumpOutputString = & docker run --rm -v "${apkParentDir}:/data" alpine:latest apk adbdump "/data/$apkFileName" 2>$null | Out-String

            if ([string]::IsNullOrWhiteSpace($adbdumpOutputString)) { throw "Docker returned empty output." }

            # Извлечение основных полей
            $pkgName = if ($adbdumpOutputString -match '(?m)^\s*name:\s*(.*)$') { $matches[1].Trim() } else { "" }
            $pkgVersion = if ($adbdumpOutputString -match '(?m)^\s*version:\s*(.*)$') { $matches[1].Trim() } else { "" }
            $pkgArch = if ($adbdumpOutputString -match '(?m)^\s*arch:\s*(.*)$') { $matches[1].Trim() } else { "" }

            # Улучшенный Regex для зависимостей (между depends и любым следующим ключом без отступа)
            $depsMatch = [regex]::Match($adbdumpOutputString, '(?ms)^  depends:(.*?)(?=\n  [a-z]|$)')
            if ($depsMatch.Success) {
                $depsList = [regex]::Matches($depsMatch.Groups[1].Value, '-\s+(.*)') | ForEach-Object { $_.Groups[1].Value.Trim() }
            }

```

---

### 2. Исправление извлечения скриптов (Post-install / Pre-deinstall)

Здесь мы добавим более надежную очистку отступов (4 пробела), как это делает `awk` в Bash.

**На что заменить (внутри того же `if ($isApk)`):**

```powershell
            # Regex для скриптов (ищем блок после '|', до следующего ключа первого уровня отступа)
            $postinstMatch = [regex]::Match($adbdumpOutputString, '(?ms)^  post-install:\s*\|(.*?)(?=\n  [a-z]|$)')
            if ($postinstMatch.Success) {
                $rawPost = $postinstMatch.Groups[1].Value
                # Убираем именно 4 начальных пробела отступа
                $postinst = ($rawPost -split '\r?\n' | ForEach-Object { $_ -replace '^    ', '' }) -join "`n"
            }

            $prermMatch = [regex]::Match($adbdumpOutputString, '(?ms)^  pre-deinstall:\s*\|(.*?)(?=\n  [a-z]|$)')
            if ($prermMatch.Success) {
                $rawPre = $prermMatch.Groups[1].Value
                $prerm = ($rawPre -split '\r?\n' | ForEach-Object { $_ -replace '^    ', '' }) -join "`n"
            }
            Write-Host "    [+] Metadata extracted successfully via Docker." -ForegroundColor Green

```

---

### 3. Обработка управляющих скриптов и `default_postinst` (Блок 6)

Здесь нужно добавить те самые два переноса строки после `default_postinst` и корректно экранировать переменные.

**На что заменить:**

```powershell
    # 6. Обработка управляющих скриптов (Очистка и экранирование для Makefile)
    $processScript = {
        param($scriptText)
        if (-not $scriptText) { return "" }
        # 1. Удаляем шебанг
        $s = $scriptText -replace '(?m)^#!/.+$', ''
        # 2. Экранируем $ для Makefile ($ -> $$)
        $s = $s -replace '\$', '$$$$'
        # 3. Добавляем два переноса после default_postinst (как в Bash версии)
        $s = $s -replace '(default_postinst\s+\$\$0\s+\$\$@)', "`$1`n`n"
        return $s.Trim()
    }

    $cleanPostinst = &$processScript $postinst
    $cleanPrerm = &$processScript $prerm

```

---

### Почему это не работало:

1. **Склейка строк:** В старом коде `$adbdumpOutput -join "\n"` создавал строку, где вместо реальных переносов текста стоял символ `\n` (буквально), из-за чего многострочные регулярные выражения (`(?m)`) не находили начало строк `^`.
2. **Отступы:** В APK метаданных скрипты всегда идут с отступом в 4 пробела. Старый метод `Substring(4)` падал, если строка была короче 4 символов (например, пустая строка). Новый метод через `-replace '^    ', ''` безопаснее.
3. **default_postinst:** В Makefile OpenWrt скрипты часто склеиваются. Твоя Bash-версия специально раздвигала их через `\n\n`, а PS1-версия лепила всё в одну кучу, что могло ломать логику выполнения `sh`.

Попробуй применить эти блоки, и `fastfetch` должен импортироваться с полным `postinst`.

Хочешь, чтобы я проверил еще какой-то конкретный кусок логики, например, маппинг библиотек `openssl`?