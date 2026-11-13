routerfw_test_tmp() {
    local root="$1"
    mkdir -p "$root/tmp"
    if grep -qi microsoft /proc/version 2>/dev/null \
        && [ "$(stat -c %d "$root" 2>/dev/null)" != "$(stat -c %d /tmp 2>/dev/null)" ]; then
        printf '%s\n' /tmp
    else
        printf '%s\n' "$root/tmp"
    fi
}
