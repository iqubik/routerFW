# routerFW — Process Diagrams / Диаграммы процессов

> Version: 4.43. Full diagram set. See [ARCHITECTURE_STUDY_PLAN.md](ARCHITECTURE_STUDY_PLAN.md) for coverage checklist.
>
> EN → [ARCHITECTURE_en.md](ARCHITECTURE_en.md) · RU → [ARCHITECTURE_ru.md](ARCHITECTURE_ru.md)

---

## 1. Startup sequence (EN)

```mermaid
flowchart TD
    START([_Builder.sh / _Builder.bat]) --> TRAP[trap SIGINT/SIGTERM\ncleanup_exit → release_locks ALL, rm .docker_tmp]
    TRAP --> COLORS[ANSI colors\nC_KEY, C_LBL, C_ERR, C_RST...]
    COLORS --> LANG_DET[Language detector\nLANG +4, locale +3, TZ +2 → SYS_LANG]
    LANG_DET --> LOAD_LANG[load_lang\nsystem/lang/ru.env or en.env → L_*, H_*]
    LOAD_LANG --> LANG_OUT[Print detector result\nScore, verdict]
    LANG_OUT --> DOCKER_CFG[Docker credentials fix\n.docker_tmp/config.json\nstrip credsStore/credHelpers]
    DOCKER_CFG --> DOCKER_CHK{docker & compose\npresent?}
    DOCKER_CHK --> |no| EXIT_DOCKER[L_ERR_DOCKER\nread, exit 1]
    DOCKER_CHK --> |yes| INIT_DIRS[check_dir\nprofiles, custom_files, firmware_output\ncustom_packages, src_packages, custom_patches]
    INIT_DIRS --> UNPACK{_unpacker.sh\npresent?}
    UNPACK --> |yes| RUN_UNPACK[bash _unpacker.sh]
    UNPACK --> |no| MIGRATE
    RUN_UNPACK --> MIGRATE[migrate_profile_vars\nPKGS→IMAGE_PKGS\nEXTRA_IMAGE_NAME→IMAGE_EXTRA_NAME]
    MIGRATE --> PATCH_ARCH[patch_architectures\nSRC_ARCH from SRC_TARGET/SUBTARGET]
    PATCH_ARCH --> MENU_LOOP[while true: draw menu]
```

---

## 2. Main menu — all choices (EN)

```mermaid
flowchart TD
    MENU([Main menu\nTable: profiles + F,P,S,M,H,X,OI,OS\nOn each draw: init dirs per profile\ncreate_perms_script])
    MENU --> CHOICE{User input}

    CHOICE --> |0 or Q| EXIT[Exit confirm\nY/n, sleep 3, exit 0]
    CHOICE --> |M| SWITCH[BUILD_MODE =\nIMAGE ↔ SOURCE]
    SWITCH --> MENU

    CHOICE --> |E| E_LIST[Edit: list profiles\nby number]
    E_LIST --> E_ID{ID 1..N\nor 0}
    E_ID --> |0| MENU
    E_ID --> |1..N| E_ANALYZE[Analyzer: custom_files\ncustom_packages, src_packages\noutput SB/IB]
    E_ANALYZE --> E_EDIT["$EDITOR (nano)\nprofiles/<id>.conf"]
    E_EDIT --> MENU

    CHOICE --> |A| A_CHECK{BUILD_MODE?}
    A_CHECK --> |SOURCE| A_WARN[Warn: mass build\nonly in IMAGE mode]
    A_WARN --> MENU
    A_CHECK --> |IMAGE| A_RUN[Log dir: .build_logs/<ts>\nSpawn build_routine for each profile\nbackground, collect PIDs]
    A_RUN --> A_WAIT[Spinner, wait all\nper-profile result + time]
    A_WAIT --> MENU

    CHOICE --> |K| K_CHECK{SOURCE\nmode?}
    K_CHECK --> |no| MENU
    K_CHECK --> |yes| K_LIST[Menuconfig: list profiles]
    K_LIST --> K_ID{ID or 0}
    K_ID --> |0| MENU
    K_ID --> |1..N| K_MC[run_menuconfig\n→ manual_config apply?]
    K_MC --> MENU

    CHOICE --> |I| I_CHECK{SOURCE?}
    I_CHECK --> |no| MENU
    I_CHECK --> |yes| I_LIST[Import IPK: list profiles]
    I_LIST --> I_ID{ID}
    I_ID --> I_RUN[import_ipk.sh p_id p_arch\ncustom_packages → src_packages]
    I_RUN --> MENU

    CHOICE --> |W| W_RUN[create_profile.sh / .ps1\nwizard → new profiles/name.conf]
    W_RUN --> MENU

    CHOICE --> |C| CLEAN_WIZ[Cleanup Wizard\nsee diagram 4]
    CLEAN_WIZ --> MENU

    CHOICE --> |1..N valid| BUILD[build_routine\nprofile N\nsee diagram 3]
    BUILD --> MENU

    CHOICE --> |invalid| ERR[L_ERR_INPUT\nsleep 1]
    ERR --> MENU
```

