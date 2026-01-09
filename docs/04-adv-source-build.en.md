<p align="center">
  <a href="04-adv-source-build.md"><b>🇷🇺 Русский</b></a> | <b>🇺🇸 English</b>
</p>

---

# Lesson 4: Advanced Source Mode: Patches, Cache, and Custom Packages

**Goal:** To explore the powerful but less obvious features of the `Source Builder` for total control over your firmware.

---

### 1. Adding Third-Party Packages from Source

If the program you need is not in the official repositories, but its source code is available (e.g., on GitHub), you can compile it alongside the firmware.

1.  Navigate to the `src_packages/` folder in the Builder's root.
2.  Clone the repository with the program's source code into it:
    ```bash
    cd src_packages
    git clone https://github.com/some-author/cool-openwrt-package.git
    ```
3.  Run `_Builder.bat` and select **[K] Menuconfig** for your profile.
4.  In the configuration menu, find the new package (usually in the `Utilities`, `Network`, or `LuCI -> Applications` sections) and mark it for inclusion:
    *   `<M>` — build as a module (`.ipk` package).
    *   `<*>` — build directly into the firmware.
5.  Save the configuration and start the main build. The Builder will automatically compile the package and add it to the firmware.

### 2. Importing Binary Packages (.ipk) into the Build (Binary-to-Source Mechanism)
*(Tested on owrt 24.10.5 + z72.20251022)*

**The Problem:** You have a program as an `.ipk` package, but you don't have its source code. This could be proprietary software (e.g., modem drivers) or a package you built earlier and don't want to recompile.

**The Solution:** Builder v3.8+ includes a powerful "Binary-to-Source" mechanism that allows you to "wrap" an `.ipk` into a full-fledged package for the `Source Builder`.

**Workflow:**

1.  **Place the `.ipk` files** in the folder `custom_packages/<your_profile_ID>/`. For example, for the profile `nanopi_r5c_full.conf`, it would be `custom_packages/nanopi_r5c_full/`.

2.  **Run the Import:** In the `_Builder.bat` main menu, select the **[I] (Import IPK)** option. The script will ask you to specify which profile you want to import packages for.

3.  **Automatic Processing:** The PowerShell script `system/import_ipk.ps1` will launch and perform the following:
    *   **Unpacking:** It analyzes the `.ipk` and extracts metadata (`control`) and data (`data.tar.gz`).
    *   **Architecture Check:** It compares the package architecture (e.g., `aarch64_cortex-a53`) with your profile's target architecture (`SRC_TARGET`). If they are incompatible, the script will issue a warning.
    *   **Dependency Correction:** It automatically replaces outdated dependencies (e.g., `libnetfilter-queue1`) with the ones relevant for OpenWrt 23.xx/24.xx.
    *   **Makefile Generation:** It creates a special `Makefile` in the folder `src_packages/<profile_ID>/<package_name>/` that "tricks" the build system into thinking it is a standard source package.

**What happens "under the hood" in the generated Makefile:**

*   The `data.tar.gz` archive is not unpacked on Windows but **copied as is**. Unpacking occurs inside the Linux container. This **preserves symbolic links (symlinks)** and correct file permissions that would otherwise be lost.
*   The commands `STRIP:=:` and `PATCHELF:=:` prevent the build system from modifying (e.g., "optimizing") binary files inside the package, which prevents errors.
*   Installation scripts (`postinst`) are wrapped in an `if [ -z "$$IPKG_INSTROOT" ]` check to ensure they don't try to run during firmware compilation, but only during installation on the router.

**Result:**

After the import is complete, new folders with the names of your packages will appear in `src_packages/<profile_ID>/`. Now you can run **[K] Menuconfig**, and these packages will be available for selection in the `Custom-Packages` category. Mark them (`<M>` or `<*>`) and start the build.

### 3. Patches and Feeds via `hooks.sh`

The `scripts/hooks.sh` script is a powerful tool that runs **before every build** in `Source Builder` mode. It allows you to automate routine tasks.

*   **Applying Patches:** If you need to fix a bug or change behavior in the source code, create a `.patch` file and place it in the project root. Then, in `scripts/hooks.sh`, add a command to apply it. The example script already contains a template.

    ```bash
    # ...inside the scripts/hooks.sh file...
    log ">>> Applying custom patches..."
    patch -p1 < /builder/my-fix.patch # /builder/ is the project root inside the container
    ```

*   **Adding Feeds (External Repositories):** There is an `add_feed` function in `hooks.sh`. You can uncomment or add new lines to connect entire repositories of packages not present in OpenWrt. Example from the script:
    ```bash
    # Adds a repository containing the amneziawg package
    add_feed "amneziawg" "https://github.com/amnezia-vpn/amnezia-wg-openwrt.git"
    ```

### 4. Solving the `vermagic` Problem (The "Vermagic Hack")

**The Problem:** You built your own firmware but cannot install kernel modules (`kmod-*.ipk`) from the official repository because the system complains about a `vermagic mismatch`.

**The Solution in Builder:** This issue is resolved **automatically** for release builds. The `hooks.sh` script identifies your OpenWrt version, downloads the official kernel "signature" (`vermagic`), and embeds it into your build.

