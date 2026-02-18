#!/bin/bash

# file: system/create_profile.sh
# =========================================================
#  OpenWrt/ImmortalWrt Universal Profile Creator
#  Bash Version 2.30 (Mirrors fix)
# =========================================================

# --- ЦВЕТА ---
C_CYAN='\033[0;36m'
C_YEL='\033[1;33m'
C_RED='\033[0;31m'
C_GRN='\033[0;32m'
C_GRY='\033[0;90m'
C_MAG='\033[0;35m'
C_RST='\033[0m'

# --- ПРОВЕРКА ЗАВИСИМОСТЕЙ ---
for cmd in curl jq; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${C_RED}Error: '$cmd' not found. Install it (sudo apt install $cmd)${C_RST}"
        exit 1
    fi
done

# --- ЛОКАЛИЗАЦИЯ ---
FORCE_LANG="AUTO"
# Простая проверка локали в Linux
DetectedLang="EN"
[[ "$LANG" == *"ru"* ]] && DetectedLang="RU"

if [ "$FORCE_LANG" != "AUTO" ]; then Lang="$FORCE_LANG"
elif [ -n "$SYS_LANG" ]; then Lang="$SYS_LANG"
else Lang="$DetectedLang"; fi

# --- СЛОВАРЬ ---
declare -A L
if [ "$Lang" == "RU" ]; then
    L[HeaderTitle]="UNIVERSAL Profile Creator (v2.30 UX++)"
    L[StructureLabel]="СТРУКТУРА ТИПОВОГО ИМЕНИ ПРОШИВКИ:"
    L[PathLabel]="ПУТЬ: "
    L[PromptSelect]="Выберите номер"
    L[PromptBack]="Назад"
    L[PromptExit]="Выход"
    L[ErrInput]="Ошибка: Некорректный ввод."
    L[Step1_Title]="Шаг 1: Выбор источника прошивки"
    L[Step1_OW]="OpenWrt (Официальная, стабильная)"
    L[Step1_IW]="ImmortalWrt (Больше пакетов, оптимизации)"
    L[Step2_Title]="Шаг 2: Выбор релиза"
    L[Step2_Fetch]="Получение списка..."
    L[Step3_Title]="Шаг 3: Выбор Target"
    L[Step4_Title]="Шаг 4: Выбор Subtarget"
    L[Step5_Title]="Шаг 5: Выбор модели устройства"
    L[Step5_Err]="Ошибка загрузки profiles.json."
    L[Step6_Title]="Шаг 6: Финализация"
    L[Step6_ErrIB]="ОШИБКА: ImageBuilder не найден!"
    L[Step6_Mirror]="Выберите источник загрузки IB:"
    L[Step6_DefPkgs]="Пакеты по умолчанию:"
    L[Step6_AddPkgs]="Дополнительные пакеты [luci] (Z - Назад)"
    L[Step6_FileName]="Введите имя файла конфига (без .conf)"
    L[Step6_Exists]="[!] Файл уже существует!"
    L[Step6_Overwrite]="Перезаписать? (y/n) [n]"
    L[Step6_Saved]="Конфиг успешно сохранен:"
    L[FinalAction]="Нажмите Enter для создания нового профиля или 'Q' для выхода..."
