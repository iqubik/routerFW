# Project audit — routerFW

**Language / Язык:** [🇷🇺 Русский](#аудит-проекта-routerfw) | [🇺🇸 English](#routerfw-project-audit)

---

## Аудит проекта routerFW

Документ описывает текущее состояние репозитория, архитектуру, соглашения и зоны внимания для разработки и сопровождения.

**Версия сборщика:** 4.43  
**Репозиторий:** https://github.com/iqubik/routerFW (ветка `main`)  
**Лицензия:** GPL-3.0  
**Автор:** iqubik  

---

## 1. Назначение проекта

**OpenWrtFW Builder** — кроссплатформенный фреймворк для сборки кастомной прошивки OpenWrt через Docker. Поддерживаются два режима:

| Режим | Оркестратор | Время | Назначение |
|-------|-------------|--------|------------|
| **Image Builder** | `system/ib_builder.sh` | 1–3 мин | Сборка из готового SDK: пакеты, оверлей, инъекция `.ipk` |
| **Source Builder** | `system/src_builder.sh` | 20–60 мин (холодный), 3–5 мин (с CCache) | Полная компиляция из исходников, патчи ядра, кастомные пакеты, Vermagic Hack |

Точки входа: `_Builder.bat` (Windows), `_Builder.sh` (Linux). Оба обеспечивают интерактивное меню, миграцию переменных профиля и паритет функциональности в рамках возможностей платформы.

---

## 2. Архитектура и структура каталогов

| Путь | Назначение |
|------|------------|
| `_Builder.sh` / `_Builder.bat` | Главное меню и оркестрация сборок |
| `system/` | Ядро: Dockerfile(s), docker-compose, `ib_builder.sh`, `src_builder.sh`, мастера профилей, локализация |
| `system/lang/` | Словари `ru.env`, `en.env` (единый псевдо-формат с плейсхолдерами `{C_*}`) |
| `profiles/*.conf` | Универсальные конфиги сборки (общие для Image и Source) |
| `custom_files/<profile>/` | Файловый оверлей → корень прошивки (приватный, в `.gitignore`) |
| `custom_packages/<profile>/` | Сторонние `.ipk` для Image Builder и импорта в Source (приватный) |
| `src_packages/<profile>/` | Исходники пакетов для Source Builder (приватный) |
| `custom_patches/<profile>/` | Патчи/зеркальный оверлей исходного кода (приватный) |
| `firmware_output/` | Готовые образы, логи, manual_config (в `.gitignore`) |
| `scripts/` | Утилиты: `hooks.sh`, `diag.sh`, `packager.sh`, `upgrade.sh` и др. |
| `docs/` | Руководства (RU/EN), уроки 1–5, архитектура, диаграммы |
| `dist/` | SVG-визуализации релизов (timeline, tree, heatmap, river, bars, stats) |
| `_packer.sh` / `_packer.bat` | Упаковка проекта в самораспаковывающийся дистрибутив |
| `_unpacker.sh` / `_unpacker.bat` | Самораспаковка (содержат большой base64-пейлоад — **не открывать в AI/редакторе**) |

Docker: Image Builder — `system/docker-compose.yaml`; Source Builder — `system/docker-compose-src.yaml`. Кэши (SDK, пакеты, ccache) вынесены в тома для ускорения повторных сборок.

---

## 3. Технологический стек

- **Скрипты:** Bash, Batch, PowerShell (.bat, .ps1, .sh).
- **Окружение сборки:** Docker, Docker Compose; базовые образы Ubuntu 18.04 (legacy) и 22.04/24.04 (modern).
- **Кэширование:** CCache (лимит 20 GB) для Source Builder; кэш SDK и пакетов для Image Builder.
- **Версионирование:** Git; большие бинарники (архивы, образы) — Git LFS (см. `.gitattributes`).

---

## 4. Конвенции и стандарты

### 4.1 Переменные профилей

- **Image Builder:** префикс `IMAGE_` — `IMAGE_PKGS`, `IMAGE_EXTRA_NAME` и т.д.
- **Source Builder:** префикс `SRC_` — `SRC_REPO`, `SRC_BRANCH`, `SRC_TARGET`, `SRC_SUBTARGET`, `SRC_PACKAGES`, `SRC_EXTRA_CONFIG`, `SRC_CORES` и др.
- **Общие:** `ROOTFS_SIZE`, `KERNEL_SIZE`, `COMMON_LIST` и др.

При старте `_Builder` выполняется миграция устаревших имён (`PKGS` → `IMAGE_PKGS`, `EXTRA_IMAGE_NAME` → `IMAGE_EXTRA_NAME`). В `ib_builder.sh` предусмотрен fallback вида `${IMAGE_PKGS:-$PKGS}` для совместимости.

### 4.2 Окончания строк и кодировки

Регламентированы в `.gitattributes`:

- **CRLF (без нормализации):** `*.bat`, `*.ps1`, `*.cmd`.
- **LF:** `*.sh`, `*.conf`, `*.yaml`, `*.yml`, `*.json`, `*.mdc`, `Dockerfile`, `.dockerignore`, `system/lang/*.env`, `profiles/personal.flag`.
- **CRLF:** `*.md`, `docs`, `README`, `LICENSE` (Windows-документы).
- **Binary / LFS:** `*.zip`, `*.zst`, `*.tar`, `*.gz`, `*.bin`, `*.7z`.

BOM: только в части PowerShell-скриптов (например, `system/create_profile.ps1`, `system/import_ipk.ps1`) для корректного отображения кириллицы в Windows.

### 4.3 Локализация

Двуязычность (RU/EN). Строки вынесены в `system/lang/ru.env` и `system/lang/en.env`. Формат: `KEY={C_VAL}value{C_RST}` без кавычек; загрузчики в `_Builder.bat` и `_Builder.sh` подставляют ANSI-коды вместо `{C_*}`. Ключи с префиксами `L_` (сообщения) и `H_` (заголовки таблиц). При отсутствии файла для `SYS_LANG` используется `en.env`.

---

## 5. Безопасность и приватные данные

Следующие каталоги в `.gitignore` и считаются пользовательскими; **не читать и не изменять без явного запроса пользователя:**

- `custom_files/<profile>/` — оверлей может содержать ключи, пароли, конфиги.
- `custom_packages/<profile>/` — бинарные/проприетарные пакеты.
- `src_packages/<profile>/` — исходники, возможны ограничения лицензий.
- `custom_patches/<profile>/` — кастомные патчи, возможны закрытые изменения.
- `firmware_output/` — артефакты сборки (объём может быть 10+ ГБ), без учёта — не открывать без необходимости.

Служебная папка `.docker_tmp/` создаётся для подстановки Docker-конфига (без credential store) и не коммитируется.

**Токсичные файлы:** `_unpacker.bat`, `_unpacker.sh` содержат крупный base64-пейлоад. Не использовать для чтения/поиска в AI и больших редакторах. Изменения вносить через `_packer.bat` / `_packer.sh`.

---

## 6. Документация и качество

- **Пользовательская:** `README.md` / `README.en.md`, `docs/index.md` / `docs/index.en.md`, уроки 01–05 (RU/EN), руководства по патчам и продвинутому Source Build.
- **Архитектура:** `docs/ARCHITECTURE_ru.md`, `docs/ARCHITECTURE_en.md`, диаграммы в `docs/ARCHITECTURE_diagram_*.md`.
- **Релизы:** `CHANGELOG.md` (тексты по тегам), визуализации в `dist/` (timeline, tree, heatmap, river, bars, stats; светлая/тёмная темы).
- **Правила для AI:** `.cursor/rules/` — project-overview, toxic-files, ignore-lx-debug, build-system, shell-scripts, batch-scripts, docker, documentation, file-header, profiles.

Тестовые распаковки `nl_test/`, `nw_test/` не являются источником истины; правки делаются только в корне репозитория.

---

## 7. Ключевые механизмы надёжности

- **Image Builder:** Atomic Downloads, общие блокировки при параллельной загрузке SDK, умный кэш.
- **Source Builder:** самовосстановление при снятии `hooks.sh` (откат патчей, очистка кэша ядра и CCache), принудительная остановка старых контейнеров перед сборкой (снижение блокировок на WSL/Windows).
- **Профили:** миграция переменных при старте, валидация в мастере создания профилей (Wizard).
- **Локальный Image Builder:** после успешной Source-сборки предлагается обновить `IMAGEBUILDER_URL` в профиле на локальный `.tar.zst` из `firmware_output`.

---

## 8. Риски и рекомендации

| Риск | Рекомендация |
|------|----------------|
| Путь с кириллицей/пробелами | Размещать проект в пути без спецсимволов (например, `C:\OpenWrt_Build\`). |
| Ошибки сети (wget) | Используются повторные попытки и перезапуски; при необходимости проверить прокси и зеркала. |
| Конфликты зависимостей (dnsmasq и др.) | В профиле явно указывать замену, например `-dnsmasq dnsmasq-full`. |
| Большой контекст Docker | `.dockerignore` исключает `firmware_output/`, `custom_files/`, `.git/` и др., чтобы не раздувать контекст сборки. |
| Параллельные сборки | На Linux (`_Builder.sh`) команда `A` — массовая фоновая сборка с раздельными логами и блокировками; на Windows параллелизм не реализован. |

---

## 9. Краткая сводка

- **Цель:** сборка кастомной прошивки OpenWrt (Image + Source) в Docker с едиными профилями и локализацией RU/EN.
- **Версия:** 4.43; конвенции по переменным, EOL и локализации зафиксированы в правилах и `.gitattributes`.
- **Приватность:** `custom_*`, `src_packages`, `firmware_output` не анализировать без запроса; `_unpacker.*` не открывать.
- **Качество:** документация и диаграммы актуализированы; Cursor-правила задают контекст для AI и стиль кода.

Аудит актуален на дату последнего обновления репозитория и правил в `.cursor/rules/`.

---

## RouterFW Project Audit

This document describes the current state of the repository, architecture, conventions, and areas of focus for development and maintenance.

**Builder version:** 4.43  
**Repository:** https://github.com/iqubik/routerFW (branch `main`)  
**License:** GPL-3.0  
**Author:** iqubik  

---

### 1. Project purpose

**OpenWrtFW Builder** is a cross-platform framework for building custom OpenWrt firmware via Docker. Two modes are supported:

| Mode | Orchestrator | Time | Purpose |
|------|--------------|------|---------|
| **Image Builder** | `system/ib_builder.sh` | 1–3 min | Build from prebuilt SDK: packages, overlay, `.ipk` injection |
| **Source Builder** | `system/src_builder.sh` | 20–60 min (cold), 3–5 min (with CCache) | Full compile from source, kernel patches, custom packages, Vermagic Hack |

Entry points: `_Builder.bat` (Windows), `_Builder.sh` (Linux). Both provide an interactive menu, profile variable migration, and feature parity within platform constraints.

---

### 2. Architecture and directory structure

| Path | Purpose |
|------|----------|
| `_Builder.sh` / `_Builder.bat` | Main menu and build orchestration |
| `system/` | Core: Dockerfile(s), docker-compose, `ib_builder.sh`, `src_builder.sh`, profile wizards, localization |
| `system/lang/` | Dictionaries `ru.env`, `en.env` (unified pseudo-format with `{C_*}` placeholders) |
| `profiles/*.conf` | Universal build configs (shared by Image and Source) |
| `custom_files/<profile>/` | File overlay → firmware root (private, in `.gitignore`) |
| `custom_packages/<profile>/` | Third-party `.ipk` for Image Builder and Source import (private) |
| `src_packages/<profile>/` | Package sources for Source Builder (private) |
| `custom_patches/<profile>/` | Patches / mirror overlay of source code (private) |
| `firmware_output/` | Built images, logs, manual_config (in `.gitignore`) |
| `scripts/` | Utilities: `hooks.sh`, `diag.sh`, `packager.sh`, `upgrade.sh`, etc. |
| `docs/` | Guides (RU/EN), lessons 1–5, architecture, diagrams |
| `dist/` | Release SVG visuals (timeline, tree, heatmap, river, bars, stats) |
| `_packer.sh` / `_packer.bat` | Pack project into self-extracting distribution |
| `_unpacker.sh` / `_unpacker.bat` | Self-extract (contain large base64 payload — **do not open in AI/editors**) |

Docker: Image Builder — `system/docker-compose.yaml`; Source Builder — `system/docker-compose-src.yaml`. Caches (SDK, packages, ccache) use volumes for faster repeat builds.

---

### 3. Technology stack

- **Scripts:** Bash, Batch, PowerShell (.bat, .ps1, .sh).
- **Build environment:** Docker, Docker Compose; base images Ubuntu 18.04 (legacy) and 22.04/24.04 (modern).
- **Caching:** CCache (20 GB limit) for Source Builder; SDK and package cache for Image Builder.
- **Versioning:** Git; large binaries (archives, images) — Git LFS (see `.gitattributes`).

---

### 4. Conventions and standards

**4.1 Profile variables**

- **Image Builder:** prefix `IMAGE_` — `IMAGE_PKGS`, `IMAGE_EXTRA_NAME`, etc.
- **Source Builder:** prefix `SRC_` — `SRC_REPO`, `SRC_BRANCH`, `SRC_TARGET`, `SRC_SUBTARGET`, `SRC_PACKAGES`, `SRC_EXTRA_CONFIG`, `SRC_CORES`, etc.
- **Shared:** `ROOTFS_SIZE`, `KERNEL_SIZE`, `COMMON_LIST`, etc.

On `_Builder` startup, legacy names are migrated (`PKGS` → `IMAGE_PKGS`, `EXTRA_IMAGE_NAME` → `IMAGE_EXTRA_NAME`). `ib_builder.sh` has fallback like `${IMAGE_PKGS:-$PKGS}` for compatibility.

**4.2 Line endings and encoding**

Defined in `.gitattributes`:

- **CRLF (no normalization):** `*.bat`, `*.ps1`, `*.cmd`.
- **LF:** `*.sh`, `*.conf`, `*.yaml`, `*.yml`, `*.json`, `*.mdc`, `Dockerfile`, `.dockerignore`, `system/lang/*.env`, `profiles/personal.flag`.
- **CRLF:** `*.md`, docs, README, LICENSE (Windows documents).
- **Binary / LFS:** `*.zip`, `*.zst`, `*.tar`, `*.gz`, `*.bin`, `*.7z`.

BOM: only in selected PowerShell scripts (e.g. `system/create_profile.ps1`, `system/import_ipk.ps1`) for correct Cyrillic on Windows.

**4.3 Localization**

Bilingual (RU/EN). Strings live in `system/lang/ru.env` and `system/lang/en.env`. Format: `KEY={C_VAL}value{C_RST}` (no quotes); loaders in `_Builder.bat` and `_Builder.sh` substitute ANSI codes for `{C_*}`. Keys use prefixes `L_` (messages) and `H_` (table headers). If the file for `SYS_LANG` is missing, `en.env` is used.

---

### 5. Security and private data

The following directories are in `.gitignore` and are considered user-private; **do not read or modify without explicit user request:**

- `custom_files/<profile>/` — overlay may contain keys, passwords, configs.
- `custom_packages/<profile>/` — binary/proprietary packages.
- `src_packages/<profile>/` — source code, possible license restrictions.
- `custom_patches/<profile>/` — custom patches, possible closed changes.
- `firmware_output/` — build artifacts (can be 10+ GB); do not open unless needed.

The `.docker_tmp/` folder is created for Docker config substitution (without credential store) and is not committed.

**Toxic files:** `_unpacker.bat`, `_unpacker.sh` contain a large base64 payload. Do not use for reading/search in AI or large editors. Make changes via `_packer.bat` / `_packer.sh`.

---

### 6. Documentation and quality

- **User-facing:** `README.md` / `README.en.md`, `docs/index.md` / `docs/index.en.md`, lessons 01–05 (RU/EN), patch and advanced Source Build guides.
- **Architecture:** `docs/ARCHITECTURE_ru.md`, `docs/ARCHITECTURE_en.md`, diagrams in `docs/ARCHITECTURE_diagram_*.md`.
- **Releases:** `CHANGELOG.md` (tag notes), visuals in `dist/` (timeline, tree, heatmap, river, bars, stats; light/dark).
- **AI rules:** `.cursor/rules/` — project-overview, toxic-files, ignore-lx-debug, build-system, shell-scripts, batch-scripts, docker, documentation, file-header, profiles.

Test unpack dirs `nl_test/`, `nw_test/` are not the source of truth; edits are made only at the repository root.

---

### 7. Key reliability mechanisms

- **Image Builder:** Atomic Downloads, shared locks for parallel SDK download, smart cache.
- **Source Builder:** self-heal when `hooks.sh` is removed (patch rollback, kernel cache and CCache clear), forced stop of old containers before build (reduces lock issues on WSL/Windows).
- **Profiles:** variable migration on startup, validation in profile creation wizard.
- **Local Image Builder:** after a successful Source build, user is offered to set `IMAGEBUILDER_URL` in the profile to a local `.tar.zst` from `firmware_output`.

---

### 8. Risks and recommendations

| Risk | Recommendation |
|------|----------------|
| Path with Cyrillic/spaces | Place project in a path without special characters (e.g. `C:\OpenWrt_Build\`). |
| Network errors (wget) | Retries and restarts are used; check proxy and mirrors if needed. |
| Dependency conflicts (dnsmasq, etc.) | In profile, specify replacement explicitly, e.g. `-dnsmasq dnsmasq-full`. |
| Large Docker context | `.dockerignore` excludes `firmware_output/`, `custom_files/`, `.git/`, etc. to keep build context small. |
| Parallel builds | On Linux (`_Builder.sh`) command `A` runs mass background builds with separate logs and locks; not implemented on Windows. |

---

### 9. Summary

- **Goal:** build custom OpenWrt firmware (Image + Source) in Docker with unified profiles and RU/EN localization.
- **Version:** 4.43; variable, EOL, and localization conventions are fixed in rules and `.gitattributes`.
- **Privacy:** do not analyze `custom_*`, `src_packages`, `firmware_output` without request; do not open `_unpacker.*`.
- **Quality:** documentation and diagrams are kept up to date; Cursor rules define context for AI and code style.

Audit is current as of the last update to the repository and `.cursor/rules/`.
