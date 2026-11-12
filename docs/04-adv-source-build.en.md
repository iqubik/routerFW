# file docs\04-adv-source-build.en.md

<p align="center">
  <a href="04-adv-source-build.md"><b>🇷🇺 Русский</b></a> | <b>🇺🇸 English</b>
</p>

---

# Lesson 4: Advanced Source Mode: Sync, Hooks, and Indicators

**Lesson Goal:** Master professional `Source Builder` tools: automatic settings synchronization, resource monitoring, advanced kernel patching via hooks, and the "Binary-to-Source" IPK/APK import mechanism.

---

### 📊 1. Resource Monitoring (Indicator System)

Version **4.33** introduced the main-menu resource panel **`[F P S M H X | OI OS]`**. This allows you to instantly assess your profile's readiness:

*   **F (Files)**: File overlay detected in `custom_files/%ID%`.
*   **P (Packages)**: Pre-compiled `.ipk` packages found in `custom_packages/%ID%` (ready for import).
*   **S (Source)**: Third-party package source code found in `src_packages/%ID%`.
*   **M (Manual Config)**: Active `manual_config` detected (unsynced Menuconfig results).
*   **H (Hooks)**: Automation script `hooks.sh` detected in the custom files folder.
*   **X (Patches)**: Patch files in `custom_patches/%ID%` for overlaying onto the OpenWrt source tree.
*   **OI / OS**: Finished firmware detected (**Image Builder** or **Source Builder**).

---

### 🔄 2. New Configuration Sync (Auto-Sync)

Since **v4.33**, the builder has provided a synchronization cycle between the interactive GUI and your text-based profile:

1.  **Launch**: Select **[K] Menuconfig**.
2.  **Modify**: Change settings in the standard OpenWrt interface.
3.  **Exit**: Upon closing, the Builder prompts: **"Update profile with Menuconfig data? [Y/N]"**.
4.  **Finalize**: If you select **Y**, the settings are converted into a clean diff and written directly to your `profiles/%ID%.conf` under the `SRC_EXTRA_CONFIG` variable.

> **Result:** Your `.conf` file becomes the "single source of truth." The raw config is archived as `applied_config_*.bak` for safety.

---

### 📦 3. Binary-to-Source IPK/APK Import

**The Problem:** You have a proprietary program (e.g., modem drivers) as an `.ipk` (for OpenWrt 23.x and older) or `.apk` (for OpenWrt 24.10+) package, but you don't have its source code. 
**The Solution:** The "Binary-to-Source" mechanism allows you to "wrap" an `.ipk`/`.apk` into a package that `Source Builder` treats as source code.

> **APK Support (starting from v4.50):** Starting from version 4.50, the builder fully supports importing and managing APK packages for Source Builder. This significantly expands firmware customization options for modern OpenWrt versions.

#### A. Workflow:
1.  **Placement**: Put `.ipk` or `.apk` files in `custom_packages/%ID%/`.
2.  **Launch**: Select **[I] (Import IPK/APK)** from the main menu.
3.  **Processing**: The import script (`system/import_ipk.ps1` for Windows or `system/import_ipk.sh` for Linux) performs the following:
    *   **Unpacking**: Extracts metadata (`control`) and data (`data.tar.gz`).
    *   **Architecture Check**: Compares the package architecture with your profile's `SRC_TARGET` (e.g., `aarch64_cortex-a53`).
    *   **Dependency Correction**: Replaces outdated dependencies with current OpenWrt 23.xx/24.xx/25.xx equivalents.
    *   **Both formats supported**: Correctly handles both `.ipk` (opkg) and `.apk` (apk) packages.
    *   **Makefile Generation**: Creates a specialized `Makefile` in `src_packages/%ID%/%package_name%/`.

#### B. What happens "under the hood":
*   **Structure Preservation**: The `data.tar.gz` is **not unpacked on Windows**. It is copied as-is and unpacked only inside the Linux container. This **preserves symbolic links and file permissions** that Windows would otherwise destroy.
*   **Binary Protection**: Commands like `STRIP:=:` and `PATCHELF:=:` prevent the build system from "optimizing" (and breaking) the pre-compiled binaries.
*   **Safe Execution**: Installation scripts (`postinst`) are wrapped in `if [ -z "$$IPKG_INSTROOT" ]` checks to ensure they only run on the router, not during the build process.

---

### 🪝 4. Automation via Hooks & The "Vermagic Hack"

The `custom_files/%ID%/hooks.sh` script (indicator **H**) runs inside the container before `make defconfig` and can modify the build tree. The `scripts/hooks.sh` template includes examples. Source Builder first copies the managed `custom_files` overlay into `files/` **without `--delete`**, then runs hooks and records newly created files under `files/`. There is no destructive overlay sync after hooks.

*   **Auto-Enable Wi-Fi:** the template can create a `uci-defaults` script to enable detected radios on first boot. Verify that it applies to the target device; hook-created files under `files/` are tracked by the supported ownership rules.
*   **Add Feeds**: Use the `add_feed` function to connect external package repositories that are not included in the default OpenWrt source.
    ```bash
    # Example: Adds the repository containing the amneziawg package
    add_feed "amneziawg" "https://github.com/amnezia-vpn/amneziawg-openwrt.git"
    ```
*   **Patching**: Apply custom code modifications using `patch -p1`.
*   **The Vermagic Hack:** the hook attempts to identify the OpenWrt branch, retrieve the corresponding official manifest, and apply the matching vermagic hash. This can improve compatibility with matching `kmod-*` packages, but cannot guarantee compatibility when kernel, configuration, or ABI differ.

#### 🛡️ Supported Vermagic Rollback (introduced in v4.09)