**How to use:** Place the `hooks.sh` file from the `\scripts\` folder into your profile's custom files folder, e.g., `\custom_files\rax3000m_emmc_test_new`.
The file will not be included in the final image in either ImageBuilder or SourceBuilder mode. Inside the file, instructions are ready to automatically replace Vermagic with the current one if possible. If you remove this file after the hack, the source code in the Vermagic area will automatically roll back to the default state during the next build.
**In short, you don't need to do much—Vermagic with `hooks.sh` works "out of the box" for stable releases!** Just know that thanks to this, you can install official `kmod` packages on your custom `Source` firmware.

### 5. Cache Management and Troubleshooting

Sometimes, after a failed build or a configuration change, the cache can become "polluted," leading to strange errors. The Builder has a built-in menu for cleaning.

**How to use:** In the main menu, select **[C] CLEAN / MAINTENANCE**. Ensure you are in `SOURCE BUILDER` mode to see the following options:

*   **[1] SOFT CLEAN (make clean):** "First aid." Deletes compiled files for the selected profile but keeps the source code and toolchain. Ideal if a build fails halfway through.
*   **[2] HARD RESET (Delete src-workdir):** Deletes the entire source code folder for the profile. Use this if the source code is corrupted or you need to start with a "clean slate." Downloaded archives (`dl`) and `ccache` are preserved.
*   **[3] Clean Source Cache (dl):** Deletes all downloaded package archives. Useful for freeing up space. They will be re-downloaded during the next build.
*   **[4] Clean CCACHE:** Completely resets the compiler cache. The next build will be as long as the very first one. Use this if you suspect compiler-related issues.
*   **[5] FULL FACTORY RESET:** The "nuclear option." Deletes **everything** for the profile: source code, `dl` cache, and `ccache`.
*   **[9] Prune Docker:** A global Docker command to clean the entire system of unused images, networks, and caches. Useful for general maintenance.

**Recommendation:** Start with `SOFT CLEAN` if issues arise. If that doesn't help, use `HARD RESET`.

---
## 🎛️ Build Resource Management (Source Builder)

For the full compilation mode (`Source Builder`), you can manage the number of processor cores allocated for the build. This allows you to speed up the process or, conversely, reduce the system load to continue working comfortably.

Management is handled via the `SRC_CORES` variable in your `.conf` profile file.

### `SRC_CORES` Usage Options

*   **`SRC_CORES="safe"` (Recommended)**
    *   **Description:** Automatic "safe" mode. The builder uses all available cores except one (`N-1`).
    *   **When to use:** This is the best choice for most cases. The build runs at near-maximum speed, but the system remains responsive for other tasks.

*   **If `SRC_CORES` is not specified (Default)**
    *   **Description:** The builder uses **all** available CPU cores (`N`).
    *   **When to use:** If you want maximum speed and are okay with the computer potentially "lagging" during compilation.

*   **`SRC_CORES="<number>"` (e.g., `SRC_CORES="4"`)**
    *   **Description:** Directly specifies the number of build threads (`make -j4`).
    *   **When to use:** If you need to strictly limit resource consumption. For example, if you have a 16-core processor but want to allocate only 4 cores to the build.

Example entry in the profile:
```bash
# Use all cores except one
SRC_CORES="safe"
```
> **Note:** The system automatically ensures that at least one core is used for the build.

---

### 💡 Advanced Example: Building with Custom Drivers (Rax3000M)
The following is a step-by-step "cold start" process for such a build:

1.  **Step 1: Profile Setup (`.conf`)**
    - In the profile file for `Source Builder`, specify the exact repository URL (`SRC_REPO`) and the target branch (`SRC_BRANCH`) containing the required drivers.

2.  **Step 2: Structure Creation (`menuconfig`)**
    - Run `[K] MENUCONFIG` for this profile. Since the cache and working directory are empty, the system will create all necessary folders, including `firmware_output/sourcebuilder/<profile_name>/`.

3.  **Step 3: Finding the Base `defconfig`**
    - In the source code repository you are building, find the base configuration file. It is usually located in the `defconfig` folder and is minimal in size (10-15 KB).
    - *Example:* `https://github.com/padavanonly/immortalwrt-mt798x-6.6/blob/openwrt-24.10-6.6/defconfig/mt7981-ax3000.config`

4.  **Step 4: Configuration Swapping**
    - Copy the found `defconfig` to the output folder and rename it to `manual_config`.
    - **Path:** `firmware_output\sourcebuilder\<profile_name>\manual_config`

5.  **Step 5: Resolving Dependencies**
    - Run `[K] MENUCONFIG` again for the same profile.
    - The OpenWrt build system will detect the minimalist `manual_config` and **automatically expand it**, including all necessary dependencies and options. Your 11 KB file will turn into a full `.config` of ~400 KB.

**Result:** You now have a complete and correct `manual_config` that includes all the source author's recommendations and is ready for further customization via `menuconfig` or manual editing, and ready to start the build.

This concludes the series of lessons. You now have all the knowledge needed to create firmwares of any complexity!