else
    L[HeaderTitle]="UNIVERSAL Profile Creator (v2.30 UX+)"
    L[StructureLabel]="TYPICAL FIRMWARE FILENAME STRUCTURE:"
    L[PathLabel]="PATH: "
    L[PromptSelect]="Select number"
    L[PromptBack]="Back"
    L[PromptExit]="Exit"
    L[ErrInput]="Error: Invalid input."
    L[Step1_Title]="Step 1: Firmware Source Selection"
    L[Step1_OW]="OpenWrt (Official, stable)"
    L[Step1_IW]="ImmortalWrt (More packages, optimized)"
    L[Step2_Title]="Step 2: Release Selection"
    L[Step2_Fetch]="Fetching list..."
    L[Step3_Title]="Step 3: Target Selection"
    L[Step4_Title]="Step 4: Subtarget Selection"
    L[Step5_Title]="Step 5: Device Model Selection"
    L[Step5_Err]="Error loading profiles.json."
    L[Step6_Title]="Step 6: Finalization"
    L[Step6_ErrIB]="ERROR: ImageBuilder not found!"
    L[Step6_Mirror]="Select IB download source:"
    L[Step6_DefPkgs]="Default packages:"
    L[Step6_AddPkgs]="Additional packages [luci] (Z - Back)"
    L[Step6_FileName]="Enter config filename (without .conf)"
    L[Step6_Exists]="[!] File already exists!"
    L[Step6_Overwrite]="Overwrite? (y/n) [n]"
    L[Step6_Saved]="Config successfully saved:"
    L[FinalAction]="Press Enter for new profile or 'Q' to exit..."
fi

# --- ИНИЦИАЛИЗАЦИЯ ---
PROFILES_DIR="./profiles"
mkdir -p "$PROFILES_DIR"

# Состояние
SOURCE=""
BASE_URL=""
REPO_URL=""
RELEASE=""
TARGET=""
SUBTARGET=""
MODEL_ID=""
MODEL_NAME=""
DEF_PKGS=""
IB_URL=""
LAST_STEP=1
STEP=1

# --- ФУНКЦИИ ---

out_part() {
    local val="$1"; local def="$2"; local part_step="$3"
    local display="${val:-$def}"
    display=$(echo "$display" | tr '[:upper:]' '[:lower:]')
    if [ "$STEP" -eq "$part_step" ]; then echo -ne "${C_MAG}[$display]${C_RST}"
    elif [ -n "$val" ]; then echo -ne "${C_GRN}$display${C_RST}"
    else echo -ne "${C_GRY}$display${C_RST}"; fi
}

show_header() {
    clear
    echo -e "${C_CYAN}==========================================================================${C_RST}"
    echo -e "  ${L[HeaderTitle]} [$Lang]"
    echo -e "  $1"
    echo -e "${C_CYAN}==========================================================================${C_RST}"
    # Визуализация структуры имени
    echo -e "  ${C_GRY}${L[StructureLabel]}${C_RST}"
    echo -ne "  "
    out_part "$SOURCE" "source" 1; echo -ne "${C_GRY}-${C_RST}"
    out_part "$TARGET" "target" 3; echo -ne "${C_GRY}-${C_RST}"
    out_part "$SUBTARGET" "subtarget" 4; echo -ne "${C_GRY}-${C_RST}"
    out_part "$MODEL_ID" "model" 5; echo -e "${C_GRY}-squashfs-sysupgrade.bin${C_RST}"

    # Хлебные крошки
    if [ -n "$SOURCE" ]; then
        echo -ne "  ${C_GRY}${L[PathLabel]}${C_RST}"
        local crumbs=("$SOURCE" "$RELEASE" "$TARGET" "$SUBTARGET" "$MODEL_NAME")
        local first=1
        for c in "${crumbs[@]}"; do
            [ -z "$c" ] && continue
            [ $first -eq 0 ] && echo -ne "${C_GRY} > ${C_RST}"
            echo -ne "${C_GRN}$c${C_RST}"
            first=0
        done
        echo ""
    fi
    echo -e "${C_GRY}--------------------------------------------------------------------------${C_RST}"
}

read_selection() {
    local max=$1
    local allow_back=${2:-true}
    while true; do
        echo -ne "\n${C_YEL}${L[PromptSelect]} (1-$max)"
        [ "$allow_back" == "true" ] && echo -ne ", [Z] ${L[PromptBack]}"
        echo -ne ", [Q] ${L[PromptExit]}: ${C_RST}"
        read -r input_val
        input_val=$(echo "$input_val" | tr '[:upper:]' '[:lower:]' | xargs)
        [ "$input_val" == "q" ] && exit 0
        [ "$allow_back" == "true" ] && [ "$input_val" == "z" ] && return 255
        if [[ "$input_val" =~ ^[0-9]+$ ]] && [ "$input_val" -ge 1 ] && [ "$input_val" -le "$max" ]; then
            return "$input_val"
        fi
        echo -e "${C_RED}${L[ErrInput]}${C_RST}"
    done
}

