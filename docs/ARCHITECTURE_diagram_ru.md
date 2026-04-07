# file: docs/ARCHITECTURE_diagram_ru.md
<p align="center">
  <b>🇷🇺 Русский</b> | <a href="ARCHITECTURE_diagram_en.md"><b>🇺🇸 English</b></a>
</p>

---

# routerFW — Диаграммы процессов

> Версия 4.60. Набор диаграмм (русская страница).
>
> Текст: [ARCHITECTURE_ru.md](ARCHITECTURE_ru.md) · EN diagrams: [ARCHITECTURE_diagram_en.md](ARCHITECTURE_diagram_en.md)

---

## 1. Стартовая последовательность (RU)

> **Платформа:** диаграмма отражает **Linux** (_Builder.sh). В Windows (_Builder.bat): нет trap и фикса Docker credentials; распаковка — _unpacker.bat; patch_arch один раз при старте; migrate выполняется при **каждой** отрисовке меню.

```mermaid
flowchart TD
    START([_Builder.sh / _Builder.bat]) --> TRAP[trap SIGINT/SIGTERM\ncleanup_exit → release_locks ALL, rm .docker_tmp]
    TRAP --> COLORS[ANSI-цвета\nC_KEY, C_LBL, C_ERR, C_RST...]
    COLORS --> LANG_DET[Детектор языка\nLANG +4, locale +3, TZ +2\nWSL: +5 Get-WinSystemLocale → SYS_LANG]
    LANG_DET --> LOAD_LANG[load_lang\nsystem/lang/ru.env или en.env → L_*, H_*]
    LOAD_LANG --> LANG_OUT[Вывод результата детектора\nScore, verdict]
    LANG_OUT --> DOCKER_CFG[Исправление Docker credentials\n.docker_tmp/config.json\nудаление credsStore/credHelpers]
    DOCKER_CFG --> DOCKER_CHK{docker и compose\nустановлены?}
    DOCKER_CHK --> |нет| EXIT_DOCKER[L_ERR_DOCKER\nread, exit 1]
    DOCKER_CHK --> |да| UNPACK{_unpacker.sh\nесть?}
    UNPACK --> |да| RUN_UNPACK[bash _unpacker.sh]
    UNPACK --> |нет| INIT_DIRS
    RUN_UNPACK --> INIT_DIRS[check_dir\nprofiles, custom_files, firmware_output\ncustom_packages, src_packages, custom_patches\n+ imagebuilder/, sourcebuilder/\n+ imagebuilder/<id>, sourcebuilder/<id> — обе платформы 4.45]
    INIT_DIRS --> PATCH_ARCH[patch_architectures\nSRC_ARCH из SRC_TARGET/SUBTARGET]
    PATCH_ARCH --> MIGRATE[migrate_profile_vars\nPKGS→IMAGE_PKGS\nEXTRA_IMAGE_NAME→IMAGE_EXTRA_NAME]
    MIGRATE --> MENU_LOOP[while true: отрисовка меню]
```

---

## 2. Главное меню — все варианты (RU)

