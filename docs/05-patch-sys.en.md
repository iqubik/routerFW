# file: docs\05-patch-sys.en.md

<p align="center">
  <a href="05-patch-sys.md"><b>🇷🇺 Русский</b></a> | <b>🇺🇸 English</b>
</p>

---

# 🛠 Guide: Source Code Patching System

## 1. Introduction

Version **4.33** introduces a new system for modifying the OpenWrt source code. It's designed to solve one of the most challenging tasks in firmware building: **how to change the project's source code without losing those changes when the container is recreated?**

Previously, this required writing complex scripts in `hooks.sh` or manually editing files inside the Docker container. Now, the process is transparent and automated.

### What is this for?
*   **Build Modification:** Changing a `Makefile` to enable hidden compilation options.
*   **Hardware Support:** Adding `.dts` files for new devices or applying kernel patches.
*   **Bug Fixes:** Applying `.patch` files to packages or the system.
*   **Customization:** Replacing default configs within the source tree.

---

## 2. Key Concept: "Mirror Overlay"

The system operates on a **mirroring** principle. The `custom_patches/<PROFILE_ID>/` directory on your computer is a projection of the OpenWrt source root folder (`/home/build/openwrt/`) inside the container.

> **Rule:** Any file placed in `custom_patches` will be copied into the source tree, preserving the folder structure and overwriting the original files.

### 🛡 Automatic CRLF Fix (Windows Fix)
One of the main problems when developing on Windows is line endings (CRLF), which break builds in Linux.
**Our system solves this automatically:**
Before applying patches, a special utility, `dos2unix`, recursively processes all your files, converting them to the safe Unix format (LF). You can edit files in Notepad and not worry about compilation errors.

---

## 3. How It Works (Lifecycle)

1.  **Preparation:** You create a folder structure inside `custom_patches/<PROFILE_ID>/` that mirrors the path to the target file.
2.  **Detection:** When `_Builder.bat` starts, it checks for patches. If they exist, the **X** (Patches) indicator lights up next to the profile in the menu.
3.  **Isolation:** The folder with your patches is mounted into the Docker container in a safe location (`/patches`).
4.  **Application:**
    *   The script converts files to Unix format.
    *   The `rsync` utility overlays your files onto the OpenWrt source code.
5.  **Build:** The compilation (`make`) starts on the already modified code.

---

## 4. Practical Examples

### Example #1: Replacing a File (Makefile)
**Task:** Change the compilation options for the `hostapd` package.
**Method:** Complete file replacement.

1.  The file's path in OpenWrt is: `package/network/services/hostapd/Makefile`
2.  Create the same structure on your disk:
    ```text
    custom_patches/
    └── my_profile/               <-- Your profile's name
        └── package/
            └── network/
                └── services/
                    └── hostapd/
                        └── Makefile  <-- Your modified file
    ```
**Result:** During the build, the original Makefile will be overwritten by your version.

---

### Example #2: Native Kernel Patching (Recommended Method) 🔥
**Task:** Add support for a new Flash memory chip to the Linux kernel.
**Method:** Using OpenWrt's built-in build system (no scripts!).

OpenWrt automatically looks for `.patch` files in `patches-x.x` folders inside `target/linux`. We just need to "drop" the file there.

1.  Find out the architecture (e.g., `ramips`) and kernel version (e.g., `5.10`).
2.  The target path in the source tree is: `target/linux/ramips/patches-5.10/`.
3.  Create the structure:
    ```text
    custom_patches/
    └── my_profile/
        └── target/
            └── linux/
                └── ramips/
                    └── patches-5.10/
                        └── 999-add-new-flash.patch
    ```
**Result:** When preparing the kernel, the OpenWrt build system will see this file and apply it using its standard tools (`quilt`/`patch`).

---

### Example #3: Applying a Patch via Hooks (Advanced Scenario)
**Task:** Apply a complex patch to the system's root that requires special logic, or if you don't want to follow OpenWrt's folder structure.

1.  Place the patch in the root of your profile's patches folder:
    ```text
    custom_patches/
    └── my_profile/
        └── 001-complex-fix.patch
    ```
2.  At the start of the build, this file will appear in the root of the OpenWrt source tree: `/home/build/openwrt/001-complex-fix.patch`.
3.  Use `custom_files/my_profile/hooks.sh` to apply it:
    ```bash
    #!/bin/bash
    # hooks.sh is executed in the /home/build/openwrt root directory
    echo "Applying manual patch..."
    patch -p1 < 001-complex-fix.patch
    ```

---

## 5. Frequently Asked Questions (FAQ)

**Q: What's the difference between `custom_files` and `custom_patches`?**
*   **`custom_files`**: These are files that will be included in the **final firmware image** (e.g., `/etc/config/network` on the router). They are overlaid at the very end of the build process.
*   **`custom_patches`**: These are files that change the OpenWrt **source code** (e.g., C/C++ sources, Makefiles). They are overlaid *before* compilation begins.

**Q: Do I need to run `make clean` after changing patches?**
*   Yes. If you've changed kernel patches or core packages, a **Soft Clean** is recommended (Menu -> Maintenance -> Soft Clean) so that OpenWrt rebuilds the modified components.

**Q: How should I name my patch file?**
*   For Example #2 (native patching), names are important. OpenWrt applies them in alphabetical order.
    *   `0xx-` — Patches from OpenWrt developers.
    *   `9xx-` — Custom user patches (it's recommended to use a prefix like `999-my-fix.patch` so it's applied last).