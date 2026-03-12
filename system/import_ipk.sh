#!/bin/bash

# file : system/import_ipk.sh
# Скрипт импорта IPK v2.7 (version ipk/apk fix)
# Портировано с PowerShell на Bash
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
for cmd in curl jq tar ar; do
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
echo -e "  IPK IMPORT WIZARD v2.7 [$TARGET_ARCH] [Source Mode]"
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
    PKG_VERSION="binary"
    PKG_ARCH=""
    PKG_DEPS=""
    POSTINST_CONTENT=""

    if [ "$IS_APK" = true ]; then
        # 2a. Распаковка APK (метаданные)
        tar -xf "$IPK_PATH" -C "$TEMP_DIR/unpack" ".PKGINFO" ".post-install" 2>/dev/null || tar -xf "$IPK_PATH" -C "$TEMP_DIR/unpack" 2>/dev/null
        
        PKGINFO_FILE="$TEMP_DIR/unpack/.PKGINFO"
        if [ -f "$PKGINFO_FILE" ]; then
            PKG_NAME=$(grep "^pkgname = " "$PKGINFO_FILE" | sed 's/^pkgname = //' | tr -d '\r ')
            PKG_VERSION=$(grep "^pkgver = " "$PKGINFO_FILE" | sed 's/^pkgver = //' | tr -d '\r ')
            PKG_ARCH=$(grep "^arch = " "$PKGINFO_FILE" | sed 's/^arch = //' | tr -d '\r ')
            
            # Парсинг зависимостей (исключаем виртуальные so:, cmd:, pc:)
            RAW_DEPS=$(grep "^depend = " "$PKGINFO_FILE" | sed 's/^depend = //' | tr -d '\r')
            for dep in $RAW_DEPS; do
                if [[ "$dep" =~ ^(so|cmd|pc): ]]; then continue; fi
                [ -z "$PKG_DEPS" ] && PKG_DEPS="+$dep" || PKG_DEPS="$PKG_DEPS +$dep"
            done
        fi
        
        if [ -f "$TEMP_DIR/unpack/.post-install" ]; then
            POSTINST_CONTENT=$(sed 's/^#!.*//' "$TEMP_DIR/unpack/.post-install" | sed 's/\$/\\$\\$/g')
        fi
    else
        # 2b. Распаковка IPK
        if tar -tf "$IPK_PATH" &>/dev/null; then
            tar -xf "$IPK_PATH" -C "$TEMP_DIR/unpack"
        else
            cd "$TEMP_DIR/unpack" && ar x "../../../$IPK_PATH" && cd - > /dev/null
        fi

        if [ -f "$TEMP_DIR/unpack/control.tar.gz" ]; then
            tar -xf "$TEMP_DIR/unpack/control.tar.gz" -C "$TEMP_DIR/control_data"
        else
            echo -e "    ${C_RED}[!] control.tar.gz not found inside IPK.${C_RST}"
            continue
        fi

        # Парсинг Control файла
        CONTROL_FILE="$TEMP_DIR/control_data/control"
        if [ -f "$CONTROL_FILE" ]; then
            PKG_NAME=$(grep "^Package: " "$CONTROL_FILE" | sed 's/^Package: //' | tr -d '\r ')
            PKG_VERSION=$(grep "^Version: " "$CONTROL_FILE" | sed 's/^Version: //' | tr -d '\r ')
            PKG_ARCH=$(grep "^Architecture: " "$CONTROL_FILE" | sed 's/^Architecture: //' | tr -d '\r ')
            
            RAW_DEPS=$(grep "^Depends: " "$CONTROL_FILE" | sed 's/^Depends: //' | tr -d '\r')
            CLEAN_DEPS=$(echo "$RAW_DEPS" | sed 's/,/ /g' \
                | sed 's/libnetfilter-queue1/libnetfilter-queue/g' \
                | sed 's/libnfnetlink0/libnfnetlink/g' \
                | sed 's/libopenssl1.1/libopenssl/g')
            
            for dep in $CLEAN_DEPS; do
                [[ "$dep" == "libc" || "$dep" == "libgcc" || -z "$dep" ]] && continue
                [ -z "$PKG_DEPS" ] && PKG_DEPS="+$dep" || PKG_DEPS="$PKG_DEPS +$dep"
            done
        fi

        if [ -f "$TEMP_DIR/control_data/postinst" ]; then
            POSTINST_CONTENT=$(sed 's/^#!.*//' "$TEMP_DIR/control_data/postinst" | sed 's/\$/\\$\\$/g')
        fi
    fi

    if [ -z "$PKG_NAME" ]; then
        echo -e "    ${C_RED}[!] Error: Could not parse package name. Skipping.${C_RST}"
        continue
    fi
    [ -z "$PKG_VERSION" ] && PKG_VERSION="binary"

    # 6. ВАЛИДАЦИЯ АРХИТЕКТУРЫ
    if [ "$PKG_ARCH" == "all" ]; then
        echo -e "    Architecture: all (Universal) - ${C_GRN}OK${C_RST}"
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

    # 7. Логика перезаписи
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

    # 8. Финализация импорта
    mkdir -p "$TARGET_PKG_DIR"
    if [ "$IS_APK" = true ]; then
        cp "$IPK_PATH" "$TARGET_PKG_DIR/data.apk"
    else
        if [ -f "$TEMP_DIR/unpack/data.tar.gz" ]; then
            cp "$TEMP_DIR/unpack/data.tar.gz" "$TARGET_PKG_DIR/data.tar.gz"
        else
            echo -e "    ${C_RED}[!] Error: data.tar.gz not found!${C_RST}"
            continue
        fi
    fi

    # 9. ГЕНЕРАЦИЯ MAKEFILE
    cat <<EOF > "$TARGET_PKG_DIR/Makefile"
