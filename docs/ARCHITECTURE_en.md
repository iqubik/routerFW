# file: docs\ARCHITECTURE_en.md
<p align="center">
  <a href="ARCHITECTURE_ru.md"><b>🇷🇺 Русский</b></a> | <b>🇺🇸 English</b>
</p>

---

# routerFW — Architecture & Process Flow

> Version: 4.71. Last updated: 2026-11.

---

## 1. Top-Level Entry Points

```
User
 ├── Windows → _Builder.bat   (PowerShell/Batch, interactive menu or CLI)
 └── Linux   → _Builder.sh    (Bash, interactive menu + parallel builds, or CLI)
```

Both entry points are **feature-parity** wrappers: same menus, same logic, different shell syntax. They also accept **CLI arguments** for non-interactive use — for scripts and CI.

**CLI commands (case-insensitive).** Optional first argument sets build mode: `ib` / `image` → Image Builder, `src` / `source` → Source Builder. Then command and arguments:

| Command (aliases) | Arguments | Description |
|-------------------|-----------|-------------|
| `build`, `b` | `<id>` | Build selected profile (id = number or name). |
| `build-all`, `a`, `all` | — | Image Builder only; Bash runs in parallel (`ROUTERFW_JOBS`, default 6), Windows runs sequentially. Rejected in Source Builder. |
| `edit`, `e` | `[id]` | Edit profile in $EDITOR; without id → interactive choice. |
| `menuconfig`, `k` | `<id>` | Run menuconfig (Source Builder only). |
| `import`, `i` | `<id>` | Import .ipk/.apk into profile tree (Source Builder only, APK support since v4.50). |
| `wizard`, `w` | — | Create new profile wizard. |
| `clean`, `c` | `[type] [id\|A]` | Clean: type 1–6 (Source) or 1–3 (Image); id or A = all. |
| `state`, `s` | — | Show profile flags (F/P/S/M/H/X/OI/OS — files, packages, builds). |
| `check` | `<id>` | Add/update checksum in profiles/ID.conf. |
| `check-all` | — | Add/update checksum:MD5 in all files from unpacker. |
| `check-clear` | `[<id>]` | Clear checksum:MD5 from all files or one profile. |
| `help`, `-h`, `--help` | — | Print CLI usage. |
| *(positional)* | `<id>` | Single number = build profile with that index. |

**Container runtime selection:** `--runtime=auto|docker|podman`, short form `-r auto|docker|podman`, or the `ROUTERFW_RUNTIME` environment variable. In `auto` mode, an interactive launch asks the user when both Docker and Podman are available; non-interactive commands choose an available runtime without opening a menu. In WSL, the Bash version can fall back to `docker.exe` / `podman.exe` when native Linux CLIs are missing.

**Local checks and CI:** GitHub Actions runs the same `tester.bat` / `tester.sh`, without separate copies of checks in YAML. The hosted OS labels are pinned to `ubuntu-24.04` / `windows-2025`; those image families still receive updates. Both suites cover the CLI, packer/unpacker roundtrips, packer determinism, and rejection of corrupt payloads. The Bash suite also runs syntax checks and ShellCheck (an installed `shellcheck` is required).

- Windows: `tester.bat` runs the full Windows suite. `ROUTERFW_TEST_SKIP_PACKER=1` explicitly skips packaging and means an incomplete run.
- Linux: `bash ./tester.sh` runs checks without starting containers; `bash ./tester.sh --ci` runs the entire suite, including Docker and Podman.
- Individual container checks: `bash ./tester.sh "Docker Smoke"` and `bash ./tester.sh "Podman Smoke"`. The corresponding CI jobs use these exact commands.

Smoke tests build the builder images and check IB/SRC volume writes, user permissions, and glibc compatibility. They require working runtimes, Compose, Python 3, and network access; a missing dependency fails the selected check. Each test uses its own Compose project and removes only its own containers, volumes, and output files. These checks do not build firmware or open Menuconfig. Use a separate fresh working copy to reproduce clean-checkout behavior. Logs: `tester_log_win.md` / `tester_log_lin.md`; CI uploads them even on failure.

