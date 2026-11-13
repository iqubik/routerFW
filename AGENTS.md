# routerFW repository guidance

Migrated without dropping content from GEMINI.md and .cursor/rules/*.mdc on 2026-11-13. Verify implementation and CI for current behavior.

AGENTS.md is now the canonical repository guidance. The GEMINI.md and .cursor/rules sections below preserve their former contents; references to those filenames describe the old layout and should be maintained here instead.

## Current implementation notes (2026-11-13)

- Windows test and local maintenance tools use the repository's `tools/runtime/python313` embeddable CPython with `-B`. WSL/Linux use native Python with `-B`; the bundled interpreter is Windows-only.
- Do not add repository-only tools or the Python runtime to `_packer.bat` or `_packer.sh`. `scripts/validate_build.py` is local audit tooling; IB/SB build snapshot capture/finalize code lives in the builder scripts.
- `system/profile_state.ps1` is the canonical source for the Windows state scanner, embedded in `_Builder.bat` and excluded as a separate packer payload. `_Builder.sh` implements its state scan in Bash.

## GEMINI.md (migrated verbatim)

# GEMINI.md — routerFW project context for AI agents

**Current version:** 4.71 (source: `system/version.env`) · **Repository:** https://github.com/iqubik/routerFW · **License:** GPL-3.0

This file is an onboarding index, not an authority over the implementation. Verify behavior in current root-level source files and current CI. Historical feature-introduction versions in this file are not current-version indicators.

## 1. Project overview

routerFW is a cross-platform, text-first framework for building OpenWrt/ImmortalWrt firmware. Windows uses `_Builder.bat`; Linux uses `_Builder.sh`. The host scripts provide an interactive menu and CLI, and orchestrate one of two containerized build engines:

- **Image Builder (IB):** `system/ib_builder.sh` uses a prebuilt ImageBuilder SDK for package/overlay customization and `make image`.
- **Source Builder (SB):** `system/src_builder.sh` fetches source, manages feeds/patches/hooks/configuration, and compiles firmware.

The container runtime is independently selectable: Docker or Podman. `ROUTERFW_RUNTIME=auto|docker|podman`, `--runtime=...`, and `-r ...` are supported. Bash under WSL may use `docker.exe` / `podman.exe` bridges.

## 2. Current container images

| Builder | Modern | Legacy |
|---|---|---|
| Image Builder | `system/dockerfile` — Ubuntu 24.04 | `system/dockerfile.legacy` — Ubuntu 20.04 |
| Source Builder | `system/src.dockerfile` — Ubuntu 24.04 | `system/src.dockerfile.legacy` — Ubuntu 18.04 |

Do not describe both legacy images as the same Ubuntu version.

## 3. Directory structure and key files

| Path | Purpose |
|---|---|
| `_Builder.bat` / `_Builder.sh` | Host entry points, CLI/menu, profile/runtime/Compose orchestration. |
| `system/` | IB/SB engines, Dockerfiles, Docker/Podman Compose files, wizards, importer, APK scanner, localization, version. |
| `system/version.env` | Canonical project version (`ROUTERFW_VERSION`). |
| `profiles/*.conf` | Shared IB/SB profile; sourced as shell code, therefore trusted input. |
| `custom_files/<profile>/` | Firmware rootfs overlay. Private; do not inspect without explicit permission. |
| `custom_packages/<profile>/` | Binary IPK/APK input. Private. |
| `src_packages/<profile>/` | Source packages/imported binary wrappers. Private. |
| `custom_patches/<profile>/` | Source-tree mirror overlay. Private. |
| `firmware_output/` | Firmware artifacts, logs, and `manual_config`; generated/large. |
| `scripts/` | Router-side utilities and Source Builder hook template. |
| `docs/` | Eight RU/EN lessons, architecture descriptions and diagrams, development map, audit. |
| `.cursor/rules/` | Agent rules for project, build system, Batch, Bash, profiles, Docker/Podman, docs, and restricted files. |
| `tester.sh` / `tester.bat` | CLI and project-health regression harnesses. |
| `capture_worktree_diff.bat` | Maintainer helper: creates a diagnostic `diff.zip` from tracked and untracked worktree changes; not part of runtime distributions. |
| `.github/workflows/tests.yml` | Current Linux and Windows CI. |
| `_packer.sh` / `_packer.bat` | Generates self-extracting distribution. |
| `_unpacker.sh` / `_unpacker.bat` | Generated Base64 payloads; never inspect or hand-edit. |

`nl_test/` and `nw_test/` are temporary unpacked snapshots. Root-level canonical files are the source of truth.

## 4. Profiles

Required identity: `PROFILE_NAME`, `TARGET_PROFILE`.

- IB: `IMAGEBUILDER_URL`, `IMAGE_PKGS`, `IMAGE_EXTRA_NAME`, `CUSTOM_KEYS`, `CUSTOM_REPOS`, `DISABLED_SERVICES`.
- SB: `SRC_REPO`, `SRC_BRANCH`, `SRC_TARGET`, `SRC_SUBTARGET`, `SRC_ARCH`, `SRC_CORES`, `SRC_PACKAGES`, `SRC_EXTRA_CONFIG`.
- Shared: `ROOTFS_SIZE`, `KERNEL_SIZE`.
- Legacy `PKGS` / `EXTRA_IMAGE_NAME` names are migrated to `IMAGE_PKGS` / `IMAGE_EXTRA_NAME`.
- `SRC_CORES`: unset = all cores; `safe` = N-1; integer = fixed jobs; `debug` = one verbose job (`make -j1 V=s`).
- `manual_config` in the profile's Source Builder output folder takes precedence over profile-generated Kconfig.

Profiles are sourced shell scripts. Treat profiles, hooks, external feeds/keys, patches, and packages as trusted executable/build inputs; inspect third-party material before use.

## 5. CLI and build-all constraints

Optional prefix: `ib` / `image` for IB, `src` / `source` for SB. Without a prefix, IB is the default.

Commands include `build`, `build-all`, `edit`, `menuconfig`, `import`, `wizard`, `clean`, `state`, `check`, `check-all`, `check-clear`, and `help`.
- `state`/`s` use one PowerShell scan on BAT and stop `find` at the first file on SH; `ROUTERFW_STATE_PROFILE=1` adds read-only phase timings to stderr. Empty directories do not count as state flags.

**Important:** Source Builder `build-all` is intentionally rejected. Image Builder `build-all` is supported. Bash runs IB profiles in parallel, controlled by `ROUTERFW_JOBS` (default 6); Windows Batch runs them sequentially. Do not document `src build-all` as supported.

Global Docker/Podman prune is disabled in interactive and CLI cleanup. Never reintroduce system-wide prune.

## 6. Source Builder ordering and state

Persistent per-profile Compose volumes:
- `src-workdir` — OpenWrt source tree.
- `src-dl-cache` — downloaded source archives.
- `src-ccache` — CCache, max size 20 GB.

Current order in `system/src_builder.sh`:
1. Permission check; execute build body as user `build`.
2. Fetch the selected Git branch/tag, verify exact detached `HEAD == FETCH_HEAD^{commit}`. Switching `SRC_REPO` in a populated persistent workdir is rejected without deleting data; reset only that profile's `src-workdir` through the Cleanup Wizard before changing upstream. Menuconfig uses a separate runner and is not covered by this specific guard.
3. Refresh feeds based on repository, branch, fetched commit, active `feeds.conf`/`feeds.conf.default` hash and TTL (24 hours by default). The optional profile setting `SRC_FEEDS_MAX_AGE_HOURS=0` forces every-run refresh. Failed or missing feeds are never marked valid. This does not pin independently moving feed branches for deterministic builds.
4. Synchronize managed patches and the firmware `files/` overlay **before** hooks, using ownership tracking and no destructive `rsync --delete`.
5. Run `custom_files/hooks.sh` or inspect/rollback supported Vermagic markers; capture new hook-generated `files/` entries.
6. Generate/use `.config`, run `make defconfig`, and copy source packages.
7. Run `make download` with bounded SHA-mismatch recovery; compile with configured jobs. Failed parallel `make` triggers one `make -j1 V=s` retry unless debug mode was requested initially.
8. Export all regular BIN_DIR files except the root `packages/` subtree, preserving relative paths and verifying published bytes and SHA256. No device/bootloader-specific repairs belong in the shared pipeline.

Consequences to keep documented: managed untracked patches/overlays may be removed only if still unchanged; unknown/modified files remain protected. Hook-generated `files/` entries are preserved by the ordering and tracked within supported ownership boundaries. An incremental build may contain existing files that OpenWrt did not regenerate. The Source Builder now probes workdir, `dl`, CCache, `/tmp`, and output storage before download/compile and after `make` failures. Confirmed storage/permission faults abort without retry or automatic cleanup; only failures with currently healthy storage take the verbose retry path. An earlier transient fault may remain unclassified.

## 7. APK and package security

The APK Scanner resolves the selected Docker/Podman runtime and uses `alpine:latest` with `apk adbdump`. It checks package metadata/filename and reports architecture mismatches. `noarch`/`all` are metadata architecture labels, not a guarantee that every dependency is compatible.

Image Builder currently disables APK signature checking in its build invocation to allow local unsigned APKs; this also affects network APK signature verification. Do not describe the exception as limited to local files.

## 8. Current CI coverage

Read `.github/workflows/tests.yml` before describing CI. Its jobs call the same locally runnable test harnesses:
- Linux: `bash ./tester.sh` (syntax, ShellCheck, CLI, packaging/unpacking, corruption, Source Builder storage and Git/feeds regressions). Requires installed ShellCheck. CI runner OS labels are pinned to `ubuntu-24.04` / `windows-2025` (not immutable package versions); do not silently revert to `*-latest`.
- Windows: `tester.bat` (native Windows CLI and packer/unpacker regression suite). Windows Python CLI/CCache fixtures prefer Git for Windows Bash, then other candidates (including installed WSL). Selection checks Bash syntax, reading the repository script, and mktemp/sed file operations, with POSIX TMPDIR=/tmp. A missing or incompatible interpreter fails the regression explicitly rather than silently skipping.
- Docker and Podman: individual CI jobs call `bash ./tester.sh "Docker Smoke"` and `bash ./tester.sh "Podman Smoke"`; full local parity via `bash ./tester.sh --ci` when runtimes and dependencies are installed.
- Real container smoke does **not** compile device firmware. Passing the local harness does not establish an unrun remote CI result.

Release 4.71 fixed Windows `CALL` argument preservation for Menuconfig and profile-editor shell launch; the Batch regression suite covers 16 Docker/Podman × Compose plugin/standalone combinations. Preserve this coverage.

## 9. Documentation and historical material

- `README.md` / `README.en.md` — current overview and CLI.
- `docs/index*.md` — lessons 01–08.
- `docs/ARCHITECTURE_*.md` and `docs/ARCHITECTURE_diagram_*.md` — text and Mermaid architecture.
- `docs/map*.md` — historical release map; keep historical events distinct from current state.
- `docs/audit.md` — dated evidence-based audit; never claim “all OK” without checking.
- `pub.md` — **temporary RU+EN GitHub Release draft**, produced by comparing the **previous published Git tag** against the **current intended release tree**, checking the resulting change list against `CHANGELOG.md`. Replace for each release as instructed; it is neither the changelog nor a permanent release-history record. Never auto-publish or overwrite without request.
- `CHANGELOG.md` — historical release log; search relevant sections rather than loading the entire file by default; never rewrite historical entries to match current state.

Keep RU/EN document pairs synchronized. Both packers must ship every page linked by README/docs indexes: lessons 01–08, architecture text, Mermaid diagrams, map, audit, and indexes. Keep `_packer.sh` and `_packer.bat` lists in parity; both tester roundtrip tests must compare these documents. Markdown uses CRLF per `.gitattributes`; `.mdc` files use LF. Recalculate existing `checksum:MD5` footers when editing files that contain them.

## 10. AI engineering workflow

`xZT24m` is an adaptive engineering-quality method, not a ritual or a mandatory minimum runtime.

- `x` means multiple, varied Zero-Trust checks at three gates: input/baseline, after implementation, and final output/artifact. Use genuinely different perspectives appropriate to the task; do not repeat the same checklist merely to satisfy a count.
- Scale audit depth to risk. A point fix can use a focused baseline check, direct regression test, and independent final review. Broad or high-impact changes need deeper independent checks at all three gates.
- The purpose of an audit is to find actionable defects. Verify findings, establish root causes, fix them when authorized, and add regression tests where practical. If several independent, varied checks reveal no new actionable issue, accept the result instead of manufacturing more rounds.
- 24 minutes is an ideal work budget, not a timer to fill. The roughly 18-minute work / 6-minute hardening split is a planning guide. Finish earlier when the goal is complete and adequately verified.
- If the scoped task is complete and time remains, consider only directly related, low-risk improvements with clear practical value. Avoid unrelated scope creep and changes made merely to use the remaining time.
- For a full quantum, create `overlay.zip` around the 18-minute checkpoint; for shorter tasks, export at completion. Include only changed files at repository-relative paths so extraction at the repository root reproduces the patch. Exclude unchanged files, private data, generated unpackers, and build artifacts.
- Inspect the relevant baseline and history before implementation. After implementation, run applicable tests, independently review the actual diff, and validate the final archive. Preserve safety behavior; never weaken tests to make them pass.
- Do not modify source unless the user explicitly authorizes implementation.

For Windows feedback bundles, run `capture_worktree_diff.bat` from the repository root. It creates `diff.zip` with a binary-capable patch, Git status, HEAD/branch metadata, statistics, whitespace diagnostics, and warnings. It does not change the real Git index. Git-ignored files and nested submodule contents are not included; review the bundle for secrets and private profile values before sharing. The helper is maintainer-only and must not be added to either runtime packer. For whole-source review, use `package_source_zip.bat` and optional Python 3.10+. It writes `routerFW_source.zip` plus a metadata-only `SOURCE_TREE_INDEX.txt` inside it: all relative paths, including those in excluded .git/build/private trees, but never the bytes of those excluded files. Enumeration is limited and fails on truncation; the sender must review path names for sensitive information before sharing. The prompt is `[Y/n]` (Enter=yes), and each exported overlay for user delivery should have a unique filename. Do not package either helper into self-extracting releases.

**Source Builder overlay lifecycle:** `system/src_builder.sh` uses SHA256 ownership manifests (`.routerfw_patch_owned_v1`, `.routerfw_files_owned_v1`) to prune only unchanged routerFW-created untracked files. The order is Git/feeds → managed patch and firmware overlays → hooks/rollback and ownership capture → `.config`/`make`; the firmware overlay runs before hooks and never uses destructive `rsync --delete`. Unknown or locally modified files must not be removed automatically; hooks changing outside `files/` remain outside automatic lifecycle management. Test via `bash tests/test_src_builder_lifecycle.sh`.

**Final xZT documentation gate:** whenever code or tool behavior changes, review relevant RU/EN README/docs, diagram accuracy, agent instruction files, and regression commands. Update anything affected within the same slice; tests passing without this review are not completion. The shared test declarations are checked by `tests/test_tester_parity.py` (with explicit Windows-only and Linux-only exceptions); both harnesses have 60 default declared checks, while real Docker/Podman smoke is additional. The optional Python exporter regression suite runs through both local testers; CI installs Python 3.11 and must fail rather than silently skip it. Do not rewrite `pub.md` automatically.


## .cursor/rules/batch-scripts.mdc (migrated verbatim)

---
description: Conventions for Windows Batch scripts in routerFW
globs: "**/*.bat"
alwaysApply: false
---

