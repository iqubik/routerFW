# RouterFW — Релиз 4.40

**Версия:** 4.40  
**Период изменений:** 12–18 февраля 2026 (от 4.32)

---

## Русский

### Что нового

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

### What's New

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