```mermaid
flowchart TD
    MENU([Главное меню\nТаблица: профили + F,P,S,M,H,X,OI,OS\nПри каждой отрисовке: init dirs\ncreate_perms_script])
    MENU --> CHOICE{Ввод пользователя}

    CHOICE --> |0| EXIT[Подтверждение выхода\nY/n, sleep 3, exit 0]
    CHOICE --> |M| SWITCH[BUILD_MODE =\nIMAGE ↔ SOURCE]
    SWITCH --> MENU

    CHOICE --> |E| E_LIST[Редактор: список профилей\nпо номеру]
    E_LIST --> E_ID{ID 1..N\nили 0}
    E_ID --> |0| MENU
    E_ID --> |1..N| E_ANALYZE[Анализатор: custom_files\ncustom_packages, src_packages\nвывод SB/IB]
    E_ANALYZE --> E_EDIT["$EDITOR (nano)\nprofiles/<id>.conf"]
    E_EDIT --> MENU

    CHOICE --> |A| A_CHECK{Режим\nBUILD_MODE?}
    A_CHECK --> |SOURCE| A_WARN[Предупреждение: массовая\nсборка только в IMAGE]
    A_WARN --> MENU
    A_CHECK --> |IMAGE| A_RUN[Каталог логов: .build_logs/<ts>\nЗапуск build_routine по каждому\nв фоне, сбор PID]
    A_RUN --> A_WAIT[Спиннер, ожидание всех\nрезультат и время по профилю]
    A_WAIT --> MENU

    CHOICE --> |K| K_CHECK{Режим\nSOURCE?}
    K_CHECK --> |нет| MENU
    K_CHECK --> |да| K_LIST[Menuconfig: список профилей]
    K_LIST --> K_ID{ID или 0}
    K_ID --> |0| MENU
    K_ID --> |1..N| K_MC[run_menuconfig\n→ применить manual_config?]
    K_MC --> MENU

    CHOICE --> |I| I_CHECK{SOURCE?}
    I_CHECK --> |нет| MENU
    I_CHECK --> |да| I_LIST[Импорт IPK/APK: список профилей]
    I_LIST --> I_ID{ID}
    I_ID --> I_RUN[import_ipk: .sh p_id p_arch / .ps1 -ProfileID -TargetArch\ncustom_packages → src_packages]
    I_RUN --> MENU

    CHOICE --> |W| W_RUN[create_profile.sh / .ps1\nмастер → новый profiles/name.conf\n выход: 0]
    W_RUN --> MENU

    CHOICE --> |C| CLEAN_WIZ[Cleanup Wizard\nсм. диаграмму 4]
    CLEAN_WIZ --> MENU

    CHOICE --> |F| F_RUN[Check All\nобновить checksum:MD5 во всех файлах unpacker]
    F_RUN --> MENU

    CHOICE --> |P| P_RUN[Вызвать _packer.bat / _packer.sh\nупаковка ресурсов]
    P_RUN --> MENU

    CHOICE --> |S| S_CHECK2{Режим\nIMAGE?}
    S_CHECK2 --> |нет| MENU
    S_CHECK2 --> |да| S_LIST2[APK Scanner: список профилей]
    S_LIST2 --> S_ID2{ID}
    S_ID2 --> |0| MENU
    S_ID2 --> |1..N| S_RUN2[apk_scanner: .sh p_id p_arch / .ps1 -ProfileID -TargetArch -Lang\nвалидация и переименование]
    S_RUN2 --> MENU

    CHOICE --> |1..N верный| BUILD[build_routine\nпрофиль N\nсм. диаграмму 3]
    BUILD --> MENU

    CHOICE --> |неверный| ERR[L_ERR_INPUT\nsleep 1]
    ERR --> MENU
```

<a id="управление-из-командной-строки-windows"></a>

### Управление из командной строки (Windows)

Запуск с аргументами выполняет действие без входа в интерактивное меню (после инициализации и построения списка профилей). На Linux те же команды и примеры применимы с заменой `_Builder.bat` на `./_Builder.sh`.

**Режим сборки (Image Builder / Source):**
- **Префикс перед командой** (опционально): `ib` или `image` — Image Builder, `src` или `source` — Source Builder. Без префикса используется **Image Builder** по умолчанию.
- **Собрать IB профиль 1:** `_Builder.bat ib build 1` или `_Builder.bat build 1` (по умолчанию IB).
- **Собрать Source профиль 1:** `_Builder.bat src build 1`.
- **Массовая сборка в нужном режиме:** `_Builder.bat ib build-all`, `_Builder.bat src build-all`.
Для явного выбора режима в одной команде используйте префикс `ib`/`src`. Переключение режима (клавиша **M** в меню) — только в интерактивном режиме.

| Команда | Краткий ключ | Аргументы | Действие |
|--------|--------------|-----------|----------|
| `build` | `b` | \<id\> — номер или имя профиля | Сборка одного профиля |
| `build-all` | `a`, `all` | — | Массовая сборка (режим: префикс ib/src или по умолчанию IB) |
| `edit` | `e` | [id] | Редактор профиля (без id — интерактивный выбор по списку) |
| `menuconfig` | `k` | \<id\> | Menuconfig (только SOURCE) |
| `import` | `i` | \<id\> | Импорт IPK/APK (только SOURCE, поддержка APK с v4.50) |
| `wizard` | `w` | — | Мастер создания профиля |
| `clean` | `c` | [тип] [цель] | Очистка: тип 1–6 (SRC) или 1–3 (IMG), 9=prune; цель — номер или A |
| `state` | `s` | — | Таблица профилей с флагами (F,P,S,M,H,X,OI,OS) |
| `check` | — | `<id>` | Добавить/обновить checksum в profiles/ID.conf |
| `check-all` | — | — | Добавить/обновить checksum:MD5 во все файлы из unpacker |
| `check-clear` | — | `[<id>]` | Очистить checksum:MD5 из всех файлов или одного профиля |
| `help` | `-h`, `--help` | — | Справка по ключам и выход |