# Batch Script Conventions

## Style

- Header: `@echo off` then `rem file: <name>`
- `setlocal enabledelayedexpansion` for variable expansion in blocks, unless preserving arbitrary external path values (for example, `capture_worktree_diff.bat`, where delayed expansion must remain disabled to preserve `!` in filenames).
- Console: `chcp 65001 >nul` (UTF-8), `mode con: cols=120 lines=40`
- ANSI colors via ESC codes: `C_KEY`, `C_LBL`, `C_GRY`, `C_VAL`, `C_ERR`, `C_RST`, `C_OK` (alias of C_VAL)

## Bilingual Pattern

Same weighted language detection as `.sh` but uses Windows-specific checks:
- Registry: `HKCU\Control Panel\Desktop\PreferredUILanguages`
- Install language: `HKLM\...\Nls\Language\InstallLanguage` (0419 = Russian)
- PowerShell: `Get-Culture`, `Get-WinUserLanguageList`
- Console codepage: CP866 = Russian

Dictionary is loaded from unified `.env` files (`system/lang/ru.env` / `system/lang/en.env`).
Format: `KEY={C_VAL}value{C_RST}` — neutral pseudo-format, no quotes, `{C_*}` placeholders.
Loader: custom `for /f "usebackq eol=# tokens=1,* delims==" %%k` block — expands `{C_*}` to ANSI codes via `!_v:{C_VAL}=%C_VAL%!` (early+late expansion). Fallback to `en.env` if file missing.

