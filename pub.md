Вот вариант текста релиза, переработанный для конечных пользователей. Он сохраняет суть технических изменений, но подает их через призму пользы, удобства и надежности.

---

# 🇷🇺 Release Notes 4.20

**Версия 4.20** — это знаковое обновление. Мы перешли на новую нумерацию версий (с 4.12 сразу на 4.20), чтобы подчеркнуть масштаб проделанной работы. Главная цель этого релиза — **стабильность** и **комфорт**. Мы устранили старые "болячки", сделали интерфейс дружелюбнее и полностью уравняли возможности скриптов для Windows и Linux.

### 🚀 Главные изменения

#### 💎 Железобетонная стабильность
Больше никаких ошибок "volume is in use" или странных блокировок.
*   **Умная очистка:** Мы полностью переписали механизм завершения работы. Скрипт теперь корректно останавливает все процессы Docker перед очисткой.
*   **Чистый выход:** Даже если вы прервете сборку через `Ctrl+C`, система аккуратно "приберет" за собой, не оставляя зависших контейнеров.
*   **Linux/WSL без боли:** Пользователям Linux больше не нужно использовать `sudo` для удаления или перемещения файлов прошивки. Скрипт автоматически возвращает вам права на созданные файлы.

#### 🎨 Новый уровень интерфейса (UI/UX)
Консоль стала не только красивее, но и полезнее.
*   **Цвет и ясность:** Мы переработали цветовую схему. Важная информация теперь сразу бросается в глаза, а сообщения стали понятнее.
*   **Тайм-менеджмент:** При массовой сборке (`[A]`) вы теперь видите **точное время**, затраченное на создание каждой прошивки, и четкий статус результата.
*   **Умный редактор:** Перед настройкой конфига (`[E]`) система подскажет, какие папки с ресурсами у вас уже есть, а какие еще предстоит создать.

#### 🛠 Технические улучшения и исправления
*   **Windows = Linux:** Функционал `_Builder.bat` и `_Builder.sh` теперь идентичен. Все фишки доступны на обеих платформах.
*   **Исправление для Xiaomi и других:** Исправлена ошибка в Windows-версии, из-за которой устройства с дефисом в названии (например, `xiaomi-4a-gigabit`) могли не собираться.
*   **Импорт пакетов:** Улучшена совместимость со старыми пакетами (`.ipk`). Зависимости вроде `libopenssl1.1` теперь автоматически адаптируются под новые версии OpenWrt.
*   **Чистые профили:** Мастер создания профилей обновлен под новый формат — меньше лишнего кода в конфигах, больше порядка.

---

# 🇺🇸 Release Notes 4.20

**Version 4.20** is a major milestone. Jumping from 4.12 to 4.20 signifies a massive shift in focus towards **stability** and **User Experience (UX)**. We have resolved long-standing issues, polished the interface, and achieved complete feature parity between Windows and Linux scripts.

### 🚀 Key Highlights

#### 💎 Rock-Solid Stability
Say goodbye to "volume is in use" errors and stuck processes.
*   **Smart Cleanup:** The cleanup engine has been completely rewritten. The script now aggressively but safely releases all Docker locks before attempting to remove volumes.
*   **Graceful Exit:** Even if you interrupt the build with `Ctrl+C`, the system will perform a clean shutdown, ensuring no "zombie" containers are left behind.
*   **Linux/WSL Permissions:** Linux users no longer need `sudo` to manage output files. The builder now automatically restores file ownership to the user after every build.

#### 🎨 Refined UI/UX
The console output is now cleaner, smarter, and more professional.
*   **Visual Clarity:** A completely new color coding system makes logs easier to read. Critical information stands out immediately.
*   **Better Monitoring:** During bulk builds (`[A]`), you can now see the **exact duration** of each task and a clear success/failure status.
*   **Smarter Editor:** Before editing a config (`[E]`), the system creates a summary dashboard showing which resource folders exist and which ones are missing.

#### 🛠 Improvements & Fixes
*   **Windows = Linux:** `_Builder.bat` and `_Builder.sh` are now fully synchronized. You get the same robust features regardless of your OS.
*   **Device Name Fix:** Fixed a bug in the Windows version where device names containing hyphens (e.g., `xiaomi-4a-gigabit`) caused build failures.
*   **Legacy Support:** The `.ipk` importer is now smarter. It automatically adjusts dependencies (like `libopenssl1.1`) to work with modern OpenWrt versions.
*   **Cleaner Profiles:** The profile creation wizard has been updated to the new format, producing cleaner and more forward-compatible configuration files.