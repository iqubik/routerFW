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

---

*Release notes for GitHub — summary of changes from tag 4.45 to current 4.46.*
