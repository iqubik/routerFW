# file docs\03-source-build.en.md

<p align="center">
  <a href="03-source-build.md"><b>🇷🇺 Русский</b></a> | <b>🇺🇸 English</b>
</p>

---

# Lesson 3: Building from Source: Maximum Control

**Goal:** To master the advanced method of building from source code (`Source Builder`), using a developer-recommended configuration as a basis.

This lesson will demonstrate a professional approach to building, which is necessary for complex cases, such as using OpenWrt forks (like ImmortalWrt) or when specific kernel configurations are required.

---

### When Is This Needed?

You already know that `Source Builder` is required for deep modifications. This advanced method is needed if:
*   You are building firmware from a non-standard repository (a fork).
*   A simple "straightforward" build results in dependency errors.
*   You want to be certain that your build includes all recommendations and optimizations from the source code author.

### Practical Example: Building for Rax3000m from a Custom Repository

We will analyze a real-world case described in `debug.md`: building firmware for the `rax3000m` from the `padavanonly` repository.

#### Step 1: Profile Creation and Configuration

1.  **Create a foundation via the Wizard.** To avoid writing a config from scratch, we'll use a trick. As in Lesson 2, run `_Builder.bat`, select **[W] Profile Wizard**, and create a base profile for your device. Name it, for example, `rax3000m_source_build`.
    *This will provide a ready-made `profiles/rax3000m_source_build.conf` file with the base parameters already filled in.*

2.  **Configure for Source Building.** Open the created file. Our task now is to edit the `Sourcebuilder` section, specifying the correct repository and branch for our target:

```conf
# The target device profile is already specified
TARGET_PROFILE="cmcc_rax3000m-emmc"

# --- Section for Sourcebuilder ---
# Specify the custom repository and branch
SRC_REPO="https://github.com/padavanonly/immortalwrt-mt798x-6.6.git"

# Target and Profile, as in Lesson 2
# Can be found from the browser address bar (append .git at the end)
SRC_REPO="https://github.com/padavanonly/immortalwrt-mt798x-6.6.git"
# The exact branch or tag name can also be found on the repository source page on GitHub.
SRC_BRANCH="openwrt-24.10-6.6"
SRC_TARGET="mediatek"
SRC_SUBTARGET="filogic"

# Leave this variable empty for now
SRC_EXTRA_CONFIG=''

```

#### Step 2: Finding and Preparing the Base Config

Fork authors often provide base "defconfig" files — these are the skeleton of the configuration.

1.  Find such a file in the repository. For our example, it is located at `defconfig/mt7981-ax3000.config` in the repository.
    *Why was this specific file chosen? Based on the processor name from the [rax3000m wiki page](https://openwrt.org/toh/cmcc/rax3000m), which lists the MediaTek MT7981B — hence 7981!*
2.  Download its contents and save it to your PC, for now using a name like `rax3000m_base.config`.

#### Step 3: Initialization and "Config Swapping"

This is the key stage.

1.  In the Builder menu, **switch to `SOURCE BUILDER` mode** (press the `M` key).
2.  Select the **[K] Menuconfig** option for your new profile `rax3000m_source_build`.
3.  The Builder will begin downloading the source code. Wait for the blue `menuconfig` window to appear. Do not change anything in it; simply select `< Exit >` and save the configuration.
4.  Now, navigate to the folder `firmware_output/sourcebuilder/rax3000m_source_build/`. There, you will find a file named `manual_config`. **Completely replace its content** with the content of your `rax3000m_base.config` file from Step 2.

#### Step 4: Expanding the Config and Final Setup

1.  Again, select the **[K] Menuconfig** option in the Builder menu for the same profile.
2.  Now OpenWrt will recognize your "swapped" minimalist config and **automatically calculate and add all necessary dependencies**.
3.  You will see the blue `menuconfig` window again, but this time it will contain a full, expanded configuration. Here, you can make your final adjustments if needed (for example, adding packages via `LuCI -> Applications`). However, at the testing and initial launch stage, it is better not to change anything—just run Menuconfig and exit.
4.  Save the configuration upon exiting to the default `.config` file (`< Save >`, then `< Exit >`).

#### Step 5: Final Build

Now that you have a fully prepared and correct `.config`, select your profile by its number in the main menu to start the actual build.
Be patient — the first compilation will take a long time.

---

**Summary:** You have mastered the most reliable method for building complex and custom firmwares, which ensures all dependencies and source author recommendations are taken into account. This method is significantly more reliable than simply editing `SRC_EXTRA_CONFIG`.

In the next advanced lesson, we will show you how to embed your own files into SourceBuild and how to work with build files and VerMagic.