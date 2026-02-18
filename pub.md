# RouterFW — Релиз 4.42

**Версия:** 4.42  
**Период изменений:** 18 февраля 2026 (от 4.41)

---

## Русский

### Что нового

- **Автоматическая миграция профилей в `_Builder.sh`.**  
  Функция `migrate_profile_vars()` теперь реализована и в Linux-скрипте. При каждом запуске все `.conf`-файлы автоматически переименовывают `PKGS` → `IMAGE_PKGS` и `EXTRA_IMAGE_NAME` → `IMAGE_EXTRA_NAME`. Идемпотентна — уже мигрированные профили не трогаются.

- **Нормализация ввода меню в `_Builder.sh`.**  
  Все команды меню теперь принимаются в любом регистре: `choice="${choice^^}"` приводит ввод к верхнему регистру. Паттерны `[Mm]`/`[Ee]`/`[Aa]` и т.д. заменены на простые `M`/`E`/`A`.

- **Enter = Yes при выходе.**  
  Подтверждение выхода `(Y/N)` изменено на `(Y/n)` — пустой ввод (Enter) теперь означает согласие. Вместо восстановления курсора добавлена 3-секундная пауза перед завершением.

- **Улучшенный Docker Credentials Fix.**  
  Вместо пустой заглушки `{"auths":{}}` теперь копируется реальный `~/.docker/config.json` с удалением только `credsStore`/`credHelpers`. Сохраняются proxy-настройки и прочие параметры.

- **Полная локализация `_Builder.sh`.**  
  Все хардкодированные английские строки в анализаторе профилей, сепараторах, сообщениях об убийстве контейнеров, кнопках меню заменены на `L_*`-ключи словаря. Добавлены более 40 новых ключей в оба языка: `L_SEPARATOR`, `L_SEPARATOR_EQ`, `L_KILL_CONTAINER`, `L_KILL_ORPHAN`, `L_IN_EDITOR`, `L_BTN_MENUCONFIG`, `L_FOUND`, `L_MISSING`, `L_EMPTY`, `L_ST_*`, `L_IB_UPDATE_*`, `L_FINISHED`, `L_BUILD_FATAL` и другие.

- **Удалены устаревшие ключи.**  
  `L_CLEAN_RUN_MSG` и `L_K_MOVE_ARCH` удалены из обоих языков в обоих скриптах.

- **`L_IB_UPDATE_PROMPT` локализован в `_Builder.bat`.**  
  Строка "Update profile? [y/N]" в PowerShell-блоке пост-обработки теперь берётся из словаря через `!L_IB_UPDATE_PROMPT!`.

- **Шаблон профиля `create_profile.sh` выровнен.**  
  Переменные `PKGS` → `IMAGE_PKGS`, `#EXTRA_IMAGE_NAME` → `#IMAGE_EXTRA_NAME` в шаблоне. URL fantastic-packages исправлен: добавлен сегмент `/packages/` и динамическая переменная `$ARCH` вместо хардкода `mipsel_24kc`.

- **UTF-8 BOM добавлен в `create_profile.ps1`.**  
  Обязателен для корректного отображения кириллицы на Windows.

- **Новый `.dockerignore`.**  
  Исключает из Docker build context: `firmware_output/`, `custom_files/`, `custom_packages/`, `src_packages/`, `custom_patches/`, `profiles/`, `.git/`, `docs/`, `_unpacker.*`. Критически важно — `firmware_output/` может весить 10+ ГБ.

- **Расширены правила `.gitattributes`.**  
  Добавлены явные правила `eol=lf` для `*.sh`, `*.yml`, `*.json`, `*.mdc`, `.dockerignore`; `eol=crlf` для `*.md`; явное правило для `profiles/personal.flag`.

---

## English

### What's New

- **Automatic profile migration in `_Builder.sh`.**  
  `migrate_profile_vars()` is now implemented in the Linux script too. On every startup all `.conf` files are automatically updated: `PKGS` → `IMAGE_PKGS` and `EXTRA_IMAGE_NAME` → `IMAGE_EXTRA_NAME`. Idempotent — already migrated profiles are untouched.

- **Case-insensitive menu input in `_Builder.sh`.**  
  `choice="${choice^^}"` normalises input to uppercase. Patterns like `[Mm]`/`[Ee]`/`[Aa]` are replaced with simple `M`/`E`/`A`.

- **Enter = Yes on exit.**  
  Exit confirmation changed from `(Y/N)` to `(Y/n)` — pressing Enter now means Yes. Cursor restore replaced with a 3-second pause before exit.

- **Improved Docker Credentials Fix.**  
  Instead of a stub `{"auths":{}}`, the real `~/.docker/config.json` is now copied via `python3` with only `credsStore`/`credHelpers` stripped. Proxy settings and other configuration are preserved.

- **Full localisation of `_Builder.sh`.**  
  All hardcoded English strings in the profile analyzer, separators, container kill messages, and menu buttons have been replaced with `L_*` dictionary keys. 40+ new keys added to both languages: `L_SEPARATOR`, `L_SEPARATOR_EQ`, `L_KILL_CONTAINER`, `L_KILL_ORPHAN`, `L_IN_EDITOR`, `L_BTN_MENUCONFIG`, `L_FOUND`, `L_MISSING`, `L_EMPTY`, `L_ST_*`, `L_IB_UPDATE_*`, `L_FINISHED`, `L_BUILD_FATAL` and others.

- **Removed obsolete keys.**  
  `L_CLEAN_RUN_MSG` and `L_K_MOVE_ARCH` removed from both languages in both scripts.

- **`L_IB_UPDATE_PROMPT` localised in `_Builder.bat`.**  
  The "Update profile? [y/N]" prompt in the PowerShell post-build block now reads from the dictionary via `!L_IB_UPDATE_PROMPT!`.

- **`create_profile.sh` template aligned.**  
  Variables renamed: `PKGS` → `IMAGE_PKGS`, `#EXTRA_IMAGE_NAME` → `#IMAGE_EXTRA_NAME`. fantastic-packages URLs fixed: added `/packages/` path segment and dynamic `$ARCH` variable instead of hardcoded `mipsel_24kc`.

- **UTF-8 BOM added to `create_profile.ps1`.**  
  Required for correct Cyrillic rendering on Windows.

- **New `.dockerignore`.**  
  Excludes from Docker build context: `firmware_output/`, `custom_files/`, `custom_packages/`, `src_packages/`, `custom_patches/`, `profiles/`, `.git/`, `docs/`, `_unpacker.*`. Critical — `firmware_output/` can weigh 10+ GB.

- **Expanded `.gitattributes` rules.**  
  Explicit `eol=lf` rules added for `*.sh`, `*.yml`, `*.json`, `*.mdc`, `.dockerignore`; `eol=crlf` for `*.md`; explicit rule for `profiles/personal.flag`.

---

*Release notes for GitHub — user-oriented summary of changes since 4.41.*
