#!/usr/bin/env python3
import sys

# Read the file
with open('_Builder.sh', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find and modify add_checksum_to_file function
# We need to:
# 1. Add CHK_OLD_HASH extraction after line 370
# 2. Add CHK_WAS_CHANGED comparison after hash calculation (around line 404)
# 3. Modify echo statement to include changed_suffix

new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    
    # Change 1: Add CHK_OLD_HASH extraction after "return 1; }"
    if i == 369 and '[ ! -f "$file" ] && { echo -e "${C_ERR}[SKIP] $file not found${C_RST}"; return 1; }' in line:
        new_lines.append(line)
        # Add blank line and CHK_OLD_HASH extraction
        new_lines.append('    \n')
        new_lines.append('    # Extract old hash BEFORE processing\n')
        new_lines.append('    CHK_OLD_HASH=$(grep "checksum:MD5=" "$file" | tail -1 | sed \'s/.*checksum:MD5=//\' | tr -d \'\\r\')\n')
        i += 1
        continue
    
    # Change 2: Add CHK_WAS_CHANGED comparison after prefix line
    # Line 404 is: prefix=$(checksum_comment_prefix "$file")
    if i == 403 and 'prefix=$(checksum_comment_prefix "$file")' in line:
        new_lines.append(line)
        # Add comparison logic
        new_lines.append('    \n')
        new_lines.append('    # Compare old vs new hash\n')
        new_lines.append('    CHK_WAS_CHANGED=0\n')
        new_lines.append('    if [ -n "$CHK_OLD_HASH" ] && [ "$CHK_OLD_HASH" != "$hash" ]; then\n')
        new_lines.append('        CHK_WAS_CHANGED=1\n')
        new_lines.append('    fi\n')
        i += 1
        continue
    
    # Change 3: Modify echo statement to include changed_suffix
    # Replace line 410: echo -e "  ${C_GRY}-${C_RST} File: ${C_VAL}${file}${C_RST} ${C_GRY}MD5=${C_KEY}${hash}${C_RST}"
    if i == 409 and 'echo -e "  ${C_GRY}-${C_RST} File: ${C_VAL}${file}${C_RST} ${C_GRY}MD5=${C_KEY}${hash}${C_RST}"' in line:
        # Replace with two lines: changed_suffix definition and modified echo
        new_lines.append('    local changed_suffix=""\n')
        new_lines.append('    [ "$CHK_WAS_CHANGED" -eq 1 ] && changed_suffix=" ${C_ERR}$L_CHKSUM_CHANGED${C_RST}"\n')
        new_lines.append('    echo -e "  ${C_GRY}-${C_RST} File: ${C_VAL}${file}${C_RST} ${C_GRY}MD5=${C_KEY}${hash}${C_RST}${changed_suffix}"\n')
        i += 1
        continue
    
    # Change 4: Modify do_checksum_all function to add changed counter
    # Line 431: local n=0
    if i == 430 and 'local n=0' in line and i > 420:
        new_lines.append(line)
        new_lines.append('    local changed=0\n')
        i += 1
        continue
    
    # Change 5: Add change check in the for loop
    # Line 433: [ -f "$f" ] && add_checksum_to_file "$f" && ((n++))
    if i == 432 and '[ -f "$f" ] && add_checksum_to_file "$f" && ((n++))' in line:
        new_lines.append(line)
        new_lines.append('        [ "$CHK_WAS_CHANGED" -eq 1 ] && ((changed++))\n')
        i += 1
        continue
    
    # Change 6: Modify final echo to include changed count
    # Line 435: echo -e "${C_OK}$L_CHKSUM_DONE $n${C_RST}"
    if i == 434 and 'echo -e "${C_OK}$L_CHKSUM_DONE $n${C_RST}"' in line and i > 420:
        new_lines.append('    echo -e "${C_OK}$L_CHKSUM_DONE $n ${C_GRY}$L_CHKSUM_CHANGED_SUM$changed${C_RST}"\n')
        i += 1
        continue
    
    new_lines.append(line)
    i += 1

# Write back
with open('_Builder.sh', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Changes applied to _Builder.sh")
