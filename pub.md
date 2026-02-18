# RouterFW — Релиз 4.43

**Версия:** 4.43  
**Период изменений:** 18 февраля 2026 (от 4.42)

---

## Русский

### Что нового

- **Единый формат языковых словарей (`ru.env` / `en.env`).**  
  Четыре платформозависимых файла (`.bat.env` + `.sh.env` на каждый язык) заменены двумя универсальными файлами с нейтральным псевдоформатом `{C_VAR}`. Плейсхолдеры `{C_VAL}`, `{C_ERR}`, `{C_LBL}` и др. подставляются ANSI-кодами при загрузке — каждым загрузчиком по-своему. Оба загрузчика переписаны:  
  — `_Builder.bat`: блок `for/f … tokens=1,* delims==` с семью строками замены `!_v:{C_*}=…!`.  
  — `_Builder.sh`: функция `load_lang()` на `while read` + `${val//\{C_*\}/$C_*}`.  
  Добавлен псевдоним цвета `C_OK` (= `C_VAL`, зелёный) в `_Builder.bat`. Около 15 ключей унифицированы (расхождения текста между платформами устранены). Форматирование `L_ST_*`, `L_INIT_ROOT`, `L_ANALYSIS` перенесено из словаря в код билдеров. Все платформо-специфичные ключи объединены в один файл.

- **Справочная шапка в словарях.**  
  В начале каждого `.env`-словаря размещена таблица цветов — описание всех плейсхолдеров, их цвет и назначение. Полностью в комментариях, загрузчиком игнорируется.

- **Конвенция заголовков файлов (`file-header.mdc`).**  
  Введено правило репозитория: каждый скрипт проекта должен начинаться с комментария `# file: относительный/путь` (или `rem file:` для `.bat`). Заголовки добавлены во все скрипты, в которых они отсутствовали: `scripts/hooks.sh`, `scripts/diag.sh`, `scripts/packager.sh`, `scripts/upgrade.sh`, `system/lang/ru.env`, `system/lang/en.env`.

- **`hooks.sh` v1.7 — зеркала ImmortalWrt для vermagic.**  
  Получение хэша ядра (vermagic hack, Source Builder) теперь работает по цепочке зеркал: PKU → SJTU → Official → KyaruCloud. Специальный случай для ветки `openwrt-24.10-6.6`: хэш берётся **только** со страницы kmods, snapshot-manifest не используется — устранена ошибка несовместимого хэша (кернел от другой сборки).

- **`create_profile.sh` / `create_profile.ps1` v2.30 — 4 источника для ImmortalWrt IB.**  
  При выборе прошивки ImmortalWrt мастер создания профиля предлагает 4 варианта загрузки Image Builder:  
  1. PKU (mirrors.pku.edu.cn) — по умолчанию  
  2. SJTU (mirrors.sjtug.sjtu.edu.cn)  
  3. Official (downloads.immortalwrt.org)  
  4. KyaruCloud (immortalwrt.kyarucloud.moe)

---

## English

### What's New

- **Unified language dictionary format (`ru.env` / `en.env`).**  
  Four platform-specific files (`.bat.env` + `.sh.env` per language) replaced by two universal files with a neutral `{C_VAR}` pseudo-format. Placeholders `{C_VAL}`, `{C_ERR}`, `{C_LBL}` etc. are expanded to ANSI codes at load time — each loader handles substitution independently. Both loaders rewritten:  
  — `_Builder.bat`: `for/f … tokens=1,* delims==` block with seven `!_v:{C_*}=…!` substitution lines.  
  — `_Builder.sh`: `load_lang()` function using `while read` + `${val//\{C_*\}/$C_*}`.  
  Color alias `C_OK` (= `C_VAL`, bright green) added to `_Builder.bat`. ~15 keys unified (cross-platform text divergences resolved). Formatting for `L_ST_*`, `L_INIT_ROOT`, `L_ANALYSIS` moved from dictionary into builder code. All platform-specific keys merged into a single file.

- **Color reference header in dictionaries.**  
  Each `.env` dictionary file now starts with a comment-block table listing all placeholders, their color name, and usage. Fully commented — ignored by both loaders.

- **File header convention (`file-header.mdc`).**  
  New repository rule: every project script must begin with a `# file: relative/path` comment (or `rem file:` for `.bat`). Headers added to all scripts missing them: `scripts/hooks.sh`, `scripts/diag.sh`, `scripts/packager.sh`, `scripts/upgrade.sh`, `system/lang/ru.env`, `system/lang/en.env`.

- **`hooks.sh` v1.7 — ImmortalWrt vermagic mirrors.**  
  Kernel hash retrieval (vermagic hack, Source Builder) now uses a mirror failover chain: PKU → SJTU → Official → KyaruCloud. Special case for the `openwrt-24.10-6.6` branch: hash is taken **only** from the kmods page — snapshot-manifest is skipped — eliminating the hash mismatch error caused by a different snapshot kernel.

- **`create_profile.sh` / `create_profile.ps1` v2.30 — 4 sources for ImmortalWrt IB.**  
  When selecting ImmortalWrt firmware, the profile creation wizard now offers 4 Image Builder download sources:  
  1. PKU (mirrors.pku.edu.cn) — default  
  2. SJTU (mirrors.sjtug.sjtu.edu.cn)  
  3. Official (downloads.immortalwrt.org)  
  4. KyaruCloud (immortalwrt.kyarucloud.moe)

---

*Release notes for GitHub — user-oriented summary of changes since 4.42.*
