# GEMINI.md — Project context for routerFW

Prompt/context file for AI (e.g. Gemini) working with this repository.  
**Builder version:** 4.49 · **Repo:** https://github.com/iqubik/routerFW (branch `main`) · **License:** GPL-3.0

---

## 1. Project overview

**OpenWrtFW Builder** is a cross-platform framework for building custom OpenWrt firmware via Docker. It runs on **Windows** (`_Builder.bat`) and **Linux** (`_Builder.sh`), providing both an interactive menu and a full command-line interface (CLI) for automation. It supports profile variable migration and aims for feature parity within platform limits.

**Two build modes:**

| Mode | Orchestrator | Time | Purpose |
|------|--------------|------|---------|
| **Image Builder** | `system/ib_builder.sh` | 1–3 min | Build from prebuilt SDK: packages, overlay, `.ipk` injection. Atomic downloads, smart cache. |
| **Source Builder** | `system/src_builder.sh` | 20–60 min (cold), 3–5 min (CCache) | Full compile from source, kernel patches, custom packages, Vermagic Hack. Persistence and self-heal. |

**Distribution:** The project is distributed as a single self-extracting file (`_unpacker.bat` / `_unpacker.sh`). **Do not read or search inside `_unpacker.*`** — they contain a large Base64 payload. All changes to the distribution are made via `_packer.bat` / `_packer.sh`.

---

## 2. Directory structure and key files

| Path | Purpose |
|------|----------|
| `_Builder.bat` / `_Builder.sh` | Main entry points: interactive menu, CLI, orchestration, profile migration. |
| `system/` | Core: `ib_builder.sh`, `src_builder.sh`, Dockerfiles, docker-compose, profile wizards, `import_ipk`, localization. |
| `system/lang/` | Localization: `ru.env`, `en.env`. See section on Localization below. |
| `profiles/*.conf` | Universal build configs (shared by Image and Source). |
| `custom_files/<profile>/` | File overlay → firmware root. **Private** (gitignored); may contain keys/configs. |
| `custom_packages/<profile>/` | Third-party `.ipk` for Image Builder and Source import. **Private.** |
| `src_packages/<profile>/` | Package sources for Source Builder. **Private.** |
| `custom_patches/<profile>/` | Mirror overlay for source code (v4.3+). Overwrites files under build tree. **Private.** |
| `firmware_output/` | Built images, logs, `manual_config`. **Gitignored** (can be 10+ GB). |
| `scripts/` | `hooks.sh`, `diag.sh`, `packager.sh`, `upgrade.sh`, `show_pkgs.sh`; `etc/uci-defaults/99-permissions.sh`. |
| `docs/` | User guides (RU/EN), lessons 1–5, architecture, diagrams (`ARCHITECTURE_*.md`, `ARCHITECTURE_diagram_*.md`). |
| `_packer.bat` / `_packer.sh` | Pack repo into self-extracting `_unpacker`. |
| `_unpacker.bat` / `_unpacker.sh` | **Toxic:** large Base64 payload. Do not open in AI or heavy editors. |
| `tester.bat` / `tester.sh` | CLI test harnesses for non-destructive checks of the command-line interface. |

**Docker:** Image Builder → `system/docker-compose.yaml`; Source Builder → `system/docker-compose-src.yaml`. Caches use volumes: SDK, packages, `src-workdir`, `src-dl-cache`, `src-ccache` (CCache, 20 GB limit).

**Do not use as source of truth:** `nl_test/`, `nw_test/` (test unpack dirs). Edits belong only in the repo root.

---

## 3. Profile configuration (`.conf`)

- **Naming:** Image Builder uses `IMAGE_*` (`IMAGE_PKGS`, `IMAGE_EXTRA_NAME`, `IMAGEBUILDER_URL`). Source Builder uses `SRC_*` (`SRC_REPO`, `SRC_BRANCH`, `SRC_TARGET`, `SRC_SUBTARGET`, `SRC_PACKAGES`, `SRC_EXTRA_CONFIG`, `SRC_CORES`). Shared: `ROOTFS_SIZE`, `KERNEL_SIZE`, `COMMON_LIST`.
- **`SRC_CORES` options**: Can be a specific number (e.g., `4`), `"safe"` (uses all available cores minus one), or `"debug"` (forces a single-threaded, verbose build with `make -j1 V=s`).
- **Migration:** On startup, `_Builder` automatically migrates legacy names (`PKGS` → `IMAGE_PKGS`, `EXTRA_IMAGE_NAME` → `IMAGE_EXTRA_NAME`). `ib_builder.sh` has fallback compatibility for safety.
- **Packages:** Package lists are space-separated. Prefix with `-` to remove a default package (e.g. `-dnsmasq dnsmasq-full`).
- **Local Image Builder:** After a successful Source build, the builder finds the generated `*imagebuilder*.tar.zst` and offers to update `IMAGEBUILDER_URL` in the profile to point to this local file, enabling fast local rebuilds.

---

## 4. Interface: Menu and CLI

The builder can be used via an interactive menu or a command-line interface for automation.

### 4.1. Interactive Menu & Indicators