---

## 2. Startup Sequence (both platforms)

```
START
  │
  ├─ [1] Ctrl+C trap (cleanup_exit → release_locks ALL → rm .docker_tmp/)
  │
  ├─ [2] Language Detector (weighted scoring: LANG env +4, locale +3, timezone +2; in WSL +5 for Get-WinSystemLocale)
  │        └─ loads system/lang/{ru|en}.env  →  sets L_* / H_* variables
  │
  ├─ [3] Runtime parse: ROUTERFW_RUNTIME / --runtime / -r → auto, docker, or podman
  │
  ├─ [4] resolve_runtime:
  │        Docker: docker compose / docker-compose / docker.exe compose
  │        Podman: podman compose / podman-compose / podman.exe compose
  │        auto: if both engines are available, ask the interactive user
  │
  ├─ [5] Docker Credentials Fix only for Docker runtime
  │        (.docker_tmp/config.json, strips credsStore/credHelpers)
  │
  ├─ [6] Selective unpack (_unpacker.sh / _unpacker.bat):
  │        bootstrap only / ROUTERFW_REPAIR=1 / missing key files
  │
  ├─ [7] Init dirs (profiles/, custom_files/, firmware_output/, custom_packages/,
  │                  src_packages/, custom_patches/;
  │                  firmware_output/imagebuilder/ and firmware_output/sourcebuilder/,
  │                  plus per-profile subdirs imagebuilder/<profile>, sourcebuilder/<profile> — both platforms since 4.45)
  │
  ├─ [8] Profile variable migration  PKGS→IMAGE_PKGS, EXTRA_IMAGE_NAME→IMAGE_EXTRA_NAME
  │        (idempotent, runs on every startup)
  │
  └─ [9] Architecture mapping  SRC_ARCH auto-fill from SRC_TARGET/SRC_SUBTARGET
          only for profiles where SRC_ARCH is missing
```

**Localization (step [2]):** UI strings are in dictionaries `system/lang/ru.env` and `system/lang/en.env` (unified pseudo-format: `KEY={C_VAL}text{C_RST}`, no quotes; `#` = comment). Two separate loaders substitute color placeholders (`{C_VAL}`, `{C_RST}`, `{C_ERR}`, etc.) and set `L_*` / `H_*` variables:
- **_Builder.sh** — `load_lang()`: line-by-line read, placeholder replacement via `${val//\{C_VAL\}/$C_VAL}` etc., `printf -v "$key"` to set variables.
- **_Builder.bat** — `for /f` loop over the file: `tokens=1,* delims==`, then delayed substitution `!_v:{C_VAL}=%C_VAL%!` etc. (requires `setlocal enabledelayedexpansion`). If the chosen language file is missing, `system/lang/en.env` is used.

---

## 3. Interactive Menu Commands

```
Main Menu
  ├─ [number]     Build selected profile
  ├─ [M]          Switch build mode: IMAGE ↔ SOURCE
  ├─ [E]          Editor: open profile folder and profile in $EDITOR
  ├─ [A]          Build all profiles in IMAGE mode only
  │               Bash: parallel (`ROUTERFW_JOBS`, default 6); Windows: sequential
  │               SOURCE build-all is rejected by both host builders
  ├─ [K]          Menuconfig (Source Builder only)
  ├─ [C]          Cleanup Wizard (cache, volumes, full reset)
  ├─ [W]          Create new profile wizard  →  system/create_profile.sh / .ps1  (exit: 0, same as main menu)
  ├─ [I]          Import .ipk/.apk packages  →  system/import_ipk.sh / .ps1 (APK support since v4.50)
  ├─ [S]          APK Scanner — validate & rename .apk  →  system/apk_scanner.sh / .ps1 (since v4.70)
  ├─ [F]          Check All — update checksum:MD5 in all unpacker files
  ├─ [P]          Run _packer.bat / _packer.sh (resource packaging)
  └─ [0]          Quit
```