Source Builder checks known markers for changes to `include/kernel-defaults.mk` and the corresponding backup. This is a narrow rollback for the supported Vermagic workflow, not a universal cleanup of arbitrary modifications.

*   **The Problem:** Vermagic changes can remain in the persistent worktree after a profile stops using the hook.

*   **Supported rollback:** if `hooks.sh` is absent and the expected Vermagic markers are detected, the builder restores the backup of `include/kernel-defaults.mk`, removes the known markers, and cleans the related kernel/CCache paths:
    1.  Restores the backup of `include/kernel-defaults.mk`.
    2.  Removes known Vermagic markers.
    3.  Cleans related kernel build directories.
    4.  Resets CCache for that work directory.

*   **Limitation:** this is not `git clean` and does not remove arbitrary untracked files created by third-party hooks or patch overlays.

---

### 🎛️ 5. Build Resource Management (SRC_CORES)

Control CPU load via the `SRC_CORES` variable in your `.conf` file:

*   **`SRC_CORES="safe"` (Recommended)**: Uses `N-1` cores. The system remains responsive for web browsing while building.
*   **Not specified (Default)**: Uses **all** available CPU cores (`N`) for maximum speed.
*   **`SRC_CORES="4"`**: Strictly limits the build to 4 threads (useful for laptop thermal management).
*   **`SRC_CORES="debug"`**: Forces a single-threaded, verbose build (`make -j1 V=s`), which is essential for diagnosing build failures.

---

### 🧹 6. Cache Management & Maintenance (CLEAN)

If a build fails or acts strangely, use the **[C] CLEAN** menu in `SOURCE BUILDER` mode. Global runtime-wide cleanup is not available:

1.  **[1] SOFT CLEAN (make clean)**: Deletes compiled files for the profile. Use if the build crashed midway.
2.  **[2] HARD RESET (Remove src-workdir)**: Deletes the entire source folder. Use for a "clean slate" without losing downloaded archives.
3.  **[3] Clean Source Cache (dl)**: Deletes all downloaded `.tar.gz` package archives to free up disk space.
4.  **[4] Clear CCACHE**: Resets the compiler cache. Use if you suspect compiler errors.
5.  **[5] Clean tmp (Package Index)**: Removes the `tmp/` folder in the source tree (package index). Use when dependency updates fail or after changing feeds.
6.  **[6] FULL FACTORY RESET**: The "nuclear option." Deletes sources, `dl` cache, and `ccache`.
*   **[9] Global prune**: this menu item is a safe no-op. Global Docker/Podman cleanup is disabled in both the menu and CLI because it could affect resources belonging to other projects.

---

### 📦 7. Local Image Builder After Source (v4.40+)

After a successful **Source Builder** run, the host builder compares output directory names before and after the run. Only when **exactly one new directory** appears, its `build.config` contains `CONFIG_IB=y`, and an `*imagebuilder*.tar.zst` archive exists there, does it offer to update `IMAGEBUILDER_URL`. Otherwise no prompt or profile change occurs; an absent optional archive is normal. Accepting (**Y**) enables subsequent **Image Builder** runs without recompiling the kernel. A newly published directory does not prove every archived file was freshly generated by incremental `make`.

**Steps:** build firmware from source → at the end you get «Update profile? [y/N]» → **Y** → switch to **M** (Image Builder) → select the profile and build. Further package and config changes are done via fast IB until you need to change the kernel or defconfig again.

**Measured example:** for profile `cmcc_rax3000m_25126_ow_full`, Image Builder using an archive produced by Source Builder completed in **26 seconds**. Output directory: `firmware_output/imagebuilder/cmcc_rax3000m_25126_ow_full/121126-034419`. This is a single-run result; build time depends on the package set and host performance.

---

### 💡 8. Life Hack: "Cold Start" (Example: Rax3000M)

**Scenario “one Source build — then IB in 1–2 minutes”:** do not pack the Source Builder with every package. In menuconfig include only the needed `kmod-` and a minimal set; at the end of the build enable Image Builder output (in menuconfig), accept updating the profile with the local IB, switch to Image Builder mode (**M**), and then build firmwares with any set of packages and configs in 1–2 minutes. A full source rebuild takes from 10 minutes with cache to 30+ on the first run.

How to build firmware using a complex `defconfig` from a third-party developer:

1.  **Setup**: Configure your `.conf` with the correct repository and branch.
2.  **Initialize**: Run **Menuconfig** once to create the folders, then exit.
3.  **Replace**: Copy the developer's configuration file to:  
    `firmware_output\sourcebuilder\%ID%\manual_config`
4.  **Expand**: Run **Menuconfig** again. The system detects the minimalist file (e.g., 11KB) and **automatically expands it** into a full `.config` (~400KB), resolving all dependencies.
5.  **Finalize**: Upon exit, select **Y** to update the profile. The Builder will compress the settings back into a clean diff and save them into your `.conf`.

---

### 🛠️ 9. Advanced Package Compilation

This section covers commands for advanced users who need to manually compile or recompile specific packages within the OpenWrt build system.

*   **`package/<package_name>/compile`**: This `make` target instructs the OpenWrt build system to compile a specific package. Replace `<package_name>` with the actual directory name of the package in `openwrt/buildroot/package/`.
*   **`V=s`**: This flag makes the build output more verbose, which is very useful for debugging if something goes wrong.

**Example:**

If you want to recompile the `luci-app-samba4` package, the command would be:

```bash
make package/luci-app-samba4/compile V=s
```

If you just want to clean cache of package, you can use:

```bash
make package/<package_name>/clean V=s
```
# checksum:MD5=248128dd35ffdd8b13c4804e4b79c8ce