## PowerShell Integration

When executing a complex PowerShell command from a `.bat` script (e.g., in `tester.bat`), follow these rules to avoid `cmd.exe` parsing issues:

1.  Enclose the entire PowerShell script block in double quotes (`"..."`).
2.  Use the **full names of PowerShell cmdlets** (e.g., `Where-Object`, `ForEach-Object`) instead of aliases (`?`, `%`).
3.  Do **not** escape PowerShell operators like `|` with the `^` character inside the quoted string.

## Feature Parity

`.bat` scripts must stay in sync with their `.sh` counterparts:
- `_Builder.bat` <-> `_Builder.sh`
- `_packer.bat` <-> `_packer.sh`

When modifying one, inspect the other and preserve equivalent user-visible behavior where the platform supports it; platform-specific implementation differences are allowed.

Windows regression requirement (4.71): inline shell commands passed through `CALL` must preserve arguments and quoting after CMD reparses the command. Keep the regression coverage in `tester.bat`; the current release tests 16 Docker/Podman × Compose plugin/standalone combinations. Re-run the relevant tester after any change to these call sites.

## Maintainer diff-capture helper

`capture_worktree_diff.bat` is a root-level maintainer tool and must stay out of both runtime packers. Keep delayed expansion disabled while handling Git paths so filenames containing `!` remain intact. It uses PowerShell `Compress-Archive`, whose destination path must end in `.zip` even for a temporary archive (use `diff.new.zip`, not `diff.zip.new`). Keep a Windows regression check in `tester.bat` for the configured extension and a small `Compress-Archive` ZIP smoke test. Preserve the previous `diff.zip` until the new ZIP has been created successfully.

## FORBIDDEN

- NEVER read or edit `_unpacker.bat` — contains base64 payload


## .cursor/rules/build-system.mdc (migrated verbatim)

---
description: Build system internals — Image Builder, Source Builder, Docker/Podman Compose
globs: "system/**"
alwaysApply: false
---

# Build System (`system/`)

## Image Builder flow

`system/docker-compose.yaml` (plus `system/podman-compose.yaml` for Podman) starts `ib_builder.sh`:
1. Normalize the selected profile (BOM/CRLF handling) and load IB variables.
2. Obtain the ImageBuilder SDK archive from a URL or local output path; cache it in `imagebuilder-cache`.
3. Extract the SDK and apply compatibility/OpenSSL setup.
4. Add local IPK/APK packages; validate APK metadata/availability when the SDK provides the APK tooling.
5. Apply package keys/repositories, partition-size settings, and a cleaned firmware overlay.
6. Run `make image` (two attempts total) and copy artifacts to `firmware_output/imagebuilder/<profile>/<timestamp>/`.

Security note: the current IB path disables APK signature checking in its make invocation to permit local unsigned APKs. This also affects network APK signature verification; do not describe this as a local-package-only exception.

## Source Builder flow

