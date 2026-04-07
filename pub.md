# routerFW v4.60 — Release Notes

> 📅 8 апреля 2026

---

## 🇷🇺 Русская версия

### 🛡️ APK Scanner — главное нововведение

Встроенный сканер для автоматической валидации и переименования `.apk`-пакетов перед сборкой в режиме Image Builder.

**Зачем:** Image Builder отвергает пакеты, если имя файла не совпадает с внутренней версией (баг `luci-i18n-podkop-ru`). Сканер читает метаданные через Docker (`apk adbdump`) и исправляет имена автоматически.

**Что умеет:**
- **Чтение метаданных** — через `docker run alpine:latest apk adbdump` (без unzip, единственный надёжный метод)
- **Валидация архитектуры** — корректная обработка `noarch`/`all` (универсальные пакеты: скрипты, LuCI, конфиги) для любых устройств
- **Проверка имени файла** — сравнение `{name}-{version}` из имени файла с метаданными пакета
- **Автоматическое переименование** — с интерактивным подтверждением пользователя
- **Двуязычный интерфейс** — язык передаётся от билдера (`APK_SCANNER_LANG=RU|EN`, `-Lang` параметр)

**Режимы работы:**
- **Автоматический** — запускается перед `docker compose up` при наличии `.apk` файлов в `custom_packages/<профиль>/`
- **Ручной** — кнопка `[S] APK Scanner` в главном меню (только IB-режим): выбор профиля → сканирование → отчёт

**Интеграция в процесс сборки:** при обнаружении проблем сканер выдаёт предупреждения и предлагает продолжить сборку или отменить.

### 📋 Новые профили

- **Radxa ROCK 5T** — добавлен профиль `radxa_rock_5t_25122_ow_full.conf` (rockchip/armv8, aarch64_generic)

### 📚 Документация

- **Урок 8** — «Встраивание APK/IPK в Image Builder»: пошаговое руководство, реальные проблемы и FAQ
- **Обновлены диаграммы архитектуры** (RU/EN) — добавлены блок-схемы APK Scanner, интеграции в `build_routine`, кнопки `[S]` в меню
- **Обновлены README** (RU/EN) — раздел про APK Scanner, описание директории `custom_packages/`
- **Обновлены индексы документации** (RU/EN) — добавлена ссылка на Урок 8

### 🔧 Улучшения и исправления

- **Исправлена валидация архитектуры** в `import_ipk` — теперь `noarch` корректно определяется как универсальная архитектура (наряду с `all`)
- **Выравнивание главного меню** — исправлено форматирование кнопок, `[S]` отображается только в IB-режиме, защита от запуска в SOURCE-режиме
- **Обновлены дистрибутивы** — пересобраны архивы для Windows и Linux

### 📊 Статистика изменений

| Файл | Изменения |
|---|---|
| `system/apk_scanner.ps1` | +211 строк (новый файл) |
| `system/apk_scanner.sh` | +236 строк (новый файл) |
| `docs/08-ib-apk-import-embed.md` | +220 строк (новый урок) |
| `_Builder.bat` | ~50 строк изменений |
| `_Builder.sh` | ~50 строк изменений |
| Документация (RU/EN) | ~500 строк обновлений |

---

## 🇬🇧 English Version

### 🛡️ APK Scanner — Major Feature

Built-in scanner for automatic validation and renaming of `.apk` packages before building in Image Builder mode.

**Why:** Image Builder rejects packages if the filename doesn't match the internal version (`luci-i18n-podkop-ru` bug). The scanner reads metadata via Docker (`apk adbdump`) and fixes filenames automatically.

**Capabilities:**
- **Metadata extraction** — via `docker run alpine:latest apk adbdump` (no unzip needed, the only reliable method)
- **Architecture validation** — proper handling of `noarch`/`all` (universal packages: scripts, LuCI, configs) for any device
- **Filename validation** — compares `{name}-{version}` from filename against package metadata
- **Automatic renaming** — with interactive user confirmation
- **Bilingual interface** — language passed from builder (`APK_SCANNER_LANG=RU|EN`, `-Lang` parameter)

**Operating modes:**
- **Automatic** — triggers before `docker compose up` when `.apk` files exist in `custom_packages/<profile>/`
- **Manual** — `[S] APK Scanner` button in main menu (IB mode only): select profile → scan → report

**Build integration:** when issues are found, the scanner reports warnings and offers to continue or cancel the build.

### 📋 New Profiles

- **Radxa ROCK 5T** — added `radxa_rock_5t_25122_ow_full.conf` profile (rockchip/armv8, aarch64_generic)

### 📚 Documentation

- **Lesson 8** — "Embedding APK/IPK in Image Builder": step-by-step guide, real-world issues, and FAQ
- **Architecture diagrams updated** (RU/EN) — added flowcharts for APK Scanner, `build_routine` integration, `[S]` menu button
- **READMEs updated** (RU/EN) — APK Scanner section, `custom_packages/` directory description
- **Documentation indexes updated** (RU/EN) — Lesson 8 link added

### 🔧 Improvements & Fixes

- **Architecture validation fix** in `import_ipk` — `noarch` now correctly recognized as universal architecture (alongside `all`)
- **Main menu alignment** — fixed button formatting, `[S]` only shown in IB mode, guard against running in SOURCE mode
- **Distribution archives rebuilt** — updated Windows and Linux packages

### 📊 Change Statistics

| File | Changes |
|---|---|
| `system/apk_scanner.ps1` | +211 lines (new file) |
| `system/apk_scanner.sh` | +236 lines (new file) |
| `docs/08-ib-apk-import-embed.md` | +220 lines (new lesson) |
| `_Builder.bat` | ~50 lines changed |
| `_Builder.sh` | ~50 lines changed |
| Documentation (RU/EN) | ~500 lines updated |

---

## Коммиты (7)

| Хеш | Описание |
|---|---|
| `6e2c6b0` | APK Scanner: ядро (скрипты ps1/sh), профиль Radxa ROCK 5T, исправление noarch в import_ipk |
| `fd131ab` | Кнопка [S] в меню, ручной запуск сканера с выбором профиля |
| `ac00d6a8` | Передача языка от билдера в сканер (APK_SCANNER_LANG / -Lang) |
| `befc0026` | Интеграция сканера в build_routine, добавление в packer/unpacker, тег 4.60 |
| `2708949` | Документация: Урок 8, обновление архитектуры, README |
| `289db58b` | Форматирование меню: выравнивание кнопок, защита [S] в SOURCE-режиме |
| `689e496` | Финальная правка форматирования меню, обновление checksum |
