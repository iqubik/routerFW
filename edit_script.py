#!/usr/bin/env python3
import re

# Read the file
with open('_Builder.sh', 'r', encoding='utf-8') as f:
    content = f.read()

# Change 1: Add CHK_OLD_HASH extraction after line 370
pattern1 = r'(add_checksum_to_file\(\) \{\s+local file="\$\{1\}"\s+\[ ! -f "\$file" \] && \{ echo -e "\$\{C_ERR\}\[SKIP\] \$file not found\$\{C_RST\}"; return 1; \})\s+(local staged\s+staged=\$\(mktemp\))'
replacement1 = r'''\1
    
    # Extract old hash BEFORE processing
    CHK_OLD_HASH=$(grep "checksum:MD5=" "$file" | tail -1 | sed 's/.*checksum:MD5=//' | tr -d '\r')
    
    \2'''
content = re.sub(pattern1, replacement1, content, flags=re.MULTILINE)

# Change 2: Add CHK_WAS_CHANGED comparison and modify echo
pattern2 = r'(hash="\$\{hash,,\}"\s+local prefix\s+prefix=\$\(checksum_comment_prefix "\$file"\)\s+)(# Файл теперь гарантированно заканчивается переносом строки \(EOL\),\s+# поэтому printf безопасно начнет запись с новой строки.\s+printf '%s checksum:MD5=%s' "\$prefix" "\$hash" >> "\$staged"\s+mv "\$staged" "\$file"\s+echo -e "  \$\{C_GRY\}-\$\{C_RST\} File: \$\{C_VAL\}\$\{file\}\$\{C_RST\} \$\{C_GRY\}MD5=\$\{C_KEY\}\$\{hash\}\$\{C_RST\}")'
replacement2 = r'''\1# Compare old vs new hash
    CHK_WAS_CHANGED=0
    if [ -n "$CHK_OLD_HASH" ] && [ "$CHK_OLD_HASH" != "$hash" ]; then
        CHK_WAS_CHANGED=1
    fi
    
    \2
    
    local changed_suffix=""
    [ "$CHK_WAS_CHANGED" -eq 1 ] && changed_suffix=" ${C_ERR}$L_CHKSUM_CHANGED${C_RST}"
    echo -e "  ${C_GRY}-${C_RST} File: ${C_VAL}${file}${C_RST} ${C_GRY}MD5=${C_KEY}${hash}${C_RST}${changed_suffix}"'''
content = re.sub(pattern2, replacement2, content, flags=re.MULTILINE | re.DOTALL)

# Change 3: Add changed counter to do_checksum_all
pattern3 = r'(do_checksum_all\(\) \{\s+local unpacker=""\s+\[ -f "_unpacker\.sh" \] && unpacker="_unpacker\.sh"\s+if \[ -z "\$unpacker" \]; then\s+echo -e "\$\{C_ERR\}\$L_CHKSUM_ERR_NO_UNPACKER\$\{C_RST\}"\s+return 1\s+fi\s+local files\s+files=\(\$\(extract_files_from_unpacker\)\)\s+\[ \$\{#files\[@\]\} -eq 0 \] && \{ echo -e "\$\{C_ERR\}\$L_CHKSUM_ERR_EMPTY\$\{C_RST\}"; return 1; \}\s+echo -e "\$\{C_LBL\}\[CHECKSUM\]\$\{C_RST\} \$\{L_CHKSUM_ALL_START\}"\s+)(local n=0\s+for f in "\$\{files\[@\]\}"; do\s+\[ -f "\$f" \] && add_checksum_to_file "\$f" && \(\(n\+\+\)\)\s+done\s+echo -e "\$\{C_OK\}\$L_CHKSUM_DONE \$n\$\{C_RST\}")'
replacement3 = r'''\1local n=0
    local changed=0
    for f in "${files[@]}"; do
        [ -f "$f" ] && add_checksum_to_file "$f" && ((n++))
        [ "$CHK_WAS_CHANGED" -eq 1 ] && ((changed++))
    done
    echo -e "${C_OK}$L_CHKSUM_DONE $n ${C_GRY}$L_CHKSUM_CHANGED_SUM$changed${C_RST}"'''
content = re.sub(pattern3, replacement3, content, flags=re.MULTILINE | re.DOTALL)

# Write the file back
with open('_Builder.sh', 'w', encoding='utf-8') as f:
    f.write(content)

print("Changes applied to _Builder.sh")
