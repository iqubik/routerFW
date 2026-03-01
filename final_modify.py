#!/usr/bin/env python3
import sys

def modify_builder_sh():
    """Modify _Builder.sh to add checksum change detection"""
    print("Reading _Builder.sh...")
    with open('_Builder.sh', 'r', encoding='utf-8') as f:
        content = f.read()

    print("Applying modifications to _Builder.sh...")

    # Mod 1: Add CHK_OLD_HASH after file check
    old1 = '''[ ! -f "$file" ] && { echo -e "${C_ERR}[SKIP] $file not found${C_RST}"; return 1; }
    local staged
    staged=$(mktemp)'''
    new1 = '''[ ! -f "$file" ] && { echo -e "${C_ERR}[SKIP] $file not found${C_RST}"; return 1; }

    # Extract old hash BEFORE processing
    CHK_OLD_HASH=$(grep "checksum:MD5=" "$file" | tail -1 | sed 's/.*checksum:MD5=//' | tr -d '\\r')

    local staged
    staged=$(mktemp)'''
    if old1 in content:
        content = content.replace(old1, new1)
        print("✓ Added CHK_OLD_HASH extraction")
    else:
        print("✗ Could not find pattern for CHK_OLD_HASH")

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
    if old2 in content:
        content = content.replace(old2, new2)
        print("✓ Added CHK_WAS_CHANGED comparison")
    else:
        print("✗ Could not find pattern for CHK_WAS_CHANGED")

    # Mod 3: Modify echo to include changed_suffix
    old3 = '''    printf '%s checksum:MD5=%s' "$prefix" "$hash" >> "$staged"
    mv "$staged" "$file"
    echo -e "  ${C_GRY}-${C_RST} File: ${C_VAL}${file}${C_RST} ${C_GRY}MD5=${C_KEY}${hash}${C_RST}"'''
    new3 = '''    printf '%s checksum:MD5=%s' "$prefix" "$hash" >> "$staged"
    mv "$staged" "$file"
    local changed_suffix=""
    [ "$CHK_WAS_CHANGED" -eq 1 ] && changed_suffix=" ${C_ERR}$L_CHKSUM_CHANGED${C_RST}"
    echo -e "  ${C_GRY}-${C_RST} File: ${C_VAL}${file}${C_RST} ${C_GRY}MD5=${C_KEY}${hash}${C_RST}${changed_suffix}"'''
    if old3 in content:
        content = content.replace(old3, new3)
        print("✓ Modified echo statement to include changed_suffix")
    else:
        print("✗ Could not find pattern for echo modification")

    # Mod 4: Add changed counter
    old4 = '''    echo -e "${C_LBL}[CHECKSUM]${C_RST} ${L_CHKSUM_ALL_START}"
    local n=0'''
    new4 = '''    echo -e "${C_LBL}[CHECKSUM]${C_RST} ${L_CHKSUM_ALL_START}"
    local n=0
    local changed=0'''
    if old4 in content:
        content = content.replace(old4, new4)
        print("✓ Added changed counter")
    else:
        print("✗ Could not find pattern for changed counter")

    # Mod 5: Add change check in loop
    old5 = '''    for f in "${files[@]}"; do
        [ -f "$f" ] && add_checksum_to_file "$f" && ((n++))
    done'''
    new5 = '''    for f in "${files[@]}"; do
        [ -f "$f" ] && add_checksum_to_file "$f" && ((n++))
        [ "$CHK_WAS_CHANGED" -eq 1 ] && ((changed++))
    done'''
    if old5 in content:
        content = content.replace(old5, new5)
        print("✓ Added change check in loop")
    else:
        print("✗ Could not find pattern for loop change check")

    # Mod 6: Update final echo
    old6 = '''    echo -e "${C_OK}$L_CHKSUM_DONE $n${C_RST}"'''
    new6 = '''    echo -e "${C_OK}$L_CHKSUM_DONE $n ${C_GRY}$L_CHKSUM_CHANGED_SUM$changed${C_RST}"'''
    if old6 in content:
        content = content.replace(old6, new6)
        print("✓ Updated final echo to include changed count")
    else:
        print("✗ Could not find pattern for final echo")

    print("\nWriting modified _Builder.sh...")
    with open('_Builder.sh', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✓ Successfully wrote _Builder.sh\n")

def modify_builder_bat():
    """Modify _Builder.bat to add checksum change detection"""
    print("Reading _Builder.bat...")
    with open('_Builder.bat', 'r', encoding='utf-8') as f:
        content = f.read()

    print("Applying modifications to _Builder.bat...")

    # Mod 1: Add CHK_OLD_HASH extraction at start of ADD_CHECKSUM_TO_FILE
    old1 = '''set "CHK_FILE=%~1"
if not exist "!CHK_FILE!" exit /b 1
set "CHK_STAGED=%TEMP%\\builder_chksum_%RANDOM%.tmp"'''
    new1 = '''set "CHK_FILE=%~1"
if not exist "!CHK_FILE!" exit /b 1

:: Extract old hash BEFORE processing
set "CHK_OLD_HASH="
for /f "tokens=*" %%a in ('findstr "checksum:MD5=" "!CHK_FILE!" 2^>nul') do set "CHK_OLD_HASH=%%a"
if defined CHK_OLD_HASH set "CHK_OLD_HASH=!CHK_OLD_HASH:*checksum:MD5=!"

set "CHK_STAGED=%TEMP%\\builder_chksum_%RANDOM%.tmp"'''
    if old1 in content:
        content = content.replace(old1, new1)
        print("✓ Added CHK_OLD_HASH extraction in .bat")
    else:
        print("✗ Could not find pattern for CHK_OLD_HASH in .bat")

    # Mod 2: Add CHK_WAS_CHANGED comparison after hash calculation
    old2 = ''':CHK_HASH_DONE
if not defined CHK_HASH set "CHK_HASH=d41d8cd98f00b204e9800998ecf8427e"
set "CHK_PREFIX=#"'''
    new2 = ''':CHK_HASH_DONE
if not defined CHK_HASH set "CHK_HASH=d41d8cd98f00b204e9800998ecf8427e"

:: Compare old vs new hash
set "CHK_WAS_CHANGED=0"
if defined CHK_OLD_HASH if /i not "!CHK_OLD_HASH!"=="!CHK_HASH!" set "CHK_WAS_CHANGED=1"

set "CHK_PREFIX=#"'''
    if old2 in content:
        content = content.replace(old2, new2)
        print("✓ Added CHK_WAS_CHANGED comparison in .bat")
    else:
        print("✗ Could not find pattern for CHK_WAS_CHANGED in .bat")

    # Mod 3: Modify echo to include changed_suffix
    old3 = '''copy /y "!CHK_STAGED!" "!CHK_FILE!" >nul 2>&1
del /q "!CHK_STAGED!" 2>nul
echo   %C_GRY%-%C_RST% File: %C_VAL%!CHK_FILE!%C_RST% %C_GRY%MD5=%C_KEY%!CHK_HASH!%C_RST%'''
    new3 = '''copy /y "!CHK_STAGED!" "!CHK_FILE!" >nul 2>&1
del /q "!CHK_STAGED!" 2>nul
set "CHK_CHANGED_SUFFIX="
if "!CHK_WAS_CHANGED!"=="1" set "CHK_CHANGED_SUFFIX= %C_ERR%!L_CHKSUM_CHANGED!%C_RST%"
echo   %C_GRY%-%C_RST% File: %C_VAL%!CHK_FILE!%C_RST% %C_GRY%MD5=%C_KEY%!CHK_HASH!%C_RST%!CHK_CHANGED_SUFFIX!'''
    if old3 in content:
        content = content.replace(old3, new3)
        print("✓ Modified echo statement in .bat")
    else:
        print("✗ Could not find pattern for echo in .bat")

    # Mod 4: Add CHK_CHANGED counter
    old4 = '''echo %C_LBL%[CHECKSUM]%C_RST% %L_CHKSUM_ALL_START%
set "CHK_N=0"'''
    new4 = '''echo %C_LBL%[CHECKSUM]%C_RST% %L_CHKSUM_ALL_START%
set "CHK_N=0"
set "CHK_CHANGED=0"'''
    if old4 in content:
        content = content.replace(old4, new4)
        print("✓ Added CHK_CHANGED counter in .bat")
    else:
        print("✗ Could not find pattern for CHK_CHANGED in .bat")

    # Mod 5: Add change check in loop
    old5 = '''        if exist "!line!" (
            call :ADD_CHECKSUM_TO_FILE "!line!"
            if not errorlevel 1 set /a CHK_N+=1
        )'''
    new5 = '''        if exist "!line!" (
            call :ADD_CHECKSUM_TO_FILE "!line!"
            if not errorlevel 1 set /a CHK_N+=1
            if "!CHK_WAS_CHANGED!"=="1" set /a CHK_CHANGED+=1
        )'''
    if old5 in content:
        content = content.replace(old5, new5)
        print("✓ Added change check in .bat loop")
    else:
        print("✗ Could not find pattern for loop in .bat")

    # Mod 6: Update final echo
    old6 = '''echo !C_OK!!L_CHKSUM_DONE! !CHK_N!!C_RST!'''
    new6 = '''echo !C_OK!!L_CHKSUM_DONE! !CHK_N! %C_GRY%!L_CHKSUM_CHANGED_SUM!!CHK_CHANGED!%C_RST%'''
    if old6 in content:
        content = content.replace(old6, new6)
        print("✓ Updated final echo in .bat")
    else:
        print("✗ Could not find pattern for final echo in .bat")

    print("\nWriting modified _Builder.bat...")
    with open('_Builder.bat', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✓ Successfully wrote _Builder.bat\n")

if __name__ == '__main__':
    try:
        modify_builder_sh()
        modify_builder_bat()
        print("\n" + "="*60)
        print("ALL MODIFICATIONS COMPLETED SUCCESSFULLY!")
        print("="*60)
    except Exception as e:
        print(f"\nError: {e}", file=sys.stderr)
        sys.exit(1)
