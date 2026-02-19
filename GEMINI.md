# GEMINI.md — Project context for routerFW

Prompt/context file for AI (e.g. Gemini) working with this repository.  
**Builder version:** 4.43 · **Repo:** https://github.com/iqubik/routerFW (branch `main`) · **License:** GPL-3.0

---

## 1. Project overview

**OpenWrtFW Builder** is a cross-platform framework for building custom OpenWrt firmware via Docker. It runs on **Windows** (`_Builder.bat`) and **Linux** (`_Builder.sh`), providing an interactive menu, profile variable migration, and feature parity within platform limits.

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
| `_Builder.bat` / `_Builder.sh` | Main entry points: menu, orchestration, profile migration. |
| `system/` | Core: `ib_builder.sh`, `src_builder.sh`, Dockerfiles, docker-compose, profile wizards, `import_ipk`, localization. |
| `system/lang/` | Localization: `ru.env`, `en.env` (pseudo-format `KEY={C_VAL}value{C_RST}`, no quotes). Loaders substitute `{C_*}` with ANSI codes. |
| `profiles/*.conf` | Universal build configs (shared by Image and Source). |
| `custom_files/<profile>/` | File overlay → firmware root. **Private** (gitignored); may contain keys/configs. |
| `custom_packages/<profile>/` | Third-party `.ipk` for Image Builder and Source import. **Private.** |
| `src_packages/<profile>/` | Package sources for Source Builder. **Private.** |
| `custom_patches/<profile>/` | Mirror overlay for source code (v4.3+). Overwrites files under build tree. **Private.** |
| `firmware_output/` | Built images, logs, `manual_config`. **Gitignored** (can be 10+ GB). |
| `scripts/` | `hooks.sh`, `diag.sh`, `packager.sh`, `upgrade.sh`, `show_pkgs.sh`; `etc/uci-defaults/99-permissions.sh`. |
| `docs/` | User guides (RU/EN), lessons 1–5, architecture, diagrams (`ARCHITECTURE_*.md`, `ARCHITECTURE_diagram_*.md`). |
| `dist/` | Release SVG visuals (timeline, tree, heatmap, river, bars, stats; light/dark). |
| `_packer.bat` / `_packer.sh` | Pack repo into self-extracting `_unpacker`. |
| `_unpacker.bat` / `_unpacker.sh` | **Toxic:** large Base64 payload. Do not open in AI or heavy editors. |

**Docker:** Image Builder → `system/docker-compose.yaml`; Source Builder → `system/docker-compose-src.yaml`. Caches use volumes: SDK, packages, `src-workdir`, `src-dl-cache`, `src-ccache` (CCache, 20 GB limit).

**Do not use as source of truth:** `nl_test/`, `nw_test/` (test unpack dirs). Edits belong only in the repo root.

---

## 3. Profile configuration (`.conf`)

- **Naming:** Image Builder uses `IMAGE_*` (`IMAGE_PKGS`, `IMAGE_EXTRA_NAME`, `IMAGEBUILDER_URL`, etc.). Source Builder uses `SRC_*` (`SRC_REPO`, `SRC_BRANCH`, `SRC_TARGET`, `SRC_SUBTARGET`, `SRC_PACKAGES`, `SRC_EXTRA_CONFIG`, `SRC_CORES`, etc.). Shared: `ROOTFS_SIZE`, `KERNEL_SIZE`, `COMMON_LIST`.
- **Migration:** On startup, `_Builder` migrates legacy names (`PKGS` → `IMAGE_PKGS`, `EXTRA_IMAGE_NAME` → `IMAGE_EXTRA_NAME`). `ib_builder.sh` has fallback `${IMAGE_PKGS:-$PKGS}`.
- **Packages:** `COMMON_LIST` — space-separated; prefix with `-` to remove (e.g. `-dnsmasq dnsmasq-full`).
- **Local Image Builder (v4.40+):** `IMAGEBUILDER_URL` can point to a local `.tar.zst` (e.g. in `firmware_output`). After a successful Source build, the builder may offer to set this in the profile.

---

## 4. Main menu and indicators

- **Build / Edit / Clean / Wizard:** `[M]` Build (Image or Source per profile), `[E]` Profile editor, `[C]` Clean (maintenance wizard), `[W]` Profile wizard, `[I]` Import IPK (Source), `[K]` Menuconfig (Source).
- **Resource panel `[F P S X M H | OI OS]`:**
  - **F** — `custom_files` not empty.
  - **P** — `custom_packages` not empty.
  - **S** — `src_packages` not empty.
  - **X** — `custom_patches` present.
  - **M** — `manual_config` exists in output.
  - **H** — `hooks.sh` in `custom_files/<profile>/`.
  - **OI** — Image Builder output present; **OS** — Source Builder output present.
