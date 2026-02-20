# file docs\06-rax3000m-emmc-flash.en.md

<p align="center">
  <a href="06-rax3000m-emmc-flash.md"><b>🇷🇺 Русский</b></a> | <b>🇺🇸 English</b>
</p>

---

# Lesson 6: Flashing RAX3000M eMMC (Manual Partitioning)

**Goal:** Step-by-step installation of firmware (including Padavanonly) on the RAX3000M eMMC variant when standard sysupgrade is not possible — via correct GPT layout, bootenv setup, and partition writing over SSH.

> **WARNING:** All eMMC operations (the `dd` command) are potentially dangerous. One wrong digit can brick the device. Make backups and have UART access if you attempt manual installation.

---

## When This Is Needed

*   The device does not yet have a custom GPT layout (e.g. still on vanilla OpenWrt or Keenetic), and sysupgrade refuses to install the image.
*   You are switching from another firmware (OpenWrt / ImmortalWrt / Keenetic) to a Padavanonly or other build that requires its own partition layout.

**Keenetic → Padavanonly:** First install vanilla OpenWrt using the official instructions, then follow the steps below for eMMC installation.

---

## Limitations and Risks

*   **eMMC:** Writing goes directly to non-volatile storage. Wrong offset or partition can damage the device.
*   **`dd`:** Always double-check the device (`lsblk`), file names, and `seek`/`count` values.
*   **UART:** For first-time manual installs, U-Boot console access is recommended to restore bootenv if something goes wrong.
*   **Backups:** If possible, save a full eMMC image or at least the `factory` partition (Wi‑Fi calibration).

---

## Required Files

Prepare and upload to `/tmp` on the router (e.g. via WinSCP):

*   **GPT:** Partition table — standard or with swap (2 GB). Files can be taken from the 4pda discussion or generated with [bl-mt798x-dhcpd](https://github.com/Yuzhii0718/bl-mt798x-dhcpd). The commands below use the swap variant: file `gpt-rax3000m-emmc-swap.bin`; for the non-swap layout the filename differs (e.g. `gpt-rax3000m-emmc.bin`); the `seek` values in the dd commands stay the same.
*   **Bootloader (FIP):** `u-boot.fip` — from your build or the [bl-mt798x-dhcpd](https://github.com/Yuzhii0718/bl-mt798x-dhcpd) repo.
*   **Kernel and rootfs:** `kernel.bin` and `rootfs.bin` — extract from the sysupgrade image using an archiver (7z, etc.).

Verify that eMMC is detected as `mmcblk0`:

```bash
lsblk
```

---

## Step 0: Bootenv (U-Boot) Setup

Without correct `bootargs` and `bootcmd`, the router will not boot the new firmware.

### Install tools

```bash
opkg update
opkg install uboot-envtools
```

### fw_env configuration

Tell the utility where U-Boot environment is stored:

```bash
echo "/dev/mmcblk0p1 0x0 0x80000" > /etc/fw_env.config
```

Check:

```bash
fw_printenv
```

If variables are printed, proceed to writing.

### Set boot variables

```bash
fw_setenv bootargs "console=ttyS0,115200 root=/dev/mmcblk0p5 rootwait"
fw_setenv bootcmd 'mmc dev 0; gpt setenv mmc 0 kernel; mmc read ${loadaddr} ${gpt_part_addr} ${gpt_part_size}; bootm ${loadaddr}'
```

Verify:

```bash
fw_printenv bootargs
fw_printenv bootcmd
```

Output should show the correct strings (including `${loadaddr}`), with no empty fields.

---

## Step 1: Writing Data

File names and `seek` values must match your GPT and the pinned instructions. Below are typical values for RAX3000M eMMC.

**Write partition table (GPT):**

```bash
dd if=/tmp/gpt-rax3000m-emmc-swap.bin of=/dev/mmcblk0 bs=512 count=34 conv=notrunc
```

**Write bootloader (U-Boot / FIP):**

```bash
dd if=/tmp/u-boot.fip of=/dev/mmcblk0 bs=512 seek=13312 conv=notrunc
```

**Write kernel:**

```bash
dd if=/tmp/kernel.bin of=/dev/mmcblk0 bs=512 seek=21504 conv=notrunc
```

**Write rootfs:**

```bash
dd if=/tmp/rootfs.bin of=/dev/mmcblk0 bs=512 seek=152576 conv=notrunc
```

---

## Step 2: Finalization

Sync and reboot:

```bash
sync
```

Wait a few seconds. If you use a layout with swap:

```bash
mkswap /dev/mmcblk0p7
```

Then:

```bash
reboot
```

First boot may take longer (partition initialization). After a successful boot, it is recommended to install the actual sysupgrade from the full firmware archive (correct vermagic and image set).

---

## Troubleshooting

### Settings do not persist (overlay not mounted)

If settings reset on every reboot, the overlay partition (`/dev/mmcblk0p6`) filesystem size may not match the new GPT. The system will not mount a “broken” partition.

**“Sabotage method”** (when Failsafe is not available): wipe the partition header so that on next boot the system treats it as empty and reformats it.

Over SSH:

```bash
dd if=/dev/zero of=/dev/mmcblk0p6 bs=4096 count=100 conv=notrunc
reboot -f
```

After boot, overlay will be recreated. If you use GPT with swap, configure swap again:

```bash
mkswap /dev/mmcblk0p7
uci set fstab.@swap[-1]=swap
uci set fstab.@swap[-1].device='/dev/mmcblk0p7'
uci set fstab.@swap[-1].enabled='1'
uci commit fstab
/etc/init.d/fstab boot
```

### Router does not boot, U-Boot console available (UART)

If boot is “lost”, set parameters manually in U-Boot:

```
setenv bootargs "console=ttyS0,115200 root=/dev/mmcblk0p5 rootwait"
setenv bootcmd "mmc dev 0; gpt setenv mmc 0 kernel; mmc read ${loadaddr} ${gpt_part_addr} ${gpt_part_size}; bootm ${loadaddr}"
saveenv
reset
```

### Useful commands

**Extract `factory` partition (calibration) from a full backup:**

```bash
zcat full_backup.img.gz | dd of=factory.bin bs=512 skip=$((0x2400)) count=$((0x1000)) status=progress
```

**Compare file and partition hash (e.g. factory):**

```bash
sha256sum /tmp/factory.bin
dd if=/dev/mmcblk0p2 bs=2M count=1 | sha256sum
```

---

## See also

*   **GPT generator:** [bl-mt798x-dhcpd](https://github.com/Yuzhii0718/bl-mt798x-dhcpd) — for custom layout (including swap).
*   **Ready-made images and builds:** see the 4pda discussion and [Releases](https://github.com/iqubik/routerFW/releases). For customization use [RouterFW Builder](https://github.com/iqubik/routerFW) and [Lesson 3](03-source-build.en.md).

Back to [lessons index](index.en.md).