### Profile Indicator System `[F P S M H X | OI OS]`

The main menu displays a "surgical" resource panel for instant profile assessment:

| Indicator | Description |
|-----------|-------------|
| **F** (Files) | File overlay present (`custom_files/%ID%/`). Contains configs and files to be placed in router's root. |
| **P** (Packages) | Third-party `.ipk` or `.apk` packages found in `custom_packages/%ID%/` for import. |
| **S** (Source) | Source code packages present (`src_packages/%ID%/`). |
| **M** (Manual Config) | Active `manual_config` file detected — saved result from Menuconfig session. |
| **H** (Hooks) | Automation script `hooks.sh` detected in `custom_files/%ID%/`. |
| **X** (Patches) | Source code patches detected (`custom_patches/%ID%/`). |
| **OI** | Image Builder firmware present (`firmware_output/imagebuilder/%ID%/`). |
| **OS** | Source Builder firmware present (`firmware_output/sourcebuilder/%ID%/`). |

---

## 4. APK Scanner — Package Validation (Image Builder)

```
system/apk_scanner.sh / system/apk_scanner.ps1  (v1.0, since v4.70)
  │
  ├─ Launch: AUTO (before running the selected compose runtime in IB mode,
  │                when .apk files exist in custom_packages/)
  │           or MANUAL ([S] button in main menu → profile selection)
  │
  ├─ Parameters:  $1 = PROFILE_ID,  $2 = TARGET_ARCH,  env: APK_SCANNER_LANG=RU|EN
  │        (PowerShell: -ProfileId, -TargetArch, -Lang)
  │
  ├─ [1] Search *.apk in custom_packages/<profile>/
  │        └─ No files → exit 0 (silent)
  │
  ├─ [2] For each APK:
  │        selected runtime run --rm alpine:latest apk adbdump -- /input/<file>.apk
  │        │
  │        ├─ Reads .PKGINFO from container (no unzip — the only reliable method)
  │        ├─ Parses: Package (name), Version, Arch
  │        └─ Parse error → exit 1 (invalid APK file)
  │
  ├─ [3] Architecture validation:
  │        ├─ pkg_arch == "all" || "noarch"  →  UNIVERSAL (skip, OK)
  │        ├─ pkg_arch == target_arch        →  MATCH (OK)
  │        └─ pkg_arch ≠ target_arch        →  WARNING (non-blocking)
  │
  ├─ [4] Filename vs metadata comparison:
  │        Expected format:  <name>-<version>-<release>.apk
  │        ├─ Matches  →  "Name matches" (OK)
  │        └─ Mismatch → Prompt: "Rename? [Y/n]"
  │              ├─ Y  →  mv / Rename-Item  →  "✓ Renamed"
  │              └─ n  →  "Skipped" (warning)
  │
  └─ [5] Summary:  "DONE: N scanned, M renamed, W warnings"
          ├─ Successful renames    →  exit 0 (NOT counted as warnings)
          ├─ Refused rename        →  exit 1 (warning)
          └─ Arch mismatch         →  exit 1 (warning)
```

**Integration into build_routine():**
```
build_routine(profile.conf)  [IB mode]
  │
  ├─ Extract SRC_ARCH from profile config
  │
  ├─ If custom_packages/<profile>/*.apk exist:
  │     ├─ Run apk_scanner.sh / .ps1
  │     │     APK_SCANNER_LANG="$SYS_LANG"  (sh)   or   -Lang "!SYS_LANG!"  (bat)
  │     ├─ exit 0 → continue build
  │     └─ exit 1 → prompt: "Continue build? [Y/n]"
  │           ├─ Y → continue
  │           └─ n → abort
  │
  └─ run_compose up  →  standard IB process through Docker or Podman
```

