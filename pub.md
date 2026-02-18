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
