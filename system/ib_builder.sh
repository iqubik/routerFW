#!/bin/bash
# file: system/ib_builder.sh v2.0
set -e

# Цвета для логов
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
error() { echo -e "${RED}[FATAL] $1${NC}"; exit 1; }

snapshot_runtime() {
python3 -B - "$@" <<'PY_ROUTERFW_SNAPSHOT'
import hashlib, json, os, sys
from pathlib import Path

def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()

def tree_hash(path):
    digest = hashlib.sha256()
    if not path.exists():
        return digest.hexdigest()
    for item in sorted(path.rglob("*"), key=lambda p: p.relative_to(path).as_posix()):
        rel = item.relative_to(path).as_posix()
        if item.is_symlink():
            digest.update(f"L\0{rel}\0{os.readlink(item)}\0".encode())
        elif item.is_file():
            digest.update(f"F\0{rel}\0{sha256(item)}\0".encode())
        elif item.is_dir():
            digest.update(f"D\0{rel}\0".encode())
    return digest.hexdigest()

action, *args = sys.argv[1:]
if action == "capture":
    profile, profile_id, destination, *inputs = args
    snapshot = {"schema": 1, "profile_id": profile_id, "profile_sha256": sha256(profile),
                "inputs": {label: tree_hash(Path(path)) for label, path in
                           (value.split("=", 1) for value in inputs)}}
    target = Path(destination)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(snapshot, indent=2, sort_keys=True) + "\n", encoding="utf-8")