**Why `alpine:latest` is not removed:** It's a service image for scanning. `run --rm` cleans up containers but the image stays for repeated runs. Takes ~7 MB.

**Dependencies:** selected container runtime (Docker or Podman) for `apk adbdump`, access to `alpine:latest` (pulled on first run). Does not require `unzip`, `jq` or other utilities — everything runs inside the Alpine container.

---

## 5. Build Flow — IMAGE BUILDER mode

```
_Builder.sh/bat  →  build_routine(profile.conf)
  │
  ├─ Reads profile vars: IMAGEBUILDER_URL, IMAGE_PKGS, IMAGE_EXTRA_NAME,
  │                       ROOTFS_SIZE, KERNEL_SIZE, CUSTOM_REPOS, CUSTOM_KEYS,
  │                       DISABLED_SERVICES
  │
  ├─ Legacy check: URL contains /17. /18. /19.  → builder-oldwrt (Ubuntu 20.04)
  │                 else                          → builder-openwrt (Ubuntu 24.04)
  │
  ├─ Export env vars: SELECTED_CONF, HOST_FILES_DIR, HOST_PKGS_DIR, HOST_OUTPUT_DIR
  │
  ├─ run_compose -f system/docker-compose.yaml up --build
  │     (for Podman, system/podman-compose.yaml is added;
  │      mount suffix: :z / :ro,z; .exe bridge uses --env-file)
  │     │
  │     │  Volume mounts:
  │     │    imagebuilder-cache:/cache
  │     │    ipk-cache:/builder_workspace/dl
  │     │    custom_packages/<profile>:/input_packages     ← .ipk files [PRIVATE]
  │     │    custom_files/<profile>:/overlay_files         ← file overlay [PRIVATE]
  │     │    firmware_output:/output
  │     │    profiles:/profiles
  │     │
  │     └─ runs: /bin/bash /ib_builder.sh
  │
  │  Security: the current IB make invocation disables APK signature checking to
  │  allow local unsigned APKs; this also affects network APK signature verification.
  │               │
  │               ├─ [1] Normalize profile (strip BOM, strip \r)
  │               ├─ [2] Clean workspace without deleting dl/ and download/cache SDK (.tar.zst or .tar.xz)
  │               │        Network URL → wget → /cache/
  │               │        Local path  → firmware_output/... → /cache/
  │               ├─ [3] Extract SDK (tar -I zstd or tar -xJf, --strip-components=1)
  │               ├─ [4] OpenSSL fix (copy openssl.cnf for legacy SSL)
  │               ├─ [5] Copy custom .ipk → packages/ and clean local package indexes carefully
  │               ├─ [6] Set ROOTFS_SIZE / KERNEL_SIZE in .config
  │               ├─ [7] Download signing keys (CUSTOM_KEYS)
  │               ├─ [8] Add custom repos (CUSTOM_REPOS → repositories.conf)
  │               ├─ [9] Prepare overlay (/tmp/clean_overlay, strip hooks.sh/README.md)
  │               ├─[10] make image  (2 attempts, retry on failure)
  │               └─[11] Copy artifacts → firmware_output/imagebuilder/<profile>/<timestamp>/
  │
  └─ Runtime-aware output permission fix to host user UID
```

---

## 6. Build Flow — SOURCE BUILDER mode