- **Commands:** `[M]` Build Mode Toggle, `[E]` Edit Profile, `[C]` Clean Wizard, `[W]` Profile Wizard, `[I]` Import IPK (Source), `[K]` Menuconfig (Source). Selecting a profile by number starts a build.
- **Resource Panel `[F P S M H X | OI OS]`:**
  - **F**: `custom_files` exists.
  - **P**: `custom_packages` exists.
  - **S**: `src_packages` exists.
  - **X**: `custom_patches` exists.
  - **M**: `manual_config` exists (from `menuconfig`).
  - **H**: `hooks.sh` in `custom_files`.
  - **OI** / **OS**: Image Builder / Source Builder output exists.

### 4.2. Command-Line Interface (CLI)

Run `_Builder.bat` or `./_Builder.sh` with arguments to bypass the menu.

- **Build Mode:** Prefix commands with `ib` (or `image`) for Image Builder and `src` (or `source`) for Source Builder. **Image Builder is the default.**
- **Language:** Use `--lang=RU` / `--lang=EN` or `-l RU` / `-l EN` anywhere to force language.

| Command | Aliases | Arguments | Example |
|---|---|---|---|
| `build` | `b` | `<id>` or `<name>` | `./_Builder.sh src build 1` (Builds profile 1 in Source mode) |
| `build-all`| `a`, `all` | - | `_Builder.bat build-all` (Builds all profiles in default IB mode) |
| `edit` | `e` | `[id]` | `./_Builder.sh edit 1` (Opens profile 1 in $EDITOR) |
| `menuconfig`| `k` | `<id>` | `./_Builder.sh src menuconfig 1` (Runs menuconfig for profile 1) |
| `import` | `i` | `<id>` | `./_Builder.sh src import 1` (Imports IPKs for profile 1) |
| `wizard` | `w` | - | `./_Builder.sh wizard` (Starts the new profile wizard) |
| `clean` | `c` | `<type> <target>` | `_Builder.bat clean 2 A` (Cleans `src-workdir` for ALL profiles) |
| `state` | `s` | - | `./_Builder.sh state` (Prints the profile status table and exits) |
| `check` | - | `<id>` | `./_Builder.sh check 1` (Adds/updates checksum in profile 1) |
| `help` | `-h` | - | `./_Builder.sh --help` (Shows CLI help and exits) |

---

## 5. Linux (`_Builder.sh`) Specifics

The Linux script has advanced features not present in the Windows version:
- **Parallel Builds:** `[A]` (or `build-all`) runs all profile builds in parallel, logging to `firmware_output/.build_logs/`.
- **Ctrl+C Trap:** Gracefully stops all Docker containers and cleans up temporary files on exit.
- **Docker Credentials Fix:** On start, it copies `~/.docker/config.json` to a temporary location but removes `credsStore` to prevent conflicts with headless runs, while preserving proxy settings.
- **Case-Insensitive Menu:** Commands `M, E, A, K`, etc., are case-insensitive.

---

## 6. Conventions and Constraints

- **Line Endings:** `.gitattributes` strictly enforces EOL: **CRLF** for `*.bat`, `*.ps1`, `*.md`; **LF** for `*.sh`, `*.conf`, `*.yaml`, `system/lang/*.env`, etc.
- **Encoding:** UTF-8. A BOM is used only in specific PowerShell scripts (`create_profile.ps1`, `import_ipk.ps1`) for Cyrillic compatibility on Windows.
- **Localization:** UI strings are in `system/lang/ru.env` and `en.env`. They use a special pseudo-format `L_KEY={C_VAL}value{C_RST}` (no quotes, with color placeholders) which is parsed by custom loaders in both `.bat` and `.sh` scripts.
- **Private Dirs:** **NEVER** read or edit `custom_files/`, `custom_packages/`, `src_packages/`, `custom_patches/`. They are user-private and may contain sensitive data. Treat them as a black box.
- **Toxic Files:** **NEVER** read `_unpacker.bat` or `_unpacker.sh`. They contain huge Base64 payloads. `CHANGELOG.md` is also considered toxic due to its large volume and should not be read without explicit instruction.
- **Test Dirs:** **IGNORE** `nl_test/` and `nw_test/`. They are temporary unpacking directories for testing and not a source of truth.

---

## 7. Utility Scripts (`scripts/`)

- **`hooks.sh`:** Template for Source build actions (e.g., Vermagic Hack). Copied to `custom_files/<profile>/` to be active.
- **`packager.sh`**, **`show_pkgs.sh`:** Run on a live router to list user-installed packages.
- **`diag.sh`:** Runs on a router to create a diagnostic report.
- **`upgrade.sh`:** Runs on a router to perform a bulk `opkg` update.

---
## 8. Docker and Caching

- **Images:** Modern images are based on Ubuntu 22.04/24.04, with legacy Ubuntu 18.04 images for older OpenWrt versions.
- **Volumes:** Caching is heavily used to speed up builds.
  - Image Builder: `imagebuilder-cache` (SDKs), `ipk-cache` (packages).
  - Source Builder: `src-workdir` (source code), `src-dl-cache` (downloaded archives), `src-ccache` (compiler cache, 20 GB).
- **Build Context:** `.dockerignore` is critical to exclude `firmware_output/`, private directories, and `.git/` to keep the Docker build context small and fast.