elif action == "finalize":
    capture_file, output, mode, config = args
    output = Path(output)
    snapshot = json.loads(Path(capture_file).read_text(encoding="utf-8"))
    config = Path(config)
    snapshot.update({"mode": mode, "config_sha256": sha256(config) if config.is_file() else None})
    (output / "routerfw-build-snapshot.json").write_text(
        json.dumps(snapshot, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    checksums, upstream = output / "sha256sums", output / ".routerfw-upstream.sha256sums"
    if checksums.is_file() and not upstream.exists():
        checksums.replace(upstream)
    entries = [path for path in output.rglob("*") if path.is_file() and path != checksums]
    checksums.write_text("".join(
        f"{sha256(path)} *{path.relative_to(output).as_posix()}\n"
        for path in sorted(entries, key=lambda item: item.relative_to(output).as_posix())
    ), encoding="utf-8")
else:
    raise SystemExit(f"unknown snapshot action: {action}")
PY_ROUTERFW_SNAPSHOT
}

# Shared policy: never inherit permission bits from Windows/NTFS into rootfs.
[ -f /overlay_permissions.sh ] || error "Shared overlay permissions module not mounted."
# shellcheck source=system/overlay_permissions.sh
source /overlay_permissions.sh

# 1. Проверка профиля
[ -f "/profiles/$CONF_FILE" ] || error "Profile /profiles/$CONF_FILE not found!"

# === 0. ПОВЫШЕНИЕ СТАБИЛЬНОСТИ СЕТИ ===
echo -e "tries = 5\ntimeout = 20\nretry_connrefused = on\nwaitretry = 2" > ~/.wgetrc

# === 1. ПОДГОТОВКА КОНФИГУРАЦИИ ===
log "Normalizing config..."
cat "/profiles/$CONF_FILE" | sed '1s/^\xEF\xBB\xBF//' | tr -d '\r' > /tmp/clean_config.env
unset PKGS IMAGE_PKGS EXTRA_IMAGE_NAME IMAGE_EXTRA_NAME CUSTOM_KEYS CUSTOM_REPOS DISABLED_SERVICES ROOTFS_SIZE KERNEL_SIZE SRC_PACKAGES
source /tmp/clean_config.env

# Обратная совместимость: поддержка старых имён переменных в профилях
PKGS="${IMAGE_PKGS:-${PKGS:-}}"
EXTRA_IMAGE_NAME="${IMAGE_EXTRA_NAME:-$EXTRA_IMAGE_NAME}"

[ -z "$IMAGEBUILDER_URL" ] && error "IMAGEBUILDER_URL is empty! Config parse failed."

# /output теперь монтирует весь firmware_output; путь записи — imagebuilder/$p_id
REL_PATH="${HOST_OUTPUT_DIR#*firmware_output/}"
OUTPUT_BASE="/output/$REL_PATH"

START_TIME=$(date +%s)
TIMESTAMP=$(TZ='UTC-3' date +%d%m%y-%H%M%S)
BUILD_CAPTURE="/tmp/routerfw-build-${CONF_FILE%.conf}-$$.json"
trap 'rm -f -- "$BUILD_CAPTURE"' EXIT
snapshot_runtime capture "/profiles/$CONF_FILE" "${CONF_FILE%.conf}" "$BUILD_CAPTURE" \
    "custom_files=/overlay_files" "custom_packages=/input_packages"

# --- 2. СКАЧИВАНИЕ SDK (БЕЗ ОЖИДАНИЯ, С ПЕРЕЗАПУСКОМ) ---
if [[ "$IMAGEBUILDER_URL" =~ ^https?:// ]]; then
    # Сетевой URL: очищаем от ? (например ?download=), качаем в кэш
    CLEAN_URL=$(echo "$IMAGEBUILDER_URL" | sed 's/[?&].*//')
    ARCHIVE_NAME=$(basename "$CLEAN_URL")
    CACHE_FILE="/cache/$ARCHIVE_NAME"
    TEMP_CACHE_FILE="/cache/$ARCHIVE_NAME.tmp"
    if [ ! -f "$CACHE_FILE" ]; then
        log "SDK not found. Preparing fresh download..."
        [ -f "$TEMP_CACHE_FILE" ] && { log "Removing stale .tmp file..."; rm -f "$TEMP_CACHE_FILE"; }
        log "Downloading $ARCHIVE_NAME..."
        wget --progress=dot:giga --tries=5 --timeout=20 --retry-connrefused -O "$TEMP_CACHE_FILE" "$IMAGEBUILDER_URL"
        mv "$TEMP_CACHE_FILE" "$CACHE_FILE"
    else
        log "Using cached $ARCHIVE_NAME"
    fi
else
    # Локальный путь: firmware_output/... в контейнере = /output/...
    LOCAL_PATH_NORM=$(echo "$IMAGEBUILDER_URL" | tr '\\' '/')
    LOCAL_PATH="/output/${LOCAL_PATH_NORM#firmware_output/}"
    ARCHIVE_NAME=$(basename "$LOCAL_PATH")
    [ -f "$LOCAL_PATH" ] || error "Local imagebuilder file not found: $LOCAL_PATH"
    LOCAL_SHA256=$(sha256sum "$LOCAL_PATH" | awk '{print $1}')
    [ -n "$LOCAL_SHA256" ] || error "Failed to calculate SHA-256 for local imagebuilder: $LOCAL_PATH"
    CACHE_FILE="/cache/local-${LOCAL_SHA256}-${ARCHIVE_NAME}"
    if [ -f "$CACHE_FILE" ]; then
        log "Using cached local imagebuilder: $ARCHIVE_NAME [$LOCAL_SHA256]"
    else
        log "Caching local imagebuilder: $LOCAL_PATH [$LOCAL_SHA256]"
        cp "$LOCAL_PATH" "$CACHE_FILE"
    fi
fi

# Compose recreates containers, but failed/interrupted local runs can still leave
# mutated ImageBuilder state. Always unpack into a clean workspace.
find . -mindepth 1 -maxdepth 1 ! -name 'dl' -exec rm -rf {} +

# Распаковка
log "Extracting SDK..."
# Проверяем расширение по имени файла, а не по ссылке
if [[ "$ARCHIVE_NAME" == *".zst" ]]; then
    # Убираем подавление ошибок! Если архив битый - надо падать.
    tar -I zstd -xf "$CACHE_FILE" --strip-components=1 || error "Failed to extract ZST archive"
else
    tar -xJf "$CACHE_FILE" --strip-components=1 || error "Failed to extract XZ archive"
fi

# Проверка, что распаковка прошла успешно (поддержка opkg и apk)
[ -f "repositories.conf" ] || [ -f "repositories" ] || [ -f "Makefile" ] || error "Extraction failed: Build root not found!"

# Local ImageBuilder archives carry x86-64 host tools from the environment that
# created them. Fail early if this container cannot provide the required glibc.
CURRENT_GLIBC=$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}' || true)
REQUIRED_GLIBC=$(
    find staging_dir/host/bin staging_dir/host/lib staging_dir/host/libexec \
        -type f -print0 2>/dev/null |
    xargs -0 -r grep -aohE 'GLIBC_[0-9]+(\.[0-9]+)+' 2>/dev/null |
    sed 's/^GLIBC_//' |
    sort -V |
    tail -1
)
if [ -n "$CURRENT_GLIBC" ] && [ -n "$REQUIRED_GLIBC" ]; then
    HIGHEST_GLIBC=$(printf '%s\n%s\n' "$CURRENT_GLIBC" "$REQUIRED_GLIBC" | sort -V | tail -1)
    if [ "$HIGHEST_GLIBC" != "$CURRENT_GLIBC" ]; then
        error "ImageBuilder host tools require GLIBC_$REQUIRED_GLIBC, but this container provides GLIBC_$CURRENT_GLIBC. Rebuild/update the modern Image Builder container on Ubuntu 24.04 or newer."
    fi
    log "GLIBC compatibility check passed: container=$CURRENT_GLIBC, required=$REQUIRED_GLIBC"
fi

config_value() {
    local key="$1"
    sed -n "s/^${key}=\"\\(.*\\)\"/\\1/p" .config 2>/dev/null | tail -1
}

version_repo_default() {
    sed -n 's/^VERSION_REPO:=.*,\(https\?:\/\/[^)]*\)).*/\1/p' include/version.mk 2>/dev/null | tail -1
}

# Some locally generated OpenWrt 25.x ImageBuilder archives contain APK
# packages and Makefile support, but omit the repositories file expected by
# apk. Recreate the standard release repository list from embedded metadata.
if [ ! -f "repositories" ] && [ -x "staging_dir/host/bin/apk" ] && ls packages/*.apk 1>/dev/null 2>&1; then
    REPO_BASE="$(config_value CONFIG_VERSION_REPO)"
    [ -n "$REPO_BASE" ] || REPO_BASE="$(version_repo_default)"
    REPO_BOARD="$(config_value CONFIG_TARGET_BOARD)"
    REPO_SUBTARGET="$(config_value CONFIG_TARGET_SUBTARGET)"
    REPO_ARCH="$(config_value CONFIG_TARGET_ARCH_PACKAGES)"

    if [ -n "$REPO_BASE" ] && [ -n "$REPO_BOARD" ] && [ -n "$REPO_SUBTARGET" ] && [ -n "$REPO_ARCH" ]; then
        log "Generating missing APK repositories file from ImageBuilder metadata..."
        {
            echo "${REPO_BASE%/}/targets/$REPO_BOARD/$REPO_SUBTARGET/packages/packages.adb"
            echo "${REPO_BASE%/}/packages/$REPO_ARCH/base/packages.adb"
            sed -n 's/^CONFIG_FEED_\([^=]*\)=y$/\1/p; s/^CONFIG_FEED_\([^=]*\)=m$/# \1/p' .config |
            while IFS= read -r feed; do
                case "$feed" in
                    \#\ *) echo "# ${REPO_BASE%/}/packages/$REPO_ARCH/${feed#\# }/packages.adb" ;;
                    *) echo "${REPO_BASE%/}/packages/$REPO_ARCH/$feed/packages.adb" ;;
                esac
            done
        } > repositories
    else
        warn "APK repositories file is missing and metadata is incomplete; package resolution may fail."
    fi
fi

# Some custom ImageBuilder archives omit opkg arch declarations, which makes
# bundled target packages (even libc) look incompatible.
if [ -f "repositories.conf" ] && ! grep -q '^arch[[:space:]]' repositories.conf; then
    IB_ARCH="${SRC_ARCH:-}"
    if [ -z "$IB_ARCH" ] && [ -f "packages/Packages" ]; then
        IB_ARCH=$(awk '/^Architecture: / && $2 != "all" { print $2; exit }' packages/Packages)
    fi
    if [ -n "$IB_ARCH" ]; then
        tmp_repos=$(mktemp)
        {
            echo "arch all 1"
            echo "arch noarch 1"
            echo "arch $IB_ARCH 10"
            cat repositories.conf
        } > "$tmp_repos"
        mv "$tmp_repos" repositories.conf
    fi
fi
if [ -f "repositories.conf" ] && grep -q '^src[[:space:]]\+imagebuilder[[:space:]]\+file:packages' repositories.conf && [ ! -f "packages/Packages.sig" ]; then
    sed -i '/^option[[:space:]]\+check_signature/d' repositories.conf
fi

# Some custom 24.10 ImageBuilder archives ship libgcc1 as the provider for the
# virtual libgcc dependency, but their Makefile installs libc before libgcc1.
if [ -f "Makefile" ] && ls packages/libgcc1_*.ipk 1>/dev/null 2>&1 && ! grep -q 'libgcc1_\\*.ipk' Makefile; then
    awk '
        /libc_[*][.]ipk/ && !done {
            print "\t$(OPKG) install $(firstword $(wildcard $(LINUX_DIR)/libgcc1_*.ipk $(PACKAGE_DIR)/libgcc1_*.ipk))";
            done=1
        }
        { print }
    ' Makefile > Makefile.routerfw && mv Makefile.routerfw Makefile
fi

# --- 3. ПОДГОТОВКА ОКРУЖЕНИЯ ---
if [ -f /openssl.cnf ]; then
    log "Applying OpenSSL Fix..."
    mkdir -p /builder/shared-workdir/build/staging_dir/host/etc/ssl
    cp /openssl.cnf /builder/shared-workdir/build/staging_dir/host/etc/ssl/openssl.cnf 2>/dev/null || true
fi

if [ -d /input_packages ]; then
    log "Processing input packages..."
    # КРИТИЧНО: Гарантируем наличие папки перед копированием
    mkdir -p packages/
    HAS_CUSTOM_IPK=0

    # Копируем IPK (старый формат)
    if ls /input_packages/*.ipk 1>/dev/null 2>&1; then
        cp /input_packages/*.ipk packages/
        HAS_CUSTOM_IPK=1
        rm -f packages/Packages packages/Packages.gz packages/Packages.manifest packages/Packages.sig 2>/dev/null || true
    fi

    # Local IPK feeds are unsigned. Keep signature checks for normal builds,
    # but allow explicitly supplied local packages to be indexed and installed.
    if [ "$HAS_CUSTOM_IPK" -eq 1 ] && [ -f "repositories.conf" ]; then
        sed -i '/^option[[:space:]]\+check_signature/d' repositories.conf
    fi

    # Обработка APK (новый формат)
    if ls /input_packages/*.apk 1>/dev/null 2>&1; then
        apk_count=$(ls /input_packages/*.apk 2>/dev/null | wc -l)
        log "Found $apk_count APK file(s). Copying to packages/..."
        cp /input_packages/*.apk packages/ 2>/dev/null || true

        # Удаляем старый индекс, чтобы исключить stale-состояние
        rm -f packages/packages.adb

        # Валидация APK (проверяем уже скопированные файлы)
        valid_apk=0
        for apk_file in packages/*.apk; do
            [ -e "$apk_file" ] || continue
            apk_name=$(basename "$apk_file")

            if [ ! -s "$apk_file" ]; then
                warn "Empty APK file: $apk_name (removed from build)"
                rm -f "$apk_file"
            else
                log "  + $apk_name ($(du -h "$apk_file" | cut -f1))"
                valid_apk=$((valid_apk + 1))
            fi
        done

        # Проверяем, что APK читаются host-apk (быстрая диагностика "битого"/несовместимого файла)
        if [ "$valid_apk" -gt 0 ]; then
            APK_BIN=""
            [ -x "./staging_dir/host/bin/apk" ] && APK_BIN="./staging_dir/host/bin/apk"
            if [ -z "$APK_BIN" ] && command -v apk >/dev/null 2>&1; then
                APK_BIN="$(command -v apk)"
            fi

            if [ -n "$APK_BIN" ]; then
                APK_BIN="$(realpath "$APK_BIN" 2>/dev/null || echo "$APK_BIN")"
                log "Validating APK metadata via $APK_BIN..."
                for apk_file in packages/*.apk; do
                    [ -e "$apk_file" ] || continue
                    if ! "$APK_BIN" adbdump "$apk_file" >/dev/null 2>&1; then
                        error "APK metadata parse failed: $(basename "$apk_file"). Incompatible/corrupted APK."
                    fi
                done
            else
                warn "apk binary not found before make image; metadata validation skipped."
            fi
        else
            warn "No valid APK files left after validation."
        fi
    fi
fi
export SOURCE_DATE_EPOCH=$(date +%s)

# === ИЗМЕНЕНИЕ РАЗМЕРА РАЗДЕЛОВ ===
if [ -n "$ROOTFS_SIZE" ]; then
    log "Setting RootFS size to $ROOTFS_SIZE MB..."
    touch .config
    sed -i '/CONFIG_TARGET_ROOTFS_PARTSIZE/d' .config
    echo "CONFIG_TARGET_ROOTFS_PARTSIZE=$ROOTFS_SIZE" >> .config
fi

if [ -n "$KERNEL_SIZE" ]; then
    log "Setting Kernel size to $KERNEL_SIZE MB..."
    touch .config
    sed -i '/CONFIG_TARGET_KERNEL_PARTSIZE/d' .config
    echo "CONFIG_TARGET_KERNEL_PARTSIZE=$KERNEL_SIZE" >> .config
fi

# --- 4. ЗАГРУЗКА КЛЮЧЕЙ И РЕПОЗИТОРИЕВ ---
if [ -n "$CUSTOM_KEYS" ]; then
    log "Downloading custom keys..."
    for key_url in $CUSTOM_KEYS; do
        wget -q --tries=5 --timeout=15 --retry-connrefused "$key_url" -P keys/ || warn "Failed to download key: $key_url"
        key_filename=$(basename "$key_url")
        key_id=${key_filename%.*}
        if [ -f "keys/$key_filename" ] && [ "$key_filename" != "$key_id" ]; then cp "keys/$key_filename" "keys/$key_id"; fi
    done
fi

if [ -n "$CUSTOM_REPOS" ]; then
    log "Adding custom repositories..."
    if [ -f "repositories.conf" ]; then
        # Legacy OPKG (OpenWrt 24.x и старее)
        sed -i '/fantastic_/d' repositories.conf 2>/dev/null || true
        echo "$CUSTOM_REPOS" | sed 's# src/gz#\nsrc/gz#g' | while read -r line; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            echo "${line%/}" >> repositories.conf
        done
    elif [ -f "repositories" ]; then
        # New APK (OpenWrt 25.x и новее)
        echo "$CUSTOM_REPOS" | sed 's# src/gz#\nsrc/gz#g' | while read -r line; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            # Оптимизация: чистый Bash вместо grep/awk
            if [[ "$line" == src/* ]]; then
                read -r _ _ url _ <<< "$line"
                if [ -n "$url" ]; then
                    url="${url%/}"
                    [[ "$url" == */packages.adb ]] || url="$url/packages.adb"
                    echo "$url" >> repositories
                fi
            else
                url="${line%/}"
                [[ "$url" == */packages.adb ]] || url="$url/packages.adb"
                echo "$url" >> repositories
            fi
        done
    fi