---

## 3. Build routine + post-actions (EN)

```mermaid
flowchart TD
    BR([build_routine\nprofile.conf])
    BR --> READ_PROFILE[Read profile vars\nIMAGE or SRC]
    READ_PROFILE --> LEGACY{Legacy check\nURL 17/18/19 or branch 19.07/18.06?}
    LEGACY --> |yes img| OLD_IMG[builder-oldwrt\nUbuntu 18.04]
    LEGACY --> |no img| NEW_IMG[builder-openwrt\nUbuntu 22.04]
    LEGACY --> |yes src| OLD_SRC[builder-src-oldwrt\nUbuntu 18.04]
    LEGACY --> |no src| NEW_SRC[builder-src-openwrt\nUbuntu 24.04]

    OLD_IMG & NEW_IMG --> IB[ib_builder.sh\nvolumes: cache, ipk-cache\noverlay_files, input_packages]
    IB --> IB_STEPS[Download/cache SDK\nExtract, OpenSSL fix\ncopy .ipk, ROOTFS/KERNEL\nCUSTOM_KEYS, CUSTOM_REPOS\nmake image x2]
    IB_STEPS --> IB_OUT[Copy to\nfirmware_output/imagebuilder/<id>/<ts>]
    IB_OUT --> IB_CHOWN[alpine chown\nHOST_OUTPUT_DIR]
    IB_CHOWN --> BR_END([return])

    OLD_SRC & NEW_SRC --> SB[src_builder.sh\nvolumes: workdir, dl-cache, ccache\npatches, overlay_files]
    SB --> SB_STEPS[chown, git fetch/reset\nfeeds, patches\nhooks.sh or VERMAGIC rollback\n.config, overlay → files\nmake download, make -jN]
    SB_STEPS --> SB_OUT[Copy to\nfirmware_output/sourcebuilder/<id>/<ts>]
    SB_OUT --> SB_OK{Build\nsuccess?}
    SB_OK --> |no| SB_FATAL[L_BUILD_FATAL]
    SB_FATAL --> SB_SHELL_Q2
    SB_OK --> |yes| IB_TAR{*imagebuilder*\n.tar.zst in output?}
    IB_TAR --> |yes| SB_Q1[Prompt: Update\nIMAGEBUILDER_URL? y/N]
    SB_Q1 --> SB_UPDATE{Y?}
    SB_UPDATE --> |yes| SB_WRITE[Edit profiles/<id>.conf\nadd/comment IMAGEBUILDER_URL]
    SB_UPDATE --> |no| SB_SHELL_Q2
    SB_WRITE --> SB_SHELL_Q2[Prompt: Stay in\ncontainer? Y/n]
    IB_TAR --> |no| SB_SHELL_Q2
    SB_SHELL_Q2 --> SB_STAY{Y?}
    SB_STAY --> |yes| SB_RUN[docker compose run\n--rm -it /bin/bash]
    SB_STAY --> |no| BR_END
    SB_RUN --> BR_END
```

---

## 4. Cleanup Wizard (EN)