include \$(TOPDIR)/rules.mk

PKG_NAME:=$PKG_NAME
PKG_VERSION:=$PKG_VERSION
PKG_RELEASE:=1

include \$(INCLUDE_DIR)/package.mk

STRIP:=:
PATCHELF:=:

define Package/\$(PKG_NAME)
  SECTION:=utils
  CATEGORY:=Custom-Packages
  TITLE:=Binary wrapper for $PKG_NAME
  DEPENDS:=$PKG_DEPS
endef

define Build/Prepare
	mkdir -p \$(PKG_BUILD_DIR)[ -f ./data.tar.gz ] && cp ./data.tar.gz \$(PKG_BUILD_DIR)/ || true ; \
	[ -f ./data.apk ] && cp ./data.apk \$(PKG_BUILD_DIR)/ || true
endef

define Build/Compile
	# Nothing to compile
endef

define Package/\$(PKG_NAME)/install
	mkdir -p \$(1)
    if [ -f \$(PKG_BUILD_DIR)/data.tar.gz ]; then \
		tar -xf \$(PKG_BUILD_DIR)/data.tar.gz -C \$(1); \
	elif [ -f \$(PKG_BUILD_DIR)/data.apk ]; then \
		tar -xf \$(PKG_BUILD_DIR)/data.apk -C \$(1) --exclude=.PKGINFO --exclude=.SIGN.* --exclude=.post-install --exclude=.pre-install; \\
	fi
	[ -d \$(1)/etc/init.d ] && chmod +x \$(1)/etc/init.d/* || true
	[ -d \$(1)/usr/bin ] && chmod +x \$(1)/usr/bin/* || true
	[ -d \$(1)/usr/sbin ] && chmod +x \$(1)/usr/sbin/* || true
	[ -d \$(1)/lib/upgrade/keep.d ] && chmod 644 \$(1)/lib/upgrade/keep.d/* || true
endef

define Package/\$(PKG_NAME)/postinst
#!/bin/sh
if [ -z "\$\$IPKG_INSTROOT" ]; then
$POSTINST_CONTENT
	:
fi
exit 0
endef

\$(eval \$(call BuildPackage,\$(PKG_NAME)))
EOF

    # Принудительно устанавливаем Unix-окончания
    sed -i 's/\r$//' "$TARGET_PKG_DIR/Makefile"
    
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
[[ "$LANG" == *"ru"* ]] && echo -e "\n Нажмите Enter, чтобы продолжить..." || echo -e "\n Press Enter to continue..."
read -r