fi

if [ -f "repositories" ] && [ -x "staging_dir/host/bin/apk" ]; then
    APK_ARCH="${REPO_ARCH:-$(config_value CONFIG_TARGET_ARCH_PACKAGES)}"
    if [ -n "$APK_ARCH" ]; then
        log "Checking APK package availability..."
        if [ -d "packages" ] && ls packages/*.apk 1>/dev/null 2>&1; then
            if [ ! -f "packages/packages.adb" ] || [ -n "$(find packages -maxdepth 1 -name '*.apk' -newer packages/packages.adb -print -quit 2>/dev/null)" ]; then
                (cd packages && ../staging_dir/host/bin/apk mkndx --allow-untrusted --output packages.adb *.apk) >/dev/null 2>&1 || true
            fi
        fi

        APK_CHECK_ROOT="/tmp/routerfw-apk-check"
        APK_CHECK_CACHE="/tmp/routerfw-apk-cache"
        rm -rf "$APK_CHECK_ROOT" "$APK_CHECK_CACHE"
        mkdir -p "$APK_CHECK_ROOT/tmp" "$APK_CHECK_CACHE"
        APK_CHECK_BIN="$(realpath staging_dir/host/bin/apk)"
        APK_REPOSITORIES="$(realpath repositories)"
        APK_LOCAL_REPO="$(realpath packages/packages.adb 2>/dev/null || true)"
        APK_CHECK_ARGS=(--root "$APK_CHECK_ROOT" --repositories-file "$APK_REPOSITORIES" --allow-untrusted --cache-dir "$APK_CHECK_CACHE")
        [ -n "$APK_LOCAL_REPO" ] && APK_CHECK_ARGS+=(--repository "$APK_LOCAL_REPO")

        if "$APK_CHECK_BIN" "${APK_CHECK_ARGS[@]}" add --arch "$APK_ARCH" --initdb >/dev/null 2>&1; then
            APK_SIM_PKGS=()
            for pkg in $PKGS; do
                case "$pkg" in
                    ""|-*) continue ;;
                esac
                pkg_name="${pkg%%[<>=~]*}"
                [ -n "$pkg_name" ] || continue
                APK_SIM_PKGS+=("$pkg")
            done
            if [ "${#APK_SIM_PKGS[@]}" -gt 0 ] && ! APK_SIM_OUTPUT=$("$APK_CHECK_BIN" "${APK_CHECK_ARGS[@]}" add --arch "$APK_ARCH" --simulate --no-scripts "${APK_SIM_PKGS[@]}" 2>&1); then
                MISSING_PKGS=$(printf '%s\n' "$APK_SIM_OUTPUT" | sed -n 's/^[[:space:]]*\([^[:space:]]\+\) (no such package):.*/\1/p' | xargs)
                [ -n "$MISSING_PKGS" ] || MISSING_PKGS="$APK_SIM_OUTPUT"
                error "Requested APK packages are not available for $APK_ARCH: $MISSING_PKGS. Add compatible CUSTOM_REPOS/CUSTOM_KEYS or remove these packages from IMAGE_PKGS."
            fi
        else
            warn "APK availability preflight failed to initialize; continuing with make image."
        fi
    fi
