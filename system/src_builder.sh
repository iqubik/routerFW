#!/bin/bash
# file: system/src_builder.sh v2.5
set -e

# 1. Исправление прав (выполняется под root)
echo '[INIT] Checking volume permissions...'
#  OPTIMIZED PERMISSION FIX
if [ ! -d "/home/build/openwrt/.git" ] || [ "$(stat -c %U /ccache)" != "build" ]; then
    echo '[INIT] Setting volume permissions (this might take a while on the first run)...'
    chown -R build:build /home/build/openwrt /ccache 2>/dev/null || true
else
    echo '[INIT] Volume permissions appear correct. Skipping slow chown.'
fi

# 2. Основная логика от пользователя build
sudo -E -u build bash << 'EOF'
set -e
export HOME=/home/build
[ -f /overlay_permissions.sh ] || { echo '[PERMISSIONS ERROR] Shared policy module not mounted.' >&2; exit 1; }
# shellcheck source=system/overlay_permissions.sh
source /overlay_permissions.sh
PROFILE_ID=$(basename "$CONF_FILE" .conf)

# FIX: Разрешаем Git работать с папкой, даже если owner UID отличается (актуально для Docker)
git config --global --add safe.directory '*'

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 0. Подготовка конфига
[ -f "/profiles/$CONF_FILE" ] || { echo "FATAL: Profile /profiles/$CONF_FILE not found!"; exit 1; }
cat "/profiles/$CONF_FILE" | sed '1s/^\xEF\xBB\xBF//' | tr -d '\r' > /tmp/clean_config.env
source /tmp/clean_config.env

#  BUILD CACHING CONFIGURATION
echo "[CACHE] Applying build cache optimizations (Rust wrapper, 20G size limit)..."
export RUSTC_WRAPPER="ccache"
export CCACHE_MAXSIZE="20G"
export CCACHE_COMPRESS="true"

export SRC_REPO SRC_BRANCH SRC_TARGET SRC_SUBTARGET SRC_DEVICE PROFILE_NAME SRC_PACKAGES

echo "=================================================="
echo "   OpenWrt SOURCE Builder for $PROFILE_NAME"
echo "=================================================="

START_TIME=$(date +%s)
TIMESTAMP=$(TZ='UTC-3' date +%d%m%y-%H%M%S)

# 1. GIT / FEEDS
# BEGIN SOURCE GIT AND FEEDS HELPERS (isolated regression tests extract this block)
# Сохраняем persistent workdir, но не допускаем смешивания содержимого разных upstream.
source_sync_git() {
    local old_url='' target_commit=''
    if [[ -z "${SRC_REPO:-}" || -z "${SRC_BRANCH:-}" ]]; then
        echo '[SOURCE ERROR] SRC_REPO and SRC_BRANCH must be set.' >&2
        return 1
    fi
    if ! git check-ref-format --branch "$SRC_BRANCH" >/dev/null 2>&1; then
        echo '[SOURCE ERROR] SRC_BRANCH must be a valid branch/tag-style name.' >&2
        return 1
    fi
    if [[ -e .git && ! -d .git ]]; then
        echo '[SOURCE SAFETY] Unexpected .git file; refusing to overwrite an existing worktree.' >&2
        return 1
    fi
    if [[ ! -d .git ]]; then
        # The separately mounted download cache (dl/) exists even in a fresh workdir.
        # All OTHER non-Git data must be protected against accidental checkout/overwrite.
        if [[ -n "$(find . -mindepth 1 -maxdepth 1 ! -name dl -print -quit)" ]]; then
            echo '[SOURCE SAFETY] Nonempty workdir without .git (beyond dl cache); refusing unsafe initialization.' >&2
            return 1
        fi
        # Preserve the existing Git compatibility settings for the first initialization.
        git config --global init.defaultBranch master
        git config --global http.postBuffer 524288000
        git config --global http.version HTTP/1.1
        git init || return 1
        git remote add origin "$SRC_REPO" || return 1
    else
        # An unborn Git directory must not be treated as an empty checkout if it
        # contains unrelated files. dl/ is an independent, persistent mount.
        if ! git rev-parse --verify HEAD >/dev/null 2>&1 &&
           [[ -n "$(find . -mindepth 1 -maxdepth 1 ! -name .git ! -name dl -print -quit)" ]]; then
            echo '[SOURCE SAFETY] Unborn Git workdir contains unknown files; refusing checkout.' >&2
            return 1
        fi
        if old_url=$(git remote get-url origin 2>/dev/null); then
            if [[ "$old_url" != "$SRC_REPO" ]]; then
                if git rev-parse --verify HEAD >/dev/null 2>&1; then
                    echo '[SOURCE SAFETY] SRC_REPO differs from the persistent workdir origin.' >&2
                    echo '[SOURCE SAFETY] To avoid mixing build trees, clean only this profile src-workdir via Cleanup Wizard, then rebuild. No data was deleted.' >&2
                    return 1
                fi
                # Only an unpopulated repository may safely acquire a new origin.
                git remote set-url origin "$SRC_REPO" || return 1
            fi
        else
            if git rev-parse --verify HEAD >/dev/null 2>&1; then
                echo '[SOURCE SAFETY] Existing Git workdir has no origin; refusing to guess upstream.' >&2
                return 1
            fi
            git remote add origin "$SRC_REPO" || return 1
        fi
    fi

    echo '[GIT] Fetching selected branch/tag from configured origin...'
    git fetch origin "$SRC_BRANCH" || return 1
    target_commit=$(git rev-parse --verify 'FETCH_HEAD^{commit}') || return 1
    git checkout --detach -f "$target_commit" || return 1
    git reset --hard "$target_commit" || return 1
    if [[ "$(git rev-parse --verify HEAD)" != "$target_commit" ]]; then
        echo '[SOURCE ERROR] HEAD does not match selected FETCH_HEAD commit.' >&2
        return 1
    fi
    echo "[GIT] Verified selected commit: $target_commit"
    SOURCE_COMMIT="$target_commit"
}

