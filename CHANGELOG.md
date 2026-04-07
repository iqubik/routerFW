# RouterFW — тексты релизов (по тегам)

Выгружено из репозитория по тегам через `gh release view`.
Дата выгрузки: 2026-04-08 00:11:47.

---



## ========== TAG: 1.0 ==========

title:	OpenWrt Builder v1.0
tag:	1.0
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2025-12-25T23:10:02Z
published:	2025-12-25T23:12:38Z
url:	https://github.com/iqubik/routerFW/releases/tag/1.0
asset:	routerFW1.zip
--
Первая и полная версия сборщика.


## ========== TAG: 2.0 ==========

title:	2.0
tag:	2.0
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2025-12-27T10:53:47Z
published:	2025-12-27T11:32:17Z
url:	https://github.com/iqubik/routerFW/releases/tag/2.0
asset:	OWRTrouterFW_Builder_v2.04.zip
--
Вот готовый текст **Release Notes** для GitHub, оформленный по стандартам релизов. Он подчеркивает масштаб изменений (переход от простого упаковщика к универсальному комбайну).

***

# 🚀 Global Update v2.0: Source Builder & Universal Profiles

Это мажорное обновление превращает проект из простого ImageBuilder в **универсальную экосистему** для сборки прошивок OpenWrt. Теперь вы можете выбирать: быстрая упаковка пакетов или глубокая компиляция из исходного кода.

## 🔥 Главные изменения

### 🏭 Новый Source Builder
Добавлена возможность компиляции прошивки **из исходного кода (C/C++)** с нуля.
*   **Два ядра сборки:** Автоматический выбор окружения:
    *   *Legacy:* Ubuntu 18.04 + Python 2.7 (для OpenWrt 18.06 / 19.07).
    *   *Modern:* Ubuntu 22.04 + Python 3 (для OpenWrt 21.02 — 24.x и Snapshot).
*   **Умное кэширование:** Реализован механизм **Persistence Cache**. Первая сборка занимает ~20-40 минут, повторные — **2-3 минуты**.
*   **Инъекция кода:** Возможность добавлять свои исходники (Makefile) в папку `src_packages`, и билдер сам внедрит их в дерево сборки.

### ⚙️ Универсальные Профили
*   Полный рефакторинг конфигурационных файлов.
*   Теперь **один `.conf` файл** содержит настройки и для ImageBuilder, и для SourceBuilder.
*   Обновлен генератор `create_profile.ps1` — теперь он парсит сайт OpenWrt и создает универсальные профили автоматически.

### ⚡ Улучшения производительности и стабильности
*   **Зеркала GitHub:** Встроена защита от падения серверов `git.openwrt.org` (Error 503). Скрипт автоматически переключает фиды на зеркала.
*   **Интеграция интерфейса:** Добавлена возможность переключения между `Image Builder` и `Source Builder` прямо из меню консоли.
*   **Изоляция:** Результаты сборки теперь разделяются по папкам `firmware_output/imagebuilder` и `firmware_output/sourcebuilder`.

## 🛠 Исправления и доработки
*   Исправлены права доступа (`Permissions Denied`) при монтировании томов Docker в Windows.
*   Исправлен алгоритм сбора артефактов: теперь сохраняются не только `.bin`, но и `build.config`, `sha256sums` и манифесты.
*   В код внедрены 5 готовых примеров профилей (Base64) для популярных роутеров (Xiaomi 4A, Giga, NanoPi R5C, TP-Link 841n, ZBT).

## ⚠️ Важное примечание
Некоторые примеры профилей (например, `zbt` или `giga_full`) настроены на максимальный функционал и могут требовать наличие локальных файлов (кастомных пакетов), не включенных в репозиторий. Если сборка падает с ошибкой `package not found` — удалите лишние пакеты из конфига или добавьте недостающие файлы.

---

## What's Changed
* Global Update v2.0: Added Source Builder, Universal Profiles and Caching by @iqubik in https://github.com/iqubik/routerFW/pull/1

## New Contributors
* @iqubik made their first contribution in https://github.com/iqubik/routerFW/pull/1

**Full Changelog**: https://github.com/iqubik/routerFW/compare/1.0...2.0


## ========== TAG: 2.1 ==========

title:	2.1
tag:	2.1
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2025-12-28T21:55:30Z
published:	2025-12-28T22:00:01Z
url:	https://github.com/iqubik/routerFW/releases/tag/2.1
asset:	OWRTrouterFW_Builder_v2.1.zip
--
## 📦 Changelog v2.1

### 🚀 Новые функции (New Features)
*   **[SourceBuilder] Добавлена поддержка `SRC_EXTRA_CONFIG`**:
    *   В профили конфигурации (`.conf`) теперь можно добавить переменную `SRC_EXTRA_CONFIG`.
    *   Позволяет внедрять дополнительные параметры в файл `.config` перед компиляцией (например, для тонкой настройки ядра, отключения ненужных модулей или устройств).
    *   Поддерживает многострочный формат значений.
    *   Обновлена логика `docker-compose.yaml` для корректной инъекции этих параметров до этапа `make defconfig`.
*   **[General] Поддержка сборки форков (ImmortalWrt и др.)**:
    *   Подтверждена и протестирована возможность сборки прошивок из альтернативных репозиториев (например, ImmortalWrt).
    *   В пакет добавлен **демонстрационный профиль**: `profiles\rax3000m_i_24104_full.conf` (сборка ImmortalWrt v24).

### 🛠 Оптимизация и Рефакторинг (Refactoring)
*   **Выделение общих ресурсов в `_unpacker.bat`**:
    *   Код ресурсов (файлы профилей, Dockerfile, openssl.cnf), закодированный в Base64, **удален** из скриптов `_Image_Builder.bat` и `_Source_Builder.bat`.
    *   Создан единый независимый модуль распаковки **`_unpacker.bat`**.
    *   Главные скрипты теперь вызывают `_unpacker.bat` при старте. Это уменьшило размер основных файлов и исключило дублирование данных.

### ⚙️ Инструментарий (Tooling)
*   **Обновлен скрипт упаковщика (`Packer.bat` v1.5)**:
    *   Переписан алгоритм генерации `_unpacker.bat`.
    *   Исключены ошибки синтаксиса CMD при обработке длинных строк и спецсимволов.
    *   Добавлена проверка целостности: теперь распаковщик проверяет наличие файлов перед записью (пропускает существующие, перезаписывает/создает отсутствующие).
    *   Добавлено расширенное логирование процесса распаковки.

---

