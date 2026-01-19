### RU

**Версия 4.12**

Ключевое обновление, направленное на повышение надежности, безопасности и воспроизводимости сборок в режиме "из исходников". Механизм сохранения конфигураций был полностью переработан, а окружение сборки — стабилизировано.

**Основные изменения:**

*   **Переработанный механизм `menuconfig`:** Логика обработки и сохранения конфигураций из `make menuconfig` (`SRC_EXTRA_CONFIG`) была полностью переписана в `_Builder.bat` и `_Builder.sh`. Новые скрипты стали значительно надежнее и корректно обрабатывают сложные конфигурации, включая спецсимволы и разные типы кавычек.
*   **Повышенная воспроизводимость сборок:** Переменная `SRC_EXTRA_CONFIG` во всех основных профилях была заполнена полным списком флагов конфигурации. Это эффективно "замораживает" проверенную конфигурацию для каждого профиля, кардинально улучшая консистентность сборок и снижая зависимость от ручных сессий `menuconfig`.
*   **Улучшенная безопасность:** Флаг `--security-opt seccomp=unconfined` был удален из команд `docker-compose`. Система сборки теперь работает без необходимости в понижении настроек безопасности.
*   **Исправление для Legacy-окружения:** Dockerfile для старых сборок (`system/src.dockerfile.legacy`) был исправлен и теперь указывает на официальные репозитории Ubuntu 18.04, что решает ошибки `apt-get` и восстанавливает возможность сборки старых версий прошивок.
*   **Оптимизация:** Скрипты-упаковщики (`_packer.sh`, `_packer.bat`) были обновлены и теперь включают более релевантный набор профилей по умолчанию.

---

### EN

**Version 4.12**

A major update focused on improving the reliability, security, and reproducibility of Source-mode builds. The configuration saving mechanism has been completely redesigned, and the build environment has been stabilized.

**Key Changes:**

*   **Redesigned `menuconfig` Handling:** The logic for processing and saving configurations from `make menuconfig` (`SRC_EXTRA_CONFIG`) has been completely overhauled in `_Builder.bat` and `_Builder.sh`. The new scripts are significantly more robust and correctly handle complex configurations, including those with special characters and different quoting styles.
*   **Enhanced Build Reproducibility:** The `SRC_EXTRA_CONFIG` variable in all major profiles has been populated with a full list of configuration flags. This effectively "locks in" a known-good configuration for each profile, dramatically improving build consistency and reducing reliance on manual `menuconfig` sessions.
*   **Improved Security:** The `--security-opt seccomp=unconfined` flag has been removed from `docker-compose` commands. The build system now operates without requiring this lowered security setting.
*   **Legacy Environment Fix:** The Dockerfile for legacy builds (`system/src.dockerfile.legacy`) has been corrected to point to the official Ubuntu 18.04 repositories, resolving `apt-get` errors and restoring the ability to build older firmware versions.
*   **Cleanup:** The packer scripts (`_packer.sh`, `_packer.bat`) have been updated to include a more streamlined set of default profiles.
