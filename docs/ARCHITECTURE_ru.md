# file docs\ARCHITECTURE_ru.md

# routerFW — Архитектура и поток процессов

> Версия: 4.43. Обновлено: 2026-02-18.

---

## 1. Точки входа

```
Пользователь
 ├── Windows → _Builder.bat   (PowerShell/Batch, интерактивное меню)
 └── Linux   → _Builder.sh    (Bash, интерактивное меню + параллельные сборки)
```

Оба файла — **паритетные обёртки**: одинаковые меню, одинаковая логика, разный синтаксис оболочки.

---

## 2. Последовательность запуска (обе платформы)

```
СТАРТ
  │
  ├─ [1] Ловушка Ctrl+C (cleanup_exit → release_locks ALL → rm .docker_tmp/)
  │
  ├─ [2] Детектор языка (взвешенная оценка: LANG env +4, locale +3, timezone +2)
  │        └─ загружает system/lang/{ru|en}.env  →  устанавливает переменные L_* / H_*
  │
  ├─ [3] Проверка Docker (docker --version, docker-compose / docker compose)
  │
  ├─ [4] Исправление учётных данных Docker (.docker_tmp/config.json, удаляет credsStore/credHelpers)
  │
  ├─ [5] Автораспаковка (_unpacker.sh / _unpacker.bat, если присутствует)
  │
  ├─ [6] Инициализация папок (profiles/, custom_files/, firmware_output/, custom_packages/,
  │                            src_packages/, custom_patches/)
  │
  ├─ [7] Миграция переменных профилей  PKGS→IMAGE_PKGS, EXTRA_IMAGE_NAME→IMAGE_EXTRA_NAME
  │        (идемпотентно, выполняется при каждом запуске)
  │
  └─ [8] Маппинг архитектур  SRC_ARCH автозаполняется по SRC_TARGET/SRC_SUBTARGET
```

---

## 3. Команды интерактивного меню

```
Главное меню
  ├─ [номер]      Собрать выбранный профиль
  ├─ [M]         Переключить режим сборки: IMAGE ↔ SOURCE
  ├─ [E]         Открыть профиль в $EDITOR
  ├─ [A]         Параллельная сборка ВСЕХ профилей (только Linux, фоновые задачи + спиннер)
  ├─ [K]         Menuconfig (только Source Builder)
  ├─ [C]         Мастер очистки (кэш, тома, полный сброс)
  ├─ [W]         Мастер создания нового профиля  →  system/create_profile.sh / .ps1
  ├─ [I]         Импорт .ipk-пакетов             →  system/import_ipk.sh / .ps1
  └─ [0]         Выход
```

---

## 4. Процесс сборки — режим IMAGE BUILDER

```
_Builder.sh/bat  →  build_routine(profile.conf)
  │
  ├─ Читает переменные профиля: IMAGEBUILDER_URL, IMAGE_PKGS, IMAGE_EXTRA_NAME,
  │                              ROOTFS_SIZE, KERNEL_SIZE, CUSTOM_REPOS, CUSTOM_KEYS,
  │                              DISABLED_SERVICES
  │
  ├─ Проверка Legacy: URL содержит /17. /18. /19.  → builder-oldwrt (Ubuntu 18.04)
  │                    иначе                         → builder-openwrt (Ubuntu 22.04)
  │
  ├─ Экспорт переменных: SELECTED_CONF, HOST_FILES_DIR, HOST_PKGS_DIR, HOST_OUTPUT_DIR
  │
  ├─ docker compose -f system/docker-compose.yaml up --build
  │     │
  │     │  Монтирование томов:
  │     │    imagebuilder-cache:/cache
  │     │    ipk-cache:/builder_workspace/dl
  │     │    custom_packages/<профиль>:/input_packages   ← .ipk файлы [ПРИВАТНО]
  │     │    custom_files/<профиль>:/overlay_files       ← файловый оверлей [ПРИВАТНО]
  │     │    firmware_output:/output
  │     │    profiles:/profiles
  │     │
  │     └─ запускает: /bin/bash /ib_builder.sh
  │               │
  │               ├─ [1] Нормализация профиля (удаление BOM, удаление \r)
  │               ├─ [2] Скачивание / кэширование SDK (.tar.zst или .tar.xz)
  │               │        Сетевой URL → wget → /cache/
  │               │        Локальный путь → firmware_output/... → /cache/
  │               ├─ [3] Распаковка SDK (tar -I zstd или tar -xJf, --strip-components=1)
  │               ├─ [4] Исправление OpenSSL (копирование openssl.cnf для legacy SSL)
  │               ├─ [5] Копирование .ipk → packages/
  │               ├─ [6] Установка ROOTFS_SIZE / KERNEL_SIZE в .config
  │               ├─ [7] Скачивание ключей подписи (CUSTOM_KEYS)
  │               ├─ [8] Добавление кастомных репозиториев (CUSTOM_REPOS → repositories.conf)
  │               ├─ [9] Подготовка оверлея (/tmp/clean_overlay, удаление hooks.sh/README.md)
  │               ├─[10] make image  (2 попытки, повтор при ошибке)
  │               └─[11] Копирование артефактов → firmware_output/imagebuilder/<профиль>/<метка времени>/
  │
  └─ Исправление прав (alpine chown до UID хост-пользователя)
```

