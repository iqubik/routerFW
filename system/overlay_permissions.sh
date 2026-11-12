#!/usr/bin/env bash
# file: system/overlay_permissions.sh v1.0
# Shared IB/SB policy for files supplied through custom_files/<profile>/.
# Usage: source this file; routerfw_normalize_overlay_permissions "$staging_dir"
# The original host-mounted custom_files directory is NEVER modified.

routerfw_permission_error() {
    printf '[PERMISSIONS ERROR] %s\n' "$*" >&2
    return 1
}

routerfw_permission_safe_relative() {
    local rel="$1" part
    local -a parts
    [[ -n "$rel" && "$rel" != /* && "$rel" != */ && "$rel" != *//* &&
       "$rel" != *$'\n'* && "$rel" != *$'\r'* ]] || return 1
    IFS='/' read -r -a parts <<< "$rel"
    for part in "${parts[@]}"; do
        [[ -n "$part" && "$part" != . && "$part" != .. ]] || return 1
    done
    case "$rel" in
        .routerfw-permissions|hooks.sh|README.md) return 1 ;;
    esac
}

routerfw_permission_default() {
    local rel="$1" type="$2"
    if [[ "$type" == directory ]]; then
        case "$rel" in
            root) printf '0750' ;;
            root/.ssh|root/.ssh/*|etc/dropbear|etc/dropbear/*|etc/ssl/private|etc/ssl/private/*|etc/wireguard|etc/wireguard/*)
                printf '0700' ;;
            *) printf '0755' ;;
        esac
        return 0
    fi
    case "$rel" in
        # Source-loaded by OpenWrt; no executable bit required.
        etc/uci-defaults/*|etc/hotplug.d/*) printf '0644' ;;
        # The init supervisor / button handlers execute these as programs.
        etc/init.d/*|etc/rc.button/*|etc/rc.local|bin/*|sbin/*|usr/bin/*|usr/sbin/*)
            printf '0755' ;;
        # Known sensitive files and directories. Public keys remain shareable.
        root/.ssh/*.pub) printf '0644' ;;
        root/.ssh/*|etc/dropbear/*|etc/ssl/private/*|etc/wireguard/*|etc/shadow|etc/shadow-*|etc/gshadow|etc/gshadow-*|etc/ppp/chap-secrets|etc/ppp/pap-secrets) printf '0600' ;;
        *) printf '0644' ;;
    esac
}

routerfw_normalize_overlay_permissions() {
    local stage="$1" metadata="$1/.routerfw-permissions" entry rel mode line number=0
    local entries='' sorted_dirs='' file_count=0 dir_count=0
    local -A overrides=()

    [[ -d "$stage" && ! -L "$stage" ]] || {
        routerfw_permission_error "Missing or unsafe staging directory: $stage"; return 1;
    }
    # First enumerate and validate everything before performing any chmod.
    entries=$(mktemp -- /tmp/routerfw-permission-list.XXXXXXXX) || return 1
    if ! find "$stage" -mindepth 1 -print0 > "$entries"; then
        rm -f -- "$entries"
        routerfw_permission_error 'Could not enumerate staged overlay.'; return 1
    fi
    while IFS= read -r -d '' entry; do
        rel="${entry#"$stage"/}"
        if ! routerfw_permission_safe_relative "$rel" &&
           [[ "$rel" != .routerfw-permissions && "$rel" != hooks.sh && "$rel" != README.md ]]; then
            rm -f -- "$entries"
            routerfw_permission_error "Unsafe staged path: $rel"; return 1
        fi
        if [[ -L "$entry" || ( ! -f "$entry" && ! -d "$entry" ) ]]; then
            rm -f -- "$entries"
            routerfw_permission_error "Unsupported file type/symlink: $rel"; return 1
        fi
    done < "$entries"

    if [[ -e "$metadata" ]]; then
        [[ -f "$metadata" && ! -L "$metadata" ]] || {
            rm -f -- "$entries"; routerfw_permission_error 'Invalid .routerfw-permissions metadata file'; return 1;
        }
        while IFS= read -r line || [[ -n "$line" ]]; do
            number=$((number + 1))
            line="${line%$'\r'}"
            if (( number == 1 )); then line="${line#$'\xef\xbb\xbf'}"; fi
            [[ "$line" =~ ^[[:space:]]*(#.*)?$ ]] && continue
            if [[ ! "$line" =~ ^([0-7]{4})[[:blank:]]+(.+)$ ]]; then
                rm -f -- "$entries"
                routerfw_permission_error "Invalid permissions line $number (expected: 0640 /etc/path)"; return 1
            fi
            mode="${BASH_REMATCH[1]}"
            rel="${BASH_REMATCH[2]}"
            rel="${rel#/}"
            if ! routerfw_permission_safe_relative "$rel"; then
                rm -f -- "$entries"
                routerfw_permission_error "Unsafe permissions path at line $number: $rel"; return 1
            fi
            if [[ -n "${overrides[$rel]+present}" ]]; then
                rm -f -- "$entries"
                routerfw_permission_error "Duplicate permissions path at line $number: $rel"; return 1
            fi
            if [[ ! -f "$stage/$rel" && ! -d "$stage/$rel" ]]; then
                rm -f -- "$entries"
                routerfw_permission_error "Permissions path not in overlay at line $number: $rel"; return 1
            fi
            # No setuid/setgid/sticky bits, no world-writable paths. This is a
            # firmware creation tool, not a generic chmod wrapper.
            if [[ "$mode" != 0[0-7][0-7][0-7] ]] || (( (8#$mode & 8#0002) != 0 )); then
                rm -f -- "$entries"
                routerfw_permission_error "Unsafe mode $mode at line $number: $rel"; return 1
            fi
            if [[ -d "$stage/$rel" ]] && (( (8#$mode & 8#0500) != 8#0500 )); then
                rm -f -- "$entries"
                routerfw_permission_error "Directory needs owner read/execute permission: $rel"; return 1
            fi
            if [[ -f "$stage/$rel" ]] && (( (8#$mode & 8#0400) == 0 )); then
                rm -f -- "$entries"
                routerfw_permission_error "File needs owner read permission: $rel"; return 1
            fi
            overrides["$rel"]="$mode"
        done < "$metadata"
    fi

    # Apply restrictive permissions to files first. Directory chmod is last so
    # an override cannot block traversal before the remaining tree is handled.
    while IFS= read -r -d '' entry; do
        [[ -f "$entry" ]] || continue
        rel="${entry#"$stage"/}"
        [[ "$rel" == .routerfw-permissions ]] && continue
        mode="${overrides[$rel]-}"
        [[ -n "$mode" ]] || mode=$(routerfw_permission_default "$rel" file)
        chmod -- "$mode" "$entry" || { rm -f -- "$entries"; return 1; }
        file_count=$((file_count + 1))
    done < "$entries"

    # Sort validated paths in reverse order: descendants precede ancestors.
    # Unlike process substitution, this makes sort failures observable.
    sorted_dirs=$(mktemp -- /tmp/routerfw-permission-dirs.XXXXXXXX) || {
        rm -f -- "$entries"; return 1;
    }
    if ! LC_ALL=C sort -zr -- "$entries" > "$sorted_dirs"; then
        rm -f -- "$entries" "$sorted_dirs"
        routerfw_permission_error 'Could not order staged directories.'; return 1
    fi
    while IFS= read -r -d '' entry; do
        [[ -d "$entry" ]] || continue
        rel="${entry#"$stage"/}"
        mode="${overrides[$rel]-}"
        [[ -n "$mode" ]] || mode=$(routerfw_permission_default "$rel" directory)
        chmod -- "$mode" "$entry" || { rm -f -- "$entries" "$sorted_dirs"; return 1; }
        dir_count=$((dir_count + 1))
    done < "$sorted_dirs"
    rm -f -- "$sorted_dirs"

    # Metadata must never ship in the firmware or ownership state.
    if [[ -f "$metadata" ]]; then
        rm -- "$metadata" || { rm -f -- "$entries"; return 1; }
    fi
    rm -f -- "$entries"
    printf '[PERMISSIONS] Normalized %d files and %d directories; host sources untouched.\n' "$file_count" "$dir_count"
}
# checksum:MD5=12e449666299841f9db22547916343a1