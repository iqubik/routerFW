# Lesson 4: Advanced Source Mode: Sync, Hooks, and Indicators (v4.03)

**Lesson Goal:** Master professional `Source Builder` tools: automatic settings synchronization, resource monitoring, advanced kernel patching via hooks, and the "Binary-to-Source" IPK import mechanism.

---

### 📊 1. Resource Monitoring (Indicator System)

In version **4.03**, the main menu features a "surgical" resource panel **`[F P S M H | OI OS]`**. This allows you to instantly assess your profile's readiness:

*   **F (Files)**: File overlay detected in `custom_files/%ID%`.
*   **P (Packages)**: Pre-compiled `.ipk` packages found in `custom_packages/%ID%` (ready for import).
*   **S (Source)**: Third-party package source code found in `src_packages/%ID%`.
*   **M (Manual Config)**: **[NEW]** Active `manual_config` detected (unsynced Menuconfig results).
*   **H (Hooks)**: **[NEW]** Automation script `hooks.sh` detected in the custom files folder.
*   **OI / OS**: Finished firmware detected (**Image Builder** or **Source Builder**).

---

### 🔄 2. New Configuration Sync (Auto-Sync)

Version **4.03** implements a seamless synchronization cycle between the interactive GUI and your text-based profile:

1.  **Launch**: Select **[K] Menuconfig**.
2.  **Modify**: Change settings in the standard OpenWrt interface.
3.  **Exit**: Upon closing, the Builder prompts: **"Update profile with Menuconfig data? [Y/N]"**.
4.  **Finalize**: If you select **Y**, the settings are converted into a clean diff and written directly to your `profiles/%ID%.conf` under the `SRC_EXTRA_CONFIG` variable.

> **Result:** Your `.conf` file becomes the "single source of truth." The raw config is archived as `applied_config_*.bak` for safety.

---

### 📦 3. Binary-to-Source IPK Import

**The Problem:** You have a proprietary program (e.g., modem drivers) as an `.ipk` package, but you don't have its source code. 
**The Solution:** The "Binary-to-Source" mechanism allows you to "wrap" an `.ipk` into a package that `Source Builder` treats as source code.

#### A. Workflow:
1.  **Placement**: Put `.ipk` files in `custom_packages/%ID%/`.
2.  **Launch**: Select **[I] (Import IPK)** from the main menu.
3.  **Processing**: The `system/import_ipk.ps1` script performs the following:
    *   **Unpacking**: Extracts metadata (`control`) and data (`data.tar.gz`).
    *   **Architecture Check**: Compares the package architecture with your profile's `SRC_TARGET` (e.g., `aarch64_cortex-a53`).
    *   **Dependency Correction**: Replaces outdated dependencies with current OpenWrt 23.xx/24.xx equivalents.
    *   **Makefile Generation**: Creates a specialized `Makefile` in `src_packages/%ID%/%package_name%/`.

#### B. What happens "under the hood":
*   **Structure Preservation**: The `data.tar.gz` is **not unpacked on Windows**. It is copied as-is and unpacked only inside the Linux container. This **preserves symbolic links and file permissions** that Windows would otherwise destroy.
*   **Binary Protection**: Commands like `STRIP:=:` and `PATCHELF:=:` prevent the build system from "optimizing" (and breaking) the pre-compiled binaries.
*   **Safe Execution**: Installation scripts (`postinst`) are wrapped in `if [ -z "$$IPKG_INSTROOT" ]` checks to ensure they only run on the router, not during the build process.

---

### 🪝 4. Automation via Hooks & The "Vermagic Hack"

The script `custom_files/%ID%/hooks.sh` (Indicator **H**) is your tool for "last-minute" automation before compilation.

*   **Feeds & Patching**: Use `add_feed` to connect extra repos or `patch -p1` to apply custom code fixes.
*   **The Vermagic Problem**: If you build custom firmware, you usually cannot install official kernel modules (`kmod-*.ipk`) due to a `vermagic mismatch`.
*   **The Solution**: This is resolved **automatically** for release builds. If `hooks.sh` is present in your custom files, the Builder identifies your version, downloads the official kernel "signature" (vermagic), and embeds it into your build.

> **Note:** If you remove `hooks.sh`, the source code will automatically roll back to the default state during the next build.

---

### 🎛️ 5. Build Resource Management (SRC_CORES)

Control CPU load via the `SRC_CORES` variable in your `.conf` file:

*   **`SRC_CORES="safe"` (Recommended)**: Uses `N-1` cores. The system remains responsive for web browsing while building.
*   **Not specified (Default)**: Uses **all** available CPU cores (`N`) for maximum speed.
*   **`SRC_CORES="4"`**: Strictly limits the build to 4 threads (useful for laptop thermal management).

---

### 🧹 6. Cache Management & Maintenance (CLEAN)

If a build fails or acts strangely, use the **[C] CLEAN** menu in `SOURCE BUILDER` mode:

1.  **[1] SOFT CLEAN (make clean)**: Deletes compiled files for the profile. Use if the build crashed midway.
2.  **[2] HARD RESET (Remove src-workdir)**: Deletes the entire source folder. Use for a "clean slate" without losing downloaded archives.
3.  **[3] Clean Source Cache (dl)**: Deletes all downloaded `.tar.gz` package archives to free up disk space.
4.  **[4] Clear CCACHE**: Resets the compiler cache. Use if you suspect compiler errors.
5.  **[5] FULL FACTORY RESET**: The "nuclear option." Deletes sources, `dl` cache, and `ccache`.
6.  **[9] Prune Docker**: Cleans unused Docker images and networks.

---

### 💡 7. Life Hack: "Cold Start" (Example: Rax3000M)

How to build firmware using a complex `defconfig` from a third-party developer:

1.  **Setup**: Configure your `.conf` with the correct repository and branch.
2.  **Initialize**: Run **Menuconfig** once to create the folders, then exit.
3.  **Replace**: Copy the developer's configuration file to:  
    `firmware_output\sourcebuilder\%ID%\manual_config`
4.  **Expand**: Run **Menuconfig** again. The system detects the minimalist file (e.g., 11KB) and **automatically expands it** into a full `.config` (~400KB), resolving all dependencies.
5.  **Finalize**: Upon exit, select **Y** to update the profile. The Builder will compress the settings back into a clean diff and save them into your `.conf`.