`system/docker-compose-src.yaml` (plus `system/podman-compose-src.yaml` for Podman) starts `src_builder.sh`:
1. The container starts as root, checks volume ownership, then runs the build body as user `build`.
2. Validate `SRC_REPO`/`SRC_BRANCH`, fetch `FETCH_HEAD`, verify the exact commit and detach HEAD at that commit. In a populated persistent workdir, changing `SRC_REPO` **fails closed** rather than mixing repositories: use the Cleanup Wizard to reset **only that profile's `src-workdir`**, then rebuild. No automatic `git clean`, volume prune or reset of other profiles.
3. Mirror standard OpenWrt feed URLs when applicable (a custom `feeds.conf` takes priority). Feeds update/install is cached using the repository URL, branch, fetched commit, effective feed-config SHA256, and a completed-update timestamp in `/ccache/.routerfw_feeds_state_v2`. Default maximum age is 24 hours; optional `SRC_FEEDS_MAX_AGE_HOURS=0` refreshes every run. Missing feeds or failed update/install force a new update next time. The historical `.last_build_commit` is not trusted for feed freshness. This is a freshness policy, **not a reproducible pin of external feed commits**.
4. Apply `custom_patches/<profile>` after Git reset using a SHA256 ownership manifest for routerFW-introduced untracked files (`.routerfw_patch_owned_v1`). Existing unknown paths are never overwritten; byte-identical legacy files may be adopted on first run.
5. Sync `/overlay_files/` into `files/` **without `--delete`**, omitting root `hooks.sh`. Clean only unchanged, previously owned untracked files recorded in `.routerfw_files_owned_v1`.
6. Run `/overlay_files/hooks.sh` if present, otherwise inspect the supported Vermagic rollback state. Capture new hook-generated `files/` outputs afterward; changes hooks make elsewhere are not tracked.
7. Generate `.config` from profile vars or `/output/manual_config`, run `make defconfig`, then copy source packages into `package/`.
8. Run `make download` and compile. On a reported SHA/MD5 mismatch, recheck the specific cached `dl/` archive, remove it only if invalid, then retry through OpenWrt’s own download mechanism (maximum three checksum-repair retries per phase). Never disable checksum verification or clear unrelated caches. A general download failure gets the existing verbose retry; a failed parallel compile gets one `make -j1 V=s` retry unless `SRC_CORES=debug` was requested initially.
9. Snapshot (never move or clean) `bin/targets/<target>/<subtarget>/` into a timestamped staging folder, **excluding only its top-level `packages/` directory** (APK/IPK files are not firmware deliverables). Preserve all other nested paths, including arbitrary firmware formats and empty directories. Keep relative paths; byte-compare copied files, verify safe relative symlinks and directory counts, and publish atomically with a recursive SHA256 manifest. Preserve upstream `sha256sums` as `.routerfw-upstream.sha256sums`. Error rather than silently dropping an unsupported entry. Reject metadata-only results. This guarantees lossless copying of files actually present after `make` outside the excluded `packages/`, not existence or freshness of every upstream-expected firmware image. `bin/packages/<arch>/` outside the leaf is also not exported. Do **not** remove either package directory from the OpenWrt build tree: OpenWrt needs packages internally.

Important ordering: overlay files must be copied **before** hooks so hook-generated firmware outputs are retained. Do not restore the former `rsync --delete`. Never delete unknown or diverged persistent files: abort with `[LIFECYCLE SAFETY]`. SHA256 manifests apply only to routerFW-owned *untracked files*, not arbitrary hook effects, pre-existing unknown files, compiled caches or imported source packages. On an ambiguous legacy workdir, explain the per-profile cleanup path rather than automatically pruning the volume.

Before downloads and compilation, and after `make` failures, Source Builder probes worktree, `dl`, CCache, `/tmp`, `/output`. Confirmed storage faults abort without retry or automatic cleanup.

**Architecture invariant:** shared Source Builder orchestration and export must not branch on MediaTek, BL2, FIP, U-Boot or individual devices. The exporter verifies and publishes files present in BIN_DIR; it cannot guarantee OpenWrt regenerated every expected image in a persistent worktree. Host post-build discovery must require exactly one new output directory, `CONFIG_IB=y`, and an ImageBuilder archive; absence of the optional archive is normal.

## Container images

| Dockerfile | Base image | Purpose |
|---|---|---|
| `system/dockerfile` | Ubuntu 24.04 | Modern Image Builder |
| `system/dockerfile.legacy` | Ubuntu 20.04 | Legacy Image Builder |
| `system/src.dockerfile` | Ubuntu 24.04 | Modern Source Builder (GCC 13 toolchain, CCache) |
| `system/src.dockerfile.legacy` | Ubuntu 18.04 | Legacy Source Builder |

Do not collapse the two legacy bases into one: Image Builder and Source Builder have different compatibility requirements.

## Compose and runtime

- Base Compose files: `docker-compose.yaml` (IB), `docker-compose-src.yaml` (SB).
- Podman overrides: `podman-compose.yaml` (IB), `podman-compose-src.yaml` (SB).
- Runtime selection is handled by host builders (`auto`, `docker`, `podman`), not by ImageBuilder URL selection alone.
- Compose resolution supports Docker Compose plugin/standalone and Podman Compose plugin/standalone, plus Windows `.exe` bridges where available.

## Persistent volumes

- IB: `imagebuilder-cache`, `ipk-cache`.
- SB: `src-workdir`, `src-dl-cache`, `src-ccache` (CCache max size 20 GB).
- SB worktrees and caches are persistent; state cleanup must be scoped to the selected profile/Compose project. A Source Builder Git safety guard protects existing state; Menuconfig has its own source-preparation path and must be separately audited before assuming identical checks there.
- Global Docker/Podman prune is intentionally disabled.

## Mass build

`build-all` is Image Builder only. Bash runs IB profiles in parallel, controlled by `ROUTERFW_JOBS` (default 6); Windows Batch runs IB profiles sequentially. Source Builder mass builds are rejected by both host builders.


## .cursor/rules/docker.mdc (migrated verbatim)

---
description: Docker and Podman Compose/runtime conventions
globs: "system/docker*.yaml,system/podman*.yaml,system/*dockerfile*"
alwaysApply: false
---

# Container Runtime and Compose Configuration

## Compose files

- `system/docker-compose.yaml` — Image Builder base Compose (modern + legacy services).
- `system/docker-compose-src.yaml` — Source Builder base Compose (modern + legacy services).
- `system/podman-compose.yaml` — Podman override for Image Builder.
- `system/podman-compose-src.yaml` — Podman override for Source Builder.

The host builders resolve Docker or Podman separately from build mode. Service selection is based on the selected profile's ImageBuilder URL (IB) or source branch (SB); runtime selection is controlled by `ROUTERFW_RUNTIME`, `--runtime`, or `-r`.

## Mount conventions

- Profiles are mounted read-only where supported.
- Profile-specific `custom_packages`, `custom_files`, and `custom_patches` / `src_packages` are mounted as input directories.
- Firmware output is mounted to `/output`.
- Image Builder uses named SDK/package caches. Source Builder uses persistent workdir, download, and CCache volumes.
- Runtime-aware mount suffixes handle Podman SELinux labels and read-only mounts; Source Builder Podman override uses `keep-id` for UID/GID mapping.

## Base images

| Dockerfile | Base | Builder |
|---|---|---|
| `dockerfile` | Ubuntu 24.04 | Modern Image Builder |
| `dockerfile.legacy` | Ubuntu 20.04 | Legacy Image Builder |
| `src.dockerfile` | Ubuntu 24.04 | Modern Source Builder |
| `src.dockerfile.legacy` | Ubuntu 18.04 | Legacy Source Builder |

Legacy Image Builder and legacy Source Builder intentionally use different Ubuntu releases.

## Safety