---

## 5. Процесс сборки — режим SOURCE BUILDER

```
_Builder.sh/bat  →  build_routine(profile.conf)
  │
  ├─ Читает переменные профиля: SRC_REPO, SRC_BRANCH, SRC_TARGET, SRC_SUBTARGET,
  │                              SRC_ARCH, SRC_CORES, SRC_PACKAGES, SRC_EXTRA_CONFIG,
  │                              ROOTFS_SIZE, KERNEL_SIZE
  │
  ├─ Проверка Legacy: ветка содержит 19.07 / 18.06  → builder-src-oldwrt (Ubuntu 18.04)
  │                    иначе                          → builder-src-openwrt (Ubuntu 24.04)
  │
  ├─ docker compose -f system/docker-compose-src.yaml up --build
  │     │
  │     │  Монтирование томов (постоянные тома Docker):
  │     │    src-workdir:/home/build/openwrt        ← дерево исходников OpenWrt
  │     │    src-dl-cache:/home/build/openwrt/dl    ← кэш скачанных архивов
  │     │    src-ccache:/ccache                      ← кэш компилятора (20 ГБ)
  │     │    profiles:/profiles
  │     │    src_packages/<профиль>:/input_packages  ← исходные пакеты [ПРИВАТНО]
  │     │    custom_patches/<профиль>:/patches        ← патчи [ПРИВАТНО]
  │     │    custom_files/<профиль>:/overlay_files   ← файловый оверлей [ПРИВАТНО]
  │     │    firmware_output/sourcebuilder/<профиль>:/output
  │     │
  │     └─ запускает: /bin/bash /src_builder.sh  (от root, затем sudo -u build)
  │               │
  │               ├─ [1] Исправление прав (chown -R build:build при первом запуске)
  │               ├─ [2] git init / fetch / checkout FETCH_HEAD (reset --hard)
  │               ├─ [3] Зеркалирование фидов (git.openwrt.org → github.com)
  │               ├─ [4] Обновление/установка фидов (пропуск при неизменном коммите — кэш)
  │               ├─ [5] Применение патчей (/patches → rsync оверлей на дерево исходников)
  │               ├─ [6] Проверка VERMAGIC Rollback (если hooks.sh отсутствует)
  │               │        Обнаруживает пропатченный kernel-defaults.mk → восстанавливает бэкап
  │               ├─ [7] Выполнение scripts/hooks.sh (хук перед сборкой)
  │               │        hooks.sh умеет: правка DTS/Makefile, добавление фидов,
  │               │        применение vermagic hack, умная очистка кэша
  │               ├─ [8] Генерация .config из переменных профиля
  │               │        (или использование manual_config, если присутствует)
  │               ├─ [9] make defconfig
  │               ├─[10] Копирование src_packages → package/
  │               ├─[11] rsync overlay_files → files/  (оверлей custom_files)
  │               ├─[12] make download (с повтором)
  │               ├─[13] make -j<SRC_CORES>  →  резервный make -j1 V=s при ошибке
  │               └─[14] Копирование артефактов → firmware_output/sourcebuilder/<профиль>/<метка времени>/
  │
  ├─ Исправление прав (alpine chown под UID хоста, как в Image Builder)
  ├─ После сборки: поиск *imagebuilder*.tar.zst → предложение обновить IMAGEBUILDER_URL в профиле
  └─ После сборки: предложение интерактивной оболочки (docker compose run --rm -it /bin/bash)
```

---

## 6. Процесс Menuconfig (только Source Builder)