**Язык интерфейса:** `--lang=RU` / `--lang=EN` или `-l RU` / `-l EN` (в любой позиции). Без ключа — автоопределение по системе.

**Позиционный вызов:** `_Builder.bat 2` трактуется как `build 2` (режим по умолчанию — IB). Регистр команд не учитывается.

**Примеры:** `_Builder.bat build 1`, `_Builder.bat --lang=EN build 1`, `_Builder.bat ib build 1`, `_Builder.bat src build-all`, `_Builder.bat clean 2 3`, `_Builder.bat check 1`, `_Builder.bat check-all`, `_Builder.bat --help`

**Тестовые оболочки CLI:** `tester.bat` / `tester.sh` запускают билдеры с аргументами и проверяют коды выхода и вывод; только безопасные проверки (без сборок, очистки и menuconfig). Логи в `.gitignore`.

---

## 2.5. APK Scanner — валидация и переименование (RU)

```mermaid
flowchart TD
    S_START([APK Scanner\napk_scanner.sh / .ps1])
    S_START --> S_LANG[Язык: APK_SCANNER_LANG=RU/EN\nили -Lang параметр]
    S_LANG --> S_PARAMS[Вход: PROFILE_ID, TARGET_ARCH]
    S_PARAMS --> S_SCAN{*.apk в\ncustom_packages/<profile>/ ?}
    S_SCAN --> |нет| S_EXIT_OK[exit 0 — тихо]
    S_SCAN --> |да| S_FOR[Для каждого APK]

    S_FOR --> S_DUMP[docker run --rm alpine:latest\napk adbdump -- /input/file.apk]
    S_DUMP --> S_PARSE{.PKGINFO\nраспарсен?}
    S_PARSE --> |нет| S_ERR["Ошибка парсинга\nexit 1"]
    S_PARSE --> |да| S_EXTRACT[Извлечь: name, version, release, arch]

    S_EXTRACT --> S_ARCH{Проверка архитектуры}
    S_ARCH --> |noarch/all| S_ARCH_UNIV["УНИВЕРСАЛЬНАЯ → OK"]
    S_ARCH --> |совпадение| S_ARCH_OK["СОВПАДЕНИЕ → OK"]
    S_ARCH --> |несовпадение| S_ARCH_WARN["ПРЕДУПРЕЖДЕНИЕ\nне блокировка"]

    S_ARCH_UNIV & S_ARCH_OK & S_ARCH_WARN --> S_NAME{Сверка имени\nfilename vs metadata?}
    S_NAME --> |совпадает| S_NAME_OK["Имя соответствует → OK"]
    S_NAME --> |нет| S_PROMPT["Переименовать?\nY/n"]
    S_PROMPT --> S_YES{Y?}
    S_YES --> |да| S_REN[mv / Rename-Item\n✓ Переименован]
    S_YES --> |нет| S_SKIP["Пропущено\n→ предупреждение"]

    S_NAME_OK & S_REN & S_SKIP & S_ARCH_WARN & S_ERR --> S_SUMMARY["Итог: проверено N\nпереименовано M, предупреждений W"]
    S_SUMMARY --> S_EXIT{Есть отказы\nили отказ от rename?}
    S_EXIT --> |нет| S_EXIT_OK
    S_EXIT --> |да| S_EXIT_WARN[exit 1]
```

### Интеграция сканера в build_routine (IB-режим)

```mermaid
flowchart TD
    BR_IB([build_routine\nIB-режим])
    BR_IB --> BR_ARCH[Извлечь SRC_ARCH\nиз profiles/<id>.conf]
    BR_ARCH --> BR_APK{.apk файлы в\ncustom_packages/<profile>/ ?}
    BR_APK --> |нет| BR_COMPOSE[docker compose up\nстандартный IB процесс]
    BR_APK --> |да| BR_SCAN[Запуск apk_scanner\nAPK_SCANNER_LANG=$SYS_LANG  sh\n-Lang !SYS_LANG!  bat]
    BR_SCAN --> BR_SCAN_EXIT{exit code?}
    BR_SCAN_EXIT --> |0| BR_COMPOSE
    BR_SCAN_EXIT --> |1| BR_PROMPT["Продолжить сборку?\nY/n"]
    BR_PROMPT --> BR_CONT{Y?}
    BR_CONT --> |да| BR_COMPOSE
    BR_CONT --> |нет| BR_ABORT[abort, возврат в меню]
```