```
_Builder.sh/bat  →  build_routine(profile.conf)
  │
  ├─ Reads profile vars: SRC_REPO, SRC_BRANCH, SRC_TARGET, SRC_SUBTARGET,
  │                       SRC_ARCH, SRC_CORES, SRC_PACKAGES, SRC_EXTRA_CONFIG,
  │                       ROOTFS_SIZE, KERNEL_SIZE
  │
  ├─ Legacy check: branch contains 19.07 / 18.06  → builder-src-oldwrt (Ubuntu 18.04)
  │                 else                            → builder-src-openwrt (Ubuntu 24.04)
  │
  ├─ run_compose -f system/docker-compose-src.yaml up --build
  │     (for Podman, system/podman-compose-src.yaml is added;
  │      SourceBuilder uses keep-id uid/gid for the build user)
  │     │
  │     │  Volume mounts (persistent named runtime volumes):
  │     │    src-workdir:/home/build/openwrt        ← OpenWrt source tree
  │     │    src-dl-cache:/home/build/openwrt/dl    ← downloaded tarballs cache (mounted even on first run)
  │     │    src-ccache:/ccache                      ← compiler cache (20 GB)
  │     │    profiles:/profiles
  │     │    src_packages/<profile>:/input_packages  ← source pkgs [PRIVATE]
  │     │    custom_patches/<profile>:/patches        ← patches [PRIVATE]
  │     │    custom_files/<profile>:/overlay_files   ← file overlay [PRIVATE]
  │     │    firmware_output/sourcebuilder/<profile>:/output
  │     │
  │     └─ runs: /bin/bash /src_builder.sh  (as root, then sudo -u build)
  │               │
  │               ├─ [1] Permission fix (chown -R build:build on first run)
  │               ├─ [2] Validate SRC_REPO/branch, fetch and verify HEAD == FETCH_HEAD commit
  │               │        upstream switch in populated workdir fails without deleting data
  │               ├─ [3] Mirror standard feeds (git.openwrt.org → github.com)
  │               ├─ [4] Feeds update/install: config SHA256 + repository/branch/commit
  │               │        + 24h TTL (SRC_FEEDS_MAX_AGE_HOURS); failed refresh is never cached
  │               ├─ [5] Apply patches (/patches → rsync -a overlay onto source tree; does not delete removed untracked files)
  │               ├─ [6] Branch on hooks.sh:
  │               │        if present, execute the hook; if absent, check Vermagic
  │               │        markers and roll back the supported modified state
  │               ├─ [7] Generate .config from profile vars
  │               │        (or use manual_config if present)
  │               ├─ [8] make defconfig
  │               ├─ [9] Copy src_packages → package/
  │               ├─[10] rsync overlay_files → files/ with --delete (custom_files overlay; can remove hook-generated files absent from the overlay)
  │               ├─[11] make download (with retry)
  │               ├─[12] make -j<SRC_CORES> → one make -j1 V=s retry after parallel failure
  │               │        (unless SRC_CORES=debug initially); fallback does not repair EROFS/EIO
  │               └─[13] Copy artifacts → firmware_output/sourcebuilder/<profile>/<timestamp>/
  │
  ├─ Runtime-aware output permission fix to host UID, same as Image Builder
  ├─ Post-build: detect *imagebuilder*.tar.zst → offer to update IMAGEBUILDER_URL in profile
  └─ Post-build: offer interactive shell (run_compose run --rm -it /bin/bash)
```

---

## 7. Menuconfig Flow (Source Builder only)

```
Menu [K]  →  run_menuconfig(profile.conf)
  │
  ├─ Generates firmware_output/sourcebuilder/<profile>/_menuconfig_runner.sh
  ├─ run_compose run --rm -it builder-src-openwrt /bin/bash
  │     │
  │     └─ _menuconfig_runner.sh:
  │           ├─ git init / checkout (if workdir empty)
  │           ├─ inject src_packages into package/custom-imports/
  │           ├─ prepare .config from profile vars
  │           ├─ make menuconfig  (interactive TUI)
  │           ├─ make defconfig → diffconfig.sh → /output/manual_config
  │           └─ optional: stay in container (/bin/bash)
  │
  └─ Post-menuconfig: offer to apply manual_config → SRC_EXTRA_CONFIG in profile
        (perl regex replaces existing SRC_EXTRA_CONFIG block, or appends)
```

---

