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

- **Docker в Linux: `run` → `up` (как в .bat).**  
  В `_Builder.sh` сборка запускается через `docker compose up --build --force-recreate --remove-orphans` вместо `run --build --rm`. Имя контейнера теперь предсказуемое: `[project]_[service]_1`, совпадает с логикой очистки и с поведением Windows-версии.

- **Исключение `.docker_tmp/` из Git.**  
  В `.gitignore` добавлена папка `.docker_tmp/` (Docker runtime) — не попадает в репозиторий.

- **Зеркала ImmortalWrt в сборке и мастерах.**  
  В `hooks.sh` (Source Builder) для vermagic и манифестов используется список зеркал: PKU, SJTU, Official, KyaruCloud. Для ветки openwrt-24.10-6.6 хэш берётся только со страницы kmods, без подстановки snapshot-manifest. В `create_profile.ps1` и `create_profile.sh` при выборе ImmortalWrt доступны четыре источника загрузки IB: 1. PKU (по умолчанию), 2. SJTU, 3. Official, 4. KyaruCloud.

- **Чтение профиля в `_Builder.sh` без CRLF.**  
  При разборе `target_var` из профиля к значению применяется `tr -d '\r'`, чтобы под Windows/WSL не ломалась проверка Legacy/SRC_BRANCH.

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

- **Docker on Linux: `run` → `up` (same as .bat).**  
  `_Builder.sh` now uses `docker compose up --build --force-recreate --remove-orphans` instead of `run --build --rm`. Container names are predictable: `[project]_[service]_1`, matching cleanup logic and Windows behaviour.

- **`.docker_tmp/` ignored by Git.**  
  `.gitignore` now includes `.docker_tmp/` (Docker runtime) so it is not tracked.

- **ImmortalWrt mirrors in build and wizards.**  
  In `hooks.sh` (Source Builder), vermagic and manifest fetching use mirrors: PKU, SJTU, Official, KyaruCloud. For branch openwrt-24.10-6.6 the hash is taken only from the kmods page, without snapshot-manifest fallback. In `create_profile.ps1` and `create_profile.sh`, when choosing ImmortalWrt, four ImageBuilder sources are available: 1. PKU (default), 2. SJTU, 3. Official, 4. KyaruCloud.

- **Profile parsing in `_Builder.sh` without CRLF.**  
  When reading `target_var` from the profile, `tr -d '\r'` is applied so Legacy/SRC_BRANCH checks work correctly under Windows/WSL.

---

*Release notes for GitHub — user-oriented summary of changes since 4.41.*
