# Language / Язык
[🇷🇺 Русский язык](README.md) | [🇺🇸 English]

# 🚀 OpenWrtFW Builder (Image + Source) + IPK Injection

Many have likely wanted to have a personal OpenWrt router binary with a full configuration and custom packages. Not just a backup, but a direct version rollback to a clean `.bin` file!

This project has now evolved into a **Universal All-in-One Tool**, combining two approaches: fast assembly (**ImageBuilder**) and full compilation (**SourceBuilder**).

In version 3.0+, a **global refactoring** took place: the old `_Image_Builder.bat` and `_Source_Builder.bat` scripts were removed and replaced by a single `_Builder` that manages both modes.

---

## 📥 Installation and Download

The entire project is contained in **one self-extracting file**, `_unpacker`. You don't need to download ZIP archives or clone the repository.

*   **Preparation:** [Download and install Docker Desktop](https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe).

## 🌍 International Unpacker
The project is deployed via a **unified international unpacker** `_unpacker`. All system messages during deployment have been translated into English to ensure clarity for global users.

### Choose your download method:
*   🔥 **[Download _unpacker.bat (Latest version)](https://github.com/iqubik/routerFW/raw/main/_unpacker.bat)** — The most up-to-date Windows code.
*   🔥 **[Download _unpacker.sh (Latest version)](https://github.com/iqubik/routerFW/raw/main/_unpacker.sh)** — The most up-to-date Linux code.
*   📦 **[Releases Section](https://github.com/iqubik/routerFW/releases)** — Verified versions with changelogs.

> **How to run:**
> 1. Place `_unpacker` in an **empty folder** (e.g., `C:\OpenWrtBuilder`) with no Cyrillic characters in the path.
> 2. Run it — it will deploy the project structure.
> 3. Run the resulting `_Builder`.

## 🖥 Interface

> **Appearance: Main Window**
<img width="1435" height="1060" alt="image" src="https://github.com/user-attachments/assets/697f34e3-c634-4203-b699-124b87152ead" />

### 📊 Profile Indicator System
The main menu features a "surgical" resource panel **`[F P S M H | OI OS]`** for instant profile assessment:
*   **F (Files)** — File overlay detected (`custom_files`).
*   **P (Packages)** — External `.ipk` packages present.
*   **S (Source)** — Package source code found (`src_packages`).
*   **Pt (Patches)** — **[NEW]** Source code patches detected (`custom_patches`).
*   **M (Manual Config)** — **[NEW]** Active Menuconfig diff file detected.
*   **H (Hooks)** — **[NEW]** Automation script `hooks.sh` detected.

---

## 📖 Documentation and Training

An extended knowledge base has been created for the project to help you go from beginner to pro.

👉 **[OPEN FULL GUIDE (DOCS EN)](docs/index.en.md)**

**Inside you will find:**
*   **Lessons 1-3:** Basics, configuration setup, and quick start.
*   **Lesson 4 (Advanced):** Advanced Source mode: implementing third-party programs from source, applying patches, and deep customization.
*   **Troubleshooting:** Solutions for common compilation and Docker issues.

---

## ⚡ About the Project

Building takes place in isolated **Docker containers**. The system does not clutter System and can be removed with a single click.

### Two operating modes:

#### 1. 🐇 Image Builder (Fast)
*   **Speed:** 1-2 minutes.
*   **Purpose:** Add packages (`luci`, `vpn`), embed Wi-Fi/PPPoE configs.
*   **Features:** **Atomic Downloads** (protection against network failures), smart cache (re-build takes ~30 sec), integration of third-party `.ipk` files (from the `custom_packages` folder).

#### 2. 🐢 Source Builder (Powerful)
*   **Speed:** First run ~20-60 min, subsequent runs ~3-5 min (thanks to **CCache**).
*   **Purpose:** 16MB mods, kernel patches, compiling programs from source.
*   **Features:**
    *   **Vermagic Hack:** Official drivers (`kmod-`) install without errors.
    *   **Persistence:** Isolated folders and caches for each profile.
    *   **Binary-to-Source Import:** Allows embedding ready-made `.ipk` packages (even without source code) directly into firmware compiled from source.
    *   Support for any Git branches and forks (ImmortalWrt, Padavan).

---

## 🧹 Maintenance Mode (Cleaning System)

The **[C] CLEAN** button invokes the granular cleaning wizard:

| Option | Description | When to use? |
| :--- | :--- | :--- |
| **Soft Clean** | Runs `make clean`. | If there are package linking errors. |
| **Hard Reset** | Deletes `src-workdir`, keeping `dl`. | If the Toolchain or Git tree is broken. |
| **Clean DL** | Deletes the source code archive. | To free up disk space. |
| **Clean Ccache** | Resets the compiler cache. | When changing architecture or GCC version. |
| **Factory Reset** | Deletes **EVERYTHING** for the profile. | Complete reset to "factory" state. |

---

### 🧙 Profile Wizard

Forgot your router's architecture or afraid of syntax errors? Use the **[W] Profile Wizard** menu item.

*   **Step-by-step selection**: Release, platform, and router model are selected from lists.
*   **Smart settings**: Just press **Enter** to select standard values (LuCI, system names).
*   **Validation**: The wizard automatically fixes spaces in names and protects files from accidental overwriting.
*   **Ready-made result**: Output is a clean `.conf` file with useful comments and optimization examples.

<img width="1483" height="348" alt="image" src="https://github.com/user-attachments/assets/5cf2537a-7886-4bed-bce8-43b0b2787926" />

---

## 📂 Folder Structure

*   `docs/` — Offline copy of the knowledge base.
*   `profiles/` — Your universal `.conf` files.
*   `custom_files/profile_name/` — File overlay (everything here goes to the router's root).
*   `custom_packages/profile_name/` — Folder for `.ipk` packages. Used in **ImageBuilder** (direct inclusion) and as a source for import in **SourceBuilder**.
*   `src_packages/profile_name/` — For source code. Used for third-party packages from GitHub and as the **output folder** for `.ipk` files processed by the importer.
*   `firmware_output/` — Ready firmwares and build logs.
*   `system/` — Folder with Dockerfiles, scripts, and the builder core.

---

## ⚙️ Source Code Patching System (v4.3+)

This feature allows you to directly modify the OpenWrt source code before compilation. It works on a **"mirror overlay"** principle: any file you place in the `custom_patches/<PROFILE_ID>/` directory will overwrite the original file in the source tree, preserving the path structure. This is perfect for replacing `Makefiles` or adding new device files, as well as for delivering `.patch` files into the build environment for `hooks.sh` to apply.

The system **automatically converts Windows line endings (CRLF)** to Unix (LF), so you can edit files in any text editor without worrying about breaking the build.

👉 Learn more in the [Advanced Guide to Source Patching](docs/05-patch-sys.en.md).

---

## ⚙️ Universal Profiles (.conf)

You don't need to configure each build mode separately. The system uses a **single configuration file** to manage the entire process:

*   **One program list**: Manage all packages (VPN, AdGuard, Luci) in a single line for both modes.
*   **Flexible management**: Router model, number of CPU cores for building, and partition sizes are all set in one place.
*   **Order**: One file — one device. Easy to edit, easy to share.

👉 Read a detailed breakdown of the profile structure and step-by-step creation of the "ideal recipe" in **[Lesson #2: Digital Twin of Your Router](docs/02-digital-twin.md)**.

---

## 🎛️ Resource Management (SRC_CORES Source Builder)

CPU load settings in the profile file (`.conf`):

*   **`SRC_CORES="safe"`** — uses all cores minus one ($N-1$). The system remains responsive.
*   **Not set (default)** — uses all available cores ($N$). Maximum speed.
*   **`SRC_CORES="4"`** — a fixed number of build threads.

```bash
# Example: leave one core free
SRC_CORES="safe"
```

---

## 🪝 Smart Hooks and Vermagic Hack

The package includes a smart script `scripts/hooks.sh`.
When placed in the `custom_files/your_profile/` folder, it activates several powerful functions:

1.  **Auto-Enable Wi-Fi on First Boot:** The script automatically creates a `uci-defaults` script that enables all wireless radios when the router first starts up. This saves you from needing a wired connection for initial setup.
2.  **Git-Safe Patching:** Safely modifies source code before building. Allows changing DTS, Makefiles (e.g., for 16MB mods). Automatic backups protect against breaking the source tree when changing versions.
3.  **Vermagic Hack (Repository Compatibility):**
    *   *The Problem:* Normally, when you build your own kernel (SourceBuilder), its "fingerprint" (vermagic) differs from the official one. This prevents you from installing `kmod-*` (driver) packages from the official repository.
    *   *The Solution:* The script **automatically downloads the official manifest** for your OpenWrt version, extracts the correct hash, and "tricks" the build system.
    *   *Result:* You get custom firmware where **official drivers can be installed** (USB, Wireguard, FS) without errors!

### 🛡️ Reliability Architecture (v4.09+)

Starting with version 4.09, the builder's architecture has been significantly redesigned with a focus on predictability and stability.

*   **"Self-Healing" Mechanism (Source Builder):**
    *   **The Problem:** Using patches (`hooks.sh`) to modify source code (e.g., for the Vermagic Hack) leaves a "dirty" trace in the build environment. If you then built firmware without these patches, the residual changes could lead to errors.
    *   **The Solution:** The builder now **automatically** detects this state. If `hooks.sh` is missing but the system has been modified, it initiates a **full rollback cycle**: restoring clean Makefiles, clearing the kernel cache, and resetting CCACHE. This ensures that every build starts in a predictably clean environment.

*   **Docker Stability on WSL/Linux:**
    *   **The Problem:** Docker's interaction with the Windows file system (via WSL) could lead to file locking errors, interrupting the build.
    *   **The Solution:** A new, more robust container management cycle has been implemented. Before starting a build, the system forcibly stops and removes old containers, giving the file system time to "breathe." This almost completely eliminates this class of errors.

---

## 🎛️ Interactive Configuration (Menuconfig)

Version 3.3 introduced the ability to fine-tune the kernel and packages via the standard OpenWrt graphical menu (`make menuconfig`). This is only available in **Source Builder** mode.

### How it works:

1.  **Launch menu:** In the main menu, select `[K] MENUCONFIG`.
2.  **Configuration:** If this is the first run, after preparation, the classic blue Linux Kernel Configuration interface will open. Select the required kernel modules, drivers, or packages.
3.  **Saving:** Press `<Save>` (keep the name `.config`) and then `<Exit>`.
4.  **Result:** The script will capture the config and save it as a **master file** in the folder:
    `firmware_output/sourcebuilder/<profile_name>/manual_config`

<img width="1154" height="548" alt="{055C8650-7708-43DD-A94A-ABD3DE48A368}" src="https://github.com/user-attachments/assets/d09999ad-cf46-4ab4-bc3c-01a190d860a1" />

### ⚠️ Configuration Priority (Manual Config)

The build system now automatically determines the configuration strategy:

*   **Automatic Mode (Default):** If the `manual_config` file is not present in the firmware output folder, the builder generates `.config` on the fly using variables from your profile (`SRC_PACKAGES`, `SRC_EXTRA_CONFIG`, `COMMON_LIST`).
*   **Manual Mode (Priority):** If the `manual_config` file is found in the output folder, the builder **IGNORES** the package lists and kernel options from the `.conf` file. Instead, it applies your saved config "as is" (adding only caching settings).

> **How to return to auto-build?** Simply delete or rename the `manual_config` file in the `firmware_output` folder.

## 🎛️ Interactive Tuning & Sync (v4.03)
In **Source Builder** mode (`[K] MENUCONFIG`), a **full synchronization cycle** is now implemented:
1.  **Modify:** Change settings in the standard OpenWrt GUI.
2.  **Sync:** Upon exit, the script offers to transfer changes **directly into your profile file (`.conf`)**.
3.  **Clean Syntax:** Parameters are saved in `SRC_EXTRA_CONFIG` using a multi-line format, supporting `# ... is not set` comments and eliminating parsing errors.
4.  **History:** Original diffs are archived with timestamps (`applied_config_*.bak`).

---

### ⚡ Source Builder Quick Start (Cold Start)

If you are using specific repositories with their own set of drivers (e.g., for MT798x), use the **manual_config** strategy:

1. **Initialization**: Configure `SRC_REPO` and run **[K] Menuconfig** so the system creates the folder structure.
2. **Replacement**: Take a minimal `defconfig` from the source author (~15 KB), rename it to `manual_config`, and place it in the profile output folder.
3. **Deployment**: Run **[K] Menuconfig** again — the system will resolve dependencies and expand the file to a full `.config` (~400 KB).

👉 Detailed instructions for deep configuration and working with custom kernels: **[docs/04-adv-source-build.md](docs/04-adv-source-build.md)**.

---

### ⚙️ Automatic `.ipk` Package Import (Binary-to-Source)

This is one of the **key features** of `Source Builder` v3.8+, solving a difficult problem: how to embed a ready-made `.ipk` package into the firmware for which you **do not have the source code**.

**The Problem:**
Normally, adding a package to a `Source` build requires writing a complex `Makefile`. If you only have a binary `.ipk` (e.g., a closed-source driver or an old program), integrating it becomes a nightmare: you have to manually unpack archives, define paths, fix permissions, and hope the build system doesn't corrupt the files.

**The Solution in Builder — Full Automation:**
Instead of manual work, you simply use the built-in importer:

1.  **Place the `.ipk`** in the `custom_packages/your_profile_name/` folder.
2.  **Select `[I] Import IPK`** in the main menu.
3.  **Done!**

The script will do all the dirty work:
*   **Create a Makefile wrapper:** You no longer need to write them manually.
*   **Preserve symlinks and permissions:** Unpacking happens inside a Linux container, solving filesystem issues.
*   **Protect binaries:** It disables `strip` and `patchelf` so the build system doesn't touch your files.
*   **Check architecture:** Warns if you try to import a `mips` package into an `aarch64` build.
*   **Integrate into Menuconfig:** After import, the package will appear in `menuconfig` under the `Custom-Packages` category, ready to be included in the firmware.

This feature turns closed-source software integration from a complex engineering task into a three-step process.

---

## 🛠 FAQ: Useful Tips and Troubleshooting

### ❓ ImageBuilder or SourceBuilder? Which to choose?
> **Choice depends on your goals:**
> *   **ImageBuilder:** (1–3 minutes). Ideal if you just need to add LuCI, VPN, configure Wi-Fi, or change the package set.
> *   **SourceBuilder:** (20–60+ minutes). Necessary for deep modding: creating firmware for 4MB flash drives (compression), changing kernel settings, integrating specific drivers, or creating firmware with non-standard partition sizes (e.g., 16MB mod).

### ❓ Is parallel building of multiple profiles safe?
> **Yes, completely.** The system implements **Atomic Downloads** and **Global Locks** technology.
> *   If you start 5 builds simultaneously using the same SDK, only the first process will download it.
> *   The others will wait for the download to complete and use the ready cache. "File in use" conflicts or archive corruption are excluded.

### ❓ What to do in case of network errors (wget error 4)?
> The system is adapted for unstable communication channels thanks to **Smart Retries**:
> *   An aggressive `wgetrc` is configured inside the containers (5 attempts for each file).
> *   If the build is interrupted due to a critical network error, the main script will automatically perform up to **3 full restarts** of the process.

---

### 🔍 Quick Solutions (Troubleshooting)

*   **Error `Package not found`?**
    *   Ensure you placed the required `.ipk` files in the `custom_packages` folder or check the package name spelling in your `.conf` file.
*   **How to check if Vermagic Hack is working?**
    *   After flashing the router, try installing any kernel module from the official repository, for example: `opkg update && opkg install kmod-fs-btrfs`. If the installation proceeds without an *Exec format error*, the hack is active.
*   **Dependency conflict (e.g., dnsmasq)?**
    *   When installing extended versions of packages (full/crypto), always remove the base version first.
    *   *Example in config:* `-dnsmasq dnsmasq-full`.
*   **Error `The system cannot find the drive specified`?**
    *   Usually occurs if the project path contains special characters or spaces. It is recommended to place the project folder closer to the root of the drive (e.g., `C:\OpenWrt_Build\`).

---

## 🔧 Utility Scripts (`/scripts`)

*   `hooks.sh` — Template for patches and Vermagic.
*   `diag.sh` — Creates a report for router diagnostics via AI.
*   `upgrade.sh` — Bulk update of all packages on the router.
*   `packager.sh` — Generates a clean list of only user-installed packages.
*   `show_pkgs.sh` — Alternative way to get a package list from the lessons.
*   `99-permissions.sh` — Auto-fix permissions for files (Dropbear/SSH).

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/iqubik/routerFW/output/github-contribution-grid-snake-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/iqubik/routerFW/output/github-contribution-grid-snake.svg">
  <img alt="github contribution grid snake animation" src="https://raw.githubusercontent.com/iqubik/routerFW/output/github-contribution-grid-snake.svg">
</picture>

---

Project audit https://github.com/iqubik/routerFW/blob/main/audit.md