source_sync_feeds() {
    local state_dir="${ROUTERFW_FEEDS_STATE_DIR:-/ccache}" state_file stamp_file
    local config_file='' feeds_config_hash='' fingerprint='' now last_version last_fingerprint last_update
    local age_seconds max_age_hours="${SRC_FEEDS_MAX_AGE_HOURS:-24}" refresh_reason=''
    state_file="$state_dir/.routerfw_feeds_state_v2"
    if [[ ! "$max_age_hours" =~ ^[0-9]{1,5}$ ]]; then
        echo '[FEEDS ERROR] SRC_FEEDS_MAX_AGE_HOURS must be a nonnegative integer.' >&2
        return 1
    fi
    # Convert base-10 even when the profile uses a leading zero (bash would use octal).
    max_age_hours=$((10#$max_age_hours))
    if (( max_age_hours > 8760 )); then
        echo '[FEEDS ERROR] SRC_FEEDS_MAX_AGE_HOURS must be at most 8760.' >&2
        return 1
    fi
    if [[ -f feeds.conf ]]; then
        config_file=feeds.conf
    elif [[ -f feeds.conf.default ]]; then
        config_file=feeds.conf.default
    else
        echo '[FEEDS ERROR] Neither feeds.conf nor feeds.conf.default exists.' >&2
        return 1
    fi
    feeds_config_hash=$(sha256sum -- "$config_file" | awk '{print $1}') || return 1
    fingerprint=$(printf '%s\0' "$SRC_REPO" "$SRC_BRANCH" "$SOURCE_COMMIT" "$feeds_config_hash" | sha256sum | awk '{print $1}') || return 1
    now=$(date +%s) || return 1
    if [[ ! -d feeds || -z "$(find feeds -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        refresh_reason='feeds directory absent/empty'
    elif [[ ! -f "$state_file" ]]; then
        refresh_reason='no validated feed state'
    else
        IFS=' ' read -r last_version last_fingerprint last_update < "$state_file" || true
        if [[ "$last_version" != v2 || "$last_fingerprint" != "$fingerprint" ]]; then
            refresh_reason='repository/branch/commit/feed configuration changed'
        elif [[ ! "$last_update" =~ ^[0-9]{1,12}$ ]]; then
            refresh_reason='invalid feed state timestamp'
        else
            age_seconds=$((now - 10#$last_update))
            if (( age_seconds < 0 || age_seconds >= max_age_hours * 3600 )); then
                refresh_reason='feed refresh interval expired'
            fi
        fi
    fi

    if [[ -z "$refresh_reason" ]]; then
        echo "[FEEDS] Cached feeds still valid (max age: ${max_age_hours}h); skipping update/install."
        return 0
    fi
    echo "[FEEDS] Refresh required: $refresh_reason."
    # Invalidate before running: failed install must not leave a 'valid' cache marker.
    rm -f -- "$state_file" || return 1
    ./scripts/feeds update -a || return 1
    ./scripts/feeds install -a || return 1
    stamp_file=$(mktemp -- "$state_dir/.routerfw-feeds.XXXXXXXXXX") || return 1
    if ! printf 'v2 %s %s\n' "$fingerprint" "$now" > "$stamp_file" || ! mv -f -- "$stamp_file" "$state_file"; then
        rm -f -- "$stamp_file"
        echo '[FEEDS ERROR] Could not persist completed feed refresh marker.' >&2
        return 1
    fi
    echo '[FEEDS] Update/install completed; state stored.'
}
# END SOURCE GIT AND FEEDS HELPERS

source_sync_git || exit 1

# Only the default feed configuration is mirrored; preserve a user-defined feeds.conf.
if [[ -f feeds.conf.default ]] && ! grep -q 'immortalwrt' feeds.conf.default; then
    sed -i 's|https://git.openwrt.org/feed/|https://github.com/openwrt/|g' feeds.conf.default
    sed -i 's|https://git.openwrt.org/project/|https://github.com/openwrt/|g' feeds.conf.default
fi

source_sync_feeds || exit 1

# BEGIN SOURCE OVERLAY LIFECYCLE HELPERS (tests extract this block)
# Manifests contain NUL-separated (SHA256, relative path) pairs for routerFW-owned
# untracked files only. Never prune unknown files or user changes.
LIFECYCLE_PATCH_STATE='.routerfw_patch_owned_v1'
LIFECYCLE_FILES_STATE='.routerfw_files_owned_v1'
LIFECYCLE_FILES_DIRS_STATE='.routerfw_files_dirs_owned_v1'
declare -A lifecycle_dirs_before=()
declare -A lifecycle_files_before=()
declare -A lifecycle_files_adopted=()

lifecycle_error() { printf '[LIFECYCLE SAFETY] %s\n' "$*" >&2; return 1; }

lifecycle_safe_path() {
    local rel="$1" component
    local -a components
    [[ -n "$rel" && "$rel" != /* && "$rel" != */ && "$rel" != *//* && "$rel" != *$'\n'* && "$rel" != *$'\r'* ]] || return 1
    IFS='/' read -r -a components <<< "$rel"
    for component in "${components[@]}"; do
        [[ -n "$component" && "$component" != '.' && "$component" != '..' ]] || return 1
    done
    case "$rel" in
        .git|.git/*|dl|dl/*|.routerfw_*|files/hooks.sh) return 1 ;;
    esac
}

lifecycle_validate_dest() {
    local rel="$1" allow_leaf_link="${2:-no}" current='' component index
    local -a components
    lifecycle_safe_path "$rel" || { lifecycle_error "Reserved/unsafe path: $rel"; return 1; }
    IFS='/' read -r -a components <<< "$rel"
    for (( index=0; index<${#components[@]}; index++ )); do
        component="${components[index]}"
        current="${current:+$current/}$component"
        if [[ -L "$current" ]] && ! { [[ "$allow_leaf_link" == yes ]] && (( index == ${#components[@]} - 1 )); }; then
            lifecycle_error "Symlink traversal blocked: $current"; return 1
        fi
        if (( index < ${#components[@]}-1 )) && [[ -e "$current" && ! -d "$current" ]]; then
            lifecycle_error "Non-directory parent blocked: $current"; return 1
        fi
    done
    if [[ -e "$current" && ! -f "$current" ]] && ! { [[ "$allow_leaf_link" == yes ]] && [[ -L "$current" ]]; }; then
        lifecycle_error "Non-regular destination blocked: $current"; return 1
    fi
}

# Directories have a separate NUL-terminated ownership state. Only paths below
# files/ may be owned, and the files/ root itself is never removed.
lifecycle_validate_owned_dir() {
    local rel="$1" current='' component
    local -a components
    [[ "$rel" == files/* ]] || { lifecycle_error "Directory outside files/ refused: $rel"; return 1; }
    lifecycle_safe_path "$rel" || { lifecycle_error "Unsafe owned directory: $rel"; return 1; }
    IFS='/' read -r -a components <<< "$rel"
    for component in "${components[@]}"; do
        current="${current:+$current/}$component"
        if [[ -L "$current" ]]; then
            lifecycle_error "Symlink traversal blocked for owned directory: $current"; return 1
        fi
        if [[ -e "$current" && ! -d "$current" ]]; then
            lifecycle_error "Non-directory in owned directory path: $current"; return 1
        fi
    done
}

# Validate the COMPLETE directory manifest before touching any owned files.
# A broken, replaced, or symlinked manifest fails closed.
lifecycle_validate_dirs_state() {
    local state="$1" rel
    if [[ -L "$state" || ( -e "$state" && ! -f "$state" ) ]]; then
        lifecycle_error "Invalid directory ownership state: $state"; return 1
    fi
    [[ -f "$state" ]] || return 0
    exec 4< "$state" || return 1
    while :; do
        rel=''
        if ! IFS= read -r -d '' rel <&4; then
            if [[ -n "$rel" ]]; then
                exec 4<&-
                lifecycle_error "Truncated directory ownership state: $state"; return 1
            fi
            break
        fi
        lifecycle_validate_owned_dir "$rel" || { exec 4<&-; return 1; }
    done
    exec 4<&-
}

# Remove ONLY previously owned directories, deepest first and only if empty.
# A foreign file in an owned directory is never touched (rmdir is nonrecursive).
lifecycle_clean_owned_dirs() {
    local state="$1" rel
    local -a dirs=()
    lifecycle_validate_dirs_state "$state" || return 1
    [[ -f "$state" ]] || return 0
    while IFS= read -r -d '' rel; do dirs+=("$rel"); done < "$state"
    (( ${#dirs[@]} )) || return 0
    while IFS= read -r -d '' rel; do
        lifecycle_validate_owned_dir "$rel" || return 1
        if [[ -d "$rel" ]] && [[ -z "$(find "$rel" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
            rmdir -- "$rel" || { lifecycle_error "Cannot remove empty owned directory: $rel"; return 1; }
        fi
    done < <(printf '%s\0' "${dirs[@]}" | LC_ALL=C sort -zr)
}

# Stage only directories that are needed to carry actual files. In particular,
# an empty directory left in custom_files after deleting its last file is NOT
# re-created in the firmware on the next build.
lifecycle_prune_empty_stage_dirs() {
    local stage="$1"
    find "$stage" -mindepth 1 -depth -type d -empty -delete
}

# Crash recovery: claim missing target directories BEFORE rsync creates them.
# Pre-existing directories are never claimed, even when currently empty.
lifecycle_plan_files_dirs() {
    local stage="$1" dir rel dest next
    next=$(mktemp -- '.routerfw-dirs-plan.XXXXXXXXXX') || return 1
    while IFS= read -r -d '' dir; do
        rel="${dir#"$stage"/}"
        dest="files/$rel"
        lifecycle_validate_owned_dir "$dest" || { rm -f -- "$next"; return 1; }
        if [[ -z "${lifecycle_dirs_before[$dest]-}" ]]; then
            printf '%s\0' "$dest" >> "$next" || { rm -f -- "$next"; return 1; }
        fi
    done < <(find "$stage" -mindepth 1 -type d -print0)
    mv -f -- "$next" "$LIFECYCLE_FILES_DIRS_STATE"
}

# After hooks, also remember any NEW directories created by hook-generated files.
lifecycle_record_files_dirs() {
    local dir rel next
    next=$(mktemp -- '.routerfw-dirs-state.XXXXXXXXXX') || return 1
    while IFS= read -r -d '' dir; do
        rel="${dir#./}"
        lifecycle_validate_owned_dir "$rel" || { rm -f -- "$next"; return 1; }
        if [[ -z "${lifecycle_dirs_before[$rel]-}" ]]; then
            printf '%s\0' "$rel" >> "$next" || { rm -f -- "$next"; return 1; }
        fi
    done < <(find files -mindepth 1 -type d -print0)
    mv -f -- "$next" "$LIFECYCLE_FILES_DIRS_STATE"
}

lifecycle_sha() {
    local result target
    if [[ -L "$1" ]]; then
        target=$(readlink -n -- "$1") || return 1
        result=$(printf 'LINK\0%s' "$target" | sha256sum) || return 1
    else
        result=$(sha256sum < "$1") || return 1
    fi
    printf '%s' "${result%% *}"
}

lifecycle_tracked() { git ls-files --error-unmatch -- "$1" >/dev/null 2>&1; }

lifecycle_clean_owned() {
    local state="$1" digest rel actual pass
    if [[ -L "$state" ]]; then
        lifecycle_error "Refusing symlinked ownership state: $state"; return 1
    fi
    [[ -f "$state" ]] || return 0
    # Two-pass validation: never delete one file and only then discover a conflict.
    for pass in check remove; do
        exec 3< "$state"
        while :; do
            digest=''
            if ! IFS= read -r -d '' digest <&3; then
                if [[ -n "$digest" ]]; then
                    exec 3<&-
                    lifecycle_error "Truncated ownership state: $state"; return 1
                fi
                break
            fi
            if ! IFS= read -r -d '' rel <&3; then
                exec 3<&-
                lifecycle_error "Truncated ownership state: $state"; return 1
            fi
            [[ "$digest" =~ ^[0-9a-f]{64}$ ]] || {
                exec 3<&-; lifecycle_error "Invalid ownership hash: $state"; return 1;
            }
            lifecycle_validate_dest "$rel" yes || { exec 3<&-; return 1; }
            # A file previously untracked might now be part of upstream Git.
            lifecycle_tracked "$rel" && continue
            [[ -f "$rel" || -L "$rel" ]] || continue
            actual=$(lifecycle_sha "$rel") || { exec 3<&-; return 1; }
            if [[ "$digest" != "$actual" ]]; then
                exec 3<&-
                lifecycle_error "Locally changed managed file: $rel (not removing). Resolve it manually or use the profile cleanup wizard."
                return 1
            fi
            if [[ "$pass" == remove ]]; then
                rm -- "$rel" || { exec 3<&-; return 1; }
            fi
        done
        exec 3<&-
    done
}

lifecycle_validate_source() {
    local root="$1" rel file
    [[ -d "$root" ]] || return 0
    while IFS= read -r -d '' file; do
        rel="${file#"$root"/}"
        lifecycle_safe_path "$rel" || { lifecycle_error "Invalid source overlay path: $rel"; return 1; }
        if [[ -L "$file" ]]; then
            lifecycle_error "Source symlink refused (not followed): $file"; return 1
        fi
    done < <(find "$root" -mindepth 1 -print0)
}

lifecycle_scan_stage() {
    local stage="$1" prefix="$2" state="$3" rel src dest
    while IFS= read -r -d '' src; do
        rel="${src#"$stage"/}"
        dest="${prefix}${rel}"
        lifecycle_validate_dest "$dest" || return 1
        if [[ -e "$dest" ]] && ! lifecycle_tracked "$dest"; then
            if [[ ! -e "$state" ]] && cmp -s -- "$src" "$dest"; then
                printf '[LIFECYCLE MIGRATION] Adopting identical pre-existing overlay file: %s\n' "$dest" >&2
                if [[ "$prefix" == 'files/' ]]; then lifecycle_files_adopted["$dest"]=1; fi
            else
                lifecycle_error "Unmanaged file collision: $dest (not overwriting)."
                return 1
            fi
        fi
    done < <(find "$stage" -type f -print0)
    return 0
}

lifecycle_write_state_from_stage() {
    local state="$1" stage="$2" prefix="$3" next src rel dest digest
    next=$(mktemp -- ".routerfw-state.XXXXXXXXXX") || return 1
    while IFS= read -r -d '' src; do
        rel="${src#"$stage"/}"
        dest="${prefix}${rel}"
        if ! lifecycle_tracked "$dest"; then
            digest=$(lifecycle_sha "$src") || { rm -f -- "$next"; return 1; }
            printf '%s\0%s\0' "$digest" "$dest" >> "$next" || { rm -f -- "$next"; return 1; }
        fi
    done < <(find "$stage" -type f -print0)
    mv -f -- "$next" "$state"
}

lifecycle_stage() {
    local input="$1" stage="$2" exclude_hook="${3:-no}" file
    if [[ -d "$input" ]]; then
        lifecycle_validate_source "$input" || return 1
        if [[ "$exclude_hook" == yes ]]; then
            rsync -a --exclude='/hooks.sh' "$input/" "$stage/" || return 1
            lifecycle_prune_empty_stage_dirs "$stage" || return 1
        else
            rsync -a "$input/" "$stage/" || return 1
            # Consistent with the existing patch overlay format; text-only patches are expected.
            while IFS= read -r -d '' file; do dos2unix -q -- "$file" || return 1; done \
                < <(find "$stage" -type f -print0)
        fi
    fi
}

source_apply_patches() {
    local stage input="${ROUTERFW_PATCH_SOURCE:-/patches}"
    stage=$(mktemp -d -- /tmp/routerfw-patches.XXXXXXXX) || return 1
    if ! lifecycle_stage "$input" "$stage"; then rm -rf -- "$stage"; return 1; fi
    lifecycle_clean_owned "$LIFECYCLE_PATCH_STATE" || { rm -rf -- "$stage"; return 1; }
    lifecycle_scan_stage "$stage" '' "$LIFECYCLE_PATCH_STATE" || { rm -rf -- "$stage"; return 1; }
    # Crash recovery: record planned writes before rsync. Missing entries are safe on retry.
    lifecycle_write_state_from_stage "$LIFECYCLE_PATCH_STATE" "$stage" '' || { rm -rf -- "$stage"; return 1; }
    if ! rsync -a "$stage/" ./; then rm -rf -- "$stage"; return 1; fi
    rm -rf -- "$stage"
    echo '[PATCH] Managed patch overlay synchronized without deleting unmanaged files.'
}

source_prepare_files() {
    local stage file rel input="${ROUTERFW_FILES_SOURCE:-/overlay_files}"
    stage=$(mktemp -d -- /tmp/routerfw-files.XXXXXXXX) || return 1
    if ! lifecycle_stage "$input" "$stage" yes; then rm -rf -- "$stage"; return 1; fi
    if ! routerfw_normalize_overlay_permissions "$stage"; then rm -rf -- "$stage"; return 1; fi
    lifecycle_validate_dirs_state "$LIFECYCLE_FILES_DIRS_STATE" || { rm -rf -- "$stage"; return 1; }
    lifecycle_clean_owned "$LIFECYCLE_FILES_STATE" || { rm -rf -- "$stage"; return 1; }
    lifecycle_clean_owned_dirs "$LIFECYCLE_FILES_DIRS_STATE" || { rm -rf -- "$stage"; return 1; }
    lifecycle_files_adopted=()
    lifecycle_scan_stage "$stage" 'files/' "$LIFECYCLE_FILES_STATE" || { rm -rf -- "$stage"; return 1; }
    mkdir -p files || { rm -rf -- "$stage"; return 1; }
    lifecycle_dirs_before=()
    while IFS= read -r -d '' file; do
        rel="${file#./}"
        lifecycle_dirs_before["$rel"]=1
    done < <(find files -type d -print0)
    lifecycle_files_before=()
    while IFS= read -r -d '' file; do
        rel="${file#./}"
        lifecycle_files_before["$rel"]=$(lifecycle_sha "$file") || { rm -rf -- "$stage"; return 1; }
    done < <(find files \( -type f -o -type l \) -print0)
    # If interrupted, the planned overlay files can still be cleaned on next start.
    lifecycle_write_state_from_stage "$LIFECYCLE_FILES_STATE" "$stage" 'files/' || { rm -rf -- "$stage"; return 1; }
    lifecycle_plan_files_dirs "$stage" || { rm -rf -- "$stage"; return 1; }
    if ! rsync -a "$stage/" files/; then rm -rf -- "$stage"; return 1; fi
    rm -rf -- "$stage"
    echo '[SYNC] Firmware overlay applied before hooks (no --delete).'
}

source_record_files() {
    local file rel digest next before
    next=$(mktemp -- '.routerfw-files-state.XXXXXXXXXX') || return 1
    # Track routerFW-generated files only: new untracked files created by overlay or hooks.
    while IFS= read -r -d '' file; do
        rel="${file#./}"
        lifecycle_validate_dest "$rel" yes || { rm -f -- "$next"; return 1; }
        lifecycle_tracked "$rel" && continue
        digest=$(lifecycle_sha "$file") || { rm -f -- "$next"; return 1; }
        before="${lifecycle_files_before[$rel]-}"
        if [[ -z "$before" || -n "${lifecycle_files_adopted[$rel]-}" ]]; then
            printf '%s\0%s\0' "$digest" "$rel" >> "$next" || { rm -f -- "$next"; return 1; }
        elif [[ "$before" != "$digest" ]]; then
            printf '[LIFECYCLE WARN] Hook/overlay changed an unmanaged file: %s; it will not be auto-deleted.\n' "$rel" >&2
        fi
    done < <(find files \( -type f -o -type l \) -print0)
    mv -f -- "$next" "$LIFECYCLE_FILES_STATE" || return 1
    lifecycle_record_files_dirs || return 1
    echo '[SYNC] Captured overlay and hook-generated file/directory ownership.'
}
# END SOURCE OVERLAY LIFECYCLE HELPERS

# Synchronize source patches and firmware overlay before running custom hooks.
source_apply_patches || exit 1
source_prepare_files || exit 1

# === ХУКИ И ПРОВЕРКА СОСТОЯНИЯ (ROLLBACK) ===
TARGET_MK="include/kernel-defaults.mk"
BACKUP_MK="include/kernel-defaults.mk.bak"
VERMAGIC_MARKER=".last_vermagic"

if [ -f "/overlay_files/hooks.sh" ]; then
    echo "[HOOKS] Executing hooks.sh..."
    tr -d '\r' < "/overlay_files/hooks.sh" > /tmp/hooks.sh
    chmod +x /tmp/hooks.sh
    if ! /bin/bash /tmp/hooks.sh; then
        source_record_files || true  # Preserve ownership for cleanup after a failed hook.
        exit 1
    fi
else
    # ЛОГИКА ОТКАТА (Rollback) с детальной диагностикой
    echo -e "${CYAN}[HOOKS] hooks.sh not found. Validating system state...${NC}"
    echo ""
    echo "[DEBUG] ========== STATE CHECK BEGIN =========="
    echo "[DEBUG] TARGET_MK = $TARGET_MK"
    echo "[DEBUG] BACKUP_MK = $BACKUP_MK"
    echo "[DEBUG] VERMAGIC_MARKER = $VERMAGIC_MARKER"
    echo ""

    NEEDS_ROLLBACK=false
    IS_PATCHED=false

    echo "[DEBUG] Check 1: Is Makefile patched?"
    if [ -f "$TARGET_MK" ]; then
        if grep -Eq 'echo [0-9a-f]{32}' "$TARGET_MK" 2>/dev/null; then
            echo -e "[DEBUG]   - Status: ${RED}PATCHED${NC} (Hardcoded hash found)"
            IS_PATCHED=true
            NEEDS_ROLLBACK=true
        else
            if grep -E 'MKHASH|mkhash|md5sum' "$TARGET_MK" >/dev/null 2>&1; then
                echo -e "[DEBUG]   - Status: ${GREEN}CLEAN${NC} (Standard logic found)"
            else
                echo -e "[DEBUG]   - Status: ${YELLOW}UNKNOWN${NC} (Inconclusive syntax)"
                if [ -f "$BACKUP_MK" ]; then NEEDS_ROLLBACK=true; fi
            fi
        fi
    else
        echo "[DEBUG]   - File exists: NO"
    fi

    echo "[DEBUG] Check 2: Vermagic marker?"
    if [ -f "$VERMAGIC_MARKER" ]; then
        MARKER_CONTENT=$(cat "$VERMAGIC_MARKER")
        echo -e "[DEBUG]   - Marker exists: ${RED}YES${NC} (content: $MARKER_CONTENT)"
        NEEDS_ROLLBACK=true
    else
        echo -e "[DEBUG]   - Marker exists: ${GREEN}NO${NC}"
    fi

    echo "[DEBUG] Check 3: Backup exists?"
    if [ -f "$BACKUP_MK" ]; then
        echo -e "[DEBUG]   - Backup: ${RED}YES${NC}"
        NEEDS_ROLLBACK=true
    else
        echo -e "[DEBUG]   - Backup exists: ${GREEN}NO${NC}"
    fi

    echo "[DEBUG] NEEDS_ROLLBACK = $NEEDS_ROLLBACK"
    echo "[DEBUG] ========== STATE CHECK END =========="
    echo ""

    if [ "$NEEDS_ROLLBACK" = "false" ]; then
        echo -e "${GREEN}[HOOKS] System is in clean state.${NC}"
    else
        echo -e "${YELLOW}[HOOKS] Dirty state detected. Rolling back...${NC}"
        [ -f "$BACKUP_MK" ] && cp -f "$BACKUP_MK" "$TARGET_MK" && rm -f "$BACKUP_MK"
        rm -f "$VERMAGIC_MARKER"
        make target/linux/clean > /dev/null 2>&1 || true
        rm -rf tmp/.packageinfo tmp/.targetinfo 2>/dev/null
        find build_dir/target-* -maxdepth 1 -type d -name "linux-*" -exec rm -rf {} + 2>/dev/null || true
        [ -d "/ccache" ] && rm -rf /ccache/*
        echo -e "${GREEN}[HOOKS] Rollback complete.${NC}"
    fi
fi

source_record_files || exit 1

# 3. КОНФИГУРАЦИЯ (.config)
rm -f .config
if [ -f "/output/manual_config" ]; then
    echo "[CONFIG] Using manual_config..."
    cp "/output/manual_config" .config
else
    echo "CONFIG_CCACHE=y" >> .config
echo "CONFIG_TARGET_${SRC_TARGET}=y" >> .config
    echo "CONFIG_TARGET_${SRC_TARGET}_${SRC_SUBTARGET}=y" >> .config
    
    # FIX: Priority to SRC_EXTRA_CONFIG for Device Selection
    if echo "$SRC_EXTRA_CONFIG" | grep -q "CONFIG_TARGET_.*_DEVICE_"; then
        echo "[CONFIG] Device selection delegated to SRC_EXTRA_CONFIG."
    else
        # Fallback: use TARGET_PROFILE as-is (OpenWrt Kconfig device IDs use hyphens, e.g. tplink_tl-wr1043nd-v2)
        echo "CONFIG_TARGET_${SRC_TARGET}_${SRC_SUBTARGET}_DEVICE_${TARGET_PROFILE}=y" >> .config
    fi
    for pkg in $SRC_PACKAGES; do
        [[ "$pkg" == -* ]] && echo "# CONFIG_PACKAGE_${pkg#-} is not set" >> .config || echo "CONFIG_PACKAGE_$pkg=y" >> .config
    done
    [ -n "$ROOTFS_SIZE" ] && echo "CONFIG_TARGET_ROOTFS_PARTSIZE=$ROOTFS_SIZE" >> .config
    [ -n "$KERNEL_SIZE" ] && echo "CONFIG_TARGET_KERNEL_PARTSIZE=$KERNEL_SIZE" >> .config
    # Исправление: выводим блок целиком, сохраняя пробелы внутри строк
    if [ -n "$SRC_EXTRA_CONFIG" ]; then
        printf "%b\n" "$SRC_EXTRA_CONFIG" | tr -d '\r' | while IFS= read -r line; do
            [ -n "$line" ] && echo "$line" >> .config
        done
    fi
fi

make defconfig

# 4. ДОПОЛНИТЕЛЬНЫЕ ПАКЕТЫ (the files/ overlay already precedes hooks)
[ -d "/input_packages" ] && [ "$(ls -A /input_packages)" ] && cp -rf /input_packages/* package/

# 5. СБОРКА
# BEGIN SOURCE STORAGE HEALTH HELPERS (used by tests/test_src_builder_storage.sh)
# Проверяем фактическую запись в тома, а не делаем вывод об их состоянии по "Error 1" от make.
# В успешном случае пробный файл обязательно удаляется; кеши и пользовательские файлы не чистим.
storage_error_code=''
storage_error_path=''
storage_error_detail=''

storage_classify_error() {
    local message="$1"
    case "$message" in
        *'Read-only file system'*) printf '%s' 'STORAGE_READONLY' ;;
        *'No space left on device'*|*'Disk quota exceeded'*) printf '%s' 'STORAGE_NO_SPACE' ;;
        *'Input/output error'*) printf '%s' 'STORAGE_IO_ERROR' ;;
        *'Permission denied'*|*'Operation not permitted'*) printf '%s' 'PERMISSION_ERROR' ;;
        *'No such file or directory'*) printf '%s' 'STORAGE_PATH_MISSING' ;;
        *) printf '%s' 'STORAGE_WRITE_ERROR' ;;
    esac
}

storage_fail() {
    local phase="$1" path="$2" code="$3" detail="$4"
    storage_error_code="$code"
    storage_error_path="$path"
    storage_error_detail="$detail"
    printf '\n[BUILD INFRA] %s during %s\n' "$code" "$phase" >&2
    printf '[BUILD INFRA] Path: %s\n' "$path" >&2
    printf '[BUILD INFRA] Evidence: %s\n' "$detail" >&2
    printf '[BUILD INFRA] Disk space (if available):\n' >&2
    LC_ALL=C df -hT -- "$path" >&2 || true
    printf '[BUILD INFRA] Inodes (if available):\n' >&2
    LC_ALL=C df -Pi -- "$path" >&2 || true
    printf '[BUILD INFRA] Stopping; no automatic volume cleanup or retry. Check Docker/Podman storage and host filesystem.\n' >&2
    return 1
}

storage_check() {
    local phase="$1" path temp err blocks inodes output
    shift
    local -a paths=("$@")
    if (( ${#paths[@]} == 0 )); then
        # /home/build/openwrt/dl — отдельный volume, /output — bind mount на хост.
        paths=("$PWD" "$PWD/dl" /ccache /tmp /output)
    fi
    storage_error_code=''
    storage_error_path=''
    storage_error_detail=''
    for path in "${paths[@]}"; do
        if [[ ! -d "$path" ]]; then
            storage_fail "$phase" "$path" STORAGE_PATH_MISSING 'Directory missing or inaccessible' || return 1
        fi
        if temp=$(LC_ALL=C mktemp -- "$path/.routerfw-health.XXXXXXXXXX" 2>&1); then
            if ! err=$(LC_ALL=C rm -- "$temp" 2>&1); then
                storage_fail "$phase" "$path" "$(storage_classify_error "$err")" "Probe cleanup failed: $err" || return 1
            fi
        else
            storage_fail "$phase" "$path" "$(storage_classify_error "$temp")" "$temp" || return 1
        fi

        # Диагноз по df ставим только при явном нуле доступных блоков/inode.
        # При неизвестных значениях (например, файловая система без inode) не делаем ложный вывод.
        if output=$(LC_ALL=C df -Pk -- "$path" 2>&1); then
            blocks=$(printf '%s\n' "$output" | awk 'END {print $4}')
            if [[ "$blocks" == 0 ]]; then
                storage_fail "$phase" "$path" STORAGE_NO_SPACE 'df reports 0 available 1K-blocks' || return 1
            fi
        else
            case "$(storage_classify_error "$output")" in
                STORAGE_READONLY|STORAGE_NO_SPACE|STORAGE_IO_ERROR)
                    storage_fail "$phase" "$path" "$(storage_classify_error "$output")" "df -Pk failed: $output" || return 1 ;;
                *) printf '[BUILD INFRA] WARN: df -Pk %s: %s\n' "$path" "$output" >&2 ;;
            esac
        fi
        if output=$(LC_ALL=C df -Pi -- "$path" 2>&1); then
            inodes=$(printf '%s\n' "$output" | awk 'END {print $4}')
            if [[ "$inodes" == 0 ]]; then
                storage_fail "$phase" "$path" STORAGE_NO_SPACE 'df reports 0 free inodes' || return 1
            fi
        else
            case "$(storage_classify_error "$output")" in
                STORAGE_READONLY|STORAGE_NO_SPACE|STORAGE_IO_ERROR)
                    storage_fail "$phase" "$path" "$(storage_classify_error "$output")" "df -Pi failed: $output" || return 1 ;;
                *) printf '[BUILD INFRA] WARN: df -Pi %s: %s\n' "$path" "$output" >&2 ;;
            esac
        fi
    done
    printf '[STORAGE] %s: writable paths verified (%s).\n' "$phase" "${#paths[@]}"
    return 0
}

# OpenWrt download.pl can abort on a bad cached archive BEFORE its unlink,
# leaving a permanently poisoned dl/ cache. Capture only checksum diagnostics
# (not the potentially enormous make log), and preserve make's exit status.
# END output remains streamed to the caller without buffering until completion.
source_make_capture_hash_errors() {
    local bad_log="$1"
    shift
    : > "$bad_log" || return 1
    make "$@" 2>&1 | LC_ALL=C awk -v report="$bad_log" '
        {
            print
            fflush()
            if (index($0, "Hash of the local file ") ||
                index($0, "Hash of the downloaded file does not match")) {
                print >> report
                fflush(report)
            }
        }
    '
    local -a statuses=("${PIPESTATUS[@]}")
    if (( statuses[1] != 0 )); then
        echo '[DOWNLOAD REPAIR] Output capture failed; refusing success.' >&2
        return 1
    fi
    return "${statuses[0]}"
}

# Only remove a specific, verifiably invalid regular file inside the mounted
# dl/ cache. Never delete a directory, follow symlinks, or touch other caches.
source_purge_bad_local_archives() {
    local report="$1" line rest name expected path actual hash_tool
    local recognized=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == *'Hash of the downloaded file does not match'* ]]; then
            # Upstream download.pl already removes its invalid *.dl temporary file.
            recognized=$((recognized + 1))
            continue
        fi
        [[ "$line" == *'Hash of the local file '*' does not match '* ]] || {
            echo '[DOWNLOAD REPAIR] Unrecognized checksum diagnostic; refusing blind cleanup.' >&2
            return 1
        }
        rest="${line#*Hash of the local file }"
        name="${rest%% does not match *}"
        expected="${line##*requested: }"
        expected="${expected%%)*}"
        # OpenWrt commonly uses SHA256; older feeds can still specify MD5.
        if [[ ! "$name" =~ ^[[:alnum:]_][[:alnum:]_.+%@~-]*$ ||
              ( ! "$expected" =~ ^[[:xdigit:]]{64}$ && ! "$expected" =~ ^[[:xdigit:]]{32}$ ) ]]; then
            printf '[DOWNLOAD REPAIR] Unsafe archive name or malformed checksum: %s\n' "$name" >&2
            return 1
        fi
        path="$PWD/dl/$name"
        if [[ -L "$path" || ( -e "$path" && ! -f "$path" ) ]]; then
            printf '[DOWNLOAD REPAIR] Refusing non-regular cache entry: %s\n' "$path" >&2
            return 1
        fi
        if [[ -f "$path" ]]; then
            if (( ${#expected} == 64 )); then hash_tool=sha256sum; else hash_tool=md5sum; fi
            actual=$($hash_tool -- "$path") || return 1
            actual="${actual%% *}"
            if [[ "${actual,,}" != "${expected,,}" ]]; then
                rm -- "$path" || {
                    printf '[DOWNLOAD REPAIR] Could not remove invalid archive: %s\n' "$path" >&2
                    return 1
                }
                printf '[DOWNLOAD REPAIR] Removed checksum-invalid cache file: %s\n' "$name"
            else
                printf '[DOWNLOAD REPAIR] Cache file already has correct checksum: %s\n' "$name"
            fi
        else
            printf '[DOWNLOAD REPAIR] Bad cache entry already absent: %s\n' "$name"
        fi
        recognized=$((recognized + 1))
    done < "$report"
    (( recognized > 0 )) || return 1
    return 0
}

# Retry a checksum mismatch at most three times, using OpenWrt's own mirror
# selection and hash verification. This is also needed during make world:
# "make download" may report success despite a package/download error.
source_make_checked() {
    local phase="$1" report status repair_attempt=0 max_repairs=3
    shift
    SOURCE_HASH_REPAIR_EXHAUSTED=0
    report=$(mktemp "${TMPDIR:-/tmp}/routerfw-sha.XXXXXXXX") || return 1
    while :; do
        if source_make_capture_hash_errors "$report" "$@"; then
            status=0
        else
            status=$?
        fi
        if [[ ! -s "$report" ]]; then
            rm -f -- "$report"
            return "$status"
        fi
        if (( repair_attempt >= max_repairs )); then
            printf '[DOWNLOAD REPAIR FAILED] SHA mismatch persisted after %s retries (%s).\n' "$max_repairs" "$phase" >&2
            SOURCE_HASH_REPAIR_EXHAUSTED=1
            rm -f -- "$report"
            return 1
        fi
        if ! source_purge_bad_local_archives "$report"; then
            SOURCE_HASH_REPAIR_EXHAUSTED=1
            rm -f -- "$report"
            return 1
        fi
        if ! storage_check "after SHA mismatch ($phase)" "$PWD/dl"; then
            SOURCE_HASH_REPAIR_EXHAUSTED=1
            rm -f -- "$report"
            return 1
        fi
        repair_attempt=$((repair_attempt + 1))
        printf '[DOWNLOAD REPAIR] Retry %s/%s after SHA mismatch (%s).\n' "$repair_attempt" "$max_repairs" "$phase"
        if [[ "$phase" == compile ]]; then
            # Reacquire using the upstream download graph, not a hardcoded URL.
            if ! run_source_download; then
                SOURCE_HASH_REPAIR_EXHAUSTED=1
                rm -f -- "$report"
                return 1
            fi
        fi
    done
}

run_source_download() {
    echo '[DOWNLOAD] Starting...'
    if source_make_checked download download; then
        return 0
    fi
    [[ "${SOURCE_HASH_REPAIR_EXHAUSTED:-0}" != 1 ]] || return 1
    storage_check 'after make download failure' || return 1
    echo '[DOWNLOAD] Attempt 2: make download V=s'
    if source_make_checked download download V=s; then
        return 0
    fi
    [[ "${SOURCE_HASH_REPAIR_EXHAUSTED:-0}" != 1 ]] || return 1
    storage_check 'after verbose make download failure' || return 1
    echo '[DOWNLOAD FAILED] Both download attempts failed; storage probe passed (cause not classified).' >&2
    return 1
}

run_source_compile() {
    local -a args=("$@")
    echo "[BUILD] Starting build with args: ${args[*]}"
    if source_make_checked compile "${args[@]}"; then
        return 0
    fi
    [[ "${SOURCE_HASH_REPAIR_EXHAUSTED:-0}" != 1 ]] || return 1
    storage_check 'after initial make failure' || return 1
    if [[ "${SRC_CORES:-}" == debug ]]; then
        echo -e "\n${RED}[BUILD FAILED] Initial debug build failed; storage probe passed (cause not classified).${NC}\n" >&2
        return 1
    fi
    echo -e "\n${RED}[BUILD ERROR] Parallel build failed! Starting Attempt 2: -j1 V=s (Debug mode)...${NC}\n"
    if source_make_checked compile -j1 V=s; then
        return 0
    fi
    [[ "${SOURCE_HASH_REPAIR_EXHAUSTED:-0}" != 1 ]] || return 1
    storage_check 'after debug make failure' || return 1
    echo -e "\n${RED}[BUILD FAILED] Debug build failed; storage probe passed (cause not classified).${NC}\n" >&2
    return 1
}
# END SOURCE STORAGE HEALTH HELPERS

storage_check 'before make download' || exit 1
run_source_download || exit 1

SYS_CORES=$(nproc)
BUILD_JOBS=$SYS_CORES
MAKE_ARGS=("-j$BUILD_JOBS")

if [[ "$SRC_CORES" == "debug" ]]; then
    MAKE_ARGS=(-j1 V=s)
    echo "[BUILD] Debug mode requested. Using: ${MAKE_ARGS[*]}"
elif [[ "$SRC_CORES" == "safe" ]]; then
    BUILD_JOBS=$((SYS_CORES > 1 ? SYS_CORES - 1 : 1))
    MAKE_ARGS=("-j$BUILD_JOBS")
elif [[ "$SRC_CORES" =~ ^[0-9]+$ ]]; then
    MAKE_ARGS=("-j$SRC_CORES")
fi

storage_check 'before compile' || exit 1
run_source_compile "${MAKE_ARGS[@]}" || exit 1

# 6. СОХРАНЕНИЕ
# BEGIN SOURCE ARTIFACT EXPORT HELPERS (offline regression tests extract this block)
# Selected RAM-boot TFA variants install standalone BL2 files directly into
# BIN_DIR. OpenWrt stamps can survive the old destructive export, so incremental
# `make` may succeed without reinstalling these files. Enumerate requirements
# from the current .config, never from historical firmware_output directories.
source_export_verify_selected_ram_bl2() {
    local source_dir="$1" config="$2" line name missing=0 selected=0
    [[ -d "$source_dir" && -f "$config" ]] || {
        echo "[BL2 ERROR] Missing target directory or configuration: $source_dir, $config" >&2
        return 1
    }
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^CONFIG_PACKAGE_trusted-firmware-a-(mt[0-9]+-ram-[a-z0-9-]+)=y$ ]]; then
            name="${BASH_REMATCH[1]}-bl2.bin"
            selected=$((selected + 1))
            if [[ ! -f "$source_dir/$name" || -L "$source_dir/$name" || ! -s "$source_dir/$name" ]]; then
                echo "[BL2 ERROR] Selected package artifact missing or invalid: $name" >&2
                missing=$((missing + 1))
            fi
        fi
    done < "$config"
    if (( missing > 0 )); then
        echo "[BL2 ERROR] $missing/$selected selected RAM-boot BL2 artifacts unavailable." >&2
        return 1
    fi
    return 0
}

# One-time recovery from the CURRENT SOURCE TREE, not from a previous archive.
# If custom hooks/patches modify ATF, rebuild under their already-applied state.
# Only the ATF package is cleaned; no Docker volume or entire workdir is reset.
source_export_ensure_current_ram_bl2() {
    local source_dir="$1"
    if source_export_verify_selected_ram_bl2 "$source_dir" .config; then
        return 0
    fi
    echo '[BL2 REPAIR] Rebuilding selected Trusted Firmware A variants from current sources...'
    if ! make package/boot/arm-trusted-firmware-mediatek/clean; then
        echo '[BL2 ERROR] Targeted Trusted Firmware A cleanup failed.' >&2
        return 1
    fi
    # The RAM boot variants install BL2 directly to BIN_DIR via the package
    # install recipe (include/package-bin.mk), NOT into a regular rootfs package.
    # Re-running 'make world' may leave them absent at the end again. Instead,
    # run ONLY the selected package compile/install AFTER the firmware build,
    # so no subsequent target/image stage can replace its BIN_DIR outputs.
    echo '[BL2 REPAIR] Installing selected Trusted Firmware A BL2 after firmware build...'
    if ! make "${MAKE_ARGS[@]}" package/boot/arm-trusted-firmware-mediatek/compile; then
        echo '[BL2 ERROR] Targeted Trusted Firmware A compile/install failed.' >&2
        return 1
    fi
    if ! source_export_verify_selected_ram_bl2 "$source_dir" .config; then
        echo '[BL2 ERROR] Rebuild did not regenerate every selected RAM BL2. Refusing incomplete export.' >&2
        return 1
    fi
    echo '[BL2 REPAIR] All selected RAM BL2 files installed into persistent bin/targets.'
}

# Export the selected OpenWrt BIN_DIR firmware tree, without its top-level
# packages/ feed (APK/IPK packages are build inputs, not firmware deliverables).
# Keep every other nested path and extension, without touching build caches.
# All I/O is checked before the timestamp directory is published.
#
# Note: this is a lossless snapshot of files PRESENT after `make`, not proof that
# upstream generated every device artifact. MediaTek RAM BL2 still need the
# separate upstream-specific repair above when OpenWrt removes them during make.
source_export_artifacts() (
    set -euo pipefail
    local source_dir="${1%/}" output_root="${2%/}" stamp="$3"
    local stage='' target='' source_list='' checksum_list=''
    local src rel dst link_src link_dst resolved src_root stage_root out_root
    local entries=0 payload=0 staged_entries=0 file_count=0

    [[ -d "$source_dir" && ! -L "$source_dir" && -f .config && ! -L .config ]] || {
        echo "[EXPORT ERROR] Missing or unsafe target BIN_DIR / .config: $source_dir" >&2
        return 1
    }
    # Stamp is a single component, never a path supplied by a profile.
    [[ "$stamp" =~ ^[[:alnum:]_.-]+$ && "$stamp" != '.' && "$stamp" != '..' ]] || {
        echo '[EXPORT ERROR] Unsafe output timestamp.' >&2
        return 1
    }
    [[ -d "$output_root" && ! -L "$output_root" ]] || {
        echo "[EXPORT ERROR] Missing or unsafe output directory: $output_root" >&2
        return 1
    }
    target="$output_root/$stamp"
    [[ ! -e "$target" && ! -L "$target" ]] || {
        echo "[EXPORT ERROR] Refusing to overwrite existing output: $target" >&2
        return 1
    }
    src_root=$(realpath -e -- "$source_dir") || return 1
    out_root=$(realpath -e -- "$output_root") || return 1
    [[ "$out_root" != "$src_root" && "$out_root" != "$src_root"/* ]] || {
        echo '[EXPORT ERROR] Output root cannot be inside the source BIN_DIR.' >&2
        return 1
    }
    stage=$(mktemp -d "$output_root/.routerfw-export.${stamp}.XXXXXXXX") || return 1
    trap 'rm -rf -- "$stage"; rm -f -- "$source_list" "$checksum_list"' EXIT
    source_list=$(mktemp "$output_root/.routerfw-source-list.XXXXXXXX") || return 1
    checksum_list=$(mktemp "$output_root/.routerfw-checksum-list.XXXXXXXX") || return 1
    stage_root=$(realpath -e -- "$stage") || return 1

    # Store find exit status explicitly. `while ... < <(find ...)` would hide it.
    # Exclude ONLY the top-level packages/ entry. Keep nested directories with
    # other names, regardless of their content or file extensions.
    if ! find "$source_dir" -mindepth 1 \
        -path "$source_dir/packages" -prune -o -print0 | LC_ALL=C sort -z > "$source_list"; then
        echo '[EXPORT ERROR] Could not enumerate BIN_DIR.' >&2
        return 1
    fi
    # Root names are reserved for routerFW metadata, but never silently replace
    # an upstream artifact. Preserve the upstream checksum under a unique name.
    if [[ -e "$source_dir/build.config" || -L "$source_dir/build.config" ||
          -e "$source_dir/.routerfw-upstream.sha256sums" || -L "$source_dir/.routerfw-upstream.sha256sums" ]]; then
        echo '[EXPORT ERROR] BIN_DIR contains a reserved routerFW metadata filename.' >&2
        return 1
    fi
    # Check types and portable symlinks BEFORE copying to output. Never follow
    # symlinks out of the source tree; otherwise the snapshot could be unsafe or
    # silently become broken when moved to the host.
    while IFS= read -r -d '' src; do
        rel=${src#"$source_dir"/}
        entries=$((entries + 1))
        if [[ -L "$src" ]]; then
            link_src=$(readlink -- "$src") || return 1
            [[ "$link_src" != /* ]] || { echo "[EXPORT ERROR] Absolute symlink: $rel" >&2; return 1; }
            resolved=$(realpath -e -- "$src") || { echo "[EXPORT ERROR] Dangling symlink: $rel" >&2; return 1; }
            [[ "$resolved" == "$src_root"/* ]] || { echo "[EXPORT ERROR] Symlink escapes BIN_DIR: $rel" >&2; return 1; }
            # Upstream sha256sums is preserved under another name; symlinks
            # pointing to its former path would silently change their meaning.
            [[ "$resolved" != "$src_root/sha256sums" ]] || {
                echo "[EXPORT ERROR] Symlink to renamed upstream checksum: $rel" >&2
                return 1
            }
        elif [[ -f "$src" ]]; then
            file_count=$((file_count + 1))
            # We cannot infer firmware formats, but metadata-only and package-only
            # trees are not successful firmware exports.
            case "$rel" in
                sha256sums|profiles.json|*.buildinfo|*.manifest) ;;
                *) payload=$((payload + 1)) ;;
            esac
        elif [[ -d "$src" ]]; then
            :
        else
            echo "[EXPORT ERROR] Unsupported entry type: $rel" >&2
            return 1
        fi
    done < "$source_list"
    (( entries > 0 && file_count > 0 && payload > 0 )) || {
        echo '[EXPORT ERROR] No non-metadata firmware payload in selected BIN_DIR.' >&2
        return 1
    }

    # rsync copies all selected paths without ever reading/copying packages/.
    # Exclude only the root-level name; nested firmware directories are retained.
    if ! rsync -a --exclude='/packages' -- "$source_dir/" "$stage/"; then
        echo '[EXPORT ERROR] Snapshot copy failed.' >&2
        return 1
    fi
    # The source BIN_DIR may be read-only; leave it untouched, but make the
    # staging root writable for routerFW's output-only metadata.
    chmod u+rwx -- "$stage" || return 1
    # Verify actual bytes, directory existence, symlink target, and tree count.
    # This detects truncated copies even when cp reports success.
    while IFS= read -r -d '' src; do
        rel=${src#"$source_dir"/}
        dst="$stage/$rel"
        if [[ -L "$src" ]]; then
            [[ -L "$dst" ]] || { echo "[EXPORT ERROR] Symlink missing after copy: $rel" >&2; return 1; }
            link_src=$(readlink -- "$src") || return 1
            link_dst=$(readlink -- "$dst") || return 1
            [[ "$link_src" == "$link_dst" ]] || { echo "[EXPORT ERROR] Symlink differs: $rel" >&2; return 1; }
            resolved=$(realpath -e -- "$dst") || return 1
            [[ "$resolved" == "$stage_root"/* ]] || { echo "[EXPORT ERROR] Published symlink escapes snapshot: $rel" >&2; return 1; }
        elif [[ -f "$src" ]]; then
            [[ -f "$dst" && ! -L "$dst" ]] && cmp -s -- "$src" "$dst" || {
                echo "[EXPORT ERROR] File missing or differs after copy: $rel" >&2
                return 1
            }
        else
            [[ -d "$dst" && ! -L "$dst" ]] || { echo "[EXPORT ERROR] Directory missing: $rel" >&2; return 1; }
        fi
    done < "$source_list"
    # Count output entries before adding our own metadata; no silent extras.
    staged_entries=$(find "$stage" -mindepth 1 -printf '.' | wc -c) || return 1
    (( staged_entries == entries )) || {
        echo "[EXPORT ERROR] Snapshot entry count differs ($entries != $staged_entries)." >&2
        return 1
    }

    if [[ -e "$stage/sha256sums" || -L "$stage/sha256sums" ]]; then
        [[ -f "$stage/sha256sums" && ! -L "$stage/sha256sums" ]] || {
            echo '[EXPORT ERROR] Unexpected upstream sha256sums type.' >&2; return 1
        }
        mv -- "$stage/sha256sums" "$stage/.routerfw-upstream.sha256sums" || return 1
    fi
    cp -- .config "$stage/build.config" || return 1
    # Hash every published regular file (firmware and metadata), including
    # the preserved upstream checksum and build.config.
    if ! (cd "$stage" && find . -type f -print0 | LC_ALL=C sort -z) > "$checksum_list"; then
        echo '[EXPORT ERROR] Published file enumeration failed.' >&2
        return 1
    fi
    (
        cd "$stage" || exit 1
        : > sha256sums || exit 1
        while IFS= read -r -d '' rel; do
            [[ "$rel" == ./sha256sums ]] && continue
            sha256sum -b -- "${rel#./}" >> sha256sums || exit 1
        done < "$checksum_list"
        sha256sum --check --status sha256sums || exit 1
    ) || {
        echo '[EXPORT ERROR] Snapshot checksum verification failed.' >&2
        return 1
    }
    [[ ! -e "$target" && ! -L "$target" ]] || {
        echo "[EXPORT ERROR] Target appeared during export: $target" >&2
        return 1
    }
    mv -- "$stage" "$target" || return 1
    stage=''
    echo "[EXPORT] Published $file_count regular source files (all nested paths included), with verified bytes and SHA256; source BIN_DIR unchanged."
)
# END SOURCE ARTIFACT EXPORT HELPERS

TARGET_DIR="/output/$TIMESTAMP"
# The target and subtarget are single path components, never arbitrary paths.
for component in "$SRC_TARGET" "$SRC_SUBTARGET"; do
    [[ "$component" =~ ^[[:alnum:]_.-]+$ && "$component" != '.' && "$component" != '..' ]] || {
        echo "[EXPORT ERROR] Unsafe target/subtarget component: $component" >&2
        exit 1
    }
done
# MediaTek RAM-boot BL2 sometimes disappears during OpenWrt's own image
# installation. Retain this narrowly scoped preflight until upstream fixes it;
# it does NOT select, filter or flatten any files for the generic exporter.
source_export_ensure_current_ram_bl2 "bin/targets/$SRC_TARGET/$SRC_SUBTARGET" || exit 1
# Export selected subtarget firmware artifacts, excluding only top-level packages/.
source_export_artifacts "bin/targets/$SRC_TARGET/$SRC_SUBTARGET" /output "$TIMESTAMP" || exit 1

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

# Список: папка (метка времени подсвечена) + имена файлов с размерами в МБ
echo ""
base_win="sourcebuilder\\${PROFILE_ID}"
printf '%b  firmware_output\\%s\\%b\\\n' "${CYAN}[FIRMWARE FOLDER]${NC}" "${base_win}" "${CYAN}${TIMESTAMP}${NC}"
printf '%b\n' "${CYAN}[FILES]${NC}"
for f in "$TARGET_DIR"/*; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    if [ -d "$f" ]; then
        printf '%s/  %b\n' "$name" "${CYAN}[directory, files preserved]${NC}"
        continue
    fi
    bytes=$(stat -c%s "$f" 2>/dev/null); bytes=${bytes:-0}
    mb=$(awk "BEGIN {printf \"%.1f\", $bytes/1048576}")
    if [ "$bytes" -ge 31457280 ]; then col="$RED"      # >= 30 MB
    elif [ "$bytes" -ge 10485760 ]; then col="$YELLOW" # >= 10 MB
    else col="$GREEN"; fi
    printf '%s  %b\n' "$name" "${col}[${mb} MB]${NC}"
done

ELAPSED=$(($(date +%s) - START_TIME))
echo -e "\n=== Build $PROFILE_NAME completed in ${ELAPSED}s. ===\n"
EOF
# checksum:MD5=83e32f92db811dfc6dc3b9b08112c803