# GEMINI.md: Project Analysis for routerFW

## 1. Project Overview

This project, "OpenWrt Universal Builder," is a comprehensive, cross-platform framework for building custom OpenWrt firmware. It is designed to run on both **Windows** (via `_Builder.bat`) and **Linux/macOS** (via `_Builder.sh`), using Docker to provide an isolated and clean build environment.

The core of the project is a powerful script (`_Builder.bat`/`_Builder.sh`) that acts as a user interface and orchestrator for two distinct build modes:

1.  **Image Builder (Fast Mode):** This mode uses the official OpenWrt ImageBuilder SDK. It takes pre-compiled packages and bundles them with custom configurations and files into a final firmware image (`.bin`). This process is very fast and is ideal for adding/removing packages or embedding configuration files.

2.  **Source Builder (Powerful Mode):** This mode compiles the entire firmware from the OpenWrt source code. It is significantly slower but offers complete control, allowing for kernel modifications, partition size changes, and compiling packages not available in the standard repositories. It leverages a multi-level caching system to dramatically speed up subsequent builds.

The entire project is distributed as a single, self-extracting script (`_unpacker.bat` for Windows, `_unpacker.sh` for Linux), which makes setup trivial for end-users.

### Key Technologies & Concepts
- **Orchestration:** Batch Script (`_Builder.bat`) & Shell Script (`_Builder.sh`)
- **Environment Isolation:** Docker, Docker Compose
- **Dual-Environment Support:** Uses separate Docker images (based on Ubuntu 22.04 for modern builds and 18.04 for legacy builds) to ensure compatibility across all OpenWrt versions.
- **Advanced Caching:** Multi-layer volume-based caching for SDKs (`imagebuilder-cache`), packages (`ipk-cache`), OpenWrt source code (`src-workdir`), package sources (`src-dl-cache`), and compiled objects (`src-ccache`).
- **Configuration:** Universal `.conf` files in the `/profiles` directory.
- **Distribution:** A self-contained, single-file distribution system (`_packer` and `_unpacker` scripts).
- **User Experience:** Interactive CLI menu and a guided "Profile Wizard" (`create_profile.ps1`/`.sh`).

## 2. User Documentation (`docs/`)

The `docs` directory contains a series of lessons that serve as the official user guide, progressing from basic to advanced topics. Key concepts introduced in the documentation include:
- **Lesson 1: Introduction:** Explains the project's philosophy and the two primary build modes.
- **Lesson 2: Digital Twin:** A practical guide on creating a "cemented backup" of a live router by capturing its settings and installed packages into a new firmware image.
- **Lesson 3: Source Build Cold Start:** Details the advanced workflow for reliably configuring a source build using a developer's `defconfig` file.
- **Lesson 4: Advanced Features:** Covers expert-level topics like the `hooks.sh` system (including the Vermagic Hack), the Binary-to-Source IPK importer, and detailed cache management.

## 3. Directory Structure and Key Files

- `_Builder.bat` / `_Builder.sh`: The main entry points and user interface for the system.
- `_packer.bat` / `_packer.sh`: Scripts to package the entire project into a single distributable file.
- `_unpacker.bat` / `_unpacker.sh`: The single-file distribution scripts that contain all other project files.
- `system/docker-compose.yaml`: Defines Docker services for the **Image Builder** mode.
- `system/docker-compose-src.yaml`: Defines Docker services for the **Source Builder** mode.
- `system/dockerfile` & `dockerfile.legacy`: Dockerfiles for creating the Image Builder environments (Ubuntu 22.04 & 18.04).
- `system/src.dockerfile` & `src.dockerfile.legacy`: Dockerfiles for the more complex Source Builder environments.
- `system/create_profile.ps1` / `create_profile.sh`: Interactive wizards to help users create new profiles.
- `system/import_ipk.ps1` / `import_ipk.sh`: Wizards to correctly import third-party `.ipk` packages.
- `profiles/`: Contains all user-defined build profiles.
- `custom_files/`: Holds custom configuration files, organized by profile name.
- `firmware_output/`: The destination for all compiled firmware.
- `scripts/`: Contains various helper and utility scripts.

## 4. Workflow & Features

The primary workflow is managed through the interactive menu in `_Builder.bat` or `_Builder.sh`.

### Main Menu Features
- **`[A] Build All`**:
    - On Windows, builds all profiles sequentially.
    - On **Linux/macOS**, launches a **parallel build** of all profiles, with logs for each build saved to `firmware_output/.build_logs/`.
- **`[E] Profile Editor`**: A shortcut to open a profile's `.conf` file and its associated resource folders.
- **`[C] Maintenance`**: A cleanup wizard to selectively delete caches (SDK, IPK, ccache) or perform a full project reset.
- **`[W] Profile Wizard`**: Launches a script that guides the user through creating a new profile.
- **`[I] IPK Importer`** (Source Mode): Launches a wizard to help import third-party `.ipk` packages.
- **`[K] Interactive Menuconfig`** (Source Mode): Starts an interactive `make menuconfig` session. After exiting, the script allows you to automatically save the changes back into the profile's `SRC_EXTRA_CONFIG` variable.

## 5. The Main Menu UI