- Never introduce `docker system prune`, `docker volume prune`, `podman system prune`, or equivalent global cleanup. Project cleanup is profile-scoped.
- Do not assume a successful `compose` command means the firmware build succeeded; inspect the container exit code and expected output artifacts.
- Do not claim a filesystem `EROFS`/`EIO` condition can be repaired by restarting a container or retrying compilation.


## .cursor/rules/documentation.mdc (migrated verbatim)

---
description: Documentation conventions for Markdown files
globs: "**/*.md"
alwaysApply: false
---

# Documentation Conventions

## Bilingual structure

- `filename.md` is the primary Russian version.
- `filename.en.md` is the paired English version.
- User-facing documentation changes must be mirrored in both languages in the same slice. Keep technical meaning, caveats, examples, and links equivalent.

## Documentation set

- `README.md` / `README.en.md` — project overview, installation, CLI, features, safety notes.
- `docs/01`–`docs/08` — eight paired RU/EN lessons. Do not describe the lesson set as ending at 05.
- `docs/index.md` / `docs/index.en.md` — bilingual lesson indexes.
- `docs/ARCHITECTURE_ru.md` / `_en.md` — detailed architecture and process descriptions.
- `docs/ARCHITECTURE_diagram_ru.md` / `_en.md` — matching Mermaid process diagrams.
- `docs/map.md` / `map.en.md` — historical development map; distinguish historical release facts from current state.
- `docs/audit.md` — dated, evidence-based repository health snapshot; never carry forward stale “all OK” claims without rechecking.
- `pub.md` — **temporary GitHub Release draft** (RU + EN): generate from the difference between the previous **published Git tag** and the **current intended release tree**, cross-checking the historical `CHANGELOG.md`. Never use the previous commit as a substitute for the previous tag. It is staging text, not a historical changelog, and must not be auto-published.
- `GEMINI.md` and `.cursor/rules/*.mdc` — agent-facing project context and constraints; keep them aligned with current source and CI.

## Architecture documentation

When build/runtime behavior changes, check all four architecture files together:
- `docs/ARCHITECTURE_ru.md`
- `docs/ARCHITECTURE_en.md`
- `docs/ARCHITECTURE_diagram_ru.md`
- `docs/ARCHITECTURE_diagram_en.md`

Keep diagrams consistent with actual host behavior. In particular, `build-all` is Image Builder only (Bash parallel, Windows sequential); Source Builder `build-all` is rejected. Current bases are IB 24.04/20.04 and SB 24.04/18.04.

## Lesson page layout

Each lesson begins with a centered RU/EN language switcher, a horizontal rule, then its main heading. Lesson numbers and links must match the index in both languages.

## Version and current-state claims

- Read the current version from `system/version.env`; do not infer it from the newest filename or a historical changelog section.
- Keep historical version numbers when explaining when a feature was introduced, but label them as historical.
- Verify Docker/Podman, base-image, CLI, cleanup, CI, and test claims against current source/workflows before changing prose.
- Never advertise global prune: it is intentionally disabled.
- Distinguish CLI/packaging tests from real firmware builds. Current CI calls the local Bash/Batch testers and separate Docker/Podman smoke checks (actual image/volume checks). It does **not** build firmware images. Keep the descriptions aligned with `.github/workflows/tests.yml` and tester options (`--ci`, smoke test labels).

## Offline documentation packaging

Both `_packer.sh` and `_packer.bat` must include every Markdown page linked from `README` or `docs/index` (lessons 01–08, both architecture descriptions, both Mermaid diagrams, `map`, `audit`, and both indexes). Keep the two packer file lists in parity. Extend both `tester.sh` and `tester.bat` packer-roundtrip assertions whenever a documentation page is added or moved.

## Maintainer source-tree export and release output

- `package_source_zip.bat` / `package_source_zip.py` export a review snapshot; they are not firmware builders or runtime dependencies. Python 3.10+ is required only for this optional tool.
- `capture_worktree_diff.bat` uses `scripts/write_worktree_tree.ps1` to put `WORKTREE_TREE.md` into every **new** `diff.zip`: a Markdown file/folder tree relative to the repository root, including names of Git-ignored, generated and private paths except root `/.git`. File contents are never read for the tree; links/junctions are not traversed. Inaccessible paths or the 500,000-entry safety limit abort ZIP replacement instead of silently truncating. Warn that private *names* may be exposed. Do not edit user-facing README for this internal maintainer diagnostic.
- The archive includes `SOURCE_TREE_INDEX.txt`, with relative *names* for all files/directories, even inside the excluded heavy and private directories; excluded contents are never copied. Clearly warn about metadata privacy. The inventory fails on enumeration errors or exceeding `--tree-max-entries` rather than claiming to be complete when truncated; `--no-tree` opts out.
- Default payload omissions include `.git`, `firmware_output`, `builds`, `bck`, `nw_test`, `nl_test`, user-custom trees and generated artifacts. Explain `--include-custom`, `--unique`, the 4 MiB file-size limit, and `[Y/n]` (Enter=yes) when relevant.
- At the output audit of **every change slice**, check affected RU/EN README/docs, architecture/diagrams when applicable, agent rules and tests. Update the relevant items with the implementation rather than deferring docs. Do not edit the temporary release draft `pub.md` unless the user requests a release.
- Tester parity is semantic: `tests/test_tester_parity.py` checks common BAT/SH CLI and health labels with explicit platform-only exceptions. Both harnesses call the optional Python source-export regression suite when available. CI must install Python and fail if these checks cannot run; do not silently mark missing CI dependencies as PASS.

## Markdown and generated artifacts

- Preserve `.gitattributes`: Markdown files use CRLF; `.mdc` agent rules, `.sh` and `profiles/*.conf` use LF. Do not silently change profile EOLs or normalize entire files as part of a documentation update.
- Recalculate a file's trailing `checksum:MD5` footer when editing a file that has one. The checksum is over the normalized content before the footer, including its final line ending.
- Do not edit generated tester logs, test snapshots, or `CHANGELOG.md` merely to make old historical output look current.


## .cursor/rules/file-header.mdc (migrated verbatim)

---
description: File header convention — every builder-owned script must start with a file path comment
globs: "**/*.sh,**/*.bat,**/*.ps1,**/*.env,system/lang/*.env"
alwaysApply: false
---

# File Header Convention

Every file that belongs to the routerFW build system must have a **file path comment** near the top.

## Format by file type

| File type | Header format | Position |
|---|---|---|
| `.sh` | `# file: relative/path/to/file.sh` | line 2, after `#!/bin/bash` or `#!/bin/sh` |
| `.bat` | `rem file: relative\path\to\file.bat` | line 2, after `@echo off` |
| `.ps1` | `# file: relative/path/to/file.ps1` | line 1, or inside `<# ... #>` block |
| `.env` | `# file: relative/path/to/file.env` | line 1 |
| `.yaml` | `# file: relative/path/to/file.yaml` | line 1 |

## Rules

- Path is **relative to repository root** (forward slashes on all platforms)
- No version suffix required (unlike ib_builder.sh / src_builder.sh which carry `v1.x`)
- Do NOT add a file header to: generated output, user profile `.conf` files, `firmware_output/`

