# Language / Язык
[🇷🇺 Русский](#аудит-проекта-routerfw) | [🇺🇸 English](#routerfw-project-audit)

---

# Аудит проекта routerFW

**Срез:** версия `4.71` из `system/version.env`\
**Дата проверки:** 2026-11-11\
**Область:** корневые исходники, документация, агентские правила, текущий CI workflow. Приватные каталоги `custom_*`, `src_packages` и `firmware_output` не анализировались.

Этот файл — датированный снимок проверок, а не гарантия отсутствия дефектов. Для текущего поведения приоритет имеют исходники и `.github/workflows/tests.yml`; исторические сведения — в `CHANGELOG.md`.

## Проверка согласованности

| Область | Наблюдение | Статус |
|---|---|---|
| Версия | `system/version.env` задаёт 4.71; оба host builder и README синхронизированы | OK |
| Платформы | Windows Batch/PowerShell и Linux Bash host-слои; тяжёлые сборки выполняются в контейнерах | OK |
| Runtime | Docker и Podman; `auto`, `--runtime`, `-r`, WSL `.exe` bridge | OK |
| Image Builder images | Modern Ubuntu 24.04; legacy Ubuntu 20.04 | Проверено по Dockerfile |
| Source Builder images | Modern Ubuntu 24.04; legacy Ubuntu 18.04 | Проверено по Dockerfile |
| Compose | Базовые Docker Compose файлы + отдельные Podman overrides для IB/SB | OK |
| Массовая сборка | `build-all` поддерживается только для IB; Bash parallel, Windows sequential; SB отклоняется | Проверено в обоих builder |
| Cleanup | Global Docker/Podman prune отключён в меню и CLI | OK |
| Профили | Универсальные `.conf`, legacy migration `PKGS` / `EXTRA_IMAGE_NAME` | OK |
| Приватные данные | `custom_files`, `custom_packages`, `src_packages`, `custom_patches` исключены из обычного AI-анализа | Правило сохранено |
| Документация | README, архитектура, диаграммы, карта, audit, pub и agent notes актуализированы до 4.71 | Этот срез |

## CI: что проверяется сейчас

Источник: `.github/workflows/tests.yml`.

**Linux job:** Bash syntax для builder, packer, unpacker, tester и `system/*.sh`; syntax checks пользовательских shell scripts; ShellCheck; синхронизация RU/EN localization keys; версия; BOM; запрет global prune; детерминированность Linux packer; полный `tester.sh`; Linux unpacker smoke.

**Windows job:** Windows packer smoke и детерминированность; полный `tester.bat`; Windows unpacker smoke и отказ на повреждённом payload.

**Границы:** текущий workflow не выполняет реальную сборку firmware для устройства и не содержит отдельных Docker/Podman container-build smoke jobs. Успешный CI подтверждает только перечисленные проверки.

Release 4.71 фиксирует Windows regression suite: 53 теста пройдены; передача аргументов через `CALL` проверяется в 16 комбинациях Docker/Podman × Compose plugin/standalone без запуска контейнеров.

## Технические ограничения, которые должны оставаться видимыми в документации

- Source Builder использует persistent workdir, DL cache и CCache. Это ускоряет повторные сборки, но делает корректность очистки и синхронизации состояния важной.
- Управляемые `custom_patches` синхронизируются с учётом ownership-манифеста: неизменённые удалённые overlay-файлы убираются, неизвестные или изменённые пользователем файлы защищены.
- Оверлей `custom_files` переносится в `files/` до hooks без `--delete`; файлы, созданные hooks в `files/`, сохраняются и учитываются по поддерживаемым правилам ownership.
- Перед загрузкой и сборкой Source Builder проверяет доступность хранилищ, при подтверждённых `EROFS`/`EIO` останавливается. При прочих ошибках параллельной компиляции выполняется диагностический `make -j1 V=s` (если не выбран `debug`); он не устраняет неисправности хранилища.
- Image Builder отключает APK signature checking в make invocation для поддержки локальных неподписанных APK; это также затрагивает сетевые APK.
- Feeds обновляются по ключу репозитория/коммита/конфигурации с TTL (по умолчанию 24 ч). Это политика свежести, но не строгая фиксация внешних feed-коммитов.

## Проверки документации в этом срезе

- Устранены устаревшие версии в агентских инструкциях и audit.
- Исправлены описания базовых образов IB/SB.
- Исправлена документация `build-all` и отключённого global prune.
- Устранены Docker-only формулировки там, где фактически поддерживается Docker/Podman.
- Обновлены ссылки на уроки и описание APK Scanner.
- Синхронизированы RU/EN пары и Mermaid-диаграммы.
- Оба packer включают все 25 Markdown-файлов из `docs/`, на которые ссылаются README и индексы.
- Packer roundtrip-тесты расширены: проверяют восстановление документации, архитектуры, диаграмм, карты и audit.
- Проверены относительные ссылки и checksum footer для изменённых файлов.

**Не проверялось этим аудитом:** реальные firmware builds, Windows runtime локально, Docker/Podman execution, ShellCheck локально. Изменения исходного кода сборщиков не входят в этот срез.

---

# routerFW Project Audit

**Snapshot:** version `4.71` from `system/version.env`\
**Review date:** 2026-11-11\
**Scope:** root source, documentation, agent rules, and the current CI workflow. Private `custom_*`, `src_packages`, and `firmware_output` contents were not inspected.

This is a dated verification snapshot, not a guarantee that the repository is defect-free. Current behavior is defined by source and `.github/workflows/tests.yml`; historical changes belong in `CHANGELOG.md`.

## Consistency checks

| Area | Observation | Status |
|---|---|---|
| Version | `system/version.env` defines 4.71; both host builders and READMEs are synchronized | OK |
| Platforms | Windows Batch/PowerShell and Linux Bash host layers; heavy builds run in containers | OK |
| Runtime | Docker and Podman; `auto`, `--runtime`, `-r`, WSL `.exe` bridge | OK |
| Image Builder images | Modern Ubuntu 24.04; legacy Ubuntu 20.04 | Verified from Dockerfiles |
| Source Builder images | Modern Ubuntu 24.04; legacy Ubuntu 18.04 | Verified from Dockerfiles |
| Compose | Docker Compose base files plus separate Podman overrides for IB/SB | OK |
| Mass build | `build-all` is IB-only; Bash parallel, Windows sequential; SB rejects it | Verified in both builders |
| Cleanup | Global Docker/Podman prune is disabled in menu and CLI | OK |
| Profiles | Shared `.conf` model; legacy `PKGS` / `EXTRA_IMAGE_NAME` migration | OK |
| Private data | `custom_files`, `custom_packages`, `src_packages`, `custom_patches` remain outside routine AI analysis | Rule preserved |
| Documentation | README, architecture, diagrams, map, audit, pub, and agent notes updated for 4.71 | This slice |

## Current CI coverage

Source: `.github/workflows/tests.yml`.

**Linux job:** Bash/custom-shell syntax, ShellCheck, RU/EN localization-key sync, version and BOM checks, global-prune guard, Linux packer determinism, full `tester.sh`, Linux unpacker smoke.

**Windows job:** Windows packer smoke/determinism, full `tester.bat`, Windows unpacker smoke, corrupt-payload rejection smoke.

**Limits:** the current workflow does not build real device firmware and does not contain separate Docker/Podman container-build smoke jobs. A green CI run proves only the checks listed above.

Release 4.71 records 53 passing Windows tests. Argument preservation across `CALL` is checked in 16 Docker/Podman × Compose plugin/standalone combinations without starting containers.

## Technical limitations that must remain visible in documentation

- Source Builder uses persistent workdir, download cache, and CCache. This speeds up repeat builds but makes state cleanup and synchronization important.
- Managed `custom_patches` are synchronized using an ownership manifest: unchanged removed overlay files can be pruned, while unknown or user-modified files are protected.
- The `custom_files` overlay is applied to `files/` **before** hooks, without `--delete`. Hook-generated `files/` outputs are retained and tracked within the supported ownership boundary.
- Source Builder probes storage before downloads and compilation and aborts on confirmed `EROFS`/`EIO`. Other parallel compilation failures trigger a diagnostic `make -j1 V=s` retry (unless `debug` was selected); it cannot repair storage faults.
- Image Builder disables APK signature checking in its make invocation to allow local unsigned APKs; this also affects network APK signature verification.
- Feeds refresh uses repository/commit/configuration identity and a TTL (24 hours by default). This is a freshness policy, not a strict pin of external feed commits.

## Documentation checks in this slice

- Removed stale versions from agent instructions and audit.
- Corrected IB/SB base-image descriptions.
- Corrected `build-all` and disabled global-prune descriptions.
- Replaced Docker-only wording where Docker/Podman are both supported.
- Updated APK Scanner references and lesson links.
- Synchronized RU/EN pairs and Mermaid diagrams.
- Both packers include all 25 Markdown files under `docs/` linked from README and the indexes.
- Packer roundtrip tests now verify recovery of lessons, architecture, diagrams, map, and audit.
- Checked relative links and checksum footers for modified files.

**Not tested in this audit:** real firmware builds, local Windows runtime, Docker/Podman execution, and local ShellCheck. Builder source-code changes are outside this documentation slice.
# checksum:MD5=1d0965d0e685f912fe68319b2bf34c21