# Changelog: Version 4.3

---

## 🚀 Версия 4.3: Система патчей исходного кода

Это обновление вводит мощный и гибкий механизм для модификации исходного кода OpenWrt, а также сопутствующие улучшения интерфейса и документации.

### ✨ Новая функция: Система патчей исходного кода (`custom_patches`)
-   **Что это дает:** Позволяет пользователям легко модифицировать исходный код OpenWrt перед компиляцией. Теперь можно изменять `Makefile`, добавлять `dts`-файлы или заменять любые другие файлы в исходниках, просто поместив их в папку `custom_patches/<имя_профиля>`, сохраняя оригинальную структуру директорий. Эта система значительно упрощает кастомизацию прошивок.
-   **Как это работает:** Система действует как "зеркальный оверлей". Файлы из `custom_patches` копируются поверх исходного кода перед запуском компиляции.
-   **Кросс-платформенная надежность:** Встроенная утилита `dos2unix` автоматически исправляет окончания строк Windows (CRLF), что предотвращает ошибки сборки при редактировании файлов в Windows.

### 🖥️ Улучшения интерфейса
-   В главном меню добавлен новый индикатор **`Pt`** (Patches), который сигнализирует о наличии патчей для профиля, делая управление сборками более наглядным.

### 📚 Обновление документации
-   **Добавлен "Урок 5"**: Создано новое подробное руководство по использованию системы патчей, доступное на русском (`docs/05-patch-sys copy.md`) и английском (`docs/05-patch-sys.en.md`) языках.
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
-   A new **`Pt`** (Patches) indicator has been added to the main menu, signaling the presence of patches for a profile and making build management more intuitive.

### 📚 Documentation Update
-   **Added "Lesson 5"**: A new detailed guide on using the patching system has been created, available in both Russian (`docs/05-patch-sys copy.md`) and English (`docs/05-patch-sys.en.md`).
-   **Updated READMEs**: The main `README.md` and `README.en.md` files have been updated with information about the new feature.
-   **Updated Indexes**: The `docs/index.md` and `docs/index.en.md` files now include links to the new guide.
