#!/bin/bash
# file : system/import_ipk.sh
SCRIPT_VERSION="3.0"
# Скрипт импорта IPK/APK (Синхронизирован с PS1 v3.0)

# --- ПАРАМЕТРЫ ---
PROFILE_ID=$1
TARGET_ARCH=$2

# --- ЦВЕТА ---
C_CYAN='\033[0;36m'
C_YEL='\033[1;33m'
C_RED='\033[0;31m'
C_GRN='\033[0;32m'
C_GRY='\033[0;90m'
C_WHT='\033[1;37m'
C_RST='\033[0m'

# --- ПРОВЕРКА ЗАВИСИМОСТЕЙ ---
for cmd in curl jq tar ar docker date; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${C_RED}Ошибка: утилита '$cmd' не найдена. Установите её (sudo apt install binutils)${C_RST}"
    fi
done

# --- ИНИЦИАЛИЗАЦИЯ ПУТЕЙ ---
if [ -n "$PROFILE_ID" ]; then
    IPK_DIR="custom_packages/$PROFILE_ID"
    OUT_DIR="src_packages/$PROFILE_ID"
else
    IPK_DIR="custom_packages"
    OUT_DIR="src_packages"
fi

TEMP_DIR="system/.ipk_temp"
OVERWRITE_ALL=false
IMPORTED_COUNT=0

echo -e "\n${C_CYAN}==========================================================${C_RST}"
echo -e "  IPK IMPORT WIZARD v$SCRIPT_VERSION [$TARGET_ARCH] [Source Mode]"
echo -e "${C_CYAN}==========================================================${C_RST}"

PROFILE_DISP="${PROFILE_ID:-GLOBAL}"
echo -ne " [CONTEXT] ${C_GRY}Profile: ${C_WHT}$PROFILE_DISP${C_RST}\n"

echo -ne " [TARGET]  ${C_GRY}Arch   : ${C_RST}"
if [ -n "$TARGET_ARCH" ]; then
    echo -e "${C_GRN}$TARGET_ARCH${C_RST}"
else
    echo -e "${C_RED}NOT DEFINED (Validation Disabled)${C_RST}"
fi

echo -e " [PATHS]   ${C_GRY}Source : $IPK_DIR${C_RST}"
echo -e "           ${C_GRY}Output : $OUT_DIR${C_RST}"
echo -e "           ${C_GRY}Temp   : $TEMP_DIR${C_RST}"
echo -e "${C_CYAN}==========================================================${C_RST}"

# --- ПРОВЕРКИ ОКРУЖЕНИЯ ---
if [ ! -d "$IPK_DIR" ]; then
    echo -e "${C_YEL}[!] Folder $IPK_DIR not found.${C_RST}"
    exit 0
fi

