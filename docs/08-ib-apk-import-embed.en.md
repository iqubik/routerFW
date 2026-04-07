# file docs\08-ib-apk-import-embed.en.md

<p align="center">
  <a href="08-ib-apk-import-embed.md"><b>🇷🇺 Русский</b></a> | <b>🇺🇸 English</b>
</p>

---

# Lesson 8: Embedding APK/IPK Packages in Image Builder

**Goal:** Learn how to add custom packages to Image Builder (IB) mode — from simple copying to automatic validation and filename correction.

> **Who needs this:** if you want to include a third-party `.apk`/`.ipk` (LuCI theme, plugin, driver) in your firmware without building from source.

---

## 1. Two Builder Modes and Where Packages Live

| Mode | Packages folder | What the builder does |
|------|----------------|----------------------|
| **Image Builder (IB)** | `custom_packages/` | Copies `.apk` directly into the IB container — installed as pre-built binaries |
| **Source Builder (SB)** | `src_packages/` | Extracts metadata, generates a Makefile, and builds from source |

**This lesson focuses on Image Builder mode** — the fastest way to get a firmware with additional packages.

---

## 2. Basic Method: "Drop and Build"

The simplest approach is to copy `.apk` files into the `custom_packages/` folder:

```
custom_packages/
└── <PROFILE_ID>/
    ├── luci-app-samba4.apk
    ├── luci-theme-argon.apk
    └── my-custom-package.apk
```

> **Where to find PROFILE_ID?** It's your profile name without `.conf`. For example, if the profile is `giga_24105_main_full.conf` — the folder is `custom_packages/giga_24105_main_full/`.

After running `_Builder.bat` (or `./_Builder.sh`), packages are automatically picked up by the Image Builder container and installed into the final firmware.

**But that's where problems start...**

---

## 3. Real-World Pain: Why Packages Don't Install

### 3.1. Problem #1: Name Mismatch (the `luci-i18n-podkop-ru` bug)