fi

# === ПОДГОТОВКА OVERLAY ===
log "Preparing custom files..."
mkdir -p /tmp/clean_overlay || error "Cannot create overlay staging directory."
if [ -d /overlay_files ]; then
    cp -R -- /overlay_files/. /tmp/clean_overlay/ || error "Cannot stage custom overlay."
fi
rm -f -- /tmp/clean_overlay/hooks.sh /tmp/clean_overlay/README.md
routerfw_normalize_overlay_permissions /tmp/clean_overlay || error "Invalid custom overlay permissions."

# --- 6. ЗАПУСК СБОРКИ (С ПОВТОРОМ) ---
log "Starting make image for $TARGET_PROFILE..."
# Жестко отключаем signature-check в .config (для локальных неподписанных/чужих APK)
touch .config
sed -i '/^CONFIG_SIGNATURE_CHECK=/d;/^# CONFIG_SIGNATURE_CHECK is not set/d' .config
echo '# CONFIG_SIGNATURE_CHECK is not set' >> .config

# Используем очищенный overlay (/tmp/clean_overlay), а не исходный
# CONFIG_SIGNATURE_CHECK="" отключает проверку подписей локальных (и сетевых) APK
MAKE_ARGS=(
    "PROFILE=$TARGET_PROFILE"
    "FILES=/tmp/clean_overlay"
    "PACKAGES=$PKGS"
    "CONFIG_SIGNATURE_CHECK="
)
[ -n "$EXTRA_IMAGE_NAME" ] && MAKE_ARGS+=("EXTRA_IMAGE_NAME=$EXTRA_IMAGE_NAME")
[ -n "$DISABLED_SERVICES" ] && MAKE_ARGS+=("DISABLED_SERVICES=$DISABLED_SERVICES")