# Собираем список IPK и APK
shopt -s nullglob
IPK_FILES=("$IPK_DIR"/*.ipk "$IPK_DIR"/*.apk)
shopt -u nullglob

if [ ${#IPK_FILES[@]} -eq 0 ]; then
    echo -e "${C_YEL}[!] No .ipk or .apk files found in $IPK_DIR${C_RST}"
    exit 0
fi

mkdir -p "$OUT_DIR"

for IPK_PATH in "${IPK_FILES[@]}"; do
    IPK_NAME=$(basename "$IPK_PATH")
    echo -e "${C_CYAN}[+] Processing: $IPK_NAME...${C_RST}"
    
    IS_APK=false
    [[ "$IPK_NAME" == *.apk ]] && IS_APK=true

    # 1. Подготовка темпа
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR/unpack"
    mkdir -p "$TEMP_DIR/control_data"

    PKG_NAME=""
    PKG_VERSION=""
    PKG_ARCH=""
    PKG_DEPS=""
    POSTINST_CONTENT=""
    PRERM_CONTENT=""

    if [ "$IS_APK" = true ]; then
        # 2a. Распаковка APK v3 (через Docker/apk-tools)
        echo -e "    ${C_CYAN}[*] APK v3 detected. Using Docker 'apk adbdump'...${C_RST}"
        
        APK_ABS_DIR=$(cd "$(dirname "$IPK_PATH")" && pwd)
        APK_FILE=$(basename "$IPK_PATH")
        
        ADBDUMP_OUT=$(docker run --rm -v "$APK_ABS_DIR:/data" alpine:latest apk adbdump "/data/$APK_FILE" 2>/dev/null)
        
        if [ -n "$ADBDUMP_OUT" ]; then
            PKG_NAME=$(echo "$ADBDUMP_OUT" | grep -m 1 "^  name: " | sed 's/.*name: //' | tr -d '\r')
            PKG_VERSION=$(echo "$ADBDUMP_OUT" | grep -m 1 "^  version: " | sed 's/.*version: //' | tr -d '\r')
            PKG_ARCH=$(echo "$ADBDUMP_OUT" | grep -m 1 "^  arch: " | sed 's/.*arch: //' | tr -d '\r')
            
            # Парсинг зависимостей
            RAW_DEPS=$(echo "$ADBDUMP_OUT" | awk '
              /^  depends:/ {in_deps=1; next}
              in_deps {
                if (match($0, /^    - /)) { sub(/^    - /, ""); print }
                else if (match($0, /^  [a-z]/) || match($0, /^#/)) { in_deps=0 }
              }
            ')
            for dep in $RAW_DEPS; do
                if [[ "$dep" =~ ^(so|cmd|pc): ]]; then continue; fi
                [ -z "$dep" ] && continue
                [ -z "$PKG_DEPS" ] && PKG_DEPS="+$dep" || PKG_DEPS="$PKG_DEPS +$dep"
            done
            
            # Извлечение скриптов
            POSTINST_CONTENT=$(echo "$ADBDUMP_OUT" | awk '/^  post-install: \|/ {in_s=1; next} in_s {if (match($0, /^    /)) {sub(/^    /, ""); print} else if ($0 ~ /^[ \t]*$/) {print ""} else if (match($0, /^  [a-z]/)) {in_s=0}}')
            PRERM_CONTENT=$(echo "$ADBDUMP_OUT" | awk '/^  pre-deinstall: \|/ {in_s=1; next} in_s {if (match($0, /^    /)) {sub(/^    /, ""); print} else if ($0 ~ /^[ \t]*$/) {print ""} else if (match($0, /^  [a-z]/)) {in_s=0}}')
            
            echo -e "    ${C_GRN}[+] Metadata extracted successfully via Docker.${C_RST}"
        else
            echo -e "    ${C_RED}[!] Docker command failed. Fallback to Smart Guess...${C_RST}"
        fi
    else
        # 2b. Распаковка IPK
        tar -xf "$IPK_PATH" -C "$TEMP_DIR/unpack" 2>/dev/null
        if [ -f "$TEMP_DIR/unpack/control.tar.gz" ]; then
            tar -xf "$TEMP_DIR/unpack/control.tar.gz" -C "$TEMP_DIR/control_data"
            CONTROL_FILE="$TEMP_DIR/control_data/control"
            if [ -f "$CONTROL_FILE" ]; then
                PKG_NAME=$(grep "^Package: " "$CONTROL_FILE" | sed 's/^Package: //' | tr -d '\r ')
                PKG_VERSION=$(grep "^Version: " "$CONTROL_FILE" | sed 's/^Version: //' | tr -d '\r ')
                PKG_ARCH=$(grep "^Architecture: " "$CONTROL_FILE" | sed 's/^Architecture: //' | tr -d '\r ')
                
                CLEAN_DEPS=$(grep "^Depends: " "$CONTROL_FILE" | sed 's/^Depends: //' | tr -d '\r' | sed 's/,/ /g' \
                    | sed 's/libnetfilter-queue1/libnetfilter-queue/g' \
                    | sed 's/libnfnetlink0/libnfnetlink/g' \
                    | sed 's/libopenssl1.1/libopenssl/g')
                
                for dep in $CLEAN_DEPS; do
                    [ -z "$dep" ] && continue
                    [ -z "$PKG_DEPS" ] && PKG_DEPS="+$dep" || PKG_DEPS="$PKG_DEPS +$dep"
                done
            fi
            [ -f "$TEMP_DIR/control_data/postinst" ] && POSTINST_CONTENT=$(cat "$TEMP_DIR/control_data/postinst")
            [ -f "$TEMP_DIR/control_data/postinst-pkg" ] && POSTINST_CONTENT="$POSTINST_CONTENT"$'\n'"$(cat "$TEMP_DIR/control_data/postinst-pkg")"
            [ -f "$TEMP_DIR/control_data/prerm" ] && PRERM_CONTENT=$(cat "$TEMP_DIR/control_data/prerm")
        fi
    fi

    # --- 4.5 СМАРТ-ФОЛЛБЕК ---
    if [ -z "$PKG_NAME" ]; then
        echo -e "    ${C_YEL}[!] Activating Smart Filename Fallback...${C_RST}"
        if [[ "$IPK_NAME" =~ ^(.*)-v?([0-9].*)\.(apk|ipk)$ ]]; then
            PKG_NAME="${BASH_REMATCH[1]}"
            PKG_VERSION="${BASH_REMATCH[2]}"
        else
            PKG_NAME="${IPK_NAME%.*}"
            PKG_VERSION="binary"
        fi
        PKG_ARCH=${TARGET_ARCH:-all}
        echo -e "    ${C_GRN}[+] Guessed Name: $PKG_NAME | Ver: $PKG_VERSION${C_RST}"
    fi
    [ -z "$PKG_VERSION" ] && PKG_VERSION="binary"

    # --- 4.7 НОРМАЛИЗАЦИЯ ВЕРСИИ И РЕЛИЗА ---
    PKG_RELEASE="1"
    if [[ "$PKG_VERSION" == *-* ]]; then
        TEMP_REL="${PKG_VERSION##*-}"
        PKG_VERSION="${PKG_VERSION%-*}"
        PKG_RELEASE=$(echo "$TEMP_REL" | tr -dc '0-9')
        [ -z "$PKG_RELEASE" ] && PKG_RELEASE="1"
    fi

    # --- 5. ВАЛИДАЦИЯ АРХИТЕКТУРЫ ---
    if [ "$PKG_ARCH" == "all" ] || [ "$PKG_ARCH" == "noarch" ]; then
        echo -e "    Architecture: $PKG_ARCH (Universal) - ${C_GRN}OK${C_RST}"
    elif [ -n "$TARGET_ARCH" ]; then
        if [ "$PKG_ARCH" == "$TARGET_ARCH" ]; then
            echo -e "    Architecture: $PKG_ARCH (Match) - ${C_GRN}OK${C_RST}"
        else
            echo -e "    ${C_RED}----------------------------------------------------------"
            echo -e "    CRITICAL ERROR: ARCHITECTURE MISMATCH!"
            echo -e "    Package: $PKG_ARCH"
            echo -e "    Profile: $TARGET_ARCH"
            echo -e "    ----------------------------------------------------------${C_RST}"
            echo -e "    ${C_GRY}[SKIP] Import of $PKG_NAME blocked to prevent bricking.${C_RST}"
            continue
        fi
    else
        echo -e "    Architecture: $PKG_ARCH ${C_YEL}(Unchecked)${C_RST}"
        echo -ne "    No arch in profile. Continue anyway?[Y/N]: "
        read -r confirm
        [[ ! "$confirm" =~ ^[Yy]$ ]] && continue
    fi

    # --- 6. ОБРАБОТКА СКРИПТОВ ---
    POSTINST_BLOCK=""
    if [ "$IS_APK" = false ] && [ -n "$(echo "$POSTINST_CONTENT" | tr -d '[:space:]')" ]; then        
        CLEAN_POST=$(echo "$POSTINST_CONTENT" | sed '/^#!/d' | sed 's/\$/$$/g' | sed 's/default_postinst \$\$0 \$\$@/&\n\n/')
        read -r -d '' POSTINST_BLOCK << EOP
define Package/\$(PKG_NAME)/postinst
#!/bin/sh
$CLEAN_POST
endef
EOP
    elif [ "$IS_APK" = false ]; then
        read -r -d '' POSTINST_BLOCK << EOP
define Package/\$(PKG_NAME)/postinst
#!/bin/sh
:
endef
EOP
    fi

    PRERM_BLOCK=""
    if [ "$IS_APK" = false ] && [ -n "$(echo "$PRERM_CONTENT" | tr -d '[:space:]')" ]; then
        CLEAN_PRE=$(echo "$PRERM_CONTENT" | sed '/^#!/d' | sed 's/\$/$$/g')
        read -r -d '' PRERM_BLOCK << EOP
define Package/\$(PKG_NAME)/prerm
#!/bin/sh
$CLEAN_PRE
exit 0
endef
EOP
    fi

    # --- 7. ЛОГИКА ПЕРЕЗАПИСИ ---
    TARGET_PKG_DIR="$OUT_DIR/$PKG_NAME"
    if [ -d "$TARGET_PKG_DIR" ]; then
        if [ "$OVERWRITE_ALL" = false ]; then
            echo -ne "    ${C_GRY}[?] Package '$PKG_NAME' already exists. Overwrite? [Y/N/A]: ${C_RST}"
            read -r choice
            case "$choice" in
                [Aa]) OVERWRITE_ALL=true ;;
                [Yy]) rm -rf "$TARGET_PKG_DIR" ;;
                *) echo "    Skipping."; continue ;;
            esac
        else
            rm -rf "$TARGET_PKG_DIR"
        fi
    fi

    # --- 8. ФИНАЛИЗАЦИЯ И УСТАНОВКА ---
    mkdir -p "$TARGET_PKG_DIR"
    INSTALL_BLOCK=""
    if [ "$IS_APK" = true ]; then
        cp "$IPK_PATH" "$TARGET_PKG_DIR/data.apk"
        read -r -d '' INSTALL_BLOCK << EOP
define Package/\$(PKG_NAME)/install
	\$(INSTALL_DIR) \$(1)/usr/lib/apk
	\$(INSTALL_BIN) \$(PKG_BUILD_DIR)/data.apk \$(1)/usr/lib/apk/\$(PKG_NAME).apk
endef
EOP
    else
        [ -f "$TEMP_DIR/unpack/data.tar.gz" ] && cp "$TEMP_DIR/unpack/data.tar.gz" "$TARGET_PKG_DIR/data.tar.gz"
        read -r -d '' INSTALL_BLOCK << EOP
define Package/\$(PKG_NAME)/install
	mkdir -p \$(1)
	if [ -f \$(PKG_BUILD_DIR)/data.tar.gz ]; then \\
		tar -xf \$(PKG_BUILD_DIR)/data.tar.gz -C \$(1); \\
	fi
	# Принудительная правка прав
	[ -d \$(1)/etc/init.d ] && chmod +x \$(1)/etc/init.d/* || true
	[ -d \$(1)/usr/bin ] && chmod +x \$(1)/usr/bin/* || true
	[ -d \$(1)/usr/sbin ] && chmod +x \$(1)/usr/sbin/* || true
	[ -d \$(1)/lib/upgrade/keep.d ] && chmod 644 \$(1)/lib/upgrade/keep.d/* || true
endef
EOP
    fi

    # --- 9. ГЕНЕРАЦИЯ MAKEFILE ---
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    {
    echo "# Generated by import_ipk.sh  v$SCRIPT_VERSION on $TIMESTAMP"
    echo ""
    cat <<EOF
include \$(TOPDIR)/rules.mk

PKG_NAME:=$PKG_NAME
PKG_VERSION:=$PKG_VERSION
PKG_RELEASE:=$PKG_RELEASE

include \$(INCLUDE_DIR)/package.mk

STRIP:=:
PATCHELF:=:

define Package/\$(PKG_NAME)
  SECTION:=utils
  CATEGORY:=Custom-Packages
  TITLE:=Binary wrapper for $PKG_NAME
EOF
    # Вставляем DEPENDS только если он не пустой (без лишних переносов строк)
    [ -n "$PKG_DEPS" ] && echo "  DEPENDS:=$PKG_DEPS"
    cat <<EOF
endef

define Build/Prepare
	mkdir -p \$(PKG_BUILD_DIR)
	[ -f ./data.tar.gz ] && cp ./data.tar.gz \$(PKG_BUILD_DIR)/ || true
	[ -f ./data.apk ] && cp ./data.apk \$(PKG_BUILD_DIR)/ || true
endef

define Build/Compile
	# Nothing to compile
endef

$INSTALL_BLOCK

$POSTINST_BLOCK

$PRERM_BLOCK

\$(eval \$(call BuildPackage,\$(PKG_NAME)))
EOF
    } > "$TARGET_PKG_DIR/Makefile"
    
    ((IMPORTED_COUNT++))
    echo -e "    ${C_GRN}[OK] Successfully imported.${C_RST}\n"
done

# Очистка
rm -rf "$TEMP_DIR"
echo -e "${C_CYAN}==========================================================${C_RST}"
echo -e "  DONE: $IMPORTED_COUNT packages imported."
[ -n "$PROFILE_ID" ] && echo -e "  Location: $OUT_DIR"
echo -e "${C_CYAN}==========================================================${C_RST}"

# Авто-определение языка для паузы
[[ "$LANG" == *"ru"* ]] && echo -ne "\n Нажмите Enter..." || echo -ne "\n Press Enter..."
read -r
# checksum:MD5=e0422ac45f185e6d0584d628b49fb05f