- **Linux only:** `[A]` Build all — parallel build of all profiles, logs in `firmware_output/.build_logs_<timestamp>/`. Menu commands are case-insensitive. Ctrl+C triggers cleanup (stop containers, remove `.docker_tmp`). Exit asks for confirmation.

---

## 5. Maintenance (Clean wizard)

`[C] CLEAN` offers: **Soft Clean** (`make clean`), **Hard Reset** (remove `src-workdir`, keep `dl`), **Clean DL** (remove source archive), **Clean Ccache**, **Factory Reset** (full reset for the profile).

---

## 6. Documentation (`docs/`)

- **Lessons 1–3:** Introduction, digital twin / backup, source build cold start.
- **Lesson 4:** Advanced Source: hooks, Vermagic Hack, Binary-to-Source IPK import, feeds.
- **Lesson 5:** Source code patching system (mirror overlay in `custom_patches`).
- **Architecture:** `docs/ARCHITECTURE_ru.md`, `docs/ARCHITECTURE_en.md`, `docs/ARCHITECTURE_diagram_*.md`.
- **Index:** `docs/index.md` (RU), `docs/index.en.md` (EN).

---

## 7. Conventions and constraints

- **Line endings:** `.gitattributes` defines EOL: CRLF for `*.bat`, `*.ps1`, `*.md`; LF for `*.sh`, `*.conf`, `*.yaml`, `system/lang/*.env`, etc. Binary/LFS for archives and images.
- **Encoding:** UTF-8; BOM only in selected PowerShell scripts for Cyrillic on Windows (`create_profile.ps1`, `import_ipk.ps1`, etc.).
- **Localization:** All UI strings in `system/lang/ru.env` and `en.env`. Keys `L_*` (messages), `H_*` (table headers). Fallback to `en.env` if language file missing.
- **Private dirs:** Do not read or edit `custom_files/`, `custom_packages/`, `src_packages/`, `custom_patches/`, `firmware_output/` unless the user explicitly asks.

---

## 8. Reliability and automation

- **Image Builder:** Atomic downloads, shared locks for SDK download, smart cache.
- **Source Builder:** Self-heal when `hooks.sh` is removed — rollback patches, clear kernel cache and CCache. Containers are stopped/removed before build to avoid file locks (WSL/Windows).
- **Profile wizard:** Creates `.conf` with correct `IMAGE_*` / `SRC_*` names; validates and protects from overwrite.
- **Unpacker:** First run creates `profiles/personal.flag`; later runs do not overwrite existing user profiles.

---

## 9. Utility scripts (`scripts/`)

- **`hooks.sh`:** Template for Source build: Vermagic Hack, git-safe patching, Wi-Fi uci-defaults. Copy to `custom_files/<profile>/`. When removed, Source Builder runs full cleanup.
- **`packager.sh`**, **`show_pkgs.sh`:** On a live router — list user-installed packages for `COMMON_LIST`.
- **`diag.sh`:** On router — diagnostic report (Markdown) for troubleshooting.
- **`upgrade.sh`:** On router — bulk `opkg` update.
- **`scripts/etc/uci-defaults/99-permissions.sh`:** First-boot permissions (e.g. SSH keys); included in firmware by the builder.

---

## 10. Packer / unpacker (distribution)

- **Packer** (`_packer.bat` / `_packer.sh`): Builds `_unpacker` from a file list; each file is Base64-encoded and appended to the unpacker script.
- **Unpacker** (`_unpacker.bat` / `_packer.sh`): Decodes and writes files; if `profiles/personal.flag` exists, does not overwrite existing profiles.
- **Rule:** Never read or grep `_unpacker.bat` / `_unpacker.sh`. Modify distribution only via the packer scripts.

---

## 11. Docker and caching

- **Image Builder:** `system/dockerfile` (modern), `system/dockerfile.legacy` (Ubuntu 18.04). Compose: `imagebuilder-cache`, `ipk-cache`.
- **Source Builder:** `system/src.dockerfile`, `system/src.dockerfile.legacy`. Compose: `src-workdir`, `src-dl-cache`, `src-ccache` (20 GB). Modern image Ubuntu 22.04/24.04; legacy for older OpenWrt (e.g. Python 2).
- **Context:** `.dockerignore` excludes `firmware_output/`, `custom_files/`, `.git/`, etc. to keep build context small.
- **Linux:** `_Builder.sh` may copy `~/.docker/config.json` to `.docker_tmp/` (without credsStore) for headless use; `--build` on run for up-to-date image.

Use this document as the primary context when analyzing or modifying the routerFW repository.
