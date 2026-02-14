# Аудит: _Builder.sh vs _Builder.bat

**Версии:**
- `_Builder.sh`: v4.20
- `_Builder.bat`: v4.32

Отставание: 0.12 версии

---

## Критические отличия (.bat → .sh отсутствует)

### 1. Папка custom_patches
| Место | .bat | .sh |
|-------|------|-----|
| Инициализация | `call :CHECK_DIR "custom_patches"` (стр 395) | ❌ отсутствует |
| Индикатор | `st_pt=X` (стр 515) | ❌ отсутствует |
| Использование в сборке | `HOST_PATCHES_DIR=./custom_patches/%PROFILE_ID%` (стр 1439) | ❌ отсутствует |

**Проблема:** SOURCE BUILDER в .bat использует custom_patches для патчей исходников, .sh не имеет этой функциональности.

---

### 2. Очистка кэша индекса пакетов (tmp)

**Меню SOURCE BUILDER:**

| Опция | .bat | .sh |
|-------|------|-----|
| SOFT CLEAN | ✅ п.1 | ✅ п.1 |
| HARD RESET | ✅ п.2 | ✅ п.2 |
| Source Cache (dl) | ✅ п.3 | ✅ п.3 |
| CCACHE | ✅ п.4 | ✅ п.4 |
| **Package Index (tmp)** | ✅ **п.5** | ❌ **отсутствует** |
| FULL RESET | ✅ п.6 | ✅ п.5 |

**Реализация в .bat (строки 1028-1045):**
```batch
:EXEC_SRC_TMP
docker-compose -f system/docker-compose-src.yaml -p %PROJ_NAME% run --rm builder-src-openwrt /bin/bash -c "cd /home/build/openwrt && rm -rf tmp/ && echo '[DONE] Index/Tmp cleaned'"
```

**Зачем нужно:** Исправляет проблемы с "залипшими" версиями пакетов в индексе OpenWrt.

---

### 3. Редактор профилей - открытие папок

**.bat (строки 644-658):**
```
Открыть также папки ресурсов в Проводнике? [Y/N]:
```
При "Y" открывает через `start explorer`:
- custom_files/{id}
- custom_packages/{id}
- src_packages/{id}
- firmware_output/sourcebuilder/{id}
- firmware_output/imagebuilder/{id}

**.sh:** ❌ Функция отсутствует

**Для Linux можно использовать:** `xdg-open {папка}` или `{editor} {папка}`

---

### 4. Menuconfig - предупреждение о перезаписи

**.bat (строки 1196-1211):**
```batch
if exist "%WIN_OUT_PATH%\manual_config" (
    echo.
    echo !L_K_WARN_EX!
    echo    1. Мы ЗАГРУСТИМ его в редактор [вы продолжите настройку].
    echo    2. После выхода из меню файл будет ПЕРЕЗАПИСАН новыми данными.
    echo.
    set /p "overwrite=%L_K_CONT%: "
    if /i not "!overwrite!"=="Y" (
        echo !L_K_CANCELLED!
        pause
        goto MENU
    )
)
```

**.sh:** ❌ Предупреждение отсутствует, сразу перезаписывает

---

## Сводная таблица

| Функция | .bat v4.32 | .sh v4.20 | Статус |
|---------|------------|-----------|--------|
| Создание `custom_patches` | ✅ | ❌ | **Критично** |
| Индикатор X (Patches) | ✅ | ❌ | **Важно** |
| Очистка tmp (index cache) | ✅ | ❌ | **Полезно** |
| Открытие папок в редакторе | ✅ | ❌ | **Удобно** |
| Предупреждение перезаписи | ✅ | ❌ | **Важно** |
| Параллельная массовая сборка | ❌ | ✅ | .sh выигрывает |
| Логирование сборок | ❌ | ✅ | .sh выигрывает |

---

## Рекомендации (приоритет)

### P0 (Критично)
1. Добавить `check_dir "custom_patches"` в инициализацию .sh
2. Добавить индикатор `X` для custom_patches в главное меню .sh

### P1 (Важно)
3. Реализовать очистку tmp (строки: docker-compose ... rm -rf tmp/)
4. Добавить предупреждение о перезаписи manual_config
5. Добавить открытие папок (xdg-open)

### P2 (Улучшения)
6. Расширить языковой детектор (9→10 баллов)
7. Добавить verbose вывод в cleanup хелперы

---

## Преимущества .sh (чего нет в .bat)

1. ✅ Параллельная массовая сборка с PID трекингом
2. ✅ Детальное логирование в `firmware_output/.build_logs/`
3. ✅ Отслеживание времени выполнения (Xm Ys)
4. ✅ Спиннер прогресса при массовой сборке
5. ✅ Исправление прав (chown) после сборки
6. ✅ Docker credentials fix (временный config без credsStore)