```
Меню [K]  →  run_menuconfig(profile.conf)
  │
  ├─ Генерирует firmware_output/sourcebuilder/<профиль>/_menuconfig_runner.sh
  ├─ docker compose run --rm -it builder-src-openwrt /bin/bash
  │     │
  │     └─ _menuconfig_runner.sh:
  │           ├─ git init / checkout (если рабочая директория пуста)
  │           ├─ внедрение src_packages в package/custom-imports/
  │           ├─ подготовка .config из переменных профиля
  │           ├─ make menuconfig  (интерактивный TUI)
  │           ├─ make defconfig → diffconfig.sh → /output/manual_config
  │           └─ опционально: остаться в контейнере (/bin/bash)
  │
  └─ После menuconfig: предложение применить manual_config → SRC_EXTRA_CONFIG в профиле
        (perl-регулярка заменяет существующий блок SRC_EXTRA_CONFIG или дописывает в конец)
```

---

## 7. scripts/hooks.sh — хук перед сборкой (Source Builder)

```
hooks.sh  (HOOKS_VERSION=1.7, запускается внутри контейнера перед make defconfig)
  │
  ├─ БЛОК 1: Демонстрация правки файлов (идемпотентный патч README)
  ├─ БЛОК 2: Управление фидами (кастомные фиды → feeds.conf)
  ├─ БЛОК 3: Внедрение исходных пакетов (папки кастомных пакетов)
  ├─ БЛОК 4: Vermagic Hack
  │     ├─ Извлекает хэш vermagic с openwrt.org
  │     ├─ Делает бэкап include/kernel-defaults.mk
  │     ├─ Патчит его, прошивая хэш намертво
  │     └─ Записывает маркер .last_vermagic (используется логикой отката)
  └─ БЛОК 5: Умная очистка кэша (обнаруживает структурные изменения → rm -rf build_dir/target-*)
```

---

## 8. Система профилей

```
profiles/*.conf  (общий формат для Image Builder и Source Builder)
  │
  ├─ Переменные Image Builder:  IMAGEBUILDER_URL, IMAGE_PKGS, IMAGE_EXTRA_NAME,
  │                              CUSTOM_REPOS, CUSTOM_KEYS, DISABLED_SERVICES
  ├─ Переменные Source Builder: SRC_REPO, SRC_BRANCH, SRC_TARGET, SRC_SUBTARGET,
  │                              SRC_ARCH, SRC_CORES, SRC_PACKAGES, SRC_EXTRA_CONFIG,
  │                              TARGET_PROFILE, PROFILE_NAME
  └─ Общие переменные:          ROOTFS_SIZE, KERNEL_SIZE
```

---

## 9. Docker-образы

```
Image Builder:
  system/dockerfile         → Ubuntu 22.04  (builder-openwrt)
  system/dockerfile.legacy  → Ubuntu 18.04  (builder-oldwrt)

Source Builder:
  system/src.dockerfile         → Ubuntu 24.04  (builder-src-openwrt)
  system/src.dockerfile.legacy  → Ubuntu 18.04  (builder-src-oldwrt)
```

---

## 10. Гитигнорируемые (приватные) директории

```
custom_files/     ← SSH-ключи, пароли, /etc/shadow, приватные конфиги — НИКОГДА не коммитить
custom_packages/  ← .ipk-бинари, лицензионные/ограниченные пакеты  — НИКОГДА не коммитить
src_packages/     ← исходные пакеты                                  — НИКОГДА не коммитить
custom_patches/   ← проприетарные патчи                              — НИКОГДА не коммитить
firmware_output/  ← скомпилированная прошивка (10+ ГБ)              — НИКОГДА не коммитить
```

---

## 11. Пакер / Дистрибутив

```
_packer.sh / _packer.bat
  └─ Упаковывает проект в самораспаковывающийся однофайловый дистрибутив
        _unpacker.sh  (Linux)   ← НЕ ЧИТАТЬ (огромная base64-нагрузка)
        _unpacker.bat (Windows) ← НЕ ЧИТАТЬ (огромная base64-нагрузка)
```

---

## 12. Полная карта процессов (Mermaid)

См. [ARCHITECTURE_diagram.md](ARCHITECTURE_diagram.md): **§1** Старт · **§2** Главное меню (все команды) · **§3** Сборка + пост-действия · **§4** Cleanup Wizard · **§5** Поток Menuconfig. EN + RU + таблица легенды.
