# file docs\07-troubleshooting-faq.en.md

<p align="center">
  <a href="07-troubleshooting-faq.md"><b>🇷🇺 Русский</b></a> | <b>🇺🇸 English</b>
</p>

---

# Troubleshooting and FAQ

Common issues and limitations when building and using firmware from the builder or third-party builds.

---

## Build limitations

### Sysupgrade/factory not built; only initramfs and other devices' images in output

**Symptoms:** A source build finishes without errors, but the result folder has no `*-squashfs-sysupgrade.bin` or `*-squashfs-factory.bin` for your device. Only `*-initramfs-kernel.bin` and metadata (manifest, buildinfo, sha256sums, etc.) are present. Sometimes images for **other** devices (e.g. 8dev_carambola2) appear — they should not be there when building a single profile.

**Cause (typical for 8 MB flash):** The image (kernel + rootfs) exceeds the device limit. The `mktplinkfw` utility prints something like `[mktplinkfw] *** error: images are too big by 31811 bytes` and does not create the image file. The Makefile marks this error as `(ignored)`, so `make` does not fail and the build continues — sysupgrade/factory simply never get created.

**How to debug:** After the build finishes, stay in the container, go to `/home/build/openwrt` and run:
```bash
make target/linux/install -j1 V=s 2>&1 | tee /tmp/image_build.log
```
In the log, search for `mktplinkfw`, `too big`, `error`. The byte count (“too big by X bytes”) shows how much you need to shrink the image.

**What to do:** Reduce the package set in the profile to fit the flash limit (e.g. for 8 MB: luci → luci-light, wpad-openssl → wpad-basic-mbedtls, drop USB/storage and heavy LuCI apps; install DOH and extra packages after flashing or after extroot). Repeat test builds from source with ccache are fast. Keep the base firmware to the necessary minimum; if using extroot, there is no need to cram everything into the image — install packages via opkg after mounting extroot.

**If the output contains images for other devices (carambola, etc.):** The build is not limited to your profile — check the builder version (current 4.44), that a single profile is selected, and that the config targets a single device. In a correct single-profile build, the folder should contain only that device’s images (initramfs, factory, sysupgrade for it).

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
# checksum:MD5=f3818381f61d1bdb66959335791eb0f5