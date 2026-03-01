#!/bin/bash
# Script to apply checksum change detection to _Builder.sh

# Backup the original file
cp _Builder.sh _Builder.sh.backup

# Apply changes using sed
echo "Applying changes to _Builder.sh..."

# Change 1: Add CHK_OLD_HASH extraction after line 370
sed -i '/\[ ! -f "\$file" \]/a\
\
    # Extract old hash BEFORE processing\
    CHK_OLD_HASH=$(grep "checksum:MD5=" "$file" | tail -1 | '"'"'s/.*checksum:MD5=//'"'"' | tr -d '"'"'\\r'"'"')' _Builder.sh

# Change 2: Add CHK_WAS_CHANGED comparison after prefix line
sed -i '/prefix=$(checksum_comment_prefix "\$file")/a\
\
    # Compare old vs new hash\
    CHK_WAS_CHANGED=0\
    if [ -n "$CHK_OLD_HASH" ] \&\& [ "$CHK_OLD_HASH" != "$hash" ]; then\
        CHK_WAS_CHANGED=1\
    fi' _Builder.sh

# Change 3: Modify echo to include changed_suffix
sed -i 's|echo -e "  \${C_GRY}-\${C_RST} File: \${C_VAL}\${file}\${C_RST} \${C_GRY}MD5=\${C_KEY}\${hash}\${C_RST}"|local changed_suffix=""\
    [ "$CHK_WAS_CHANGED" -eq 1 ] \&\& changed_suffix=" \${C_ERR}$L_CHKSUM_CHANGED\${C_RST}"\
    echo -e "  \${C_GRY}-\${C_RST} File: \${C_VAL}\${file}\${C_RST} \${C_GRY}MD5=\${C_KEY}\${hash}\${C_RST}\${changed_suffix}"|' _Builder.sh

# Change 4: Add changed counter
sed -i '/echo -e "\${C_LBL}\[CHECKSUM\]\${C_RST} \${L_CHKSUM_ALL_START}"/a\    local changed=0' _Builder.sh

# Change 5: Add change check in loop
sed -i '/add_checksum_to_file "\$f" \&\& (($(n++)))/a\        [ "$CHK_WAS_CHANGED" -eq 1 ] \&\& ((changed++))' _Builder.sh

# Change 6: Update final echo
sed -i 's|echo -e "\${C_OK}\$L_CHKSUM_DONE \$n\${C_RST}"|echo -e "\${C_OK}$L_CHKSUM_DONE $n \${C_GRY}$L_CHKSUM_CHANGED_SUM$changed\${C_RST}"|' _Builder.sh

echo "Changes applied to _Builder.sh!"
echo "Original saved as _Builder.sh.backup"