## Examples

```bash
#!/bin/bash
# file: system/create_profile.sh
```

```batch
@echo off
rem file: _Builder.bat
```

```
# file: system/lang/ru.env
```


## .cursor/rules/ignore-lx-debug.mdc (migrated verbatim)

---
description: Ignore nl_test/ and nw_test/ debug unpacked trees (do not read or edit)
alwaysApply: true
---

# Ignore nl_test/ and nw_test/ test folders

- **Назначение**: Папки `nl_test/` и `nw_test/` используются только как временные тестовые среды — туда распаковывается дистрибутив (`_unpacker`) для имитации действий конечного пользователя.
- **Требование**:
  - Не читать, не анализировать и не редактировать файлы внутри `nl_test/`, `nw_test/` и любых их вложенных подкаталогов.
  - Всегда считать исходным и «истинным» проектом корень репозитория вне этих папок.
  - Любые правки и поиск багов должны выполняться только в оригинальных файлах, а не в копиях из тестовых сред.


## .cursor/rules/profiles.mdc (migrated verbatim)

---
description: Profile configuration format for OpenWrt builds
globs: "profiles/**/*.conf"
alwaysApply: false
---

# Profile Configuration (.conf)

Profiles are sourced as shell scripts. They define variables for both Image Builder and Source Builder modes.

## Required Variables

```bash
PROFILE_NAME="human_readable_name"
TARGET_PROFILE="openwrt_device_profile_id"
```

## Image Builder Variables

```bash
IMAGEBUILDER_URL="https://..."          # URL to ImageBuilder SDK archive (.tar.zst)
IMAGE_EXTRA_NAME="tag"                  # Appended to output filenames (was: EXTRA_IMAGE_NAME)
CUSTOM_KEYS="https://.../key.pub"       # Custom repo signing keys
CUSTOM_REPOS="src/gz name https://..."  # Custom package repositories (multiline)
IMAGE_PKGS="package1 package2 -excluded" # Final package list for Image Builder (was: PKGS)
DISABLED_SERVICES="svc1 svc2"           # Services to disable
```

## Source Builder Variables

```bash
SRC_REPO="https://github.com/..."       # OpenWrt source repository
SRC_BRANCH="openwrt-24.10"             # Git branch
SRC_TARGET="mediatek"                   # OpenWrt target
SRC_SUBTARGET="filogic"                # OpenWrt subtarget
SRC_ARCH="aarch64_cortex-a53"          # Package architecture
SRC_CORES="safe"                        # Compilation threads: "safe" (max-1), number, or "debug" (verbose single-thread)
SRC_PACKAGES="$BASE_PKGS $EXTRA_PKGS"  # Package list for Source Builder
SRC_EXTRA_CONFIG='CONFIG_...'          # Multiline Kconfig (single-quoted heredoc style)
```

## Shared Variables

```bash
ROOTFS_SIZE="512"                       # Root filesystem size (MB)
KERNEL_SIZE="64"                        # Kernel partition size (MB)
```

## Package List Pattern

Profiles often compose package lists from named groups:

```bash
BASE_PKGS="pkg1 pkg2..."
NET_PKGS="luci-proto-wireguard..."
MODEM_PKGS="kmod-usb-serial-option..."
MUNIS_PKGS="-pkg_to_exclude..."         # Exclusions with dash prefix
IMAGE_PKGS="$COMMON_LIST $SRC_PACKAGES" # Final list passed to Image Builder
```


## .cursor/rules/project-overview.mdc (migrated verbatim)

---
description: Core knowledge base for routerFW (OpenWrtFW Builder) — universal cross-platform OpenWrt firmware builder
alwaysApply: true
---

# routerFW — OpenWrtFW Builder

Cross-platform, text-first framework for building custom OpenWrt/ImmortalWrt firmware. Current repository version: **4.71**, read from `system/version.env` (`ROUTERFW_VERSION`). License: GPL-3.0. Author: iqubik. Remote: https://github.com/iqubik/routerFW.git, branch: `main`.

## Source-of-truth order

1. Current root-level implementation and `system/version.env` define actual behavior and version.
2. `CHANGELOG.md` is the historical record: consult the relevant/latest entries when onboarding or when a change needs history; do not assume historical release notes describe current behavior.
3. `docs/ARCHITECTURE_*.md`, process diagrams, README, and agent notes explain behavior but may lag the code. Verify important claims against implementation.
4. `nl_test/` and `nw_test/` are disposable unpacked test snapshots, never source of truth.

Do not edit generated `_unpacker.*`; update source files and regenerate distribution through `_packer.*` only when explicitly requested.

**`pub.md` release draft (maintainer workspace):** a temporary Markdown staging file for a bilingual (RU+EN) GitHub Release description. When preparing a release, compare the **previous published Git tag** with the **current working tree / intended release state**, reconcile changes with `CHANGELOG.md`, and draft both languages in `pub.md`. Do not treat `pub.md` as release history or source of truth; do not overwrite it or publish a release unless requested. `CHANGELOG.md` is the enduring history, while `pub.md` is a replaceable draft.

## Build modes and runtime

- **Image Builder (IB):** `system/ib_builder.sh`, base Compose `system/docker-compose.yaml`, Podman override `system/podman-compose.yaml`. Uses a prebuilt SDK, package archives, overlays, repository/key configuration, and `make image`.
- **Source Builder (SB):** `system/src_builder.sh`, base Compose `system/docker-compose-src.yaml`, Podman override `system/podman-compose-src.yaml`. Uses a persistent OpenWrt worktree, feeds, mirror patches, hooks, Kconfig, imported/source packages, downloads, CCache, and `make`.
- Runtime is selected independently: Docker or Podman (`ROUTERFW_RUNTIME=auto|docker|podman`, `--runtime=...`, `-r ...`). Bash under WSL can bridge to `docker.exe` / `podman.exe` when applicable.
- Current base images: IB modern Ubuntu 24.04, IB legacy Ubuntu 20.04; SB modern Ubuntu 24.04, SB legacy Ubuntu 18.04. Verify `system/*.dockerfile` before changing these facts.
- Source Builder `build-all` is intentionally rejected. Image Builder `build-all` is supported: Bash runs profiles in parallel (default `ROUTERFW_JOBS=6`); Windows Batch processes them sequentially.

## Directory map