SUCCESS=0
set -o pipefail # Гарантирует, что ошибка от make не "проглотится" командой sed
for i in {1..2}; do
    log "Attempt $i of 2..."
    if make image "${MAKE_ARGS[@]}" 2>&1 | sed -u "s|WARNING: opening .*/packages\.adb: No such file or directory|$(printf '%b' "$GREEN")[INFO]$(printf '%b' "$NC") Generating local packages.adb index...|"; then
        SUCCESS=1
        break
    else 
        warn "Build failed! Retrying in 5s..."
        sleep 5
    fi
done
set +o pipefail

[ $SUCCESS -eq 0 ] && error "Build failed after 2 attempts."

# --- 7. СОХРАНЕНИЕ РЕЗУЛЬТАТОВ ---
log "Saving artifacts..."
TARGET_DIR="$OUTPUT_BASE/$TIMESTAMP"
mkdir -p "$TARGET_DIR"
find bin/targets -type f -not -path "*/packages/*" -exec cp {} "$TARGET_DIR/" \;
snapshot_runtime finalize "$BUILD_CAPTURE" "$TARGET_DIR" imagebuilder "$TARGET_DIR/config.buildinfo"

# Метаданные ядра из profiles.json (версия и vermagic)
META_FILE="$TARGET_DIR/profiles.json"
if [ -f "$META_FILE" ]; then
    meta_line=$(tr -d '\n' < "$META_FILE")
    kernel_ver=$(echo "$meta_line" | sed -n 's/.*"linux_kernel":[^}]*"version":"\([^"]*\)".*/\1/p')
    kernel_vm=$(echo "$meta_line" | sed -n 's/.*"linux_kernel":[^}]*"vermagic":"\([^"]*\)".*/\1/p')
    if [ -n "$kernel_ver" ] || [ -n "$kernel_vm" ]; then
        echo ""
        printf '%b kernel %s  vermagic %s\n' "${CYAN}[LINUX KERNEL]${NC}" "${kernel_ver:-?}" "${kernel_vm:-?}"
    fi
