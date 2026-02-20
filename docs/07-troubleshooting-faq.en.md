# file docs\07-troubleshooting-faq.en.md

<p align="center">
  <a href="07-troubleshooting-faq.md"><b>🇷🇺 Русский</b></a> | <b>🇺🇸 English</b>
</p>

---

# Troubleshooting and FAQ

Common issues and limitations when building and using firmware from the builder or third-party builds.

---

## Build limitations

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