## 8. scripts/hooks.sh — Pre-build Hook (Source Builder)

```
hooks.sh  (HOOKS_VERSION=1.7, runs inside container before make defconfig)
  │
  ├─ BLOCK 1: File modification demo (idempotent README patch)
  ├─ BLOCK 2: Feed management (custom feeds → feeds.conf)
  ├─ BLOCK 3: Source package injection (custom package directories)
  ├─ BLOCK 4: Vermagic Hack
  │     ├─ Extracts vermagic hash from openwrt.org
  │     ├─ Backs up include/kernel-defaults.mk
  │     ├─ Patches it to hardcode the hash
  │     └─ Writes .last_vermagic marker (used by rollback logic)
  └─ BLOCK 5: Smart cache clean (detects structural changes → rm -rf build_dir/target-*)
```

---

## 9. Profile System

```
profiles/*.conf  (shared between Image Builder and Source Builder)
  │
  ├─ Image Builder vars:  IMAGEBUILDER_URL, IMAGE_PKGS, IMAGE_EXTRA_NAME,
  │                        CUSTOM_REPOS, CUSTOM_KEYS, DISABLED_SERVICES
  ├─ Source Builder vars: SRC_REPO, SRC_BRANCH, SRC_TARGET, SRC_SUBTARGET,
  │                        SRC_ARCH, SRC_CORES, SRC_PACKAGES, SRC_EXTRA_CONFIG,
  │                        TARGET_PROFILE, PROFILE_NAME
  └─ Shared vars:         ROOTFS_SIZE, KERNEL_SIZE
```

---

## 10. Container Images and Compose

```
Image Builder:
  system/dockerfile         → Ubuntu 24.04  (builder-openwrt)
  system/dockerfile.legacy  → Ubuntu 20.04  (builder-oldwrt)

Source Builder:
  system/src.dockerfile         → Ubuntu 24.04  (builder-src-openwrt)
  system/src.dockerfile.legacy  → Ubuntu 18.04  (builder-src-oldwrt)

Compose:
  system/docker-compose.yaml      → base Image Builder compose
  system/docker-compose-src.yaml  → base Source Builder compose
  system/podman-compose.yaml      → Podman override for Image Builder
  system/podman-compose-src.yaml  → Podman override for Source Builder
```

---

## 11. Gitignored (Private) Directories

```
custom_files/     ← SSH keys, passwords, /etc/shadow, private configs — NEVER commit
custom_packages/  ← .ipk binaries, licensed/restricted packages — NEVER commit
src_packages/     ← source packages — NEVER commit
custom_patches/   ← proprietary patches — NEVER commit
firmware_output/  ← compiled firmware (10+ GB) — NEVER commit
nl_test/ nw_test/ ← test unpack dirs (distribution snapshots); not source of truth
```

---

## 12. Packer / Distribution / Generated Artifacts

```
_packer.sh / _packer.bat  (v2.7MT)
  └─ Packs project into self-extracting single-file distribution
        _unpacker.sh  (Linux)   ← DO NOT READ (huge base64 payload)
        _unpacker.bat (Windows) ← DO NOT READ (huge base64 payload)

```

Packer and unpacker are covered by CI on Linux and Windows: deterministic regeneration, key-file roundtrip, strict Base64/MD5 validation, and no false success when payload recovery fails. The Windows packer uses a PowerShell worker for safe parallel packaging without fragile CMD quoting.

---

## 13. Full Process Map (Mermaid)

See [ARCHITECTURE_diagram_en.md](ARCHITECTURE_diagram_en.md): **§1** Startup · **§2** Main menu (all choices) · **§3** Build routine + post-actions · **§4** Cleanup Wizard · **§5** Menuconfig flow + legend. RU diagrams: [ARCHITECTURE_diagram_ru.md](ARCHITECTURE_diagram_ru.md).
# checksum:MD5=aea4936ca0914944c52f07ec7e38af12