### Место кнопки [S] в главном меню

```mermaid
flowchart TD
    MENU([Главное меню])
    MENU --> CHOICE{Ввод}
    CHOICE --> |S| S_CHECK{Режим\nIMAGE?}
    S_CHECK --> |нет| S_NOAPK["Сканер работает\nтолько в IB-режиме"]
    S_NOAPK --> MENU
    S_CHECK --> |да| S_LIST["Список профилей\nвыбор ID"]
    S_LIST --> S_ID{ID}
    S_ID --> |0| MENU
    S_ID --> |1..N| S_RUN[apk_scanner: .sh p_id p_arch / .ps1 -ProfileID -TargetArch -Lang\ncustom_packages/<profile>/*.apk]
    S_RUN --> S_RESULT{"exit 0 или 1?\nпоказать итог"}
    S_RESULT --> MENU
```

---

## 3. Сборка и пост-действия (RU)

```mermaid
flowchart TD
    BR([build_routine\nprofile.conf])
    BR --> READ_PROFILE["Чтение переменных профиля\nIMAGE или SRC"]
    READ_PROFILE --> LEGACY{"Проверка Legacy\nURL 17/18/19 или ветка 19.07/18.06?"}
    LEGACY --> |да img| OLD_IMG["builder-oldwrt\nUbuntu 18.04"]
    LEGACY --> |нет img| NEW_IMG["builder-openwrt\nUbuntu 22.04"]
    LEGACY --> |да src| OLD_SRC["builder-src-oldwrt\nUbuntu 18.04"]
    LEGACY --> |нет src| NEW_SRC["builder-src-openwrt\nUbuntu 24.04"]

    OLD_IMG & NEW_IMG --> IB["ib_builder.sh\nтома: cache, ipk-cache\noverlay_files, input_packages"]
    IB --> IB_STEPS["Скачать/кэш SDK\nРаспаковка, OpenSSL fix\nкопирование .ipk, ROOTFS/KERNEL\nCUSTOM_KEYS, CUSTOM_REPOS\nmake image x2"]
    IB_STEPS --> IB_OUT["Копирование в\nfirmware_output/imagebuilder/<id>/<ts>"]
    IB_OUT --> IB_CHOWN["alpine chown\nHOST_OUTPUT_DIR"]
    IB_CHOWN --> BR_END([return])

    OLD_SRC & NEW_SRC --> SB["src_builder.sh\nтома: workdir, dl-cache, ccache\npatches, overlay_files"]
    SB --> SB_STEPS["chown, git, feeds, patches\nhooks.sh/откат, .config, overlay\nmake download, затем сборка:\n-j1 V=s (если SRC_CORES=debug)\n-jN (параллельно, с откатом на debug при сбое)"]
    SB_STEPS --> SB_OUT["Копирование в\nfirmware_output/sourcebuilder/<id>/<ts>"]
    SB_OUT --> SB_CHOWN["alpine chown\nHOST_OUTPUT_DIR"]
    SB_CHOWN --> SB_OK{"Сборка\nуспешна?"}
    SB_OK --> |нет| SB_FATAL["L_BUILD_FATAL"]
    SB_FATAL --> SB_SHELL_Q2
    SB_OK --> |да| IB_TAR{"*imagebuilder*\n.tar.zst в выводе?"}
    IB_TAR --> |да| SB_Q1["Вопрос: Обновить\nIMAGEBUILDER_URL? y/N"]
    SB_Q1 --> SB_UPDATE{"Y?"}
    SB_UPDATE --> |да| SB_WRITE["Правка profiles/<id>.conf\nдобавить/закомментировать IMAGEBUILDER_URL"]
    SB_UPDATE --> |нет| SB_SHELL_Q2
    SB_WRITE --> SB_SHELL_Q2["Вопрос: Остаться в\nконтейнере? Y/n"]
    IB_TAR --> |нет| SB_SHELL_Q2
    SB_SHELL_Q2 --> SB_STAY{"Y?"}
    SB_STAY --> |да| SB_RUN["docker compose run\n--rm -it /bin/bash"]
    SB_STAY --> |нет| BR_END
    SB_RUN --> BR_END
```

---

## 4. Cleanup Wizard (RU)