The main menu provides at-a-glance information about each profile using status indicators.

- **Resource Indicators (`[F P S M H]`)**:
    - `F` (Files): `custom_files` for this profile is not empty.
    - `P` (Packages): `custom_packages` (for ImageBuilder) is not empty.
    - `S` (Source): `src_packages` (for SourceBuilder) is not empty.
    - `M` (Manual): A saved `manual_config` from a previous Menuconfig session exists.
    - `H` (Hooks): A `hooks.sh` script exists in `custom_files/<profile>/`.
- **Build Output Indicators (`[ OI OS ]`)**:
    - `OI` (Output Image): A firmware has been successfully built in ImageBuilder mode.
    - `OS` (Output Source): A firmware has been successfully built in SourceBuilder mode.

## 6. Profile Configuration (`.conf` files)

- **`COMMON_LIST`**: A space-separated list of packages. To *add* a package, list its name. To *remove* a default package, prefix it with a hyphen (e.g., `-wpad-basic-mbedtls`).
- **`IMAGEBUILDER_*` Variables**: Control the Image Builder mode (`IMAGEBUILDER_URL`, `CUSTOM_REPOS`, etc.).
- **`SRC_*` Variables**: Control the Source Builder mode (`SRC_REPO`, `SRC_BRANCH`, `SRC_PACKAGES`, etc.).
- **`SRC_EXTRA_CONFIG`**: A powerful multi-line variable for injecting advanced options directly into the `.config` file during a source build.

## 7. Utility Scripts (`scripts/`)

The `scripts` directory contains a collection of helper scripts for diagnostics, customization, and maintenance.

- **`hooks.sh`**: A powerful template for applying custom modifications during a **Source build**. It runs inside the container before compilation. Users can copy it to `custom_files/<profile_name>/` to patch Makefiles, add third-party feeds, or apply the included "Vermagic Hack" to align the kernel with official builds for `kmod` compatibility.
- **`packager.sh` & `show_pkgs.sh`**: Utilities to be run on a live router. They generate a clean list of user-installed packages, filtering out dependencies and base-system packages. This is ideal for populating the `COMMON_LIST` in a build profile.
- **`diag.sh`**: A comprehensive diagnostic tool to be run on a live router. It gathers detailed information and generates a sanitized report in Markdown for easy troubleshooting.
- **`upgrade.sh`**: A simple utility for a live router that updates all installed `opkg` packages.

- **`etc/uci-defaults/99-permissions.sh`**: A first-boot script that the builder automatically includes in firmwares to ensure correct, secure permissions are set for SSH keys and other sensitive files.
## 8. Distribution System (`_packer` scripts)

The project includes an elegant system for bundling the entire framework into a single, portable, self-extracting script.

- **Purpose**: `_packer.bat` and `_packer.sh` are release scripts that create `_unpacker.bat` and `_unpacker.sh`, respectively. This allows the project to be distributed as one file.
- **Packing Process**:
    1.  A hardcoded list of project files (scripts, configs, docs) is defined.
    2.  Each file is encoded into **Base64** in parallel to speed up the process.
    3.  The script then assembles a new `_unpacker` script, which contains the decoding logic followed by the Base64 data for all files.
- **Unpacking Process**:
    1.  When executed, the `_unpacker` script reads its own source code.
    2.  It finds the Base64 blocks for each file, decodes them, and writes them to the correct subdirectories.
    3.  **Smart Unpacking**: It creates a `profiles/personal.flag` file on first run. On subsequent runs, if this flag exists, it will not overwrite existing user profiles, preserving user modifications.

## 9. Advanced Mechanics

The builder scripts contain several "smart" features to simplify the workflow.

### Docker Architecture
The build system is split into two main Docker Compose configurations, with a standard and legacy version for each to ensure maximum compatibility.

- **Standard vs. Legacy Environments**:
    - **Standard (`dockerfile`, `src.dockerfile`)**: Based on **Ubuntu 22.04** for modern OpenWrt builds.
    - **Legacy (`*.legacy`)**: Based on **Ubuntu 18.04** to support older OpenWrt versions (e.g., 19.07 and earlier) that require dependencies like Python 2.

- **Image Builder Caching (`docker-compose.yaml`):**
    - `imagebuilder-cache`: Persists the downloaded ImageBuilder SDKs.
    - `ipk-cache`: Caches downloaded `.ipk` packages in the `dl/` folder.

- **Source Builder Caching (`docker-compose-src.yaml`):**
    - `src-workdir`: Caches the **entire OpenWrt source code tree**, preventing re-cloning.
    - `src-dl-cache`: Caches the source code archives for all packages.
    - `src-ccache`: Caches **compiled objects** using `ccache`. This provides a massive speed boost on subsequent builds.

- **In-Container Logic**: The `command` section of the `docker-compose` files contains complex shell scripts that orchestrate the entire build. They include robustness features like network stability fixes, a retry loop for failed downloads, and intelligent management of build flags.

### Automation Features
- **Auto-Arch-Patcher**: On startup, the scripts scan all profiles. If a profile is missing the `SRC_ARCH` variable, it is automatically detected and injected.
- **Automatic Localization**: The user interface automatically detects the system language (Russian or English) and displays all menus and prompts accordingly.