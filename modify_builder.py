#!/usr/bin/env python3
import re

# Read the file
with open('_Builder.sh', 'r', encoding='utf-8') as f:
    content = f.read()

# Change 1: Add CHK_OLD_HASH extraction after line 370 in add_checksum_to_file
pattern1 = r'(\[ ! -f "\$file" \] && \{ echo -e "\$\{C_ERR\}\[SKIP\] \$file not found\$\{C_RST\}"; return 1; \})\s+(local staged\s+staged=\$\(mktemp\))'
replacement1 = r'''\1
    
    # Extract old hash BEFORE processing
    CHK_OLD_HASH=$(grep "checksum:MD5=" "$file" | tail -1 | sed 's/.*checksum:MD5=//' | tr -d '\r')
    
    \2'''
content = re.sub(pattern1, replacement1, content)

# Change 2: Add CHK_WAS_CHANGED comparison after prefix line
pattern2 = r'(local prefix\s+prefix=\$\(checksum_comment_prefix "\$file"\)\s+)(# Файл теперь гарантированно заканчивается переносом строки \(EOL\),)'
replacement2 = r'''\1# Compare old vs new hash
    CHK_WAS_CHANGED=0
    if [ -n "$CHK_OLD_HASH" ] && [ "$CHK_OLD_HASH" != "$hash" ]; then
        CHK_WAS_CHANGED=1
    fi
    
    \2'''
content = re.sub(pattern2, replacement2, content)

# Change 3: Modify echo statement to include changed_suffix
pattern3 = r'(printf \'%s checksum:MD5=%s\' "\$prefix" "\$hash" >> "\$staged"\s+mv "\$staged" "\$file"\s+)(echo -e "  \$\{C_GRY\}-\$\{C_RST\} File: \$\{C_VAL\}\$\{file\}\$\{C_RST\} \$\{C_GRY\}MD5=\$\{C_KEY\}\$\{hash\}\$\{C_RST\}")'
replacement3 = r'''\1local changed_suffix=""
    [ "$CHK_WAS_CHANGED" -eq 1 ] && changed_suffix=" ${C_ERR}$L_CHKSUM_CHANGED${C_RST}"
    echo -e "  ${C_GRY}-${C_RST} File: ${C_VAL}${file}${C_RST} ${C_GRY}MD5=${C_KEY}${hash}${C_RST}${changed_suffix}"'''
content = re.sub(pattern3, replacement3, content)

# Change 4: Add changed counter to do_checksum_all
pattern4 = r'(echo -e "\$\{C_LBL\}\[CHECKSUM\]\$\{C_RST\} \$\{L_CHKSUM_ALL_START\}"\s+)(local n=0)'
replacement4 = r'''\1local n=0
    local changed=0'''
content = re.sub(pattern4, replacement4, content)

# Change 5: Add change check in for loop
pattern5 = r'(\[ -f "\$f" \] && add_checksum_to_file "\$f" && \(\(n\+\+\)\))'
replacement5 = r'''\1
        [ "$CHK_WAS_CHANGED" -eq 1 ] && ((changed++))'''
content = re.sub(pattern5, replacement5, content)

# Change 6: Modify final echo to include changed count
pattern6 = r'(echo -e "\$\{C_OK\}\$L_CHKSUM_DONE \$n\$\{C_RST\}")'
replacement6 = r'echo -e "${C_OK}$L_CHKSUM_DONE $n ${C_GRY}$L_CHKSUM_CHANGED_SUM$changed${C_RST}"'
content = re.sub(pattern6, replacement6, content)

# Write back
with open('_Builder.sh', 'w', encoding='utf-8') as f:
    f.write(content)

print("Successfully modified _Builder.sh")