| Path | Purpose |
|---|---|
| `_Builder.sh` / `_Builder.bat` | Host entry points: menu, CLI, profile handling, runtime/Compose orchestration. |
| `system/` | Builder engines, Compose files, Dockerfiles, profile wizard, package importer, APK scanner, localization, version. |
| `system/lang/ru.env`, `system/lang/en.env` | Shared RU/EN UI dictionaries (neutral `{C_*}` pseudo-format). |
| `profiles/*.conf` | Shared profile configuration for IB and SB; profiles are sourced as shell input and must be trusted. |
| `custom_files/<profile>/` | Firmware rootfs overlay. **Private; do not inspect without explicit user permission.** |
| `custom_packages/<profile>/` | Binary IPK/APK packages. **Private.** |
| `src_packages/<profile>/` | Source packages and imported binary package wrappers. **Private.** |
| `custom_patches/<profile>/` | Source-tree mirror overlay. **Private.** |
| `firmware_output/` | Firmware artifacts, build logs, `manual_config`; large/generated. Do not inspect unless needed and authorized. |
| `scripts/` | Router-side utilities and Source Builder hook template. |
| `docs/` | RU/EN lessons 01–08, architecture descriptions/diagrams, development map, audit. |
| `_packer.sh` / `_packer.bat` | Build self-extracting distributions from source files. |
| `_unpacker.sh` / `_unpacker.bat` | Generated Base64 distribution payloads. **Toxic: never read/edit.** |
| `tester.sh` / `tester.bat` | CLI, runtime-wrapper, and project-health regression harnesses. |
| `capture_worktree_diff.bat` | Maintainer-only helper: creates `diff.zip` with tracked/untracked worktree changes and diagnostic metadata; not part of runtime distributions. |
| `package_source_zip.bat` / `.py` | Optional Python 3.10+ maintainer source-export tool. Creates `routerFW_source.zip` with `SOURCE_TREE_INDEX.txt` (all relative file/dir names, including excluded paths; their contents remain excluded). Never ship in runtime unpacker. |
| `tests/test_package_source_zip.py` / `tests/test_packer_staging_cleanup.sh` | Source-export regression suite and isolated Linux packer-staging failure test. |
| `.github/workflows/tests.yml` | Current Linux and Windows CI checks. |

## Profile model

- Required/common identity: `PROFILE_NAME`, `TARGET_PROFILE`.
- IB: `IMAGEBUILDER_URL`, `IMAGE_PKGS`, `IMAGE_EXTRA_NAME`, `CUSTOM_KEYS`, `CUSTOM_REPOS`, `DISABLED_SERVICES`.
- SB: `SRC_REPO`, `SRC_BRANCH`, `SRC_TARGET`, `SRC_SUBTARGET`, `SRC_ARCH`, `SRC_CORES`, `SRC_PACKAGES`, `SRC_EXTRA_CONFIG`.
- Shared: `ROOTFS_SIZE`, `KERNEL_SIZE`; legacy `PKGS` and `EXTRA_IMAGE_NAME` are migrated to `IMAGE_PKGS` and `IMAGE_EXTRA_NAME`.
- `SRC_CORES`: unset = all available cores; `safe` = N-1 (minimum 1); integer = explicit jobs; `debug` = `make -j1 V=s`.
- `manual_config` in the profile's Source Builder output directory takes precedence over generated Kconfig from profile variables.

Profiles are sourced shell code, not inert data. Hooks, external repositories/keys, source packages, and patches also execute or influence the build. Treat all third-party inputs as untrusted until reviewed.

## Source Builder state and ordering

- Persistent per-profile Compose project volumes hold `src-workdir`, `src-dl-cache`, and `src-ccache` (CCache max size 20 GB). Note: the `dl/` volume is mounted *inside* the workdir even when the source tree itself is empty; Git initialization must allow that mount.
- GitHub Actions uses explicit OS-major runner labels (`ubuntu-24.04` and `windows-2025`) rather than `*-latest`; keep CI and local tester coverage aligned. Source Builder verifies the exact fetched Git commit, rejects changing upstream repositories in already populated workdirs, and refreshes feeds according to commit/configuration identity and an age limit (default 24h; `SRC_FEEDS_MAX_AGE_HOURS`). The current Menuconfig runner is separate; do not assume it inherits these protections.
- The current flow verifies the exact source commit, refreshes feeds according to repository/commit/configuration and TTL, applies managed patches and the firmware overlay to `files/` without `--delete`, then runs hooks (or supported rollback), captures newly created hook outputs, prepares `.config`, runs `make defconfig`, copies source packages, downloads sources with bounded SHA recovery, builds and publishes the current BIN_DIR files. Hardware-specific outputs are decided by upstream OpenWrt, not routerFW.
- `custom_patches` is currently copied with `rsync -a` (no `--delete`); deleting an overlay file does not guarantee removal of a previously copied untracked file from the persistent worktree.
- Hooks run **after** the managed `custom_files` → `files/` overlay. There is no destructive `rsync --delete` after hooks. New hook-generated `files/` entries are recorded under the supported ownership rules; unrelated or modified files are not pruned automatically.
- Source Builder probes write/delete access and disk/inode availability for its worktree, downloads, CCache, `/tmp`, and output before download and compile. On a confirmed storage failure (`STORAGE_READONLY`, `STORAGE_NO_SPACE`, `STORAGE_IO_ERROR`, permission/path errors) it stops instead of retrying; it never automatically purges volumes. If the checks pass, an ordinary parallel `make` failure triggers the existing diagnostic `make -j1 V=s` fallback (except when already in debug mode). Diagnostic checks cannot prove the cause of an earlier failure once a transient fault has cleared; do not claim they can.

## Cleanup and safety invariants

- Global Docker/Podman prune is disabled in both interactive and non-interactive cleanup paths. Never reintroduce global prune.
- Cleanup is profile/project-scoped. Do not delete volumes, caches, or outputs outside the selected project/profile.
- Image Builder currently disables APK signature checking in its build invocation to permit local unsigned packages; this affects network APK signature verification too. Keep this security consequence visible in user documentation.
- Never claim that a green CLI/Compose test proves a firmware image is valid. Current CI does not perform full device firmware builds.

## CI and test coverage (current tree)

`tests.yml` invokes the same local test harnesses instead of duplicating their internals:
- Linux: `bash ./tester.sh` (syntax, ShellCheck, localization/version/BOM, safety, CLI, deterministic packer/unpacker, corrupt-payload tests, Source Builder storage regression). An installed ShellCheck is required.
- Windows: `tester.bat` (CLI, packaging/unpacking and corruption tests); the native Windows test suite must still be executed on Windows.
- Docker/Podman: separate CI jobs run `bash ./tester.sh "Docker Smoke"` and `bash ./tester.sh "Podman Smoke"`, respectively; these build containers and test volume write permissions, not real firmware.
- For full local parity: `bash ./tester.sh --ci` runs the Linux suite plus both runtime smoke tests (requires Docker, Podman, Compose and dependencies). Normal `tester.sh` skips container smoke explicitly.
Current CI does **not** compile complete firmware images. Check actual workflow/tester implementation before making coverage claims; a successful local test is not proof that an unrun CI job passed.

Release 4.71 fixed Windows `CALL` argument preservation for Menuconfig and profile-editor shell launch. Keep the regression coverage in `tester.bat`; changes to inline shell commands crossing `CALL` must preserve quoting/arguments across the Docker/Podman × Compose invocation variants.

## AI / xZT24m workflow

`xZT24m` is an adaptive engineering-quality method, not a ritual or a mandatory minimum runtime.