```mermaid
flowchart TD
    CW([cleanup_wizard\nBUILD_MODE])
    CW --> CW_MODE{Режим\nBUILD_MODE?}
    CW_MODE --> |SOURCE| SRC_MENU[1=make clean\n2=src-workdir\n3=src-dl-cache\n4=src-ccache\n5=rm tmp\n6=Полный сброс\n9=docker prune\n0=назад]
    CW_MODE --> |IMAGE| IMG_MENU[1=imagebuilder-cache\n2=ipk-cache\n3=Полный сброс\n9=docker prune\n0=назад]

    SRC_MENU --> C_SEL[Выбор 1-6, 9 или 0]
    IMG_MENU --> C_SEL
    C_SEL --> |0| CW_BACK([возврат в MENU])
    C_SEL --> |9| PRUNE[docker system prune -f\nPress Enter]
    PRUNE --> CW_BACK
    C_SEL --> |1-6 или 1-3| T_SEL[Цель: номер профиля\nили A = ВСЕ]
    T_SEL --> REL[release_locks\ntarget_id]
    REL --> ALL_OK{Цель\nALL?}
    ALL_OK --> |да + 1 или 5| SOFT_ERR[L_CLEAN_SOFT_ALL_ERR\nтолько один профиль]
    SOFT_ERR --> CW_BACK
    ALL_OK --> |нет или 2,3,4,6| EXEC
    T_SEL --> EXEC{Действие}

    EXEC --> |SRC 1| SRC_SOFT[docker run\nmake clean]
    EXEC --> |SRC 2| SRC_WORK[cleanup_logic\nsrc-workdir]
    EXEC --> |SRC 3| SRC_DL[cleanup_logic\nsrc-dl-cache]
    EXEC --> |SRC 4| SRC_CC[cleanup_logic\nsrc-ccache]
    EXEC --> |SRC 5| SRC_TMP[docker run\nrm -rf tmp/]
    EXEC --> |SRC 6| SRC_FULL[workdir+dl+ccache\nrm firmware_output/sourcebuilder/id]
    EXEC --> |IMG 1| IMG_SDK[cleanup_logic\nimagebuilder-cache]
    EXEC --> |IMG 2| IMG_IPK[cleanup_logic\nipk/apk-cache]
    EXEC --> |IMG 3| IMG_FULL[оба кэша\nrm firmware_output/imagebuilder/id]

    SRC_SOFT & SRC_WORK & SRC_DL & SRC_CC & SRC_TMP & SRC_FULL --> DONE[Press Enter]
    IMG_SDK & IMG_IPK & IMG_FULL --> DONE
    DONE --> CW_BACK
```

---

## 5. Поток Menuconfig (RU)

```mermaid
flowchart TD
    K_START([K → run_menuconfig\nпрофиль])
    K_START --> K_GEN[Генерация\n_menuconfig_runner.sh\nв firmware_output/sourcebuilder/id/]
    K_GEN --> K_RUN[docker compose run\n--rm -it\nскрипт runner]
    K_RUN --> K_RUNNER[git init/checkout при необходимости\nвнедрение src_packages\nподготовка .config\nmake menuconfig\nmake defconfig, diffconfig\n→ manual_config]
    K_RUNNER --> K_OUT[Выход из контейнера]
    K_OUT --> K_HAVE{manual_config\nсуществует?}
    K_HAVE --> |нет| K_CLEAN[rm _menuconfig_runner.sh\nPress Enter]
    K_HAVE --> |да| K_APPLY[Вопрос: Применить к\nпрофилю? Y/n]
    K_APPLY --> K_YES{Y?}
    K_YES --> |да| K_PERL[perl замена\nSRC_EXTRA_CONFIG в профиле\nmv manual_config → applied_config_ts.bak]
    K_YES --> |нет| K_DISC[mv manual_config\n→ discarded_config_ts.bak]
    K_PERL --> K_CLEAN
    K_DISC --> K_CLEAN
    K_CLEAN --> K_END([возврат в MENU])
```

---

## Легенда (таблица при отрисовке меню)

| Symbol | Meaning |
|--------|---------|
| F | custom_files/<id> non-empty |
| P | custom_packages/<id> non-empty |
| S | src_packages/<id> non-empty |
| M | manual_config exists (sourcebuilder/<id>) |
| H | hooks.sh in custom_files/<id> |
| X | custom_patches/<id> non-empty |
| OI | firmware_output/imagebuilder/<id> has files |
| OS | firmware_output/sourcebuilder/<id> has files |
