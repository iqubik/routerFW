# file docs\ARCHITECTURE_en.md

# routerFW — Architecture & Process Flow

> Version: 4.43. Last updated: 2026-02-18.

---

## 1. Top-Level Entry Points

```
User
 ├── Windows → _Builder.bat   (PowerShell/Batch, interactive menu)
 └── Linux   → _Builder.sh    (Bash, interactive menu + parallel builds)
```

Both entry points are **feature-parity** wrappers: same menus, same logic, different shell syntax.

---

## 2. Startup Sequence (both platforms)

```
START
  │
  ├─ [1] Ctrl+C trap (cleanup_exit → release_locks ALL → rm .docker_tmp/)
  │
  ├─ [2] Language Detector (weighted scoring: LANG env +4, locale +3, timezone +2)
  │        └─ loads system/lang/{ru|en}.env  →  sets L_* / H_* variables
  │
  ├─ [3] Docker check (docker --version, docker-compose / docker compose)
  │
  ├─ [4] Docker Credentials Fix (.docker_tmp/config.json, strips credsStore/credHelpers)
  │
  ├─ [5] Auto-unpack (_unpacker.sh / _unpacker.bat, if present)
  │
  ├─ [6] Init dirs (profiles/, custom_files/, firmware_output/, custom_packages/,
  │                  src_packages/, custom_patches/)
  │
  ├─ [7] Profile variable migration  PKGS→IMAGE_PKGS, EXTRA_IMAGE_NAME→IMAGE_EXTRA_NAME
  │        (idempotent, runs on every startup)
  │
  └─ [8] Architecture mapping  SRC_ARCH auto-fill from SRC_TARGET/SRC_SUBTARGET
```

---

## 3. Interactive Menu Commands

```
Main Menu
  ├─ [B / number] Build selected profile
  ├─ [M]          Switch build mode: IMAGE ↔ SOURCE
  ├─ [E]          Edit profile in $EDITOR
  ├─ [A]          Parallel build ALL profiles (Linux only, background jobs + spinner)
  ├─ [K]          Cleanup menu (cache, volumes, full reset)
  ├─ [C]          Create new profile wizard  →  system/create_profile.sh / .ps1
  ├─ [I]          Import .ipk packages       →  system/import_ipk.sh / .ps1
  ├─ [W]          Menuconfig (Source Builder only)
  └─ [Q / 0]      Quit
```

---

## 4. Build Flow — IMAGE BUILDER mode

```
_Builder.sh/bat  →  build_routine(profile.conf)
  │
  ├─ Reads profile vars: IMAGEBUILDER_URL, IMAGE_PKGS, IMAGE_EXTRA_NAME,
  │                       ROOTFS_SIZE, KERNEL_SIZE, CUSTOM_REPOS, CUSTOM_KEYS,
  │                       DISABLED_SERVICES
  │
  ├─ Legacy check: URL contains /17. /18. /19.  → builder-oldwrt (Ubuntu 18.04)
  │                 else                          → builder-openwrt (Ubuntu 22.04)
  │
  ├─ Export env vars: SELECTED_CONF, HOST_FILES_DIR, HOST_PKGS_DIR, HOST_OUTPUT_DIR
  │
  ├─ docker compose -f system/docker-compose.yaml up --build
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
  │               │
  │               ├─ [1] Normalize profile (strip BOM, strip \r)
  │               ├─ [2] Download / cache SDK (.tar.zst or .tar.xz)
  │               │        Network URL → wget → /cache/
  │               │        Local path  → firmware_output/... → /cache/
  │               ├─ [3] Extract SDK (tar -I zstd or tar -xJf, --strip-components=1)
  │               ├─ [4] OpenSSL fix (copy openssl.cnf for legacy SSL)
  │               ├─ [5] Copy custom .ipk → packages/
  │               ├─ [6] Set ROOTFS_SIZE / KERNEL_SIZE in .config
  │               ├─ [7] Download signing keys (CUSTOM_KEYS)
  │               ├─ [8] Add custom repos (CUSTOM_REPOS → repositories.conf)
  │               ├─ [9] Prepare overlay (/tmp/clean_overlay, strip hooks.sh/README.md)
  │               ├─[10] make image  (2 attempts, retry on failure)
  │               └─[11] Copy artifacts → firmware_output/imagebuilder/<profile>/<timestamp>/
  │
  └─ Fix permissions (alpine chown to host user UID)
```