### Пример использования `SRC_EXTRA_CONFIG` в профиле:
```bash
# Пример добавления в .conf файл
SRC_EXTRA_CONFIG="CONFIG_TARGET_KERNEL_PARTSIZE=256 \
CONFIG_PACKAGE_wpad-mbedtls=y"


## ========== TAG: 2.4 ==========

title:	2.4
tag:	2.4
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2025-12-29T00:40:18Z
published:	2025-12-29T00:47:15Z
url:	https://github.com/iqubik/routerFW/releases/tag/2.4
asset:	routerFW_WinDockerBuilder_v2.4.zip
--
# 🚀 Update v2.4: Fine-Tuning, ImmortalWrt & Modular Core

Продолжая развитие идеи **Универсального Комбайна**, заложенной в v2.0, версия **2.4** фокусируется на гибкости конфигурации и архитектурной чистоте. Если v2.0 дала нам мощный двигатель (SourceBuilder), то v2.4 дает руль для тонкой настройки и облегчает корпус.

## 🔥 Новые возможности (New Features)

### 🎛️ Тонкая настройка через `SRC_EXTRA_CONFIG`
В SourceBuilder добавлена фича для продвинутых пользователей. Теперь в профиле `.conf` можно передавать "сырые" параметры конфигурации, которые внедряются в `.config` **до** этапа компиляции.
*   **Зачем это нужно:** Изменение размера разделов ядра (`KERNEL_PARTSIZE`), отключение лишних модулей, тюнинг опций, недоступных через обычный список пакетов.
*   **Как работает:** Поддерживает многострочный ввод.

**Пример использования в профиле:**
```bash
# Тонкая настройка ядра и пакетов
SRC_EXTRA_CONFIG="CONFIG_TARGET_KERNEL_PARTSIZE=256 \
CONFIG_PACKAGE_wpad-mbedtls=y \
CONFIG_PACKAGE_wpad-openssl=n"
```

### 🍴 Поддержка форков (ImmortalWrt)
Система официально протестирована на совместимость с альтернативными репозиториями.
*   Добавлен демонстрационный профиль `profiles\rax3000m_i_24104_full.conf`.
*   Успешно собирает прошивки на базе **ImmortalWrt v24** (использует тот же движок, что и официальный OpenWrt).

---

## 🛠 Архитектурные изменения (Refactoring)

Мы устранили "технический долг" и дублирование кода, возникшее при слиянии билдеров в v2.0.

### 📦 Модуль распаковки `_unpacker.bat`
*   **Было:** Base64-код ресурсов (Dockerfile, openssl.cnf, профили) дублировался в каждом скрипте (`_Image_...bat` и `_Source_...bat`).
*   **Стало:** Весь Base64 вынесен в единый независимый модуль `_unpacker.bat`.
*   **Результат:** Основные скрипты стали легче, чище и используют единый источник ресурсов. При запуске любой из билдеров вызывает распаковщик автоматически.

### 🔧 Обновление `Packer.bat` до v1.5
Инструмент для разработчика (сборка релиза) полностью переписан:
*   Устранены ошибки синтаксиса CMD при кодировании длинных строк и спецсимволов.
*   Внедрена **проверка целостности**: распаковщик теперь проверяет наличие файлов перед записью (пропускает существующие, восстанавливает отсутствующие).
*   Добавлено расширенное логирование процесса.

---

## 📜 История изменений (Full Changelog)

*   **Feature:** Внедрение логики инъекции `SRC_EXTRA_CONFIG` в `docker-compose.yaml`.
*   **Feature:** Добавлен профиль для ImmortalWrt (RAX3000M).
*   **Refactor:** Выделение ресурсов в `_unpacker.bat`.
*   **Refactor:** Удаление Base64 блоков из исполняемых скриптов билдеров.
*   **Fix:** Исправление логики переключения между билдерами (меню).

**Full Changelog**: https://github.com/iqubik/routerFW/compare/2.0...2.1
**Full Changelog**: https://github.com/iqubik/routerFW/compare/2.1...2.4


## ========== TAG: 2.5 ==========

title:	2.5
tag:	2.5
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2025-12-29T10:07:05Z
published:	2025-12-29T10:16:20Z
url:	https://github.com/iqubik/routerFW/releases/tag/2.5
asset:	routerFW_WinDockerBuilder_v2.5.zip
--
---

### 🚀 OpenWrt Smart Builder v2.5 — прокачка SourceBuilder

Главный фокус этого релиза — **Гибкость и Интеллект**. Научил билдер решать самые сложные проблемы энтузиастов (Vermagic, патчи, кэширование).

#### 🔥 Ключевые нововведения:

**1. Система "Умных Хуков" (Smart Hooks)**
Внедрен механизм `hooks.sh`. Теперь вы можете модифицировать исходный код OpenWrt **до** начала компиляции без вмешательства в системные файлы.
*   *Хотите 16MB флеш на 841n?* Просто положите скрипт в папку профиля.
*   *Нужно поправить DTS или Makefile?* Хук сделает это автоматически.
*   **Auto-Sanitize:** Билдер сам лечит проблему переноса строк (CRLF -> LF), так что писать скрипты можно даже в Блокноте Windows.

**2. Интеллектуальный Vermagic Hack** 🧠
Священный Грааль для самосборных прошивок!
*   Билдер научился подменять хэш ядра (Vermagic) на официальный релизный.
*   **Зачем:** Это позволяет устанавливать любые пакеты `kmod-*` из официального репозитория OpenWrt (`opkg install ...`) на вашу кастомную прошивку. Больше никаких ошибок совместимости ядра!
*   **Smart Cache:** Билдер отслеживает изменение хэша. Если версия изменилась — он сам очистит только нужную часть кэша ядра, не трогая Toolchain (экономия часов сборки).

#### 🛠 Технические улучшения:
*   **Smart Cache Cleaning:** Умная очистка при смене конфигурации. Вам больше не нужно гадать, почему сборка падает — система сама приведет кэш в порядок.

#### 📦 Как обновиться:
Полная пересборка среды не требуется, но рекомендуется обновить скрипты запуска (`.bat`) и `docker-compose` файлы из репозитория, чтобы активировать новые функции хуков и кэширования.
И самый простой вариант это запустить _unpacker,bat в пустой папке а в папку профилей перетащий свой профили из старой версии и проверить что всё ок по формату и составу.

**Full Changelog**: https://github.com/iqubik/routerFW/compare/2.4...2.5


## ========== TAG: 2.51 ==========

title:	2.51
tag:	2.51
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2025-12-29T20:53:02Z
published:	2025-12-29T20:54:05Z
url:	https://github.com/iqubik/routerFW/releases/tag/2.51
asset:	routerFW_WinDockerBuilder_v2.51.zip
--
# Релиз v2.51

Этот релиз включает в себя ряд улучшений, направленных на повышение надежности сборочного процесса, удобства использования и исправление ошибок.

## Основные изменения:

### Улучшения сборки и упаковки

*   **Исправлена кодировка:** В скрипты `_packer.bat` и `_unpacker.bat` добавлена команда `chcp 65001`, которая принудительно включает кодировку UTF-8. Это решает проблемы с отображением не-латинских символов в консоли Windows.
*   **Исправлен баг:** hooks.sh теперь не попадает в корень ImageBuilder сборки.

### Документация

*   **README обновлен:** Внутренний `README.md` (находящийся внутри `_unpacker.bat`) был значительно переработан. Добавлены более подробные объяснения по работе с `hooks.sh`, механизму `Vermagic` и решению частых проблем.

### Прочее
*   **Рефакторинг `docker-compose(_src).yaml`:** Скрипты сборки внутри Docker были реорганизованы и снабжены комментариями для лучшей читаемости и упрощения дальнейшей поддержки.

---

**Full Changelog**: https://github.com/iqubik/routerFW/compare/2.5...2.51


## ========== TAG: 3.2 ==========

title:	v3.2
tag:	3.2
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-02T10:39:13Z
published:	2026-01-02T10:41:43Z
url:	https://github.com/iqubik/routerFW/releases/tag/3.2
asset:	routerFW_WinDockerBuilder_v3.2.zip
--
# 📋 Полный список изменений (Changelog)

### Версия проекта: v3.2 (Builder)

---

### 1. Глобальная архитектура: Единый `_Builder.bat`

Проект прошел через **масштабный рефакторинг**, который заменил старую систему из нескольких скриптов (`_Image_Builder.bat`, `_Source_Builder.bat`) на **единый, централизованный `_Builder.bat`**.

**Ключевые нововведения:**

*   **Два режима в одном:** `IMAGE` (быстрая сборка) и `SOURCE` (полная компиляция) теперь объединены в одном интерфейсе и переключаются на лету (`[M]`).
*   **Динамический запуск:** Скрипт автоматически определяет нужный `docker-compose` файл и сервис в зависимости от выбранного режима и профиля.
*   **Параллельная сборка:** Поддерживается запуск сборки всех профилей (`[A]`), причем каждая сборка стартует в отдельном окне.
*   **Полный отказ от вложенных скобок `( ... )`** в пользу переходов `goto`, что устранило критическую ошибку Windows CMD.

---

### 2. Мастер создания профилей (`create_profile.ps1`)

Скрипт создания профилей был кардинально переработан для удобства и защиты от ошибок.

*   **Улучшенный UI:** На каждом шаге мастера теперь отображается строка состояния с уже выбранными параметрами (например, `Release: [22.03.5] > Target: [ramips]`).
*   **Надежный ввод:** Внедрена функция `Read-Selection`, которая проверяет ввод на корректность (число, диапазон, не пустое значение), полностью исключая ошибки.
*   **Самодокументируемые профили:** Генерируемый `.conf` файл теперь содержит множество **полезных закомментированных примеров** для `CUSTOM_REPOS`, `CUSTOM_KEYS` и, что особенно важно, для `SRC_EXTRA_CONFIG` (экономия места, файловые системы, модули ядра).

---

### 3. Система обслуживания (`_Builder.bat` -> Clean Menu)

**Новый "Мастер Очистки" (`[C]`):**
*   **Гранулярный контроль:** Позволяет выбрать **ТИП** очистки (Soft, Hard, DL, Ccache) и **ЦЕЛЬ** (конкретный профиль или `[A]` для всех).
*   **Интеллектуальное управление томами:** Автоматически находит нужные Docker-тома и корректно останавливает контейнеры перед их удалением, чтобы избежать ошибки `volume is in use`.

---

### 4. Image Builder (`docker-compose.yaml`) — Сетевая надежность

*   **Атомарная загрузка SDK:** Скачивание идет во временный `.tmp` файл, что исключает "гонку состояний" при параллельных сборках. Добавлен механизм блокировок, заставляющий сборки ждать, пока одна из них скачивает SDK.
*   **Устойчивость `wget` и `opkg`:** Внутри контейнера создается `.wgetrc` с параметрами `tries = 5`, `timeout = 20`. `opkg` и `make` больше не падают при кратковременных разрывах связи.
*   **Автоматический перезапуск сборки:** Команда `make image` обернута в цикл, который перезапустит сборку до 3 раз в случае сетевого сбоя.
*   **Чистые логи:** `wget` переведен в режим `--progress=dot:giga`.

---

### 5. Source Builder (`docker-compose-src.yaml`) — Производительность и самовосстановление

*   **Внедрение CCACHE:**
    *   Интегрирован `ccache` для кэширования результатов компиляции, что сократило время повторной сборки с ~40 до **~5-10 минут**.
    *   **Авто-фикс прав:** Скрипт сам делает `chown build:build` для папки `/ccache`, устраняя ошибку компиляции.
*   **Логика "самовосстановления" (Self-Healing):**
    *   **Новое!** В `docker-compose-src.yaml` встроена система отката.
    *   **Сценарий:** Если вы убираете `hooks.sh` из профиля, который ранее его использовал.
    *   **Действие:** Система автоматически обнаруживает "грязное состояние" (патченный vermagic, бэкапы) и выполняет **полный откат**: восстанавливает чистый `kernel-defaults.mk`, делает глубокую очистку кэша ядра (`make target/linux/clean`) и **полностью сбрасывает CCACHE**.
    *   **Результат:** Это предотвращает труднодиагностируемые ошибки сборки и делает систему гораздо более надежной и предсказуемой.

---

### 6. Скрипт хуков (`scripts/hooks.sh`) — Vermagic и Универсальность

*   **Vermagic Hack v1.3.1:** Автоматически подменяет хэш ядра, позволяя ставить официальные `kmod-*` пакеты.
*   **Git-Safe & Idempotency:** Создает бэкапы (`.bak`) и корректно работает со `SNAPSHOT` версиями.
*   **Smart Cache Cleaning:** Принудительно запускает пересборку только ядра, если хэш изменился.
*   **Поддержка ImmortalWrt:** Автоматически определяет дистрибутив и использует правильные URL.

---

### Итог
Проект трансформировался в **полноценную, быструю и отказоустойчивую платформу для сборки прошивок**. Она не только работает быстрее и надежнее, но и умеет **самостоятельно восстанавливаться** после изменений в конфигурации, что значительно упрощает ее использование.

## What's Changed
* Compare by @iqubik in https://github.com/iqubik/routerFW/pull/5
* Compare by @iqubik in https://github.com/iqubik/routerFW/pull/6


**Full Changelog**: https://github.com/iqubik/routerFW/compare/2.51...3.2


## ========== TAG: 3.3 ==========

title:	3.3
tag:	3.3
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-03T08:37:40Z
published:	2026-01-03T08:40:46Z
url:	https://github.com/iqubik/routerFW/releases/tag/3.3
asset:	routerFW_WinDockerBuilder_v3.3.zip
--
## 📦 Changes in v3.3

### 🚀 Новые функции Source Builder
*   **Интерактивный Menuconfig:** Добавлен пункт `[K]`, запускающий стандартное синее меню конфигурации OpenWrt прямо в контейнере.
*   **Приоритет ручной настройки:** Если в папке профиля сохранен файл `manual_config` который там создаёт система после работы с `menuconfig`, сборщик автоматически переключается в "Ручной режим", игнорируя списки пакетов из `.conf` файла.
*   **Smart Init:** Menuconfig теперь можно запускать даже на пустом проекте — скрипт сам скачает исходники и подготовит `Makefile`.

### 🐛 Исправления
*   **Сбор артефактов:** Исправлена ошибка копирования прошивки, если архитектура (Subtarget) была изменена через Menuconfig.
*   **Windows Fixes:** Устранены проблемы с переносом строк (CRLF) и правами доступа при запуске скриптов внутри Docker.
*   **Dependency Hell:** Улучшена логика генерации `.config` для предотвращения конфликтов зависимостей.

**Full Changelog**: https://github.com/iqubik/routerFW/compare/3.2...3.3


## ========== TAG: 3.4 ==========

title:	3.4
tag:	3.4
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-05T15:40:01Z
published:	2026-01-05T15:48:41Z
url:	https://github.com/iqubik/routerFW/releases/tag/3.4
asset:	routerFW_WinDockerBuilder_v3.4.zip
--
Внедрена механика сборки репозитория со специфическим кастомным китайский кодом wifi драйверов для mt79 для роутеров Rax3000M/ME/EMMC на ядре 6.6. **Боль ветки 4pda rax3000m-emmc-mt-wifi**

Так же появилось понимание как такие сборки собирать:
1. определяем верное название какое надо собирать и фиксируем версию цель и название ветки в файле профиля.
2. запускаем menuconfig Для этой сборки - так как профиль пустой кэш пустой, файлов пока нет.
3. берём образец конфига для сборки который обычно лежит в папках наподобии
https://github.com/padavanonly/immortalwrt-mt798x-6.6/blob/openwrt-24.10-6.6/defconfig/mt7981-ax3000.config
и кладём его в выходную папку прошивки там после menuconfig появится файл firmware_output\sourcebuilder\rax3000m_emmc_test_new\manual_config
4. вместо 400кб файла который у нас получился мы положили 11кб файл
5. чтобы сборщик устранил все зависимости желательно опять просто запустить menuconfig и наш 11кб файлик превратится в 400кб зато теперь в этом файле видны все конфиги что возможны, можно с ним работать и из menuconfig и он включил в себя все рекомендации автора исходников дистрибутива который вы собираете.

Так же устранены другие шероховатости:
Profile wizard не работал! :( Кодировка файла была не bom. Теперь работает!
https://github.com/iqubik/routerFW/issues/7

Добавлен контроль количества ядер при сборке. В профиле добавляем
safe = max-1;
Или задать число ядер вручную =5
SRC_CORES="safe"
SRC_CORES="5"

**Full Changelog**: https://github.com/iqubik/routerFW/compare/3.3...3.4


## ========== TAG: 3.5 ==========

title:	3.5
tag:	3.5
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-05T18:23:54Z
published:	2026-01-05T18:42:46Z
url:	https://github.com/iqubik/routerFW/releases/tag/3.5
asset:	routerFW_WinDockerBuilder_v3.5.zip
--
---

## 🚀 Update v3.5: User Data Protection & Smarter Wizard

В этом обновлении мы сосредоточились на удобстве работы с пользовательскими файлами и улучшении логики создания профилей.

### 🛡️ Защита пользовательских данных (Unpacker v1.9)
Решена проблема с "неудаляемыми" стандартными профилями. Теперь ваши изменения, скрипты и готовые прошивки защищены от перезаписи при обновлении или перезапуске сборщика.

*   **Как это работает:** После первой успешной распаковки скрипт `_unpacker.bat` создает файл-маркер `profiles\personal.flag`.
*   **Что это дает:** При наличии этого файла следующие папки **исключаются** из процесса самовосстановления (сброса к дефолту):
    *   📂 `/profiles/` (теперь можно удалить лишние дефолтные профили, и они не вернутся)
    *   📂 `/scripts/`
    *   📂 `/firmware_output/`

> **Важно:** Это делает опцию **"[A] Собрать ВСЕ (Параллельно)"** по-настоящему полезной, так как теперь она будет собирать только те профили, которые вы оставили в папке.

### 🧠 Улучшенный Profile Wizard
Больше не нужно гадать, какие пакеты установлены в системе по умолчанию.

*   **Автоматический импорт пакетов:** При создании профиля скрипт теперь обращается к базе данных OpenWrt (аналогично Web Image Builder) и загружает список заводских пакетов для выбранного устройства.
*   **Контроль конфликтов:** Список сохраняется в переменную `DEFAULT_PACKAGES`. Это позволяет легко отследить конфликты перед сборкой (например, наличие `dnsmasq` при попытке установить `dnsmasq-full`) и скорректировать список `CUSTOM_PACKAGES`.

![Preview](https://github.com/user-attachments/assets/f7cb32b8-d753-4cb6-b7e5-94ba82952b5d)

---

### 📦 Файлы
*   **Full Changelog:** [View comparison 3.4...3.5](https://github.com/iqubik/routerFW/compare/3.4...3.5)


## ========== TAG: 3.51 ==========

title:	3.51
tag:	3.51
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-05T20:10:22Z
published:	2026-01-05T20:12:47Z
url:	https://github.com/iqubik/routerFW/releases/tag/3.51
asset:	routerFW_WinDockerBuilder_v3.51.zip
--
## Update v3.51
## profile wizard v2.0: Навигация, ImmortalWrt и Зеркала

Крупное обновление генератора профилей. Переработана архитектура скрипта и добавлена поддержка альтернативных прошивок.

###  Ключевые изменения

*   ** Поддержка ImmortalWrt**
    *   Теперь на старте можно выбрать источник: **OpenWrt** или **ImmortalWrt**.
    *   Скрипт автоматически подменяет `SRC_REPO` и ссылки на загрузку в зависимости от выбора.
*   ** Скоростные зеркала**
    *   Добавлен выбор источника загрузки *ImageBuilder* для ImmortalWrt.
    *   Доступно зеркало **KyaruCloud (Cloudflare CDN)** — решает проблему низкой скорости скачивания из РФ/Европы.
*   ** Навигация и UX**
    *   Скрипт больше не линеен. Реализована машина состояний (State Machine).
    *   Добавлены команды: `[Z]` — вернуться на шаг назад, `[Q]` — выход.
    *   После создания профиля можно сразу начать создание следующего без перезапуска скрипта.

###  Прочие улучшения
*   ** Smart Package Analysis:** Улучшен алгоритм парсинга `DEFAULT_PACKAGES`. Теперь корректно обрабатываются списки пакетов `device_packages`, включая удаление ненужных (с префиксом `-`).
*   ** Refactoring:** Код полностью структурирован, добавлены регионы и документация к функциям.
*   **Bugfix:** Исправлена ошибка с пустыми списками пакетов на некоторых устройствах.

---
**Full Changelog**: https://github.com/iqubik/routerFW/compare/3.5...3.51


## ========== TAG: 3.54 ==========

title:	3.54
tag:	3.54
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-05T22:24:34Z
published:	2026-01-05T22:29:18Z
url:	https://github.com/iqubik/routerFW/releases/tag/3.54
asset:	routerFW_WinDockerBuilder_v3.54.zip
--
 profile wizard v2.2: UX+
### Added
- **Smart Inputs:** Добавлена подстановка значений по умолчанию (Enter для `luci` и имени профиля).
- **Auto-Naming:** Реализована матричная генерация имен файлов по шаблону `[Model]_[Version]_[Source]_full`.
- **Safety:** Добавлена проверка существования файла с защитой от случайной перезаписи.

### Changed
- **UI:** Шапка состояния ("хлебные крошки") переведена в однострочный формат с цветовым кодированием.
- **Input Sanitization:** Внедрена автокоррекция имени файла (приведение к нижнему регистру, замена пробелов и спецсимволов на `_`).

### Fixed
- Исправлена логика ввода дополнительных пакетов (корректная обработка пустой строки).
**Full Changelog**: https://github.com/iqubik/routerFW/compare/3.51...3.54


## ========== TAG: 3.6 ==========

title:	3.6
tag:	3.6
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-07T19:32:39Z
published:	2026-01-07T19:35:24Z
url:	https://github.com/iqubik/routerFW/releases/tag/3.6
asset:	routerFW_WinDockerBuilder_v3.6.zip
--

# 📝 Changelog: RouterFW v3.6

---

## 🏗 [1ef5cd7] Рефакторинг и изоляция системы
**Дата:** 7 января 2026 г. | **Автор:** iqubik

Проведен масштабный рефакторинг структуры проекта. Все системные компоненты и конфигурации Docker изолированы в отдельную директорию для исключения «засорения» корня проекта.

### 📂 Изменения в структуре файлов
| Исходный файл | Новый путь в `system/` |
| :--- | :--- |
| `create_profile.ps1` | `system/create_profile.ps1` |
| `docker-compose-src.yaml` | `system/docker-compose-src.yaml` |
| `docker-compose.yaml` | `system/docker-compose.yaml` |
| `dockerfile` | `system/dockerfile` |
| `dockerfile.841n` | `system/dockerfile.841n` |
| `openssl.cnf` | `system/openssl.cnf` |
| `src.dockerfile` | `system/src.dockerfile` |
| `src.dockerfile.legacy` | `system/src.dockerfile.legacy` |

### 🛠 Обновление логики скриптов
*   **Скрипты управления:** `_Builder.bat`, `_packer.bat` и `_unpacker.bat` полностью переписаны для работы с относительными путями внутри подпапки `system/`.
*   **Изоляция:** Теперь корневая директория содержит только пользовательские данные и основные инструменты запуска.

---

## 📚 Обновление документации (Этапы 1-2)
**Дата:** 7 января 2026 г. | **Автор:** iqubik

Комплексная работа над описанием проекта и созданием базы знаний.

### 📑 [cc31bd3] Шаг 1: Создание структуры `docs/`
Создана выделенная директория для документации со следующими разделами:
*   `index.md` — Главная страница базы знаний.
*   `01-introduction.md` — Введение в проект и его цели.
*   `02-digital-twin.md` — Описание архитектурной концепции "цифрового двойника".
*   `03-source-build.md` — Базовая инструкция по сборке из исходных кодов.
*   `04-adv-source-build.md` — Черновик раздела по продвинутой сборке.

### 🖋 [2016bbb] Шаг 2: Наполнение и актуализация
*   **`README.md`:** Полный рерайт главного файла. Отражена новая структура проекта и актуальные инструкции по быстрому старту.
*   **`docs/04-adv-source-build.md`:** Расширен раздел по тонкой настройке компиляции.

---

### 💡 Итоговое резюме
Версия 3.6 переводит проект на новый уровень организации:
1.  **Чистый корень:** Все технические конфиги скрыты.
2.  **Масштабируемость:** Новая структура папок позволяет легче добавлять новые типы сборщиков.
3.  **Порог входа:** Полноценная документация в папке `docs/` упрощает изучение проекта новым пользователям.

---

## What's Changed
* Lessons + path by @iqubik in https://github.com/iqubik/routerFW/pull/9
**Full Changelog**: https://github.com/iqubik/routerFW/compare/3.54...3.6


## ========== TAG: 3.8 ==========

title:	3.8
tag:	3.8
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-08T20:03:49Z
published:	2026-01-08T20:10:23Z
url:	https://github.com/iqubik/routerFW/releases/tag/3.8
asset:	routerFW_WinDockerBuilder_v3.86.zip
--
# 🚀 OpenWrt FW Builder v3.8

Версия **3.8** — это масштабное обновление логики работы с кастомным ПО. Мы сосредоточились на том, чтобы сделать процесс встраивания сторонних бинарных пакетов в сложную сборку из исходников максимально простым, наглядным и безопасным.

<img width="1484" height="719" alt="image" src="https://github.com/user-attachments/assets/1debcdad-8b3c-46c3-9174-d6485b839d0a" />

## 🌟 Главная особенность: Автоматический IPK-конвейер
Теперь встраивание готовых пакетов (`.ipk`) в Source Build происходит почти на полном автомате. Больше не нужно вручную писать Makefile или разбираться в зависимостях — система всё сделает за вас.

### 📦 Основные улучшения:

*   **Интеллектуальный Wrapper:** Скрипт сам «оборачивает» ваши IPK в формат, понятный системе сборки OpenWrt, автоматически исправляя устаревшие имена зависимостей и маппинг библиотек.
*   **Изоляция профилей (Sandboxing):** У каждого аппаратного профиля теперь свои личные папки для пакетов. Больше никакого «винегрета» из софта для разных архитектур — всё строго разложено по полочкам `custom_packages/%profile_id%`.
*   **Контроль архитектуры:** Система видит, что вы импортируете. Если пакет предназначен для другой платформы, сборщик выдаст предупреждение еще на этапе подготовки, защищая вас от нерабочей прошивки.
*   **Binary Integrity (Windows Fix):** Мы решили проблему «битых» файлов. Пакеты передаются в Docker в упакованном виде, что сохраняет системные ссылки (Symlinks) и права доступа, которые обычно ломаются при работе в Windows.

## 🎨 Интерфейс и UX
Мы «причесали» внешний вид и сделали взаимодействие с консолью более приятным:
*   **Цветовая индикация:** Важные системные сообщения, статусы архитектур и ошибки теперь подсвечиваются разными цветами для лучшей читаемости.
*   **Контекстные меню:** Сборщик стал «умнее» — при импорте или настройке он всегда спрашивает, с каким конкретным устройством вы работаете в данный момент.
*   **Авто-инъекция:** Все ваши импортированные пакеты мгновенно появляются в `menuconfig` в отдельной категории.
*   **Отображение папок** Все всязанные с профилем папки мониторятся билдером на наличие файлов и отображаются в главном меню.
<img width="1483" height="762" alt="image" src="https://github.com/user-attachments/assets/6807d011-ca01-4896-86aa-b976b6eb6749" />
---

## 🛠 Технический список изменений (Changelog):

- **[NEW]** Реализована иерархическая структура хранения пакетов по ID профиля.
- **[NEW]** Добавлен автоматический генератор Makefile для бинарных пакетов с поддержкой `postinst` скриптов.
- **[NEW]** Мониторинг связанных папок профиля.
- **[FIX]** Исправлена ошибка именования зависимостей (маппинг `libnetfilter-queue` и др.) для совместимости с OpenWrt 24.10.
- **[FIX]** Добавлена блокировка `STRIP` для бинарных пакетов, решающая ошибки компиляции сторонних модулей (например, Zapret).
- **[IMPROVED]** Обновлен PowerShell-скрипт импорта: добавлен вывод архитектуры и интерактивный режим перезаписи.
- **[IMPROVED]** В Docker Compose внедрена динамическая подстановка путей через переменные окружения.

---
**OpenWrt FW Builder: Сборка профессиональных прошивок без рутины.**

## What's Changed
* Src ipk by @iqubik in https://github.com/iqubik/routerFW/pull/10

**Full Changelog**: https://github.com/iqubik/routerFW/compare/3.6...3.8


## ========== TAG: 3.9 ==========

title:	3.9 RU-EN lang + Linux?
tag:	3.9
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-09T20:21:01Z
published:	2026-01-09T20:25:51Z
url:	https://github.com/iqubik/routerFW/releases/tag/3.9
asset:	routerFW_LinuxDockerBuilder_v11.01.2026_03-09.tar.gz
asset:	routerFW_WinDockerBuilder_v11.01.2026_03-09.zip
--
### Description (RU / EN):

**EN:**
- **Detection System:** Implemented a weighted system language detection algorithm (scores: 3, 2, 4, 1) across Batch and PowerShell scripts.
- **Builder UI:** Fully localized `_Builder.bat`, updated build indicators (`OI/OS`), and fixed special character (`|`) parsing issues in menus.
- **Docker Toolchain:** Migrated all container-internal console output (`echo`) to technical English for better compatibility.
- **Wizard Scripts:** Added language support to `create_profile.ps1` and cleaned up terminal output for `import_ipk.ps1`.
- **Code Maintenance:** Preserved and updated internal Russian comments for ease of development while keeping UI elements English/Bilingual.

**RU:**
- **Система детекции:** Внедрен алгоритм взвешенного определения языка (Weighted Detection) в Batch и PowerShell скриптах.
- **Интерфейс билдера:** Полная локализация `_Builder.bat`, исправлено отображение индикаторов сборки (`OI/OS`) и решена проблема экранирования спецсимволов (`|`) в меню.
- **Docker-инструментарий:** Все консольные сообщения (`echo`) внутри контейнеров переведены на технический английский язык для универсальной совместимости.
- **Скрипты-мастеры:** Добавлена поддержка языковых переменных в `create_profile.ps1` и очищен вывод `import_ipk.ps1`.
- **Комментарии:** Сохранены и актуализированы внутренние русскоязычные комментарии для удобства сопровождения кода.

P.S.

Вот подробный список изменений (Changelog) для Git, разделенный на логические блоки.

### 🇷🇺 Russian (RU)
**Заголовок: Улучшенная защита архитектуры и рефакторинг интерфейса v4.0**

**Основные изменения:**
*   **Умная валидация IPK:** Реализована строгая проверка совместимости архитектур (`SRC_ARCH`) при импорте. Теперь скрипт блокирует установку пакетов с неверным эндианностью (например, MIPS BE на LE) для предотвращения поломки прошивки.
*   **Авто-патчер профилей:** В `_Builder.bat` интегрирован идемпотентный блок инициализации, который автоматически анализирует старые профили и дописывает в них `SRC_ARCH` на основе расширенной таблицы соответствия таргетов (Target/Subtarget).
*   **Рекурсивное обнаружение прошивок:** Исправлены индикаторы готовности `OI` (Image) и `OS` (Source). Теперь сканер выполняет глубокий поиск во вложенных папках `bin/targets/`, корректно отображая наличие готовых бинарников.
*   **Оптимизация Makefile:**
    *   Исправлен баг "двойного шебанга" в блоке `postinst`.
    *   Улучшен маппинг зависимостей (например, автоматическая замена `libnetfilter-queue1` на `libnetfilter-queue`).
    *   Добавлены автоматические правила `chmod +x` для всех скриптов и бинарников внутри `install` секции.
*   **Обновление UI/UX:**
    *   Из всех меню удалено отображение расширения `.conf` для чистоты интерфейса.
    *   В главном списке добавлена колонка с архитектурой профиля.
    *   Добавлен расширенный лог инициализации (версии Docker, Compose и путь к проекту).
*   **Мастер профилей:** Логика умного определения архитектуры интегрирована в `create_profile.ps1`.

---

### 🇺🇸 English (EN)
**Headline: Update v4.0: Smart Architecture Protection & UI Refactor**

**Core Changes:**
*   **Strict IPK Validation:** Implemented mandatory architecture compatibility checks (`SRC_ARCH`) during import. The system now blocks cross-architecture packages (e.g., MIPS Big Endian vs Little Endian) to prevent firmware bricks.
*   **Idempotent Profile Patcher:** Integrated an initialization block in `_Builder.bat` that automatically scans and assigns `SRC_ARCH` to existing profiles using an advanced Target/Subtarget mapping table.
*   **Recursive Firmware Detection:** Fixed `OI` (Image) and `OS` (Source) status indicators. The scanner now performs recursive searches in `bin/targets/` subdirectories to accurately detect compiled binaries.
*   **Makefile Engine Optimization:**
    *   Fixed "double shellbang" redundancy in the `postinst` block.
    *   Enhanced dependency mapping (e.g., auto-resolving `libnetfilter-queue1` to `libnetfilter-queue`).
    *   Added automated `chmod +x` rules for scripts and binaries within the `install` section.
*   **UI/UX Improvements:**
    *   Stripped `.conf` extensions from all menus for a cleaner look.
    *   Added a dedicated Architecture column in the main profile list.
    *   Extended initialization logs (displaying Docker/Compose versions and project root path).
*   **Profile Wizard:** Integrated smart architecture mapping into the `create_profile.ps1` workflow.

UPD:
Добавлен WIFI EN patch.

UPD:
Linux Alpha

---
**Commit message suggestion:**
`feat: add smart arch validation, auto-patcher, and UI refactor v4.0`

---

## What's Changed
* Locale EN added by @iqubik in https://github.com/iqubik/routerFW/pull/11


**Full Changelog**: https://github.com/iqubik/routerFW/compare/3.8...3.9


## ========== TAG: 4.0 ==========

title:	< 4.0 Win+Lin RU+EN >
tag:	4.0
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-11T00:10:22Z
published:	2026-01-11T09:48:18Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.0
asset:	routerFW_LinuxDockerBuilder_v11.01.2026_03-09.tar.gz
asset:	routerFW_WinDockerBuilder_v11.01.2026_03-09.zip
--
# 🚀 Release: routerFW v11.01.2026 (The Linux Dawn)

### [RU] Описание релиза
**routerFW** Начиная с этого момента, мы переходим на систему версий, основанную на датах, и представляем самое неожиданное обновление — полную поддержку Linux.

#### 🐧 Портирование на SH (Alpha 1)
Главная новинка этого релиза — появление портов всех основных скриптов на **Bash (.sh)**. 
- Теперь `_Builder.sh`, `_packer.sh` и `_unpacker.sh` доступны «из коробки».
- Функционал полностью идентичен Windows-версии (.bat).
- Код оптимизирован для работы в нативных Linux-окружениях и Docker-контейнерах.

#### 🗺 Дорожная карта проекта (Путь версии 4.0)
Проект прошел большой путь, эволюционировав из простого частного скрипта сборщика в комплексный инструмент:
1.  **Основание:** Запуск Image Builder для быстрой кастомизации готовых образов.
2.  **Глубокая модификация:** Внедрение Source Builder и технологии **Vermagic Hack**, позволившей совместить официальные репозитории с кастомными ядрами.
3.  **Интеллектуальный импорт:** Разработка системы **IPK Injection** для вшивания бинарных пакетов в сборки из исходников.
4.  **Юзабилити:** Появление **Profile Wizard** (интерактивного помощника) и системы **Maintenance** для умной очистки кэша.
5.  **Кроссплатформенность:** Сегодняшний релиз закрывает потребность в поддержке Linux, делая инструмент по-настоящему универсальным.
6.  **Двуязычность:** Проект полноценно поддерживает как русский так и английский языки.
---

### [EN] Release Description
Welcome to the new era of **routerFW**! Starting now, we are switching to a date-based versioning system and introducing the most anticipated update — full Linux support.

#### 🐧 SH Port (Alpha 1)
The highlight of this release is the porting of all core scripts to **Bash (.sh)**.
- `_Builder.sh`, `_packer.sh`, and `_unpacker.sh` are now available out of the box.
- The functionality is a 1:1 match with the Windows (.bat) version.
- Optimized for native Linux environments and Docker containers.

#### 🗺 Project Roadmap (The Path to v4.0)
The project has come a long way, evolving from a simple builder into an intelligent toolkit:
1.  **Foundation:** Launch of Image Builder for rapid customization of pre-built images.
2.  **Deep Modification:** Introduction of Source Builder and **Vermagic Hack** technology, allowing official repositories to work with custom kernels.
3.  **Smart Import:** Development of **IPK Injection** for embedding binary packages into source-based builds.
4.  **Usability:** Introduction of the **Profile Wizard** (interactive assistant) and the **Maintenance** system for smart cache management.
5.  **Cross-platform:** Today's release fulfills the need for Linux support, making the tool truly universal.

---

### 🛠 Quick Start / Быстрый старт
**Linux:**
```bash
chmod +x *.sh system/*.sh
./_Builder.sh
```
**Windows:**
```cmd
_Builder.bat
```
---
*Generated by routerFW Release Team. Shaping the future of OpenWrt automation.*

## What's Changed
* Autoipk src by @iqubik in https://github.com/iqubik/routerFW/pull/12
* Sh version by @iqubik in https://github.com/iqubik/routerFW/pull/13


**Full Changelog**: https://github.com/iqubik/routerFW/compare/3.9...4.0


## ========== TAG: 4.02 ==========

title:	4.02
tag:	4.02
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-12T16:20:30Z
published:	2026-01-12T16:23:14Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.02
asset:	routerFW_LinuxDockerBuilder_v12.01.2026_22-28.tar.gz
asset:	routerFW_WinDockerBuilder_v12.01.2026_22-28.zip
--
###  Changelog v4.02 (RU)

**Синхронизация логики `_Builder.bat` и `_Builder.sh` и визуальные улучшения:**

####  Умная синхронизация конфигурации (Source Builder)
- **Интеграция Menuconfig:** Добавлена возможность автоматического переноса настроек из интерактивного `Menuconfig` прямо в файл профиля (`.conf`).
- **Чистый синтаксис:** Переменная `SRC_EXTRA_CONFIG` теперь сохраняется в многострочном формате без использования обратных слэшей (`\`). Это обеспечило полную совместимость с комментариями `# ... is not set` и устранило ошибки парсинга.
- **Безопасная архивация:** Все временные конфиги теперь сохраняются с уникальными метками времени (`applied_config_YYYYMMDD_HHMMSS.bak`), что исключает потерю истории удачных настроек.

####  Визуальные изменения и UI
- **Индикатор «M» (Manual Config):** В сканер ресурсов добавлен новый статус. Строка ресурсов теперь выглядит как `[F P S M | OI OS]`, где **M** (ярко-зеленый) указывает на наличие активного файла ручной настройки.
- **Стабилизация меню:** В Linux-версии (`_Builder.sh`) исправлена проблема «сползания» интерфейса вверх и оптимизирован процесс выхода.
- **Обновленная легенда:** В главное меню добавлена расшифровка нового индикатора для обеих локализаций.

####  Интернационализация (i18n)
- **Англоязычный Unpacker:** Все системные сообщения в логах распаковщика ресурсов (`unpacker`) переведены с русского на английский язык для обеспечения понятности процесса при международном использовании.
- **Двуязычные диалоги:** Синхронизированы тексты вопросов и подтверждений в обоих скриптах для RU и EN режимов.

---

###  Changelog v4.02 (EN)

**Logic synchronization between `_Builder.bat` and `_Builder.sh` plus UI enhancements:**

####  Smart Configuration Sync (Source Builder)
- **Menuconfig Integration:** Added automatic transfer of settings from interactive `Menuconfig` directly into the profile file (`.conf`).
- **Clean Syntax:** The `SRC_EXTRA_CONFIG` variable is now saved in a multi-line format without backslashes (`\`). This ensures full compatibility with `# ... is not set` comments and eliminates parsing errors.
- **Safe Archiving:** All temporary configs are now saved with unique timestamps (`applied_config_YYYYMMDD_HHMMSS.bak`), preventing loss of successful configuration history.

####  UI and Visual Improvements
- **«M» Indicator (Manual Config):** A new status has been added to the profile scanner. The resource string now looks like `[F P S M | OI OS]`, where **M** (bright green) indicates the presence of an active manual configuration file.
- **Menu Stability:** In the Linux version (`_Builder.sh`), fixed the interface shifting issue and optimized the exit routine.
- **Updated Legend:** The main menu now includes the new indicator's description for both localizations.

####  Internationalization (i18n)
- **English-friendly Unpacker:** All system messages in the resource unpacker logs have been manually translated from Russian to English to ensure clarity for global users.
- **Bilingual Dialogs:** Prompt texts and confirmations have been synchronized in both scripts for RU and EN modes.



## What's Changed
* Souce cfg by @iqubik in https://github.com/iqubik/routerFW/pull/14
**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.0...4.02


## ========== TAG: 4.04_hotfix ==========

title:	4.08_hotfix
tag:	4.04_hotfix
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-13T14:06:39Z
published:	2026-01-13T14:07:51Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.04_hotfix
asset:	routerFW_LinuxDockerBuilder_v14.01.2026_00-52.tar.gz
asset:	routerFW_WinDockerBuilder_v14.01.2026_00-53.zip
--
# Release 4.08

### RU | Основные изменения
Обновление с версии 4.02 до 4.08 фокусируется на исправлении ошибок скачивания, автоматизации настройки и улучшении интерфейса.

**1. Скрипт управления (`_Builder.`)**
*   **Новые индикаторы:** В меню добавлен символ `H` (наличие `hooks.sh`) и уточнено описание `M` (ручной конфиг).
*   **Умный поиск:** Индикаторы готовых прошивок теперь видят любые файлы результатов (не только `.bin/.img`), что важно для специфичных образов.
*   **Стабильность:** Переработан импорт настроек из `manual_config` в профиль через PowerShell — теперь без ошибок в форматировании.

**2. Логика Docker (ImageBuilder)**
*   **Исправлен баг загрузки:** Удалена сложная система ожидания между контейнерами. Теперь, если загрузка прервана, старый `.tmp` файл просто удаляется и закачка начинается заново. Это исключает "вечное ожидание".

**3. Мастер профилей (`create_profile.`)**
*   **Авто-конфиг:** Скрипт теперь сам заполняет `SRC_EXTRA_CONFIG` базовыми параметрами архитектуры. Новичкам больше не нужно вручную искать настройки таргета для Source Builder.
*   **Чистые списки:** Пакеты теперь автоматически сортируются и очищаются от дублей.
*   **Кодировка:** Принудительное использование **UTF-8 без BOM** для совместимости с Linux.

**4. Поддержка устройств**
*   Добавлен актуальный профиль для **FriendlyARM NanoPi R3S**.

---

### EN | Key Changes
Version 4.08 improves download reliability, automates profile creation, and cleans up the UI.

**1. Orchestrator (`_Builder.`)**
*   **New Indicators:** Added `H` symbol to show if `hooks.sh` is present; clarified `M` for manual config.
*   **Better Detection:** Output indicators now track all result files (e.g., `.itb`), not just standard `.bin` images.
*   **Reliability:** PowerShell-based config merging replaced buggy line-by-line parsing.

**2. Docker Environment (ImageBuilder)**
*   **Fixed Stuck Downloads:** Removed complex "wait for other container" logic. The system now simply clears stale `.tmp` files and retries, preventing deadlocks.

**3. Profile Wizard (`create_profile.`)**
*   **Automation:** Automatically generates `SRC_EXTRA_CONFIG` with target-specific options. No more manual searching for base arch settings.
*   **Cleanup:** Package lists are now sorted and de-duplicated automatically.
*   **Encoding:** Switched to **UTF-8 (no BOM)** to prevent Linux compatibility issues.

**4. Hardware Support**
*   Added a new optimized profile for **FriendlyARM NanoPi R3S**.

**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.02...4.04_hotfix


## ========== TAG: 4.09 ==========

title:	4.09
tag:	4.09
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-14T20:47:23Z
published:	2026-01-14T21:00:47Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.09
asset:	routerFW_LinuxDockerBuilder_v15.01.2026_01-41.tar.gz
asset:	routerFW_WinDockerBuilder_v15.01.2026_01-41.zip
--
# CHANGELOG: routerFW Universal Builder

## [4.09] — 2026-01-14

### 🇷🇺 Русский

#### Добавлено
- **Скрипты-оркестраторы:** Вся логика сборки вынесена в `system/ib_builder.sh` и `system/src_builder.sh`.
- **Профили и шаблоны:**
  - Добавлена поддержка **NanoPi R3S**.
  - Мастера создания профилей (`.sh`/`.ps1`) теперь генерируют расширенные шаблоны с примерами и комментариями.
- **Документация:** Добавлен `audit.md` (анализ архитектуры) и английская версия лицензии `LICENSE.en`.

#### Изменено
- **Рефакторинг:** Логика сборки полностью отделена от Docker-конфигураций для модульности и чистоты кода.
- **Улучшение мастеров:** Скрипты `create_profile` теперь динамически формируют блок `SRC_EXTRA_CONFIG`.
- **Локализация:** Основной файл `LICENSE` переведен на русский язык.
- **Стандартизация:** Конфигурации профилей приведены к многострочному читаемому виду.
- **Версия:** Проект обновлен до v4.09.

#### Исправлено
- **Стабильность Docker:** Оптимизирован цикл перезапуска контейнеров (актуально для WSL) для предотвращения блокировок файлов.
- **Сеть:** Повышена устойчивость `wget` и `git` к нестабильному соединению (добавлены ретраи и таймауты).
- **Кросс-платформенность:**
  - Исправлены ошибки кодировки (UTF-8 без BOM) и символов конца строки (`\r`) между Windows и Linux.
  - Решена проблема с `credsStore` в Docker.
- **Логика завершения:** Успех сборки теперь определяется по наличию любого артефакта в папке вывода.

#### Удалено
- Устаревшая функция авто-включения Wi-Fi.
- Громоздкие inline-скрипты из YAML-файлов Docker.

---

### 🇺🇸 English

#### Added
- **Build Orchestrators:** Dedicated `system/ib_builder.sh` and `system/src_builder.sh` for streamlined build logic.
- **Profiles & Templates:**
  - Added **NanoPi R3S** support.
  - Profile wizards (`.sh`/`.ps1`) now generate detailed templates with best practices and examples.
- **Docs & Legal:** Added `audit.md` (architectural review) and `LICENSE.en`.

#### Changed
- **Architectural Refactoring:** Decoupled build logic from Docker Compose files into standalone scripts for better maintainability.
- **Improved Wizards:** `create_profile` scripts now dynamically generate robust `SRC_EXTRA_CONFIG` blocks.
- **Localization:** Main `LICENSE` file updated to Russian; English version moved to `LICENSE.en`.
- **Code Style:** Standardized `SRC_EXTRA_CONFIG` to a readable multi-line format.
- **Version:** Bumped to v4.09.

#### Fixed
- **Docker Reliability:** Improved container lifecycle management to prevent file-locking issues in WSL.
- **Network Resilience:** Added aggressive retries and timeouts for `wget` and `git` operations.
- **Cross-Platform Compatibility:**
  - Fixed line endings (`\r`) and encoding issues (UTF-8 no BOM) between Windows/Linux.
  - Patched Docker `credsStore` errors in specific environments.
- **Build Detection:** Success is now triggered by the presence of any output file, improving detection accuracy.

#### Removed
- Obsolete auto-WiFi activation script.
- Legacy embedded shell logic (here-docs) in Docker YAML files.

## What's Changed
* Compose logic by @iqubik in https://github.com/iqubik/routerFW/pull/16
**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.02...4.09


## ========== TAG: 4.1 ==========

title:	4.1
tag:	4.1
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-16T00:39:07Z
published:	2026-01-16T00:41:18Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.1
asset:	routerFW_LinuxDockerBuilder_v16.01.2026_04-23.tar.gz
asset:	routerFW_WinDockerBuilder_v16.01.2026_03-44.zip
--
> fix auto SRC_EXTRA_CONFIG='
> CONFIG_TARGET_OPTIMIZATION="-O2 -pipe -mcpu=generic"
> '

# 📋 RouterFW v4.1

Это обновление сосредоточено на надежности и удобстве. Переработали внутренние механизмы, чтобы сборка прошивки была предсказуемой и стабильной.

### 🚀 Главные улучшения

*   **Система самовосстановления:** Сборщик теперь автоматически устраняет последствия предыдущих экспериментов с кодом. Каждая новая сборка без специальных скриптов гарантированно начинается с «чистого листа», исключая скрытые ошибки.
*   **Улучшенная обработка настроек:** Исправлены проблемы с чтением сложных конфигураций. Ваши пользовательские настройки теперь передаются в прошивку абсолютно корректно.
*   **Умное ускорение и Wi-Fi:** Обновленный скрипт `hooks.sh` экономит время, очищая кэш только при реальной необходимости. Также добавлена функция автоматического включения Wi-Fi при первом запуске роутера.
*   **Стабильность на Windows:** Улучшена работа Docker внутри WSL. Исправлены ошибки блокировки файлов, которые могли прерывать процесс сборки.
*   **Прочее:** Обновлена документация и профили устройств (включая NanoPi R3S).

---

# 📋 Changelog v4.1

This update focuses on reliability and usability. We have reworked internal mechanisms to make firmware building predictable and stable.

### 🚀 Key Improvements

*   **Self-Healing System:** The builder now automatically cleans up after previous code experiments. Every new build without special scripts starts from a guaranteed "clean slate," eliminating hidden errors.
*   **Improved Configuration Parsing:** Fixed issues with reading complex settings. Your custom configurations are now applied to the firmware correctly.
*   **Smart Speed & Wi-Fi:** The updated `hooks.sh` script saves time by clearing the cache only when absolutely necessary. We also added a feature to automatically enable Wi-Fi on the first router boot.
*   **Windows Stability:** Improved Docker performance within WSL. Fixed file locking errors that could interrupt the build process.
*   **Misc:** Updated documentation and device profiles (including NanoPi R3S).

## What's Changed
* fix by @iqubik in https://github.com/iqubik/routerFW/pull/17
**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.09...4.1


## ========== TAG: 4.11 ==========

title:	4.11
tag:	4.11
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-17T18:17:26Z
published:	2026-01-17T18:34:03Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.11
asset:	routerFW_LinuxDockerBuilder_v18.01.2026_16-07.tar.gz
asset:	routerFW_WinDockerBuilder_v18.01.2026_16-04.zip
--
# v4.11 HotFix

### 🇷🇺 Русский
Исправление совместимости с Ubuntu 24.04 и обновление Legacy сборщиков

***   **Ошибка при создании профиля:** Устаревший формат SRC_EXTRA_CONFIG изменён.**
*   **HOTFIX:** Решена критическая ошибка `GCC appears to be broken` при запуске `menuconfig` и сборке на новых ядрах Linux (Ubuntu 24.04, WSL2). В параметры Docker добавлен флаг `seccomp=unconfined`.
*   **Legacy:** Исправлена сборка контейнеров на базе Ubuntu 18.04. Репозитории переключены на `old-releases`, так как ОС достигла EOL.
*   **Git:** Устранена ошибка `fatal: detected dubious ownership` при работе с git внутри контейнера.
*   **UI:** Улучшено меню выбора профилей в `_Builder.sh`.

---

### 🇺🇸 English
Ubuntu 24.04 Compatibility Fix & Legacy Builders Update

***   **Profile Wizard profile error** Change format SRC_EXTRA_CONFIG.**
*   **HOTFIX:** Resolved the critical `GCC appears to be broken` error during `menuconfig` and build processes on modern Linux kernels (Ubuntu 24.04, WSL2). Added `seccomp=unconfined` flag to Docker parameters.
*   **Legacy:** Fixed container builds based on Ubuntu 18.04. Repositories switched to `old-releases` as the OS reached EOL.
*   **Git:** Fixed `fatal: detected dubious ownership` error when using git inside the container.
*   **UI:** Improved profile selection menu in `_Builder.sh`.

**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.1...4.11


## ========== TAG: 4.12 ==========

title:	4.12
tag:	4.12
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-19T18:19:20Z
published:	2026-01-19T18:20:50Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.12
asset:	routerFW_LinuxDockerBuilder_v20.01.2026_00-36.tar.gz
asset:	routerFW_WinDockerBuilder_v19.01.2026_21-14.zip
--
### EN

**Version 4.12**

A major update focused on improving the reliability, security, and reproducibility of Source-mode builds. The configuration saving mechanism has been completely redesigned, and the build environment has been stabilized.

**Key Changes:**

*   **Redesigned `menuconfig` Handling:** The logic for processing and saving configurations from `make menuconfig` (`SRC_EXTRA_CONFIG`) has been completely overhauled in `_Builder.bat` and `_Builder.sh`. The new scripts are significantly more robust and correctly handle complex configurations, including those with special characters and different quoting styles.
*   **Enhanced Build Reproducibility:** The `SRC_EXTRA_CONFIG` variable in all major profiles has been populated with a full list of configuration flags. This effectively "locks in" a known-good configuration for each profile, dramatically improving build consistency and reducing reliance on manual `menuconfig` sessions.
*   **Improved Security:** The `--security-opt seccomp=unconfined` flag has been removed from `docker-compose` commands. The build system now operates without requiring this lowered security setting.
*   **Legacy Environment Fix:** The Dockerfile for legacy builds (`system/src.dockerfile.legacy`) has been corrected to point to the official Ubuntu 18.04 repositories, resolving `apt-get` errors and restoring the ability to build older firmware versions.
*   **Cleanup:** The packer scripts (`_packer.sh`, `_packer.bat`) have been updated to include a more streamlined set of default profiles.

---

### RU

**Версия 4.12**

Ключевое обновление, направленное на повышение надежности, безопасности и воспроизводимости сборок в режиме "из исходников". Механизм сохранения конфигураций был полностью переработан, а окружение сборки — стабилизировано.

**Основные изменения:**

*   **Переработанный механизм `menuconfig`:** Логика обработки и сохранения конфигураций из `make menuconfig` (`SRC_EXTRA_CONFIG`) была полностью переписана в `_Builder.bat` и `_Builder.sh`. Новые скрипты стали значительно надежнее и корректно обрабатывают сложные конфигурации, включая спецсимволы и разные типы кавычек.
*   **Повышенная воспроизводимость сборок:** Переменная `SRC_EXTRA_CONFIG` во всех основных профилях была заполнена полным списком флагов конфигурации. Это эффективно "замораживает" проверенную конфигурацию для каждого профиля, кардинально улучшая консистентность сборок и снижая зависимость от ручных сессий `menuconfig`.
*   **Улучшенная безопасность:** Флаг `--security-opt seccomp=unconfined` был удален из команд `docker-compose`. Система сборки теперь работает без необходимости в понижении настроек безопасности.
*   **Исправление для Legacy-окружения:** Dockerfile для старых сборок (`system/src.dockerfile.legacy`) был исправлен и теперь указывает на официальные репозитории Ubuntu 18.04, что решает ошибки `apt-get` и восстанавливает возможность сборки старых версий прошивок.
*   **Оптимизация:** Скрипты-упаковщики (`_packer.sh`, `_packer.bat`) были обновлены и теперь включают более релевантный набор профилей по умолчанию.


**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.11...4.12


## ========== TAG: 4.20 ==========

title:	4.20
tag:	4.20
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-01-20T19:56:52Z
published:	2026-01-20T19:58:58Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.20
asset:	routerFW_LinuxDockerBuilder_v20.01.2026_22-54.tar.gz
asset:	routerFW_WinDockerBuilder_v20.01.2026_22-54.zip
--
# 🇺🇸 v4.20

Major update focused on stability, bug fixes, and feature parity between Windows and Linux scripts. Bumped version to 4.20.

### Key Changes

*   **Fixed Docker Volume Locking:** Rewrote the cleanup logic. The script now force-stops containers before removing volumes, fixing the persistent "volume is in use" error.
*   **Script Parity:** `_Builder.sh` (Linux) and `_Builder.bat` (Windows) now share the exact same functionality and logic.
*   **WSL/Linux Improvements:**
    *   Fixed file permissions: The script now `chown`s artifacts back to the user. No more `sudo` needed to move or delete output files.
    *   Fixed mounting paths: Now creates absolute paths to prevent mounting errors in WSL.
*   **UI & Logging:**
    *   Refactored console output with better color coding for readability.
    *   Bulk build mode (`[A]`) now shows the execution time for each task.
    *   Added a resource summary dashboard before entering the config editor (`[E]`).
*   **Bug Fixes:**
    *   Fixed `menuconfig` generation on Windows for device names containing hyphens (e.g., `xiaomi-4a-gigabit`).
    *   Updated `.ipk` importer: Automatically replaces `libopenssl1.1` dependency with `libopenssl` for compatibility with newer OpenWrt versions.
    *   Better `Ctrl+C` handling: properly shuts down child Docker processes upon interruption.

---

# 🇷🇺 v4.20

Крупное обновление, направленное на исправление ошибок и синхронизацию работы скриптов между Windows и Linux. Перешли на версию 4.20 (вместо 4.12).

### Основные изменения

*   **Исправлена блокировка Docker-томов:** Полностью переписан механизм очистки (`cleanup_wizard`). Скрипт теперь принудительно останавливает контейнеры перед удалением томов. Это решает частую ошибку `"volume is in use"`.
*   **Синхронизация скриптов:** Логика работы `_Builder.sh` (Linux) и `_Builder.bat` (Windows) теперь идентична.
*   **Исправления для WSL/Linux:**
    *   Скрипт теперь возвращает права текущему пользователю (`chown`) на созданные файлы. Больше не нужно использовать `sudo` для работы с готовыми прошивками.
    *   Используются абсолютные пути при монтировании, что решает проблемы совместимости в WSL.
*   **Интерфейс и логи:**
    *   Переработан вывод в консоль: добавлена цветовая разметка для читаемости.
    *   В режиме массовой сборки (`[A]`) теперь отображается точное время выполнения каждого этапа.
    *   Перед редактированием конфига (`[E]`) выводится сводка о наличии папок с ресурсами.
*   **Исправления багов:**
    *   Исправлена ошибка в Windows при сборке устройств с дефисом в названии (например, `xiaomi-4a-gigabit`).
    *   Скрипт импорта пакетов (`import_ipk`) теперь автоматически меняет зависимость `libopenssl1.1` на `libopenssl` для совместимости с новыми версиями OpenWrt.
    *   Корректная обработка прерывания скрипта через `Ctrl+C` (не оставляет "сирот" в Docker).

## What's Changed
* Ref4.2 by @iqubik in https://github.com/iqubik/routerFW/pull/19
**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.12...4.20


## ========== TAG: 4.22 ==========

title:	Release v4.22 (RAX3000M eMMC Optimized)
tag:	4.22
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-02-05T15:55:16Z
published:	2026-02-05T15:57:06Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.22
asset:	routerFW_WinDockerBuilder_v06.02.2026_01-07.zip
--
# 🚀 Release v4.22 (RAX3000M eMMC Optimized)

## 🇷🇺 Russian (Русский)

### 🛠 Основные изменения сборщика (_Builder.bat)
*   **Версия:** Обновлена до `4.22`.
*   **Интерактивный режим:** Добавлена возможность войти в командную оболочку (`/bin/bash`) контейнера после завершения процесса в режиме `SOURCE`. Теперь при ошибке или для отладки можно остаться внутри контейнера, ответив `y` на запрос.
*   **Исправления интерфейса:** Отключено скрытие курсора через PowerShell, что могло вызывать ошибки на некоторых системах.

### ⚙️ Изменения в профилях (RAX3000M eMMC)
*   **Целевая архитектура:** Убрана поддержка `MULTI_PROFILE`. Конфигурация теперь строго зафиксирована на `cmcc_rax3000m-emmc-mtk` для исключения конфликтов при сборке.
*   **Версионирование прошивки:**
    *   Включены опции `CONFIG_VERSIONOPT`.
    *   Добавлены метаданные релиза: версия `iq1.1-eMMC`, ссылки на поддержку (4pda), авторство и описание продукта (`MTK-IWRT`).
*   **Пакетная база:**
    *   Добавлены утилиты для работы с дисками: `fdisk`, `cfdisk`, `gdisk`, `tune2fs`, `resize2fs`.
    *   Оптимизирован список пакетов модемов (`MODEM_PKGS`): убран конфликтующий драйвер `kmod-usb-net-qmi-wwan` (оставлены специфичные варианты).
    *   Явно включены базовые зависимости: `bash`, `curl`, `htop`, `gzip`, `btrfs-progs` и др.
*   **Сетевые настройки:**
    *   Включен `CONFIG_TARGET_DEFAULT_LAN_IP_FROM_PREINIT`.
    *   Маска подсети по умолчанию изменена на `255.255.0.0`.
*   **Оптимизация:** Включен `CCACHE` и `IMAGEOPT` для ускорения повторных сборок и оптимизации образов.

### 🔧 Скрипты и хуки (hooks.sh)
*   **Vermagic Hack 2.0:**
    *   Полностью переработана логика получения хэша ядра (Kernel Hash).
    *   Для ветки https://github.com/padavanonly/immortalwrt-mt798x-6.6 `openwrt-24.10-6.6` добавлен специальный механизм получения хэша с зеркала `immortalwrt.kyarucloud.moe`, так как официальный манифест может отсутствовать.
    *   Улучшена обработка ошибок 404 при запросе манифестов.
    *   Добавлена цветовая индикация найденного хэша в логах.
*   **Архивация:** Старый скрипт хуков сохранен как `scripts/old_hooks.sh` для истории.

---

## 🇺🇸 English

### 🛠 Builder Core Changes (_Builder.bat)
*   **Version:** Bumped to `4.22`.
*   **Interactive Shell:** Added support for entering the container shell (`/bin/bash`) after the build process in `SOURCE` mode. You can now choose to stay inside the container for debugging by answering `y` at the prompt.
*   **UI Fixes:** Disabled the PowerShell cursor visibility command which caused issues on some environments.

### ⚙️ Profile Updates (RAX3000M eMMC)
*   **Target Architecture:** Removed `MULTI_PROFILE` support. The configuration is now strictly pinned to `cmcc_rax3000m-emmc-mtk` to prevent build conflicts.
*   **Firmware Versioning:**
    *   Enabled `CONFIG_VERSIONOPT`.
    *   Added release metadata: version `iq1.1-eMMC`, support links, authorship, and product description (`MTK-IWRT`).
*   **Package Management:**
    *   Added disk manipulation tools: `fdisk`, `cfdisk`, `gdisk`, `tune2fs`, `resize2fs`.
    *   Optimized modem packages (`MODEM_PKGS`): removed generic `kmod-usb-net-qmi-wwan` to avoid conflicts.
    *   Explicitly included essential dependencies: `bash`, `curl`, `htop`, `gzip`, `btrfs-progs`, etc.
*   **Network Settings:**
    *   Enabled `CONFIG_TARGET_DEFAULT_LAN_IP_FROM_PREINIT`.
    *   Default subnet mask set to `255.255.0.0`.
*   **Optimization:** Enabled `CCACHE` and `IMAGEOPT` for faster rebuilds and optimized images.

### 🔧 Scripts & Hooks (hooks.sh)
*   **Vermagic Hack 2.0:**
    *   Completely overhauled the Kernel Hash fetching logic.
    *   Added a fallback mechanism for the https://github.com/padavanonly/immortalwrt-mt798x-6.6 `openwrt-24.10-6.6` branch to fetch the hash from the `immortalwrt.kyarucloud.moe` mirror (bypassing missing official manifests).
    *   Improved handling of 404 errors when fetching manifests.
    *   Added colored output for the detected hash in logs.
*   **Archiving:** The old hook script has been backed up as `scripts/old_hooks.sh`.


## ========== TAG: 4.3 ==========

title:	4.3 src patch support
tag:	4.3
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-02-06T13:52:30Z
published:	2026-02-06T13:54:00Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.3
asset:	routerFW_WinDockerBuilder_v06.02.2026_16-50.zip
--
## 🚀 Версия 4.3: Система патчей исходного кода

Это обновление вводит мощный и гибкий механизм для модификации исходного кода OpenWrt, а также сопутствующие улучшения интерфейса и документации.

### ✨ Новая функция: Система патчей исходного кода (`custom_patches`)
-   **Что это дает:** Позволяет пользователям легко модифицировать исходный код OpenWrt перед компиляцией. Теперь можно изменять `Makefile`, добавлять `dts`-файлы или заменять любые другие файлы в исходниках, просто поместив их в папку `custom_patches/<имя_профиля>`, сохраняя оригинальную структуру директорий. Эта система значительно упрощает кастомизацию прошивок.
-   **Как это работает:** Система действует как "зеркальный оверлей". Файлы из `custom_patches` копируются поверх исходного кода перед запуском компиляции.
-   **Кросс-платформенная надежность:** Встроенная утилита `dos2unix` автоматически исправляет окончания строк Windows (CRLF), что предотвращает ошибки сборки при редактировании файлов в Windows.

### 🖥️ Улучшения интерфейса
-   В главном меню добавлен новый индикатор **`X`** (Patches), который сигнализирует о наличии патчей для профиля, делая управление сборками более наглядным.

### 📚 Обновление документации
-   **Добавлен "Урок 5"**: Создано новое подробное руководство по использованию системы патчей, доступное на русском (`docs/05-patch-sys.md`) и английском (`docs/05-patch-sys.en.md`) языках.
-   **Обновлены README**: Главные файлы `README.md` и `README.en.md` были дополнены информацией о новой функции.
-   **Обновлены индексы**: Файлы `docs/index.md` и `docs/index.en.md` теперь включают ссылки на новое руководство.

---
---

## 🚀 Version 4.3: Source Code Patching System

This update introduces a powerful and flexible mechanism for modifying OpenWrt source code, along with related UI and documentation improvements.

### ✨ New Feature: Source Code Patching System (`custom_patches`)
-   **What it provides:** Allows users to easily modify the OpenWrt source code before compilation. You can now change a `Makefile`, add a `.dts` file, or replace any other file in the source tree by simply placing it in the `custom_patches/<profile_name>` folder, preserving the original directory structure. This system significantly simplifies firmware customization.
-   **How it works:** The system functions as a "mirror overlay." Files from `custom_patches` are copied over the source code before the compilation begins.
-   **Cross-Platform Reliability:** The built-in `dos2unix` utility automatically fixes Windows line endings (CRLF), preventing build errors when files are edited on Windows.

### 🖥️ UI Enhancements
-   A new **`X`** (Patches) indicator has been added to the main menu, signaling the presence of patches for a profile and making build management more intuitive.

### 📚 Documentation Update
-   **Added "Lesson 5"**: A new detailed guide on using the patching system has been created, available in both Russian (`docs/05-patch-sys.md`) and English (`docs/05-patch-sys.en.md`).
-   **Updated READMEs**: The main `README.md` and `README.en.md` files have been updated with information about the new feature.
-   **Updated Indexes**: The `docs/index.md` and `docs/index.en.md` files now include links to the new guide.


## What's Changed
* Patch by @iqubik in https://github.com/iqubik/routerFW/pull/23


**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.22...4.3


## ========== TAG: 4.31 ==========

(нет GitHub Release для тега 4.31 или ошибка gh)



## ========== TAG: 4.32 ==========

title:	4.32 menuconfig, patches, libxcryptm, rax3000m
tag:	4.32
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-02-11T22:54:28Z
published:	2026-02-11T23:33:36Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.32
asset:	routerFW_LinuxDockerBuilder_v16.02.2026_17-31.tar.gz
asset:	routerFW_WinDockerBuilder_v15.02.2026_13-21.zip
--
short:
speed up menuconfig start
libxcryptm hooks.sh fix 1,4
rax3000m profile updated + imagebuilder git padavanonly
update linux version

---

# 🇷🇺 Russian Description

## 🚀 Обновление сборщика v4.32

Данный релиз включает обновление основного скрипта сборки до версии **4.32**, значительные улучшения в ImageBuilder, поддержку новых форматов архивов и адаптацию под компиляторы GCC 13+.

### ✨ Основные изменения в Builder (_Builder.sh v4.32)
*   **Кастомные патчи:** Добавлена поддержка `custom_patches/$p_id` и переменная `HOST_PATCHES_DIR`. В списке профилей теперь отображается индикатор **[X]**, если применяются патчи.
*   **Интерактивность:** Добавлена опция **"Stay in Container"** — возможность остаться в интерактивной оболочке контейнера после завершения сборки (для отладки).
*   **Управление кэшем:** Новый пункт меню для очистки индексов пакетов (`Clean Package Index (tmp)`).
*   **Умное определение:** Внедрено `Smart Device Detection` и учет `SRC_EXTRA_CONFIG`.
*   **Исправления прав доступа:** Улучшена логика создания выходных директорий и назначения прав (fix permissions).

### 📦 Улучшения Image Builder (System)
*   **Обработка URL:** Исправлено определение имени файла из ссылок (игнорируются query-параметры вроде `?download=`).
*   **Поддержка форматов:** Добавлена нативная поддержка распаковки **.zst** и **.xz** архивов.
*   **Репозитории:** Улучшен парсинг `CUSTOM_REPOS` (игнорирование пустых строк, удаление лишних слэшей, проверка `repositories.conf`).
*   **Стабильность:** Количество попыток сборки оптимизировано (3 → 2).

### 🛠 Технические исправления и Инфраструктура
*   **Совместимость с GCC 13+:** В `hooks.sh` добавлен автоматический патч для `libxcrypt` (`-Wno-error=format-nonliteral`), устраняющий ошибки сборки на свежих дистрибутивах Linux.
*   **Git LFS:** Обновлен `.gitattributes`. Теперь файлы `*.zst`, `*.tar`, `*.gz`, `*.bin`, `*.7z` корректно обрабатываются через LFS.
*   **Профили:** Существенно переработан конфиг `rax3000m_emmc_test_new`.
*   **Артефакты:** Обновлены Docker-билдеры (Win/Linux) и добавлены новые ImageBuilder-пакеты (v1.21 - v1.23).

---

# 🇬🇧 English Description

## 🚀 Builder Update v4.32

This release brings the main build script to version **4.32**, featuring significant improvements to the ImageBuilder, support for new archive formats, and fixes for GCC 13+ compilers.

### ✨ Builder Highlights (_Builder.sh v4.32)
*   **Custom Patches:** Added support for `custom_patches/$p_id` and the `HOST_PATCHES_DIR` variable. Profiles utilizing patches are now marked with an **[X]** indicator in the menu.
*   **Interactivity:** New **"Stay in Container"** option allows users to remain in the container shell after the build process finishes (useful for debugging).
*   **Cache Management:** Added a menu option to "Clean Package Index (tmp)".
*   **Smart Features:** Implemented `Smart Device Detection` and `SRC_EXTRA_CONFIG` handling.
*   **Permissions:** Improved logic for output directory creation and permission handling.

### 📦 Image Builder Improvements (System)
*   **URL Handling:** Fixed filename extraction from URLs (query parameters like `?download=` are now stripped correctly).
*   **Format Support:** Added native support for unpacking **.zst** and **.xz** archives.
*   **Repositories:** Enhanced `CUSTOM_REPOS` parsing (skips empty lines, removes trailing slashes, validates `repositories.conf`).
*   **Stability:** Build retry count optimized (reduced from 3 to 2).

### 🛠 Technical Fixes & Infrastructure
*   **GCC 13+ Compatibility:** Updated `hooks.sh` with an automatic patch for `libxcrypt` (`-Wno-error=format-nonliteral`) to fix build errors on newer Linux distributions.
*   **Git LFS:** Updated `.gitattributes`. Files with extensions `*.zst`, `*.tar`, `*.gz`, `*.bin`, and `*.7z` are now correctly handled via LFS.
*   **Profiles:** Major update to the `rax3000m_emmc_test_new` configuration.
*   **Artifacts:** Updated Docker builders (Win/Linux) and added new ImageBuilder packages (v1.21 - v1.23).

**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.31...4.32


## ========== TAG: 4.40 ==========

title:	4.40 local ib win
tag:	4.40
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-02-18T00:49:28Z
published:	2026-02-18T00:54:59Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.40
asset:	routerFW_WinDockerBuilder_v18.02.2026_03-59.zip
--
# RouterFW — Релиз 4.40

**Версия:** 4.40  
**Период изменений:** 12–18 февраля 2026 (от 4.32)

---

## Русский

### Что нового в Windows версии

- **Сборка прошивки из своего Image Builder.**  
  Можно указать в профиле путь к уже собранному образу Image Builder на диске (например, после сборки из исходников). Не обязательно каждый раз качать его из интернета — сборка пойдёт из локального файла.

- **Автообновление профиля после сборки из исходников.**  
  После успешной сборки прошивки из исходников (режим SOURCE) программа может сама предложить подставить в профиль путь к только что собранному Image Builder. Так следующий запуск сборки «из коробки» уже использует ваш локальный образ.

- **Быстрый запуск Menuconfig.**  
  При повторном открытии настройки ядра (menuconfig) проверяются права доступа к файлам. Если всё в порядке, лишняя подготовка не выполняется — вход в menuconfig становится быстрее.

- **Корректные ссылки на доп. репозитории в новом профиле.**  
  При создании профиля через мастер (create_profile) в шаблоне подставляется правильная архитектура вашего устройства для примеров доп. репозиториев (fantastic-packages и др.), а не одна и та же для всех.

- **Удобный список собранных файлов.**  
  После сборки (и через Image Builder, и из исходников) в консоли выводится список созданных файлов прошивки и их расположение — проще найти нужный образ.

- **Сборка из исходников на новых компиляторах.**  
  Добавлено исправление для сборки на системах с GCC 13 и новее (ошибка с библиотекой libxcrypt). Сборка из исходников должна проходить без лишних сбоев.

- **Стабильность и мелкие исправления.**  
  Улучшена обработка ошибок при распаковке архивов, исправлены добавление сторонних репозиториев и применение своих патчей при сборке из исходников. Обновлены скрипты для Windows и Linux и актуальные архивы дистрибутива.

---

## English

### What's New on Windows version

- **Build firmware using your own Image Builder.**  
  You can set in the profile a path to an Image Builder archive stored on your disk (e.g. after a source build). You no longer have to download it every time — the build will use your local file.

- **Auto-update profile after source build.**  
  After a successful source build (SOURCE mode), the tool can offer to update the profile with the path to the newly built Image Builder. The next build will then use that local image by default.

- **Faster Menuconfig startup.**  
  When opening kernel configuration (menuconfig) again, file permissions are checked. If everything is already correct, the extra setup is skipped — menuconfig starts faster.

- **Correct extra-repo links in new profiles.**  
  When creating a profile with the wizard (create_profile), the template uses the correct architecture for your device in the example extra repositories (e.g. fantastic-packages), instead of a single hardcoded one for all.

- **Clear list of built files.**  
  After each build (both Image Builder and source), the console shows a list of created firmware files and where they are — easier to find the image you need.

- **Source builds on newer compilers.**  
  A fix was added for building on systems with GCC 13+ (libxcrypt-related error). Source builds should complete without extra failures.

- **Stability and small fixes.**  
  Better error handling when unpacking archives; fixed adding custom repositories and applying custom patches in source builds. Updated Windows and Linux scripts and current distribution archives.

---

*Release notes for GitHub — user-oriented summary of changes since 4.32.*


## What's Changed
* Update local ib by @iqubik in https://github.com/iqubik/routerFW/pull/25
* Update pub.md by @iqubik in https://github.com/iqubik/routerFW/pull/26


**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.32...4.40


## ========== TAG: 4.41 ==========

title:	RouterFW 4.41
tag:	4.41
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-02-18T10:37:44Z
published:	2026-02-18T10:37:56Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.41
asset:	routerFW_WinDockerBuilder_v18.02.2026_13-53.zip
--
# RouterFW — Релиз 4.41

**Версия:** 4.41  
**Период изменений:** 18 февраля 2026 (от 4.40)

---

## Русский

### Что нового

- **Переименование переменных профиля Image Builder.**  
  Переменные `PKGS` и `EXTRA_IMAGE_NAME` переименованы в `IMAGE_PKGS` и `IMAGE_EXTRA_NAME` для единообразия: теперь все переменные, относящиеся к Image Builder, имеют префикс `IMAGE_`, переменные Source Builder — `SRC_`, а общие (`ROOTFS_SIZE`, `KERNEL_SIZE`) остаются без префикса.

- **Автоматическая миграция профилей.**  
  При каждом запуске `_Builder.bat` все `.conf`-файлы в папке `profiles/` автоматически проверяются и при необходимости обновляются на новые имена переменных. Миграция идемпотентна — уже обновлённые профили не трогаются. Все существующие профили репозитория уже мигрированы.

- **Обратная совместимость.**  
  `ib_builder.sh` поддерживает оба имени переменных: если профиль содержит старые `PKGS` / `EXTRA_IMAGE_NAME` (например, написан вручную), сборка пройдёт без ошибок.

- **Обновлены шаблон профиля и документация.**  
  Мастер создания профилей (`create_profile.ps1`) теперь генерирует профили с новыми именами. Документация в `docs/` и правила Cursor обновлены.

---

## English

### What's New

- **Profile variable renaming for Image Builder.**  
  Variables `PKGS` and `EXTRA_IMAGE_NAME` have been renamed to `IMAGE_PKGS` and `IMAGE_EXTRA_NAME` for consistency: all Image Builder variables now use the `IMAGE_` prefix, Source Builder variables use `SRC_`, and shared variables (`ROOTFS_SIZE`, `KERNEL_SIZE`) remain unprefixed.

- **Automatic profile migration.**  
  Every time `_Builder.bat` runs, all `.conf` files in the `profiles/` folder are automatically checked and updated to the new variable names if needed. Migration is idempotent — already updated profiles are not touched. All existing profiles in the repository have been migrated.

- **Backward compatibility.**  
  `ib_builder.sh` supports both variable names: if a profile still contains the old `PKGS` / `EXTRA_IMAGE_NAME` (e.g. written manually), the build will complete without errors.

- **Updated profile template and documentation.**  
  The profile creation wizard (`create_profile.ps1`) now generates profiles with the new names. Documentation in `docs/` and Cursor rules have been updated.

---

*Release notes for GitHub — user-oriented summary of changes since 4.40.*


## ========== TAG: 4.42 ==========

title:	4.42
tag:	4.42
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-02-18T15:14:28Z
published:	2026-02-18T17:37:23Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.42
asset:	routerFW_LinuxDockerBuilder_v18.02.2026_20-34.tar.gz
asset:	routerFW_WinDockerBuilder_v18.02.2026_20-33.zip
--
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


**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.41...4.42


## ========== TAG: 4.43 ==========

title:	4.43 lang refactor
tag:	4.43
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-02-18T21:27:34Z
published:	2026-02-18T21:29:46Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.43
asset:	routerFW_LinuxDockerBuilder_v19.02.2026_01-59.tar.gz
asset:	routerFW_WinDockerBuilder_v19.02.2026_01-59.zip
--
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


## ========== TAG: 4.44 ==========

title:	4.44 cli cmd's
tag:	4.44
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-02-24T19:15:52Z
published:	2026-02-24T19:18:07Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.44
asset:	routerFW_LinuxDockerBuilder_v24.02.2026_22-08.tar.gz
asset:	routerFW_WinDockerBuilder_v24.02.2026_22-07.zip
--
# RouterFW — Релиз 4.44

**Версия:** 4.44  
**Период изменений:** от тега 4.43 до текущего состояния ветки 4.44

---

## Русский

### Что нового

- **CLI (аргументы командной строки).**  
  `_Builder.bat` и `_Builder.sh` принимают аргументы для неинтерактивного запуска: выбор профиля, режима сборки (Image Builder / Source Builder) и других действий без входа в интерактивное меню. Удобно для скриптов и CI.

- **Тестовые оболочки CLI.**  
  Добавлены `tester.bat` и `tester.sh` — первые версии тестовых оболочек для проверки CLI: запуск билдеров с аргументами, проверка кодов выхода и вывода. Выполняют только безопасные проверки (без сборок, очистки, menuconfig, wizard). Логи и артефакты (`tester_log_*.md`, `tester_tmp_*_out.txt`) добавлены в `.gitignore`.

- **Определение языка на Linux.**  
  Улучшено автоматическое определение языка при старте `_Builder.sh` (переменная/окружение); словари `ru.env` / `en.env` по-прежнему загружаются до меню.

- **Source Builder — исправление определения цели/устройства.**  
  Исправлен баг с определением target/subtarget и профиля в `src_builder.sh` и в мастерах создания профилей (`create_profile.sh`, `create_profile.ps1`). Корректное использование конфигурации профиля при сборке из исходников. Добавлены примеры профилей для TP-Link TL-WR1043ND v2 (OpenWrt 24.01.05).

- **Шаблоны URL в мастере профилей.**  
  В шаблонах профилей (Fantastic packages) исправлены URL: добавлен сегмент `/packages/` и корректное использование переменной архитектуры (`$ARCH` / `$arch`) в `create_profile.sh` и `create_profile.ps1`.

- **Документация.**  
  — Добавлена карта документации: `docs/map.md`, `docs/map.en.md`.  
  — Схема архитектуры разделена на русскую и английскую версии: `docs/ARCHITECTURE_diagram_ru.md`, `docs/ARCHITECTURE_diagram_en.md` (общий `ARCHITECTURE_diagram.md` удалён).  
  — Новые гайды: `docs/06-rax3000m-emmc-flash.md` / `.en.md` (прошивка eMMC на Rax3000M), `docs/07-troubleshooting-faq.md` / `.en.md` (часто задаваемые вопросы и решение проблем).  
  — Обновлены вводная часть, разделы по Source Build, патчам и индексы (`docs/index.md`, `docs/index.en.md`, `docs/ARCHITECTURE_*.md`).

- **Визуализация релизов и каталог `dist/`.**  
  — GitHub Actions workflow `release-visualizer.yml`: по расписанию и ручному запуску обновляет CHANGELOG из GitHub Releases (`system/get-git.ps1`), генерирует SVG: timeline, tree, виджеты V3 (heatmap, river, bars, stats), «архитектурный тетрис» (`system/changelog-to-svg.ps1`, `system/changelog-to-svg-v3.ps1`, `system/architecture-tetris.ps1`), змейку контрибуций; деплоит результат в ветку `output`.  
  — Каталог `dist/` описан в правилах проекта как место для сгенерированных SVG-артефактов.

- **Правила и игноры репозитория.**  
  — Добавлен `.cursorignore`: исключение из индекса Cursor токсичных файлов (`_unpacker.*`), приватных каталогов, `firmware_output/`, тестовых сред (`nl_test/`, `nw_test/`), `.docker_tmp/` — в соответствии с `.gitignore` и правилами проекта.  
  — Обновлены `.cursor/rules/project-overview.mdc` и `documentation.mdc` (CLI, тестеры, Source Builder fix, dist, .cursorignore).

- **Очистка и обслуживание.**  
  — Удалены устаревшие скрипты в `scripts/rax3000m/`: `manual_config*`, `run_generator.bat`, `generate_options.ps1`.  
  — Удалён `scripts/old_hooks.sh`.  
  — В `.gitattributes` добавлено правило для `profiles/personal.flag` (EOL).  
  — Упаковщики `_packer.bat` / `_packer.sh`: обновление формата/версии распаковщиков.

---

## English

### What's New

- **CLI (command-line arguments).**  
  `_Builder.bat` and `_Builder.sh` accept command-line arguments for non-interactive runs: profile selection, build mode (Image Builder / Source Builder), and other actions without entering the interactive menu. Suitable for scripts and CI.

- **CLI test harnesses.**  
  Added `tester.bat` and `tester.sh` — first versions of test harnesses for CLI verification: running builders with arguments and checking exit codes and output. They only perform safe checks (no builds, clean, menuconfig, wizard). Logs and artifacts (`tester_log_*.md`, `tester_tmp_*_out.txt`) are listed in `.gitignore`.

- **Language detection on Linux.**  
  Improved automatic language detection at `_Builder.sh` startup (variable/environment); dictionaries `ru.env` / `en.env` are still loaded before the menu.

- **Source Builder — target/device detection fix.**  
  Fixed a bug in target/subtarget and profile handling in `src_builder.sh` and in the profile creation wizards (`create_profile.sh`, `create_profile.ps1`). Profile configuration is now correctly applied when building from source. Example profiles for TP-Link TL-WR1043ND v2 (OpenWrt 24.01.05) added.

- **URL templates in profile wizard.**  
  Profile templates (Fantastic packages) now use corrected URLs: the `/packages/` path segment and the correct architecture variable (`$ARCH` / `$arch`) in `create_profile.sh` and `create_profile.ps1`.

- **Documentation.**  
  — Documentation map added: `docs/map.md`, `docs/map.en.md`.  
  — Architecture diagram split into Russian and English: `docs/ARCHITECTURE_diagram_ru.md`, `docs/ARCHITECTURE_diagram_en.md` (single `ARCHITECTURE_diagram.md` removed).  
  — New guides: `docs/06-rax3000m-emmc-flash.md` / `.en.md` (Rax3000M eMMC flashing), `docs/07-troubleshooting-faq.md` / `.en.md` (FAQ and troubleshooting).  
  — Introduction, Source Build and patch sections, and indexes updated (`docs/index.md`, `docs/index.en.md`, `docs/ARCHITECTURE_*.md`).

- **Release visualization and `dist/`.**  
  — GitHub Actions workflow `release-visualizer.yml`: on schedule and manual trigger it refreshes CHANGELOG from GitHub Releases (`system/get-git.ps1`), generates SVG assets: timeline, tree, V3 widgets (heatmap, river, bars, stats), “architecture tetris” (`system/changelog-to-svg.ps1`, `system/changelog-to-svg-v3.ps1`, `system/architecture-tetris.ps1`), contribution snake; deploys results to the `output` branch.  
  — The `dist/` directory is documented in project rules as the place for generated SVG artifacts.

- **Repository rules and ignores.**  
  — Added `.cursorignore`: excludes from Cursor index toxic files (`_unpacker.*`), private dirs, `firmware_output/`, test envs (`nl_test/`, `nw_test/`), `.docker_tmp/` — aligned with `.gitignore` and project rules.  
  — Updated `.cursor/rules/project-overview.mdc` and `documentation.mdc` (CLI, testers, Source Builder fix, dist, .cursorignore).

- **Cleanup and maintenance.**  
  — Removed obsolete scripts in `scripts/rax3000m/`: `manual_config*`, `run_generator.bat`, `generate_options.ps1`.  
  — Removed `scripts/old_hooks.sh`.  
  — `.gitattributes`: added rule for `profiles/personal.flag` (EOL).  
  — Packagers `_packer.bat` / `_packer.sh`: updated unpacker format/version.

---

*Release notes for GitHub — summary of changes from tag 4.43 to current 4.44.*


## What's Changed
* 4.44 by @iqubik in https://github.com/iqubik/routerFW/pull/27

**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.43...4.44


## ========== TAG: 4.45 ==========

title:	4.45
tag:	4.45
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-02-26T18:05:45Z
published:	2026-02-26T18:22:32Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.45
asset:	routerFW_LinuxDockerBuilder_v26.02.2026_21-05.tar.gz
asset:	routerFW_WinDockerBuilder_v26.02.2026_21-00.zip
--
# RouterFW — Релиз 4.45 / Release 4.45

**Версия / Version:** 4.45  
**Период изменений / Changes since:** тег 4.44 → текущее состояние (tag 4.44 → HEAD)

---

## Русский

### Что нового

- **Версия билдера.** Обновление номера версии до 4.45 в `_Builder.bat` и `_Builder.sh`.

- **Структура выходных папок (Windows).** В `_Builder.bat` добавлена инициализация подкаталогов `firmware_output\imagebuilder` и `firmware_output\sourcebuilder` при старте, а также автосоздание для каждого профиля папок `firmware_output\imagebuilder\<profile>` и `firmware_output\sourcebuilder\<profile>` — паритет с поведением `_Builder.sh`.

- **Меню очистки, мастера и menuconfig (Windows).** В экранах «Очистка», «Мастер создания профиля» и «Menuconfig» заголовки оформлены через отдельную переменную `MENU_SEP` и цвет `C_KEY` для разделителя — корректное отображение при включённом `setlocal enabledelayedexpansion` (исправление отображения `L_SEPARATOR_EQ` и подстановки `!L_*!`).

- **Мастер создания профиля: выход по «0».** В `create_profile.ps1` и `create_profile.sh` выход из мастера изменён с клавиши **Q** на **0**: меньше путаницы с нумерацией пунктов, единообразие (0 = выход). Версии мастера: PowerShell 2.6, Bash 2.60.

- **Скрипт выгрузки релизов.** В `system/get-git.ps1` перед формированием CHANGELOG добавлен `git fetch --tags`, чтобы учитывать теги с remote (актуальные релизы при запуске в CI).

- **Визуализация релизов (GitHub Actions).** В workflow `release-visualizer.yml` шаг генерации «змейки» контрибуций (Platane/snk) перенесён после шагов, создающих каталог `dist/` и timeline/tree SVG, чтобы целевая директория существовала. В `system/changelog-to-svg.ps1` добавлено автосоздание каталога `dist/` при отсутствии.

- **Документация: FAQ по ограничениям сборки.** В `docs/07-troubleshooting-faq.md` и `docs/07-troubleshooting-faq.en.md` добавлен подпункт «Sysupgrade/factory не собираются; в выводе только initramfs и „чужие“ образы»: типичная ситуация для устройств с флешем 8 MB (образ превышает лимит, `mktplinkfw` не создаёт образ, make не падает). Описаны отладка через `make target/linux/install`, рекомендации по сокращению набора пакетов и проверке однопрофильной сборки.

- **Профиль TP-Link TL-WR1043ND v2.** Профиль `tplink_tl_wr1043nd_v2_24105_ow_full.conf` приведён к минимальному набору под 8 MB: luci-light, wpad-openssl, убраны тяжёлые пакеты и лишние CONFIG_* в SRC_EXTRA_CONFIG; удалён тестовый профиль `tplink_tl_wr1043nd_v2_24105_ow_full_test.conf`.

- **Упаковщики.** `_packer.bat` и `_packer.sh` обновлены до версии 2.2 MT: в список включаются `docs/06-rax3000m-emmc-flash.md|.en.md` и `docs/07-troubleshooting-faq.md|.en.md`; порядок документов приведён к единому виду.

- **Игноры и тестовые среды.** В `.gitignore` добавлены каталоги `nw_test` и `nl_test`. В `.cursorignore` убраны исключения `firmware_output/`, `debug.md`, `.docker_tmp/` (актуализация под текущее использование репозитория).

- **Очистка.** Удалены резервные копии профилей в `profiles/bck/` (rax3000m_emmc_test_new_bck*.conf). Обновлён CHANGELOG.md (дата выгрузки, правка пути `docs/audit.md` → `audit.md`, блок релиза 4.44).

---

## English

### What's New

- **Builder version.** Version number updated to 4.45 in `_Builder.bat` and `_Builder.sh`.

- **Output folder structure (Windows).** In `_Builder.bat`, startup now ensures `firmware_output\imagebuilder` and `firmware_output\sourcebuilder` exist, and auto-creates per-profile directories `firmware_output\imagebuilder\<profile>` and `firmware_output\sourcebuilder\<profile>` — matching `_Builder.sh` behaviour.

- **Clean menu, wizard, and menuconfig (Windows).** On the Clean, Profile Wizard, and Menuconfig screens, headers use a dedicated `MENU_SEP` variable and `C_KEY` color for the separator — correct display with `setlocal enabledelayedexpansion` (fixes `L_SEPARATOR_EQ` and `!L_*!` expansion).

- **Profile wizard: exit with “0”.** In `create_profile.ps1` and `create_profile.sh`, exit key changed from **Q** to **0**: less confusion with numbered options and consistent “0 = exit”. Wizard versions: PowerShell 2.6, Bash 2.60.

- **Release export script.** In `system/get-git.ps1`, `git fetch --tags` is run before building CHANGELOG so that tags from remote are up to date (relevant for CI runs).

- **Release visualization (GitHub Actions).** In workflow `release-visualizer.yml`, the contribution snake step (Platane/snk) was moved after the steps that create the `dist/` directory and timeline/tree SVGs, so the target directory exists. In `system/changelog-to-svg.ps1`, `dist/` is created automatically if missing.

- **Documentation: build limits FAQ.** In `docs/07-troubleshooting-faq.md` and `docs/07-troubleshooting-faq.en.md`, a new subsection “Sysupgrade/factory not built; only initramfs and other devices' images in output” was added: typical for 8 MB flash (image exceeds device limit, `mktplinkfw` does not create the image, make does not fail). Describes debugging via `make target/linux/install`, tips for reducing package set, and verifying single-profile builds.

- **TP-Link TL-WR1043ND v2 profile.** Profile `tplink_tl_wr1043nd_v2_24105_ow_full.conf` was trimmed to a minimal set for 8 MB: luci-light, wpad-openssl, heavy packages and extra CONFIG_* in SRC_EXTRA_CONFIG removed; test profile `tplink_tl_wr1043nd_v2_24105_ow_full_test.conf` removed.

- **Packagers.** `_packer.bat` and `_packer.sh` updated to version 2.2 MT: include `docs/06-rax3000m-emmc-flash.md|.en.md` and `docs/07-troubleshooting-faq.md|.en.md`; document order aligned between both scripts.

- **Ignores and test envs.** `.gitignore` now includes `nw_test` and `nl_test`. `.cursorignore` updated: removed exclusions for `firmware_output/`, `debug.md`, `.docker_tmp/` to match current repo usage.

- **Cleanup.** Removed backup profiles in `profiles/bck/` (rax3000m_emmc_test_new_bck*.conf). CHANGELOG.md updated (export date, `docs/audit.md` → `audit.md` path fix, 4.44 release block).

---

*Release notes for GitHub — summary of changes from tag 4.44 to 4.45.*


**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.44...4.45


## ========== TAG: 4.46 ==========

title:	4.46
tag:	4.46
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-02-28T01:05:48Z
published:	2026-02-28T01:09:36Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.46
asset:	routerFW_LinuxDockerBuilder_v28.02.2026_03-21.tar.gz
asset:	routerFW_WinDockerBuilder_v28.02.2026_03-21.zip
--
# RouterFW — Релиз 4.46

**Версия:** 4.46  
**Период изменений:** от тега 4.45 до текущего состояния

---

## Русский

### Что нового

- **Новые CLI-команды `check` и `check-all`.**  
  Добавлены команды для работы с контрольными суммами файлов:  
  — `check-all` — добавить или обновить метку `checksum:MD5` во все файлы, перечисленные в unpacker.  
  — `check <profile_id>` — добавить или обновить checksum в конкретном файле профиля `profiles/<ID>.conf`.  
  Это позволяет верифицировать целостность конфигурационных файлов и отслеживать их изменения.

- **Обновление языковых словарей.**  
  В `system/lang/ru.env` и `system/lang/en.env` добавлены новые ключи для команд работы с checksum: `L_CLI_DESC_CHKSUM_ALL`, `L_CLI_DESC_CHKSUM`, `L_CHKSUM_*`.

- **Версия обновлена до 4.46.**  
  Номер версии синхронизирован в `_Builder.bat` и `_Builder.sh`.

Зачем? Чтобы сверять профили, чтобы избегать атак подмены кода, чтобы сделать updater.bat как систему обновления RouterFW.
---

## English

### What's New

- **New CLI commands `check` and `check-all`.**  
  Added commands for file checksum handling:  
  — `check-all` — add or update the `checksum:MD5` tag in all files listed in the unpacker.  
  — `check <profile_id>` — add or update the checksum in a specific profile file `profiles/<ID>.conf`.  
  This allows verifying configuration file integrity and tracking changes.

- **Language dictionary updates.**  
  New keys for checksum commands added to `system/lang/ru.env` and `system/lang/en.env`: `L_CLI_DESC_CHKSUM_ALL`, `L_CLI_DESC_CHKSUM`, `L_CHKSUM_*`.

- **Version bumped to 4.46.**  
  Version number synchronized in `_Builder.bat` and `_Builder.sh`.

What for? To compare profiles, to avoid code substitution attacks, to make an updater.bat as a RouterFW update system.
---

*Release notes for GitHub — summary of changes from tag 4.45 to current 4.46.*


## What's Changed
* Test cli1 by @iqubik in https://github.com/iqubik/routerFW/pull/28
* docs: Add check and check-all CLI commands to documentation by @cto-new[bot] in https://github.com/iqubik/routerFW/pull/29
* Cli md5 by @iqubik in https://github.com/iqubik/routerFW/pull/30
* Release notes 4.46 (pub.md) by @cto-new[bot] in https://github.com/iqubik/routerFW/pull/31

## New Contributors
* @cto-new[bot] made their first contribution in https://github.com/iqubik/routerFW/pull/29

**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.45...4.46


## ========== TAG: 4.47 ==========

title:	4.47-4.48
tag:	4.47
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-02-28T15:15:55Z
published:	2026-02-28T15:17:22Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.47
asset:	routerFW_LinuxDockerBuilder_v01.03.2026_01-40.tar.gz
asset:	routerFW_WinDockerBuilder_v01.03.2026_01-41.zip
--
# RouterFW — Релиз 4.48

**Версия:** 4.48  
**Период изменений:** от тега 4.46 до текущего состояния

---

## Русский

### Что нового

Исправлена критическая ошибка кодировки файлов формата *.PS1 (wizard, import)

- **Новая CLI-команда `check-clear`.**  
  Добавлена команда для удаления контрольных сумм из файлов:  
  — Без аргументов или с `all` — очищает `checksum:MD5` из всех файлов, перечисленных в unpacker, а также из самого unpacker.  
  — С указанным ID профиля — очищает checksum только из конкретного файла `profiles/<ID>.conf`.

- **Улучшение скриптов упаковщика (`_packer.sh`, `_packer.bat`).**  
  Теперь при упаковке генерируется таблица MD5-хешей для распаковщика.  
  MD5 каждого файла сохраняется и передается в unpacker для логирования при верификации.

- **Улучшение скриптов распаковщика (`_unpacker.sh`, `_unpacker.bat`).**  
  Теперь при восстановлении файлов в лог выводится MD5-хеш рядом с каждым файлом.  
  Формат: `[UNPACK] Recover: <filename> - md5(<hash>)`.

- **Обновление языковых словарей.**  
  В `system/lang/ru.env` и `system/lang/en.env` добавлен новый ключ `L_CLI_DESC_CHKSUM_CLEAR` для команды `check-clear`.  
  Обновлен текст ключа `L_CHKSUM_ALL_START`.

- **Обновление документации.**  
  Команда `check-clear` добавлена в таблицы CLI команд в файлах:  
  — `README.md`  
  — `README.en.md`  
  — `docs/ARCHITECTURE_diagram_ru.md`  
  — `docs/ARCHITECTURE_diagram_en.md`

- **Обновление архивов Docker Builder.**  
  Новые сборки:  
  — `routerFW_LinuxDockerBuilder_v01.03.2026_01-40.tar.gz`  
  — `routerFW_WinDockerBuilder_v01.03.2026_01-41.zip`

---

## English

### What's New

*.PS1 files CRLF BOM FIXed - wizard and import IPK work correct now (_Builder.bat _packer.bat)

- **New CLI command `check-clear`.**  
  Added a command to remove checksums from files:  
  — Without arguments or with `all` — clears `checksum:MD5` from all files listed in the unpacker, plus the unpacker itself.  
  — With a specific profile ID — clears checksum only from that specific `profiles/<ID>.conf` file.

- **Enhanced packer scripts (`_packer.sh`, `_packer.bat`).**  
  Now generates an MD5 hash table for the unpacker during packaging.  
  Each file's MD5 is saved and passed to the unpacker for verification logging.

- **Enhanced unpacker scripts (`_unpacker.sh`, `_unpacker.bat`).**  
  Now displays the MD5 hash next to each recovered file in the log.  
  Format: `[UNPACK] Recover: <filename> - md5(<hash>)`.

- **Language dictionary updates.**  
  Added new key `L_CLI_DESC_CHKSUM_CLEAR` for the `check-clear` command to `system/lang/ru.env` and `system/lang/en.env`.  
  Updated the `L_CHKSUM_ALL_START` text.

- **Documentation updated.**  
  Added `check-clear` command to CLI tables in:  
  — `README.md`  
  — `README.en.md`  
  — `docs/ARCHITECTURE_diagram_ru.md`  
  — `docs/ARCHITECTURE_diagram_en.md`

- **Updated Docker Builder archives.**  
  New builds:  
  — `routerFW_LinuxDockerBuilder_v01.03.2026_01-40.tar.gz`  
  — `routerFW_WinDockerBuilder_v01.03.2026_01-41.zip`

---

*Release notes for GitHub — summary of changes from tag 4.46 to current 4.48.*

**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.46...4.47


## ========== TAG: 4.49 ==========

title:	4.49
tag:	4.49
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-03-05T20:46:56Z
published:	2026-03-05T20:51:21Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.49
asset:	routerFW_LinuxDockerBuilder_v05.03.2026_23-44.tar.gz
asset:	routerFW_WinDockerBuilder_v05.03.2026_23-44.zip
--
### ROUTERFW — РЕЛИЗ 4.49

**Версия:** 4.49
**Период изменений:** от тега 4.47 до текущего состояния

---

### РУССКИЙ

**ЧТО НОВОГО**

*   **Новая опция `SRC_CORES=debug` для Source Builder**
    *   Добавлена новая опция `SRC_CORES="debug"`, которая позволяет немедленно запустить сборку в режиме отладки.
    *   Сборка принудительно запускается в один поток с максимальной детализацией логов (`make -j1 V=s`).
    *   Это идеально подходит для диагностики и поиска ошибок на самом раннем этапе, без необходимости ждать сбоя основной параллельной сборки.

*   **Комплексное обновление документации**
    *   Обновлена вся связанная документация, чтобы отразить новую возможность: `README.md` (ru/en), `GEMINI.md`, все релевантные уроки в `docs/`, диаграммы архитектуры и правила `.cursor/rules`.

*   **Обновление версий служебных скриптов**
    *   Повышены версии в затронутых скриптах: `system/src_builder.sh` (до v2.0), `system/create_profile.sh` (до v2.70) и `system/create_profile.ps1` (до v2.7).

---

### ENGLISH

<details>
<summary>WHAT'S NEW</summary>

*   **New `SRC_CORES=debug` Option for Source Builder**
    *   Added a new `SRC_CORES="debug"` option that allows immediately starting a build in debug mode.
    *   The build is forced to run in a single thread with maximum log verbosity (`make -j1 V=s`).
    *   This is ideal for troubleshooting and diagnosing errors at the earliest stage, without having to wait for a parallel build to fail.

*   **Comprehensive Documentation Update**
    *   Updated all related documentation to reflect the new feature: `README.md` (ru/en), `GEMINI.md`, all relevant lessons in `docs/`, architecture diagrams, and `.cursor/rules`.

*   **Utility Script Version Bump**
    *   Incremented versions in the affected scripts: `system/src_builder.sh` (to v2.0), `system/create_profile.sh` (to v2.70), and `system/create_profile.ps1` (to v2.7).

</details>

---


## What's Changed
* docs: add check-clear command to CLI tables in documentation by @cto-new[bot] in https://github.com/iqubik/routerFW/pull/33
* docs: add release notes for v4.48 by @cto-new[bot] in https://github.com/iqubik/routerFW/pull/34
* Prevent snake workflow from deleting non-snake files in output branch by @cto-new[bot] in https://github.com/iqubik/routerFW/pull/35
* fix: update GitHub Pages action to keep non-snake files by @cto-new[bot] in https://github.com/iqubik/routerFW/pull/36
* Src debug by @iqubik in https://github.com/iqubik/routerFW/pull/39


**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.47...4.49


## ========== TAG: 4.50 ==========

title:	4.50
tag:	4.50
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-03-13T08:41:37Z
published:	2026-03-13T08:45:40Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.50
asset:	routerFW_LinuxDockerBuilder_v17.03.2026_15-11.tar.gz
asset:	routerFW_WinDockerBuilder_v13.03.2026_14-14.zip
--
# RouterFW Release Notes (from 4.49 to 4.50)

## Russian (Русский)

### Новые возможности и улучшения

*   **Расширенная поддержка пакетов (APK):** Введена полная поддержка импорта и управления пакетами APK для Source Builder. Это значительно расширяет возможности кастомизации прошивок.
*   **Улучшения в работе с extroot:** Внесены многочисленные изменения и оптимизации в скрипты `99-extroot-setup.sh` для повышения стабильности и совместимости работы с extroot.
*   **Обновления профилей:** Обновлены и оптимизированы конфигурационные файлы для различных профилей (например, `cmcc_rax3000m_24105_ow_full.conf`) для улучшения производительности и добавления новых опций.
*   **Информация о ядре и Vermagic:** Добавлены функции для отображения информации о ядре и Vermagic, что полезно для отладки и проверки совместимости.
*   **Обновления документации:** Актуализированы различные разделы документации и CHANGELOG.

### Исправления

*   Устранены мелкие ошибки и недочеты, обнаруженные в процессе разработки.
*   Оптимизирована работа упаковщика/распаковщика.

---

## English

### New Features and Improvements

*   **Extended Package (APK) Support:** Full support for importing and managing APK packages has been introduced for the Source Builder. This significantly expands firmware customization options.
*   **Extroot Enhancements:** Numerous changes and optimizations have been made to the `99-extroot-setup.sh` scripts to improve the stability and compatibility of extroot functionality.
*   **Profile Updates:** Configuration files for various profiles (e.g., `cmcc_rax3000m_24105_ow_full.conf`) have been updated and optimized to enhance performance and add new options.
*   **Kernel and Vermagic Information:** Added functions to display kernel and Vermagic information, which is useful for debugging and compatibility checks.
*   **Documentation Updates:** Various documentation sections and the CHANGELOG have been updated.

### Fixes

*   Minor bugs and imperfections discovered during development have been resolved.
*   The packer/unpacker operations have been optimized.


## What's Changed
* Apk import by @iqubik in https://github.com/iqubik/routerFW/pull/40
**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.49...4.50


## ========== TAG: 4.51 ==========

title:	4.51 APK IB FIX
tag:	4.51
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-04-04T15:11:26Z
published:	2026-04-04T15:12:51Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.51
asset:	routerFW_LinuxDockerBuilder_v04.04.2026_18-09.tar.gz
asset:	routerFW_WinDockerBuilder_v04.04.2026_18-09.zip
--
# Release Notes: v4.50 → v4.51

---

## ru Русский

### Новые возможности

- **Новые профили устройств:**
  - `cmcc_rax3000me` (ImmortalWrt 24.10.5, PadavanOnly) — профиль для CMCC RAX3000ME-версии
  - `netcore_n60_pro_2410_pad` — Netcore N60 Pro (ImmortalWrt 24.10, PadavanOnly)
  - `netcore_n60_pro_25120_ow_full` — Netcore N60 Pro (OpenWrt 25.12.0, официальный)

### Улучшения

- **Image Builder — полная поддержка APK:**
  - Валидация APK-пакетов перед сборкой (проверка через `apk adbdump`)
  - Отключение проверки подписей (`CONFIG_SIGNATURE_CHECK`) для локальных APK
  - Улучшенная обработка и индексация локальных пакетов (`.apk` + `.ipk`)
  - Подавление ложных предупреждений о `packages.adb`
  - Использование массивов Bash вместо `eval` для надёжности

- **Документация:**
  - Обновлены ARCHITECTURE документы (исправлены описания команд F и P)
  - Добавлена карта роста проекта в `pub.md`
  - Обновлена документация по Source Build и Advanced Source Build
  - FAQ по troubleshooting обновлён

- **Локализация:**
  - Все строки интерфейса обновлены: «Импорт IPK» → «Импорт IPK+APK»
  - Русский и английский языки синхронизированы

### Исправления

- Исправлена совместимость с Arch Linux
- Оптимизирована работа с пользовательскими репозиториями (чистый Bash вместо `grep`/`awk`)
- Исправлен путь к overlay (`/tmp/clean_overlay` вместо `/overlay_files`)

---

## en English

### New Features

- **New device profiles:**
  - `cmcc_rax3000me` (ImmortalWrt 24.10.5, PadavanOnly) — profile for CMCC RAX3000M E-version
  - `netcore_n60_pro_2410_pad` — Netcore N60 Pro (ImmortalWrt 24.10, PadavanOnly)
  - `netcore_n60_pro_25120_ow_full` — Netcore N60 Pro (OpenWrt 25.12.0, official)

### Improvements

- **Image Builder — full APK support:**
  - APK package validation before build (via `apk adbdump`)
  - Signature check disabled (`CONFIG_SIGNATURE_CHECK`) for local APK files
  - Improved local package handling and indexing (`.apk` + `.ipk`)
  - Suppressed false `packages.adb` warnings
  - Bash arrays used instead of `eval` for reliability

- **Documentation:**
  - Updated ARCHITECTURE documents (fixed F and P command descriptions)
  - Added project growth map in `pub.md`
  - Updated Source Build and Advanced Source Build documentation
  - Troubleshooting FAQ updated

- **Localization:**
  - All UI strings updated: "Import IPK" → "Import IPK+APK"
  - Russian and English languages synchronized

### Bug Fixes

- Arch Linux compatibility fixed
- Custom repository handling optimized (pure Bash instead of `grep`/`awk`)
- Overlay path corrected (`/tmp/clean_overlay` instead of `/overlay_files`)

---

**Сравнение изменений:** https://github.com/iqubik/routerFW/compare/4.50...4.51
**Релиз:** https://github.com/iqubik/routerFW/releases/tag/4.51


## What's Changed
* docs: add APK format alongside IPK in documentation by @cto-new[bot] in https://github.com/iqubik/routerFW/pull/41
* docs: Исправление описания команд F и P в ARCHITECTURE документах by @cto-new[bot] in https://github.com/iqubik/routerFW/pull/42
* Create project growth map in pub.md by @cto-new[bot] in https://github.com/iqubik/routerFW/pull/43


**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.50...4.51


## ========== TAG: 4.60 ==========

title:	IB APK SCANNER
tag:	4.60
draft:	false
prerelease:	false
immutable:	false
author:	iqubik
created:	2026-04-07T19:53:05Z
published:	2026-04-07T19:54:11Z
url:	https://github.com/iqubik/routerFW/releases/tag/4.60
asset:	routerFW_LinuxDockerBuilder_v07.04.2026_23-56.tar.gz
asset:	routerFW_WinDockerBuilder_v07.04.2026_23-57.zip
--
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


**Full Changelog**: https://github.com/iqubik/routerFW/compare/4.51...4.60