# --- ОСНОВНОЙ ЦИКЛ ---
while true; do
    case $STEP in
        1) # Выбор источника
            SOURCE=""; show_header "${L[Step1_Title]}" 1
            echo " 1. ${L[Step1_OW]}"; echo " 2. ${L[Step1_IW]}"
            read_selection 2 false; sel=$?
            if [ $sel -eq 1 ]; then
                SOURCE="OpenWrt"; BASE_URL="https://downloads.openwrt.org"; REPO_URL="https://github.com/openwrt/openwrt.git"
            else
                SOURCE="ImmortalWrt"; BASE_URL="https://downloads.immortalwrt.org"; REPO_URL="https://github.com/immortalwrt/immortalwrt.git"
            fi
            LAST_STEP=1; ((STEP++))
            ;;
        2) # Выбор релиза
            RELEASE=""; show_header "${L[Step2_Title]} ($SOURCE)" 2
            echo -e "${L[Step2_Fetch]}"
            html=$(curl -s "$BASE_URL/releases/")
            # Парсинг ссылок вида "23.05.0/" или "snapshots/"
            releases=($(echo "$html" | grep -oE 'href="([0-9]{2}\.[0-9]{2}\.[^"/]+/|snapshots/)"' | sed -E 's/href="([^"/]+)\/?"/\1/' | sort -rV | uniq))
            for i in "${!releases[@]}"; do printf " %2d. %s\n" "$((i+1))" "${releases[$i]}"; done
            read_selection "${#releases[@]}"; idx=$?
            if [ $idx -eq 255 ]; then ((STEP--)); continue; fi
            RELEASE="${releases[$((idx-1))]}"; LAST_STEP=2; ((STEP++))
            ;;
        3) # Выбор Target
            TARGET=""; show_header "${L[Step3_Title]}" 3
            [ "$RELEASE" == "snapshots" ] && t_url="$BASE_URL/snapshots/targets/" || t_url="$BASE_URL/releases/$RELEASE/targets/"
            html=$(curl -s "$t_url")
            targets=($(echo "$html" | grep -oE 'href="([^"\./ ]+/)"' | sed 's/href="//;s/\/"//' | grep -vE 'backups|kmodindex|parent'))
            for i in "${!targets[@]}"; do printf " %2d. %s\n" "$((i+1))" "${targets[$i]}"; done
            read_selection "${#targets[@]}"; idx=$?
            if [ $idx -eq 255 ]; then ((STEP--)); continue; fi
            TARGET="${targets[$((idx-1))]}"; LAST_STEP=3; ((STEP++))
            ;;
        4) # Выбор Subtarget
            SUBTARGET=""
            [ "$RELEASE" == "snapshots" ] && st_url="$BASE_URL/snapshots/targets/$TARGET/" || st_url="$BASE_URL/releases/$RELEASE/targets/$TARGET/"
            FINAL_BASE_URL="$st_url"
            html=$(curl -s "$st_url")
            subtargets=($(echo "$html" | grep -oE 'href="([^"\./ ]+/)"' | sed 's/href="//;s/\/"//' | grep -vE 'backups|kmodindex|packages|parent'))
            if [ "${#subtargets[@]}" -le 1 ]; then
                [ "$LAST_STEP" -eq 5 ] && { ((STEP--)); continue; }
                SUBTARGET="${subtargets[0]:-generic}"; LAST_STEP=4; ((STEP++)); continue
            else
                show_header "${L[Step4_Title]}" 4
                for i in "${!subtargets[@]}"; do printf " %2d. %s\n" "$((i+1))" "${subtargets[$i]}"; done
                read_selection "${#subtargets[@]}"; idx=$?
                if [ $idx -eq 255 ]; then ((STEP--)); continue; fi
                SUBTARGET="${subtargets[$((idx-1))]}"; LAST_STEP=4; ((STEP++))
            fi
            ;;
        5) # Модель и Пакеты
            MODEL_ID=""; MODEL_NAME=""; show_header "${L[Step5_Title]}" 5
            FINAL_URL="${FINAL_BASE_URL}${SUBTARGET}/"
            p_json=$(curl -s "${FINAL_URL}profiles.json")
            if [ -z "$p_json" ] || [ "$p_json" == "null" ]; then 
                echo -e "${C_RED}${L[Step5_Err]}${C_RST}"; sleep 2; ((STEP--)); continue; 
            fi
            
            # Получаем ID профилей
            profile_ids=($(echo "$p_json" | jq -r '.profiles | keys[]' | sort))
            for i in "${!profile_ids[@]}"; do
                id="${profile_ids[$i]}"
                # Handle old 'title' vs new 'titles' array
                title=$(echo "$p_json" | jq -r ".profiles[\"$id\"] | if .titles then .titles[0].title else .title end")
                # Если всё еще null (бывает в битых JSON) - пишем ID
                [ "$title" == "null" ] || [ -z "$title" ] && title="$id"
                printf " %3d. %s (%s)\n" "$((i+1))" "$title" "$id"
            done
            
            read_selection "${#profile_ids[@]}"; idx=$?
            if [ $idx -eq 255 ]; then LAST_STEP=5; ((STEP--)); continue; fi
            
            MODEL_ID="${profile_ids[$((idx-1))]}"
            # Повторяем логику для сохранения имени модели
            MODEL_NAME=$(echo "$p_json" | jq -r ".profiles[\"$MODEL_ID\"] | if .titles then .titles[0].title else .title end")
            [ "$MODEL_NAME" == "null" ] && MODEL_NAME="$MODEL_ID"

            # Пакеты (без изменений)
            DEF_PKGS=$(echo "$p_json" | jq -r '.default_packages | join(" ")')
            device_pkgs=$(echo "$p_json" | jq -r ".profiles[\"$MODEL_ID\"].device_packages | join(\" \")")
            pkgs_to_add=""; pkgs_to_remove=""
            for p in $device_pkgs; do if [[ $p == -* ]]; then pkgs_to_remove+=" ${p:1}"; else pkgs_to_add+=" $p"; fi; done
            final_list=""
            for p in $DEF_PKGS; do [[ " $pkgs_to_remove " == *" $p "* ]] || final_list+=" $p"; done
            DEF_PKGS=$(echo "$final_list $pkgs_to_add" | xargs -n1 | sort -u | xargs)
            LAST_STEP=5; ((STEP++))
            ;;
        6) # Финализация
            show_header "${L[Step6_Title]}" 6
            folder_html=$(curl -s "$FINAL_URL")
            ib_file=$(echo "$folder_html" | grep -oE '(openwrt|immortalwrt)-imagebuilder-[^"]+\.tar\.(xz|zst)' | head -n 1)
            if [ -n "$ib_file" ]; then
                IB_URL="${FINAL_URL}${ib_file}"
                if [ "$SOURCE" == "ImmortalWrt" ]; then
                    echo -e "${C_YEL}${L[Step6_Mirror]}${C_RST}\n 1. PKU (mirrors.pku.edu.cn)\n 2. SJTU (mirrors.sjtug.sjtu.edu.cn)\n 3. Official\n 4. KyaruCloud (CDN)"
                    read -p "Choice (1-4) [1]: " m_sel
                    case "${m_sel:-1}" in
                        2) IB_URL="${IB_URL/downloads.immortalwrt.org/mirrors.sjtug.sjtu.edu.cn/immortalwrt}" ;;
                        3) ;; # Official — не меняем
                        4) IB_URL="${IB_URL/downloads.immortalwrt.org/immortalwrt.kyarucloud.moe}" ;;
                        *) IB_URL="${IB_URL/downloads.immortalwrt.org/mirrors.pku.edu.cn/immortalwrt}" ;;
                    esac
                fi
            else echo -e "${C_RED}${L[Step6_ErrIB]}${C_RST}"; read; ((STEP--)); continue; fi

            echo -e "${C_GRY}${L[Step6_DefPkgs]}\n$DEF_PKGS\n${C_RST}"
            echo -ne "${C_YEL}${L[Step6_AddPkgs]}: ${C_RST}"
            read -r input_pkgs
            [ "$(echo "$input_pkgs" | tr '[:upper:]' '[:lower:]')" == "z" ] && { STEP=6; ((STEP--)); continue; }
            
            # Объединяем всё в одну строку COMMON_LIST (как в образце)
            [ -z "$input_pkgs" ] && extra="luci" || extra="$input_pkgs"
            FINAL_COMMON_LIST=$(echo "$DEF_PKGS $extra" | xargs -n1 | sort -u | xargs)

            # Полный Маппинг архитектуры (Mirror PS1)
            case "$TARGET" in
                ramips) ARCH="mipsel_24kc" ;;
                ath79|ar71xx|lantiq|realtek) ARCH="mips_24kc" ;;
                x86) [ "$SUBTARGET" == "64" ] && ARCH="x86_64" || ARCH="i386_pentium4" ;;
                mediatek) 
                    if [[ "$SUBTARGET" =~ mt798|mt7622 ]]; then ARCH="aarch64_cortex-a53"
                    elif [ "$SUBTARGET" == "mt7623" ]; then ARCH="arm_cortex-a7_neon-vfpv4"
                    else ARCH="mipsel_24kc"; fi ;;
                mvebu) [ "$SUBTARGET" == "cortexa72" ] && ARCH="aarch64_cortex-a72" || ARCH="arm_cortex-a9_vfpv3-d16" ;;
                ipq40xx) ARCH="arm_cortex-a7_neon-vfpv4" ;;
                ipq806x) ARCH="arm_cortex-a15_neon-vfpv4" ;;
                rockchip) ARCH="aarch64_generic" ;;
                bcm27xx) 
                    if [ "$SUBTARGET" == "bcm2711" ]; then ARCH="aarch64_cortex-a72"
                    elif [ "$SUBTARGET" == "bcm2710" ]; then ARCH="aarch64_cortex-a53"
                    else ARCH="arm_arm1176jzf-s_vfp"; fi ;;
                sunxi) ARCH="arm_cortex-a7_neon-vfpv4" ;;
                layerscape) [ "$SUBTARGET" == "64b" ] && ARCH="aarch64_generic" || ARCH="arm_cortex-a7_neon-vfpv4" ;;
                *64*) ARCH="aarch64_generic" ;;
                *) ARCH="mipsel_24kc" ;;
            esac

            # Имя файла (Полное)
            ver_clean=$(echo "$RELEASE" | sed 's/\.//g;s/snapshots/snap/')
            src_short=$([ "$SOURCE" == "ImmortalWrt" ] && echo "iw" || echo "ow")
            mod_clean=$(echo "$MODEL_ID" | tr '-' '_')
            def_name="${mod_clean}_${ver_clean}_${src_short}_full"

            while true; do
                echo -ne "\n${C_GRY}${L[Step6_FileName]} [$def_name]: ${C_RST}"
                read -r input_name
                [ "$(echo "$input_name" | tr '[:upper:]' '[:lower:]')" == "z" ] && { STEP=6; ((STEP--)); continue 2; }
                [ -z "$input_name" ] && profile_name="$def_name" || profile_name=$(echo "$input_name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[[:space:]\-\.]+/_/g;s/[^a-z0-9_]//g')
                conf_path="$PROFILES_DIR/$profile_name.conf"
                if [ -f "$conf_path" ]; then
                    echo -e " ${C_YEL}${L[Step6_Exists]}${C_RST}"
                    read -p " ${L[Step6_Overwrite]} (y/n) [n]: " ovr
                    [[ "$ovr" == "y" ]] || continue
                fi
                break
            done

            branch=$([ "$RELEASE" == "snapshots" ] && echo "master" || echo "v$RELEASE")

            # Генерация (По образцу NanoPi R5C)
            cat <<EOF > "$conf_path"
# === Profile for $MODEL_ID ($SOURCE $RELEASE) ===

PROFILE_NAME="$profile_name"
TARGET_PROFILE="$MODEL_ID"

COMMON_LIST="$FINAL_COMMON_LIST"

# === IMAGE BUILDER CONFIG
IMAGEBUILDER_URL="$IB_URL"
#CUSTOM_KEYS="https://fantastic-packages.github.io/packages/releases/24.10/53ff2b6672243d28.pub"
#CUSTOM_REPOS="src/gz fantastic_luci https://fantastic-packages.github.io/packages/releases/24.10/packages/$ARCH/luci
#src/gz fantastic_packages https://fantastic-packages.github.io/packages/releases/24.10/packages/$ARCH/packages
#src/gz fantastic_special https://fantastic-packages.github.io/packages/releases/24.10/packages/$ARCH/special"
#DISABLED_SERVICES="transmission-daemon minidlna"
IMAGE_PKGS="\$COMMON_LIST"
#IMAGE_EXTRA_NAME="custom"

# === Extra config options
#ROOTFS_SIZE="512"
#KERNEL_SIZE="64"

# === SOURCE BUILDER CONFIG
SRC_REPO="$REPO_URL"
SRC_BRANCH="$branch"
SRC_TARGET="$TARGET"
SRC_SUBTARGET="$SUBTARGET"
SRC_ARCH="$ARCH"
SRC_PACKAGES="\$IMAGE_PKGS"
SRC_CORES="safe"

## SPACE SAVING (For 4MB / 8MB flash devices)
#    - CONFIG_LUCI_SRCDIET=y      -> Compresses Lua/JS in LuCI (saves ~100-200KB)
#    - CONFIG_IPV6=n              -> Completely removes IPv6 support (saves ~300KB)
#    - CONFIG_KERNEL_DEBUG_INFO=n -> Removes debugging information from the kernel
#    - CONFIG_STRIP_KERNEL_EXPORTS=y -> Strips kernel export symbols (if no external kmods needed)
## FILE SYSTEMS (For SD cards / x86 / NanoPi)
#    By default, SquashFS (Read-Only) is created. EXT4 is recommended for SBCs.
#    - CONFIG_TARGET_ROOTFS_SQUASHFS=n -> Disable SquashFS
#    - CONFIG_TARGET_ROOTFS_EXT4FS=y   -> Enable EXT4 (Read/Write partition)
#    - CONFIG_TARGET_ROOTFS_TARGZ=y    -> Create an archive (for containers/backups)
## DEBUGGING AND LOGS
#    - CONFIG_KERNEL_PRINTK=n     -> Disables boot log output to console (quiet boot)
#    - CONFIG_BUILD_LOG=y         -> Saves build logs for each package (to debug build errors)
## FORCED MODULE INCLUSION
#    If a package fails to install via SRC_PACKAGES, you can force-enable it here.
# CONFIG_PACKAGE_kmod-usb-net-rndis=y

SRC_EXTRA_CONFIG=''

EOF
            echo -e "\n${C_GRN}[OK] ${L[Step6_Saved]} $conf_path${C_RST}"
            echo -e "\n${L[FinalAction]}"
            read -r final_act
            [[ "$(echo "$final_act" | tr '[:upper:]' '[:lower:]')" == "q" ]] && exit 0
            STEP=1
            ;;
    esac
done