- `x` means multiple, varied Zero-Trust checks at three gates: input/baseline, after implementation, and final output/artifact. Choose genuinely different perspectives and checks appropriate to the task; do not repeat the same checklist merely to satisfy a count.
- Scale the depth to risk. A small point fix may need a focused baseline check, a direct regression test, and an independent final review. Broad or high-impact changes warrant deeper, independent audits at all three gates.
- Audits are valuable because they uncover actionable defects. Verify each finding, establish its cause, fix it when authorized, and add a regression test where practical. If several independent, varied checks reveal no new actionable issue, accept the result; do not manufacture more audit rounds.
- The 24-minute quantum is an ideal work budget, not a timer to fill. Roughly 18 minutes of implementation plus 6 minutes of hardening is a planning guide. Finish earlier when the objective is complete and adequately verified.
- If the scoped task is complete and time remains, consider only directly related, low-risk improvements with clear practical value. Do not add unrelated scope or churn merely to use the remaining time.
- For a full quantum, create `overlay.zip` around the 18-minute checkpoint; for a shorter task, export at completion. The archive contains only changed files at repository-relative paths so extraction at the repository root reproduces the changes. Never include unchanged files, private data, generated unpackers, or build artifacts.
- Before implementation, inspect the relevant baseline and history. After implementation, run applicable tests, review the actual diff independently, and validate the final archive. Preserve existing safety behavior and never weaken tests to make them pass.
- Do not modify source unless the user explicitly authorizes implementation.
- At final output, explicitly check whether any user-facing behavior, agent guidance, packaging inventory, test commands or safety assumptions now require synchronized RU/EN documentation. Do not deliver a code-only slice while leaving relevant docs stale.
- For full-source feedback use `package_source_zip.bat` (optional Python 3.10+), not a build artifact dump. The ZIP includes metadata-only `SOURCE_TREE_INDEX.txt` for omitted directories, including `.git` and `firmware_output`. Inform the sender that filenames in that inventory can be sensitive; the exporter limits enumeration rather than silently truncating.
- Keep shared BAT/SH regression labels aligned: `tests/test_tester_parity.py` records justified platform-only exceptions. Current default declared suites contain 60 tests each; Docker/Podman smoke are separate. CI installs Python 3.11 for the optional source-export tool's regression tests and must not silently skip them.
- Use a unique downloadable name for each returned overlay archive to avoid stale download links; keep repository-relative paths inside the archive.


## .cursor/rules/shell-scripts.mdc (migrated verbatim)

---
description: Conventions for Bash scripts in routerFW
globs: "**/*.sh"
alwaysApply: false
---

# Shell Script Conventions

## Style

- Shebang: `#!/bin/bash`
- Header comment: `# file: <relative_path>` (version suffix optional, mandatory only for system builders)
- Comments in Russian (primary) or English — match surrounding context
- ANSI color codes via variables: `C_VAL`, `C_ERR`, `C_KEY`, `C_LBL`, `C_GRY`, `C_RST`, `C_OK` (alias of C_VAL)
- Logging functions: `log()`, `warn()`, `error()` with colored `[INFO]`, `[WARN]`, `[FATAL]` prefixes
- Use `set -e` for fail-fast in builder scripts

## Bilingual Pattern

Main scripts (`_Builder.sh`) use a language detection system (weighted scoring):

```bash
SYS_LANG="EN"  # or "RU", set by detection logic
FORCE_LANG="AUTO"  # AUTO | RU | EN override
```

Dictionary is loaded from unified `.env` files (`system/lang/ru.env` / `system/lang/en.env`).
Format: `KEY={C_VAL}value{C_RST}` — neutral pseudo-format, no quotes, `{C_*}` placeholders.
Loader: `load_lang()` function — `while read` loop + `${val//\{C_VAL\}/$C_VAL}` substitutions, `printf -v` to set globals.
`${SYS_LANG,,}` lowercases the lang code for filename matching. Fallback to `en.env` if file missing.

## Key Variables

- `PROJECT_DIR` — root of the project (set via `cd "$(dirname "${BASH_SOURCE[0]}")" && pwd`)
- `PROFILE_ID` — profile name without `.conf` extension
- `CONF_FILE` — selected profile filename (e.g. `rax3000m_emmc_test_new.conf`)
- `VER_NUM` — version number string

## Container Runtime Integration

Builder scripts orchestrate Docker or Podman containers. The host builders resolve the selected runtime and Compose command. Container scripts receive configuration via:
- Environment variables from docker-compose (`CONF_FILE`, `HOST_OUTPUT_DIR`)
- Mounted volumes for profiles, packages, files, output, and cache

## Argument Filtering

For scripts that selectively run parts of their code based on command-line arguments (like `tester.sh`), use the following robust pattern:

1.  **Capture arguments globally:** At the top of the script, capture all arguments, including those with spaces, into an array. This makes the filters globally available.
    ```bash
    FILTERS=("$@")
    ```

2.  **Use a filter function:** Create a single, reusable function to check if a given label matches any of the stored filters. If the filter array is empty, it should always permit execution.
    ```bash
    should_run() {
      local label="$1"
      if [ ${#FILTERS[@]} -eq 0 ]; then return 0; fi # No filters = run all
      for filter in "${FILTERS[@]}"; do
        if [ "$filter" = "$label" ]; then return 0; fi # Match found
      done
      return 1 # No match
    }
    ```

3.  **Apply as a guard clause:** In any function that can be filtered, use this check at the very beginning. This is clean, safe, and avoids the common error of misinterpreting a function's arguments (`$@`) as the script's arguments.
    ```bash
    my_feature() {
      if ! should_run "My Feature Label"; then return 0; fi
      # ... rest of the function logic
    }
    ```


## .cursor/rules/toxic-files.mdc (migrated verbatim)

---
description: Generated payload files and large historical artifacts that require careful handling
alwaysApply: true
---

# Toxic and Generated Files — Handling Rules

## Never read or hand-edit generated unpackers

- `_unpacker.bat` and `_unpacker.sh` contain large Base64 payloads for the self-extracting distribution. Never read, grep, or edit them as source files.
- To change distributed content, edit the canonical source file and regenerate the unpacker with `_packer.bat` / `_packer.sh` only when explicitly requested.

## CHANGELOG.md is historical source, not a current specification

- The changelog can be large. Do not ingest the entire file by default.
- When onboarding, reconstructing a regression, or updating the development map, targeted searches for the relevant/latest release sections are allowed and expected when the task requires history.
- Never edit historical release entries to make them appear current. Add a new release entry only through the project's release workflow or explicit user instruction.

## Temporary release draft

- `pub.md` is a maintainer's replaceable RU/EN GitHub Release description draft, not a historical source or canonical release manifest. Prepare it only when requested by comparing the previous published Git tag with the intended current release tree, verifying against `CHANGELOG.md`. Do not publish or overwrite it automatically.

## Other generated/test artifacts

- Do not treat `tester_log_*.md`, `tester_tmp_*`, or unpacked snapshots under `nl_test/` and `nw_test/` as canonical documentation or source.
- Do not rewrite historical tester logs to match current versions.
