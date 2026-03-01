#!/usr/bin/env python3
# This script modifies _Builder.sh to add checksum change detection
import re

print("Reading _Builder.sh...")
with open('_Builder.sh', 'r', encoding='utf-8') as f:
    content = f.read()

print("Applying modifications...")

# Mod 1: Add CHK_OLD_HASH after file check
old1 = '[ ! -f "$file" ] && { echo -e "${C_ERR}[SKIP] $file not found${C_RST}"; return 1; }\n    local staged\n    staged=$(mktemp)'
new1 = '''[ ! -f "$file" ] && { echo -e "${C_ERR}[SKIP] $file not found${C_RST}"; return 1; }
    
    # Extract old hash BEFORE processing
    CHK_OLD_HASH=$(grep "checksum:MD5=" "$file" | tail -1 | sed 's/.*checksum:MD5=//' | tr -d '\\r')
    
    local staged
    staged=$(mktemp)'''
content = content.replace(old1, new1)

# Mod 2: Add CHK_WAS_CHANGED after prefix
old2 = '''    local prefix
    prefix=$(checksum_comment_prefix "$file")    
    
    # Файл теперь гарантированно заканчивается переносом строки (EOL),'''
new2 = '''    local prefix
    prefix=$(checksum_comment_prefix "$file")
    
    # Compare old vs new hash
    CHK_WAS_CHANGED=0
    if [ -n "$CHK_OLD_HASH" ] && [ "$CHK_OLD_HASH" != "$hash" ]; then
        CHK_WAS_CHANGED=1
    fi
    
    # Файл теперь гарантированно заканчивается переносом строки (EOL),'''
content = content.replace(old2, new2)

# Mod 3: Change echo statement
old3 = '''    printf '%s checksum:MD5=%s' "$prefix" "$hash" >> "$staged"
    mv "$staged" "$file"
    echo -e "  ${C_GRY}-${C_RST} File: ${C_VAL}${file}${C_RST} ${C_GRY}MD5=${C_KEY}${hash}${C_RST}"'''
new3 = '''    printf '%s checksum:MD5=%s' "$prefix" "$hash" >> "$staged"
    mv "$staged" "$file"
    local changed_suffix=""
    [ "$CHK_WAS_CHANGED" -eq 1 ] && changed_suffix=" ${C_ERR}$L_CHKSUM_CHANGED${C_RST}"
    echo -e "  ${C_GRY}-${C_RST} File: ${C_VAL}${file}${C_RST} ${C_GRY}MD5=${C_KEY}${hash}${C_RST}${changed_suffix}"'''
content = content.replace(old3, new3)

# Mod 4: Add changed counter
old4 = '''    echo -e "${C_LBL}[CHECKSUM]${C_RST} ${L_CHKSUM_ALL_START}"
    local n=0'''
new4 = '''    echo -e "${C_LBL}[CHECKSUM]${C_RST} ${L_CHKSUM_ALL_START}"
    local n=0
    local changed=0'''
content = content.replace(old4, new4)

# Mod 5: Add change check in loop
old5 = '''    for f in "${files[@]}"; do
        [ -f "$f" ] && add_checksum_to_file "$f" && ((n++))
    done'''
new5 = '''    for f in "${files[@]}"; do
        [ -f "$f" ] && add_checksum_to_file "$f" && ((n++))
        [ "$CHK_WAS_CHANGED" -eq 1 ] && ((changed++))
    done'''
content = content.replace(old5, new5)

# Mod 6: Update final echo
old6 = '    echo -e "${C_OK}$L_CHKSUM_DONE $n${C_RST}"'
new6 = '    echo -e "${C_OK}$L_CHKSUM_DONE $n ${C_GRY}$L_CHKSUM_CHANGED_SUM$changed${C_RST}"'
content = content.replace(old6, new6)

print("Writing _Builder.sh...")
with open('_Builder.sh', 'w', encoding='utf-8') as f:
    f.write(content)

print("Done! All modifications applied to _Builder.sh")
