<p align="center">
  <a href="02-digital-twin.md"><b>🇷🇺 Русский</b></a> | <b>🇺🇸 English</b>
</p>

---

# Lesson 2: Cemented Backup of Your Settings

**Goal:** To build a fresh firmware where all programs and settings from your current router are "cemented-in."

This is the most practical and useful scenario for using the Builder. We will perform this in two stages: first, a test build to ensure that everything is working correctly, and then the final build with your actual data.

---

### Step 0: Creating the Settings Archive

1.  Access your router's web interface (usually `192.168.1.1`).
2.  Navigate to the menu **System -> Backup / Flash Firmware**.
3.  Click the **Generate archive** button and save the file (e.g., `backup-OpenWrt-2026-01-07.tar.gz`) to your computer.

### Step 1: Creating a Base Profile Using the Wizard

Now we need a "clean" recipe for the build specifically for your router model. We will obtain it using the Profile Wizard (`create_profile.ps1`), and we will take all the necessary information from the filename of the official firmware.

**1. Analyzing the Firmware Filename**

Find the firmware for update (`sysupgrade`) on the [official OpenWrt website](https://firmware-selector.openwrt.org/) or on the releases page of your fork (ImmortalWrt, etc.). Its name is the key to everything.

Let's look at your example: `immortalwrt-mediatek-filogic-cmcc_rax3000m-nand-mtk-squashfs-sysupgrade.bin`

-   `immortalwrt`: This is the **Release** or distribution (it could be `openwrt-23.05.2`).
-   `mediatek-filogic`: This is the **Target** and **Subtarget**. The Wizard may ask you to select `mediatek` first, and then `filogic`.
-   `cmcc_rax3000m-nand-mtk`: This is the **Profile** — the specific model of your device.

**2. Running the Wizard and Entering Data**

Now that we have this information:

1.  In the Builder's main menu, select the option **[W] Profile Wizard**.
2.  The Wizard will sequentially ask you for the parameters we just determined: **Release, Target, Profile**. Enter them based on the analyzed filename.
3.  When asked about adding packages, **do not insert anything** for now, just press Enter.

As a result, a file named `your_model_name.conf` will appear in the `profiles/` folder with the correct technical parameters already set.

### Step 2: Test Build

This is a vital check to ensure the base profile was created correctly and the system is functional.

1.  Run `_Builder.bat` again. Your new profile will appear in the menu. Enter its number and press Enter.
2.  Wait for the build to complete. If it finishes successfully and the firmware files appear, everything is in order.
You can delete this test firmware from the `firmware_output/imagebuilder/` folder and move forward.

### ⚙️ Anatomy of a Universal Profile

Before making changes, let's take a look "under the hood." The Builder uses a single file for both build modes. If you created a profile via the Wizard, open it in `profiles/your_profile.conf`. You will see a structure divided into logical blocks:

```bash
PROFILE_NAME="my_router"
TARGET_PROFILE="xiaomi_mi-router-4a-gigabit"

# Common package list for both modes
COMMON_LIST="luci uhttpd htop -wpad-basic wpad-mbedtls"

# IMAGE BUILDER BLOCK (Fast assembly from pre-compiled packages)
IMAGEBUILDER_URL="https://downloads.openwrt.org/..."
PKGS="$COMMON_LIST" # You can add or exclude packages using the '-' prefix

# SOURCE BUILDER BLOCK (Full compilation from source code)
SRC_REPO="https://github.com/openwrt/openwrt.git"
SRC_BRANCH="v24.10.0"
SRC_TARGET="ramips"
SRC_SUBTARGET="mt7621"
SRC_PACKAGES="$COMMON_LIST"

# Resource and Hardware Settings (Source Builder)
SRC_CORES="safe"       # Use all CPU cores except one (N-1) to keep the OS responsive
SRC_EXTRA_CONFIG="CONFIG_TARGET_KERNEL_PARTSIZE=64 \
CONFIG_TARGET_ROOTFS_PARTSIZE=256"
```

**Why is this convenient?** You don't need to maintain two different program lists. You simply edit `COMMON_LIST`, and the changes are applied to both the fast (Image) build and the deep (Source) compilation.

---

### Where to insert:
Insert this block immediately after completing **Step 2** (before the header `### Step 3: Adding Your Data`).

### Why this is important for this lesson:
1. **Separation of Entities:** The user immediately sees the difference between settings for "fast" and "full" builds.
2. **The `COMMON_LIST` Variable:** In Step 3, you ask the user to find this line. Thanks to this inserted block, they already know what this variable is and what it's responsible for.
3. **SRC_CORES and Limits:** This prepares the user for the fact that a Source-build requires hardware resource configuration (as mentioned in the structure).

---

### Step 3: Adding Your Data

Now, let's "bring life" to our clean profile.

1.  **Settings:** Go to the `custom_files/` folder. Find the new folder there with the **exact name of your profile**. Extract the `backup.tar.gz` archive from Step 0 into it. This is the first key to personalization.
2.  **Programs:** Open the file `profiles/**.conf`. Find the line `COMMON_LIST=""` and insert the list of packages we will obtain below between the quotes.

### Obtaining the Program (Package) List

To ensure the new firmware contains all the programs you've installed (AdGuard, VPN clients, etc.), you need to copy their list.

1.  Connect to your router via SSH.
2.  Execute and copy the result of this command. It automatically generates a clean list of packages that you have installed additionally:
    ```bash
    wget -qO- https://raw.githubusercontent.com/iqubik/routerFW/main/scripts/show_pkgs.sh | sh
    ```
    > Example command output:
    ```
    root@OpenWrt2:~# wget -qO- https://raw.githubusercontent.com/iqubik/routerFW/main/scripts/show_pkgs.sh | sh
    -----------------------v0.1 (Hardcoded Filter)-------------------
    arp-scan arp-scan-database
    -----------------------------------------------------------------

    -----------------------v0.2 (Smart ROM Diff)---------------------
    ethtool-full
    -----------------------end---------------------------------------    
    ```
    Two types of filters are used here:

    ** First Output ** - a list of packages that were not automatically installed in the system, meaning they are not dependencies of other packages.

    ** Second Output ** - uses a comparison with the "out-of-the-box" system package list to find differences from the current state of the system.
    
    Unfortunately, generating such a list cannot be fully automated yet, but this is a point for future growth.

3.  Save this list into the `COMMON_LIST=""` variable inside your profile. This is the second of the two keys to your personal build configuration.
4.  This is perhaps the most nuanced moment regarding the list of required packages. It makes sense to take the resulting list to an AI (like ChatGPT) to filter and improve the result.

### Step 4: Final "Cementing" Build

1.  Run `_Builder.bat` again.
2.  Select the same profile for the build.
3.  Wait for completion.

**Done!** Now, in the `firmware_output` folder, lies a firmware in which all your packages and settings are "cemented-in." After installing this firmware, the router will immediately work the way you are used to.