fi

# Список: папка (метка времени подсвечена) + имена файлов с размерами
base_win="${REL_PATH//\//\\}"
echo ""
printf '%b  firmware_output\\%s\\%b\\\n' "${CYAN}[FIRMWARE FOLDER]${NC}" "${base_win}" "${CYAN}${TIMESTAMP}${NC}"
printf '%b\n' "${CYAN}[FILES]${NC}"
for f in "$TARGET_DIR"/*; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    bytes=$(stat -c%s "$f" 2>/dev/null); bytes=${bytes:-0}
    mb=$(awk "BEGIN {printf \"%.1f\", $bytes/1048576}")
    if [ "$bytes" -ge 31457280 ]; then col="$RED"      # >= 30 MB
    elif [ "$bytes" -ge 10485760 ]; then col="$YELLOW" # >= 10 MB
    else col="$GREEN"; fi
    printf '%s  %b\n' "$name" "${col}[${mb} MB]${NC}"
done

ELAPSED=$(($(date +%s) - START_TIME))
echo -e "\n============================================================"
echo -e "=== Build completed in ${ELAPSED}s."
echo -e "=== Artifacts: firmware_output/$REL_PATH/$TIMESTAMP"
echo -e "============================================================\n"
# checksum:MD5=08ba05dc54724fc903184892119a1d4f