**Scenario (from issue #44):** A user downloaded `luci-i18n-podkop-ru-0.260124.35205.apk`, but the actual version inside the package is `0.7.14-r1`. Image Builder compares the filename against internal metadata and **refuses to install** a package with a mismatched name.

**What happens:**
```
Installed: luci-i18n-podkop-ru = 0.7.14-r1
Filename:  luci-i18n-podkop-ru-0.260124.35205.apk  ← MISMATCH
Result:    ERROR — unable to satisfy dependencies
```

**Solution:** Rename the file to match the internal version:
```
luci-i18n-podkop-ru-0.260124.35205.apk  →  luci-i18n-podkop-ru-0.7.14-r1.apk
```

Previously this had to be done manually by extracting the version via `unzip -p ... .PKGINFO` or guessing. Now **APK Scanner** does it for you.

---

### 3.2. Problem #2: `noarch` Architecture Rejected

**Scenario (from issue #44):** A user with a `radxa_rock_5t` device (arch `aarch64_generic`) tried to import packages with architecture `noarch`. The builder incorrectly flagged them as incompatible and rejected them.

**What `noarch` and `all` mean:** These are **universal** architectures — packages without machine code (LuCI scripts, Lua files, configs). They work on **any** device.

**Solution (v4.60+):** The builder now passes `noarch` and `all` as universal architectures without errors.

---

## 4. APK Scanner: Automatic Validation and Correction

Starting with **v4.60**, the builder includes an **APK Scanner** — a utility that checks and fixes your `.apk` files before the build.

### What It Does

1. **Extracts metadata** via Docker:
   ```bash
   docker run --rm alpine:latest apk adbdump -- /package.apk
   ```
   This reads `.PKGINFO` inside the APK without unzip — the only reliable way to get the actual version and architecture.

2. **Compares the filename** against internal metadata (`name-version-release.arch.apk`).

3. **Validates the package architecture** against the profile's target architecture.

4. **Offers to rename** if the name doesn't match (default: yes).

### When It Runs

- **Automatically:** before `docker compose up` in IB mode, if `.apk` files are present in `custom_packages/`.
- **Manually:** via the **`[S] APK Scanner`** button in the builder's main menu.

### Example Output

```
==========================================================
  APK SCANNER v1.0 [aarch64_generic] [EN]
==========================================================
Scanning APKs in... custom_packages/radxa_rock_5t_25122_ow_full

----------------------------------------------------------
PACKAGE: luci-i18n-podkop-ru-0.260124.35205.apk
  ⚠ NAME MISMATCH
  Filename   : luci-i18n-podkop-ru-0.260124.35205.apk
  Internal   : luci-i18n-podkop-ru-0.7.14-r1
  Rename? [Y/n]: Y
  ✓ Renamed to luci-i18n-podkop-ru-0.7.14-r1.apk
----------------------------------------------------------

----------------------------------------------------------
PACKAGE: luci-theme-argon-2.4.3-r20250722.apk
  ✓ Name matches
  Architecture: noarch (Universal) — OK
----------------------------------------------------------

==========================================================
  DONE: 7 scanned, 1 renamed, 0 warnings
==========================================================
```

### Scanner Language

The scanner uses the language specified in your profile (`SYS_LANG=RU` or `SYS_LANG=EN`). In manual mode, the language is detected automatically based on builder settings.

---

## 5. Step-by-Step: Adding Packages to IB

### Step 1: Create the Profile Folder

```bash
mkdir -p custom_packages/my_profile
```

### Step 2: Copy APK Files

Place all the `.apk` files you need into this folder. Filenames don't matter — the scanner will fix them.

### Step 3: Run the Builder

```bash
_Builder.bat     # Windows
./_Builder.sh    # Linux
```

Select your profile and press **`B`** (Build). The scanner will automatically launch before the build starts.

### Step 4 (Optional): Validate Manually

If you want to validate packages without building — press **`S`** in the main menu.

---

## 6. Frequently Asked Questions (FAQ)

**Q: Is renaming files mandatory?**  
Yes, Image Builder compares the filename against internal metadata. The scanner does this for you automatically.

**Q: What if the scanner can't read metadata?**  
A `Parse Fail` error means `apk adbdump` couldn't read `.PKGINFO`. Make sure the file is a valid APK (not a renamed `.ipk` or `.deb`). The `alpine:latest` Docker image must be available.

**Q: Is `noarch` really safe?**  
Yes. `noarch`/`all` means the package contains no machine code — it's scripts, configs, LuCI interfaces. They are compatible with any architecture.

**Q: Can I disable the auto-scanner?**  
The auto-scanner only runs in IB mode and only when `.apk` files are present. It doesn't slow down the build — validation takes 2-5 seconds per package.

**Q: Scanner says "Arch MISMATCH" for a package with my architecture**  
This is a **warning**, not an error. The package will be checked and added if you confirm. The scanner simply informs you that the package architecture differs from the target (e.g. package is `x86_64`, profile is `aarch64_generic`).

**Q: Where is the `alpine:latest` image stored, can I delete it?**  
`alpine:latest` is a service image used for scanning. **Do not delete** it — it's required for the scanner to work. It's only ~7 MB.

---

## 7. Under the Hood: How the Scanner Works

```
┌──────────────┐     docker run       ┌──────────────────┐
│  custom_     │  alpine:latest       │  apk adbdump     │
│  packages/   │ ──────────────────►  │  (reads .PKGINFO)│
│  *.apk       │                      │  name, version,  │
└──────────────┘                      │  release, arch   │
                                      └────────┬─────────┘
                                               │
                                        returns JSON
                                               │
                                               ▼
┌──────────────────────────────────────────────────────┐
│  COMPARISON                                          │
│  filename_name == metadata_name ✓                    │
│  filename_version == metadata_version ✓              │
│  filename_arch  == profile_arch   ✓ (or noarch)      │
│                                                      │
│  If mismatch → prompt to rename                     │
│  If arch ≠ profile and ≠ noarch → warning            │
│  exit 0 = all good, exit 1 = issues found            │
└──────────────────────────────────────────────────────┘
```

---

## See Also

*   **Importing packages in Source Builder** — [Lesson 4](04-adv-source-build.en.md).
*   **Source Code Patching System** — [Lesson 5](05-patch-sys.en.md).
*   **Building from Source: Maximum Control** — [Lesson 3](03-source-build.en.md).
*   **Troubleshooting and FAQ** — [Lesson 7](07-troubleshooting-faq.en.md).

Back to [lessons index](index.en.md).