```mermaid
flowchart TD
    CW([cleanup_wizard\nBUILD_MODE])
    CW --> CW_MODE{BUILD_MODE?}
    CW_MODE --> |SOURCE| SRC_MENU[1=make clean\n2=src-workdir\n3=src-dl-cache\n4=src-ccache\n5=rm tmp\n6=Full reset\n9=docker prune\n0=back]
    CW_MODE --> |IMAGE| IMG_MENU[1=imagebuilder-cache\n2=ipk-cache\n3=Full reset\n9=docker prune\n0=back]

    SRC_MENU --> C_SEL[Choice 1-6, 9 or 0]
    IMG_MENU --> C_SEL
    C_SEL --> |0| CW_BACK([return to MENU])
    C_SEL --> |9| PRUNE[docker system prune -f\nPress Enter]
    PRUNE --> CW_BACK
    C_SEL --> |1-6 or 1-3| T_SEL[Target: profile number\nor A = ALL]
    T_SEL --> REL[release_locks\ntarget_id]
    REL --> ALL_OK{Target\nALL?}
    ALL_OK --> |yes + 1 or 5| SOFT_ERR[L_CLEAN_SOFT_ALL_ERR\nonly single profile]
    SOFT_ERR --> CW_BACK
    ALL_OK --> |no or 2,3,4,6| EXEC
    T_SEL --> EXEC{Action}

    EXEC --> |SRC 1| SRC_SOFT[docker run\nmake clean]
    EXEC --> |SRC 2| SRC_WORK[cleanup_logic\nsrc-workdir]
    EXEC --> |SRC 3| SRC_DL[cleanup_logic\nsrc-dl-cache]
    EXEC --> |SRC 4| SRC_CC[cleanup_logic\nsrc-ccache]
    EXEC --> |SRC 5| SRC_TMP[docker run\nrm -rf tmp/]
    EXEC --> |SRC 6| SRC_FULL[workdir+dl+ccache\nrm firmware_output/sourcebuilder/id]
    EXEC --> |IMG 1| IMG_SDK[cleanup_logic\nimagebuilder-cache]
    EXEC --> |IMG 2| IMG_IPK[cleanup_logic\nipk-cache]
    EXEC --> |IMG 3| IMG_FULL[both caches\nrm firmware_output/imagebuilder/id]

    SRC_SOFT & SRC_WORK & SRC_DL & SRC_CC & SRC_TMP & SRC_FULL --> DONE[Press Enter]
    IMG_SDK & IMG_IPK & IMG_FULL --> DONE
    DONE --> CW_BACK
```

---

## 5. Menuconfig flow (EN)

```mermaid
flowchart TD
    K_START([K → run_menuconfig\nprofile])
    K_START --> K_GEN[Generate\n_menuconfig_runner.sh\nin firmware_output/sourcebuilder/id/]
    K_GEN --> K_RUN[docker compose run\n--rm -it\nrunner script]
    K_RUN --> K_RUNNER[git init/checkout if needed\ninject src_packages\nprepare .config\nmake menuconfig\nmake defconfig, diffconfig\n→ manual_config]
    K_RUNNER --> K_OUT[Exit container]
    K_OUT --> K_HAVE{manual_config\nexists?}
    K_HAVE --> |no| K_CLEAN[rm _menuconfig_runner.sh\nPress Enter]
    K_HAVE --> |yes| K_APPLY[Prompt: Apply to\nprofile? Y/n]
    K_APPLY --> K_YES{Y?}
    K_YES --> |yes| K_PERL[perl replace\nSRC_EXTRA_CONFIG in profile\nmv manual_config → applied_config_ts.bak]
    K_YES --> |no| K_DISC[mv manual_config\n→ discarded_config_ts.bak]
    K_PERL --> K_CLEAN
    K_DISC --> K_CLEAN
    K_CLEAN --> K_END([return to MENU])
```

---

## 6. Startup sequence (RU)

```mermaid
flowchart TD
    START([_Builder.sh / _Builder.bat]) --> TRAP[trap SIGINT/SIGTERM\ncleanup_exit → release_locks ALL, rm .docker_tmp]
    TRAP --> COLORS[ANSI-цвета\nC_KEY, C_LBL, C_ERR, C_RST...]
    COLORS --> LANG_DET[Детектор языка\nLANG +4, locale +3, TZ +2 → SYS_LANG]
    LANG_DET --> LOAD_LANG[load_lang\nsystem/lang/ru.env или en.env → L_*, H_*]
    LOAD_LANG --> LANG_OUT[Вывод результата детектора\nScore, verdict]
    LANG_OUT --> DOCKER_CFG[Исправление Docker credentials\n.docker_tmp/config.json\nудаление credsStore/credHelpers]
    DOCKER_CFG --> DOCKER_CHK{docker и compose\nустановлены?}
    DOCKER_CHK --> |нет| EXIT_DOCKER[L_ERR_DOCKER\nread, exit 1]
    DOCKER_CHK --> |да| INIT_DIRS[check_dir\nprofiles, custom_files, firmware_output\ncustom_packages, src_packages, custom_patches]
    INIT_DIRS --> UNPACK{_unpacker.sh\nесть?}
    UNPACK --> |да| RUN_UNPACK[bash _unpacker.sh]
    UNPACK --> |нет| MIGRATE
    RUN_UNPACK --> MIGRATE[migrate_profile_vars\nPKGS→IMAGE_PKGS\nEXTRA_IMAGE_NAME→IMAGE_EXTRA_NAME]
    MIGRATE --> PATCH_ARCH[patch_architectures\nSRC_ARCH из SRC_TARGET/SUBTARGET]
    PATCH_ARCH --> MENU_LOOP[while true: отрисовка меню]
```

---

## 7. Main menu — all choices (RU)

