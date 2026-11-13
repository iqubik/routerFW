# Lesson 9: `custom_files` permission policy (IB / SB)

## Purpose

Windows/NTFS bind mounts often expose files and directories as `0777`. Previously, Image Builder's `cp -a` and Source Builder's `rsync -a` could propagate those modes into SquashFS. `system/overlay_permissions.sh` is the **same policy** for IB and SB; it runs **only on a temporary staged copy** of `custom_files/<profile>` before `make image` or writing to SB `files/`. Host originals are unchanged. An invalid policy stops SB **before** it removes any previously managed file in its persistent workdir.

| Path / purpose in final rootfs | Default mode |
|---|---|
| Ordinary files (including `.sh` outside executable locations) | `0644` |
| Ordinary directories | `0755` |
| `/root` | `0750` |
| `/root/.ssh/`, `/etc/dropbear/`, `/etc/ssl/private/`, `/etc/wireguard/` and their descendant directories | `0700` |
| Private SSH keys, `authorized_keys`, Dropbear host keys, `/etc/shadow`, `/etc/gshadow`, PPP secrets, files below private directories | `0600` |
| Public keys `/root/.ssh/*.pub` | `0644` |
| `/etc/uci-defaults/*`, `/etc/hotplug.d/*` | `0644` (OpenWrt sources these scripts, so an executable bit is not required) |
| `/etc/init.d/*`, `/etc/rc.button/*`, `/etc/rc.local`, programs under `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin` | `0755` |

**No blanket executable-bit inference from `.sh`**: OpenWrt has both executable and shell-sourced scripts. Upstream OpenWrt files and the contents of `.apk`/`.ipk` packages are not recursively chmod'ed.

## Explicit overrides

Create a UTF-8 text file `custom_files/<profile>/.routerfw-permissions` (LF or CRLF) when a different mode is needed:

```text
# MODE /absolute/path/in/router/rootfs
0600 /etc/config/my-private-service
0750 /etc/my-private-service
0755 /opt/my-app/launch.sh
0640 /etc/routerfw/with space.txt
```

Each row targets an **existing, exact path** in `custom_files`. A leading `/` is optional. Modes must have four octal digits with no special bits or world-write; directories must be owner-readable/traversable, and regular files owner-readable. Duplicates, `..`, links, missing paths and malformed entries are fatal, never silently ignored. `.routerfw-permissions` and `hooks.sh` are not shipped into firmware. `0777` is rejected.

* A mode-only change is applied on the next incremental SB run, even when content bytes have not changed.
* Avoid embedding secrets into publicly distributed firmware: `0600` restricts unprivileged runtime access but **does not hide bytes from anyone possessing the firmware image**.
* Symlinks, FIFOs, sockets and device nodes in ordinary `custom_files` are refused; package unusual files properly instead.
* The separately executed `hooks.sh` can create/modify `files/` paths after this normalization step; **hook-generated files are not covered by this policy** and hooks must set appropriate permissions themselves.
* OpenWrt's regular image packaging assigns usual `root:root` ownership; this policy sets permission bits and does not run `chown`.

## Verification

Inspect the actual SquashFS within `sysupgrade.itb`: `/etc/routerfw/overlay-probe.txt` should be `0644`, `/etc/routerfw/` `0755`, and `/etc/uci-defaults/99-permissions.sh` `0644`. Rebuild to affect existing firmware images. Keep the persistent Docker volume when checking SB ON → OFF and v1 → v2.

Offline tests: `python3 -B -m unittest tests.test_overlay_permissions` and `bash tests/test_src_builder_lifecycle.sh`. Both `_packer.sh` and `_packer.bat` include the shared policy module and this documentation in distributed `_unpacker` resources.
# checksum:MD5=5e790572556ccdd3f1003a509a55499d