---

## 5. Build Flow — SOURCE BUILDER mode

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
  ├─ docker compose -f system/docker-compose-src.yaml up --build
  │     │
  │     │  Volume mounts (persistent Docker volumes):
  │     │    src-workdir:/home/build/openwrt        ← OpenWrt source tree
  │     │    src-dl-cache:/home/build/openwrt/dl    ← downloaded tarballs cache
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
  │               ├─ [2] git init / fetch / checkout FETCH_HEAD (reset --hard)
  │               ├─ [3] Mirror feeds (git.openwrt.org → github.com)
  │               ├─ [4] Feeds update/install (skipped if commit unchanged — cached)
  │               ├─ [5] Apply patches (/patches → rsync overlay onto source tree)
  │               ├─ [6] VERMAGIC Rollback check (if hooks.sh missing)
  │               │        Detects patched kernel-defaults.mk → restores backup
  │               ├─ [7] Execute scripts/hooks.sh (custom pre-build hook)
  │               │        hooks.sh can: modify DTS/Makefiles, add feeds,
  │               │        apply vermagic hack, smart cache clean
  │               ├─ [8] Generate .config from profile vars
  │               │        (or use manual_config if present)
  │               ├─ [9] make defconfig
  │               ├─[10] Copy src_packages → package/
  │               ├─[11] rsync overlay_files → files/  (custom_files overlay)
  │               ├─[12] make download (with retry)
  │               ├─[13] make -j<SRC_CORES>  →  fallback make -j1 V=s on error
  │               └─[14] Copy artifacts → firmware_output/sourcebuilder/<profile>/<timestamp>/
  │
  ├─ Post-build: detect *imagebuilder*.tar.zst → offer to update IMAGEBUILDER_URL in profile
  └─ Post-build: offer interactive shell (docker compose run --rm -it /bin/bash)
```

---

## 6. Menuconfig Flow (Source Builder only)

```
Menu [W]  →  run_menuconfig(profile.conf)
  │
  ├─ Generates firmware_output/sourcebuilder/<profile>/_menuconfig_runner.sh
  ├─ docker compose run --rm -it builder-src-openwrt /bin/bash
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

## 7. scripts/hooks.sh — Pre-build Hook (Source Builder)

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

## 8. Profile System

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

## 9. Docker Images

```
Image Builder:
  system/dockerfile         → Ubuntu 22.04  (builder-openwrt)
  system/dockerfile.legacy  → Ubuntu 18.04  (builder-oldwrt)

Source Builder:
  system/src.dockerfile         → Ubuntu 24.04  (builder-src-openwrt)
  system/src.dockerfile.legacy  → Ubuntu 18.04  (builder-src-oldwrt)
```

---

## 10. Gitignored (Private) Directories

```
custom_files/     ← SSH keys, passwords, /etc/shadow, private configs — NEVER commit
custom_packages/  ← .ipk binaries, licensed/restricted packages — NEVER commit
src_packages/     ← source packages — NEVER commit
custom_patches/   ← proprietary patches — NEVER commit
firmware_output/  ← compiled firmware (10+ GB) — NEVER commit
```

---

## 11. Packer / Distribution

```
_packer.sh / _packer.bat
  └─ Packs project into self-extracting single-file distribution
        _unpacker.sh  (Linux)   ← DO NOT READ (huge base64 payload)
        _unpacker.bat (Windows) ← DO NOT READ (huge base64 payload)
```

---

## 12. Full Process Map (Mermaid)

See [ARCHITECTURE_diagram.md](ARCHITECTURE_diagram.md): **§1** Startup · **§2** Main menu (all choices) · **§3** Build routine + post-actions · **§4** Cleanup Wizard · **§5** Menuconfig flow. EN + RU + legend table.