```mermaid
flowchart TD
    MENU([Главное меню\nТаблица: профили + F,P,S,M,H,X,OI,OS\nПри каждой отрисовке: init dirs\ncreate_perms_script])
    MENU --> CHOICE{Ввод пользователя}

    CHOICE --> |0 или Q| EXIT[Подтверждение выхода\nY/n, sleep 3, exit 0]
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
    I_CHECK --> |да| I_LIST[Импорт IPK: список профилей]
    I_LIST --> I_ID{ID}
    I_ID --> I_RUN[import_ipk.sh p_id p_arch\ncustom_packages → src_packages]
    I_RUN --> MENU

    CHOICE --> |W| W_RUN[create_profile.sh / .ps1\nмастер → новый profiles/name.conf]
    W_RUN --> MENU

    CHOICE --> |C| CLEAN_WIZ[Cleanup Wizard\nсм. диаграмму 4]
    CLEAN_WIZ --> MENU

    CHOICE --> |1..N верный| BUILD[build_routine\nпрофиль N\nсм. диаграмму 3]
    BUILD --> MENU

    CHOICE --> |неверный| ERR[L_ERR_INPUT\nsleep 1]
    ERR --> MENU
```

---

## 8. Build routine + post-actions (RU)

```mermaid
flowchart TD
    BR([build_routine\nprofile.conf])
    BR --> READ_PROFILE[Чтение переменных профиля\nIMAGE или SRC]
    READ_PROFILE --> LEGACY{Проверка Legacy\nURL 17/18/19 или ветка 19.07/18.06?}
    LEGACY --> |да img| OLD_IMG[builder-oldwrt\nUbuntu 18.04]
    LEGACY --> |нет img| NEW_IMG[builder-openwrt\nUbuntu 22.04]
    LEGACY --> |да src| OLD_SRC[builder-src-oldwrt\nUbuntu 18.04]
    LEGACY --> |нет src| NEW_SRC[builder-src-openwrt\nUbuntu 24.04]

    OLD_IMG & NEW_IMG --> IB[ib_builder.sh\nтома: cache, ipk-cache\noverlay_files, input_packages]
    IB --> IB_STEPS[Скачать/кэш SDK\nРаспаковка, OpenSSL fix\nкопирование .ipk, ROOTFS/KERNEL\nCUSTOM_KEYS, CUSTOM_REPOS\nmake image x2]
    IB_STEPS --> IB_OUT[Копирование в\nfirmware_output/imagebuilder/<id>/<ts>]
    IB_OUT --> IB_CHOWN[alpine chown\nHOST_OUTPUT_DIR]
    IB_CHOWN --> BR_END([return])

    OLD_SRC & NEW_SRC --> SB[src_builder.sh\nтома: workdir, dl-cache, ccache\npatches, overlay_files]
    SB --> SB_STEPS[chown, git fetch/reset\nfeeds, patches\nhooks.sh или откат VERMAGIC\n.config, overlay → files\nmake download, make -jN]
    SB_STEPS --> SB_OUT[Копирование в\nfirmware_output/sourcebuilder/<id>/<ts>]
    SB_OUT --> SB_OK{Сборка\nуспешна?}
    SB_OK --> |нет| SB_FATAL[L_BUILD_FATAL]
    SB_FATAL --> SB_SHELL_Q2
    SB_OK --> |да| IB_TAR{*imagebuilder*\n.tar.zst в выводе?}
    IB_TAR --> |да| SB_Q1[Вопрос: Обновить\nIMAGEBUILDER_URL? y/N]
    SB_Q1 --> SB_UPDATE{Y?}
    SB_UPDATE --> |да| SB_WRITE[Правка profiles/<id>.conf\nдобавить/закомментировать IMAGEBUILDER_URL]
    SB_UPDATE --> |нет| SB_SHELL_Q2
    SB_WRITE --> SB_SHELL_Q2[Вопрос: Остаться в\nконтейнере? Y/n]
    IB_TAR --> |нет| SB_SHELL_Q2
    SB_SHELL_Q2 --> SB_STAY{Y?}
    SB_STAY --> |да| SB_RUN[docker compose run\n--rm -it /bin/bash]
    SB_STAY --> |нет| BR_END
    SB_RUN --> BR_END
```

---

## 9. Cleanup Wizard (RU)

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
    EXEC --> |IMG 2| IMG_IPK[cleanup_logic\nipk-cache]
    EXEC --> |IMG 3| IMG_FULL[оба кэша\nrm firmware_output/imagebuilder/id]

    SRC_SOFT & SRC_WORK & SRC_DL & SRC_CC & SRC_TMP & SRC_FULL --> DONE[Press Enter]
    IMG_SDK & IMG_IPK & IMG_FULL --> DONE
    DONE --> CW_BACK
```

---

## 10. Menuconfig flow (RU)

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

## Legend (table on menu draw)

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
