# file docs\07-troubleshooting-faq.en.md

<p align="center">
  <a href="07-troubleshooting-faq.md"><b>🇷🇺 Русский</b></a> | <b>🇺🇸 English</b>
</p>

---

# Troubleshooting and FAQ

Common issues and limitations when building and using firmware from the builder or third-party builds.

---

## Build limitations

### Source Builder: storage failure vs compilation error

**Symptoms:** after `make ... Error 1`, the log includes `Read-only file system`, `No space left on device`, `Input/output error`, failures to write to `/tmp`, or Git errors. `Error 1` alone does **not** establish a storage failure or an invalid profile.

**Source Builder safeguard:** before `make download` and compilation, and after failed `make` attempts, the builder tests whether it can create and remove a temporary file in the source worktree, the separate `dl` volume, `/ccache`, `/tmp`, and `/output`. An observed failure produces `[BUILD INFRA]` with `STORAGE_READONLY`, `STORAGE_NO_SPACE`, `STORAGE_IO_ERROR`, `PERMISSION_ERROR`, `STORAGE_PATH_MISSING`, or `STORAGE_WRITE_ERROR`, plus `df` details; it **does not** start a futile retry. If storage is healthy, the normal `make -j1 V=s` fallback remains enabled. These probes do not replace the initial OpenWrt log: transient hardware or filesystem failures might not recur during the probe.

**First steps:** preserve the full log, including several hundred lines **before** the first failure. On the host, check `docker system df -v` (or Podman's equivalents), physical disk free space, and system messages for `I/O error`, `EXT4-fs error`, or `Remounting filesystem read-only`. For Docker Desktop/WSL2 also check the VHDX storage. Do not run `docker compose down -v`, global `prune`, or Docker Desktop factory reset before collecting evidence: persistent volume data could be lost. Free disk space alone cannot rule out filesystem damage.

### Sysupgrade/factory not built; only initramfs and other devices' images in output

**Symptoms:** A source build finishes without errors, but the result folder has no `*-squashfs-sysupgrade.bin` or `*-squashfs-factory.bin` for your device. Only `*-initramfs-kernel.bin` and metadata (manifest, buildinfo, sha256sums, etc.) are present. Sometimes images for **other** devices (e.g. 8dev_carambola2) appear — they should not be there when building a single profile.

**Cause (typical for 8 MB flash):** The image (kernel + rootfs) exceeds the device limit. The `mktplinkfw` utility prints something like `[mktplinkfw] *** error: images are too big by 31811 bytes` and does not create the image file. The Makefile marks this error as `(ignored)`, so `make` does not fail and the build continues — sysupgrade/factory simply never get created.

**How to debug:** After the build finishes, stay in the container, go to `/home/build/openwrt` and run:
```bash
make target/linux/install -j1 V=s 2>&1 | tee /tmp/image_build.log
```
In the log, search for `mktplinkfw`, `too big`, `error`. The byte count (“too big by X bytes”) shows how much you need to shrink the image.

**What to do:** Reduce the package set in the profile to fit the flash limit (e.g. for 8 MB: luci → luci-light, wpad-openssl → wpad-basic-mbedtls, drop USB/storage and heavy LuCI apps; install DOH and extra packages after flashing or after extroot). Repeat test builds from source with ccache are fast. Keep the base firmware to the necessary minimum; if using extroot, there is no need to cram everything into the image — install packages via opkg after mounting extroot.

**If the output contains images for other devices (carambola, etc.):** The build is not limited to your profile — check the builder version (the current version is recorded in `system/version.env`; at the time of this guide update it is 4.71), that a single profile is selected, and that the config targets a single device. In a correct single-profile build, the folder should contain only that device’s images (initramfs, factory, sysupgrade for it).

---

### Zapret / nfqws does not work on custom firmware

Some custom firmwares (including builds with non-standard kernel or packages) are not compatible with **zapret** (nfqws): the package and iptables modules for nfqueue may be missing or incompatible with that build. As a result, zapret-based blocking does not work.

**What to do:** If you need zapret/nfqws, use vanilla OpenWrt or build firmware in the builder with the required packages and kernel configuration that supports nfqws. Check that the image includes the correct iptables and nfqueue-related packages and versions.

---

## Device tips

### RAX3000M eMMC: faster Wi‑Fi boot (~30 s)

On some builds (e.g. Padavanonly), Wi‑Fi readiness can be improved: if you set the **Wi‑Fi channel manually** (not “auto”), the driver starts once at boot without scanning DFS channels. Boot time may drop from ~50 to ~30 seconds. Optional, for when you want faster router startup.

---

## See also

*   **`/tmp_patches`: Permission denied** when applying patches — [Lesson 5, FAQ](05-patch-sys.en.md).
*   Choosing “ready-made builds vs builder” — [Lesson 1](01-introduction.en.md).
*   RAX3000M eMMC installation and overlay/U-Boot issues — [Lesson 6](06-rax3000m-emmc-flash.en.md).

Back to [lessons index](index.en.md).
# checksum:MD5=c1ed061a75914803fd015fa64daf3fe1