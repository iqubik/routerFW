#!/bin/bash

# file: _Builder.sh
# Выключаем мигающий курсор
tput civis 2>/dev/null

# Функция восстановления курсора при выходе
trap "tput cnorm; exit" SIGINT SIGTERM EXIT

# Настройка цветов ANSI
ESC=$(printf '\033')
C_KEY="${ESC}[93m"   # Bright Yellow
C_LBL="${ESC}[36m"   # Cyan/Blue
C_GRY="${ESC}[90m"   # Gray
C_VAL="${ESC}[92m"   # Bright Green
C_OK="${ESC}[92m"    # Bright Green
C_ERR="${ESC}[91m"   # Bright Red
C_RST="${ESC}[0m"    # Reset

VER_NUM="3.98"

# === ЯЗЫКОВОЙ МОДУЛЬ ===
FORCE_LANG="AUTO"
SYS_LANG="EN"
ru_score=0

echo -e "${C_LBL}[INIT]${C_RST} Language detector (Weighted Detection)..."

# 1. Проверка переменной окружения LANG (4 балла)
if [[ "$LANG" == *"ru"* ]]; then
    ((ru_score+=4))
    echo -e "  ${C_GRY}-${C_RST} Environment LANG      ${C_OK}RU${C_RST} [+4]"
else
    echo -e "  ${C_GRY}-${C_RST} Environment LANG      ${C_ERR}EN${C_RST}"
fi

# 2. Проверка команды locale (3 балла)
if command -v locale >/dev/null 2>&1; then
    if locale | grep -qi "ru_RU"; then
        ((ru_score+=3))
        echo -e "  ${C_GRY}-${C_RST} System Locale         ${C_OK}RU${C_RST} [+3]"
    else
        echo -e "  ${C_GRY}-${C_RST} System Locale         ${C_ERR}EN${C_RST}"
    fi
fi

# 3. Проверка временной зоны (2 балла)
if [ -f /etc/timezone ]; then
    if grep -qi "Moscow\|Europe/Russian" /etc/timezone; then
        ((ru_score+=2))
        echo -e "  ${C_GRY}-${C_RST} Timezone Check        ${C_OK}RU${C_RST} [+2]"
    fi
elif command -v timedatectl >/dev/null 2>&1; then
    if timedatectl | grep -qi "Moscow"; then
        ((ru_score+=2))
        echo -e "  ${C_GRY}-${C_RST} Timezone Check        ${C_OK}RU${C_RST} [+2]"
    fi
fi

# Логика суждения
if [ $ru_score -ge 5 ]; then SYS_LANG="RU"; fi

# === ПРИНУДИТЕЛЬНЫЙ ПЕРЕКЛЮЧАТЕЛЬ (OVERRIDE) ===
if [ "$FORCE_LANG" == "RU" ]; then SYS_LANG="RU"; fi
if [ "$FORCE_LANG" == "EN" ]; then SYS_LANG="EN"; fi

# === СЛОВАРЬ (DICTIONARY) ===
if [ "$SYS_LANG" == "RU" ]; then
    L_EXIT_CONFIRM="Выйти из программы? (Y/N): "
    L_EXIT_BYE="До новых встреч!"
    H_PROF="Профиль"
    H_ARCH="Архитектура"
    H_RES="Ресурсы | Сборки"
    L_VERDICT="Вердикт"
    L_LANG_NAME="РУССКИЙ"
    L_INIT_ENV="[INIT] Проверка окружения..."
    L_ERR_DOCKER="[ERROR] Docker не обнаружен!"
    L_ERR_DOCKER_MSG="Убедитесь, что Docker установлен и запущен."
    L_ERR_COMPOSE="[ERROR] docker-compose не найден!"
    L_INIT_NET="[INIT] Очистка неиспользуемых сетей Docker..."
    L_INIT_UNPACK="[INIT] Проверка распаковщика..."
    L_MODE_IMG="IMAGE BUILDER (Быстрая сборка)"
    L_MODE_SRC="SOURCE BUILDER (Полная компиляция)"
    L_CUR_MODE="Текущий режим"
    L_PROFILES="Профили сборки"
    L_LEGEND_IND="Индикаторы показывают состояние ресурсов и результатов сборки."
    L_LEGEND_TEXT="Легенда: F:Файлы P:Пакеты S:Исх | Прошивки: OI:Образ OS:Сборка"
    L_BTN_ALL="Собрать ВСЕ"
    L_BTN_SWITCH="Режим на "
    L_BTN_EDIT="Редактор"
    L_BTN_CLEAN="Обслуживание"
    L_BTN_WIZ="Мастер профилей"
    L_BTN_EXIT="Выход"
    L_BTN_IPK="Импорт IPK"
    L_CHOICE="Ваш выбор"
    L_RUNNING="Сборка запущена..."
    L_EDIT_TITLE="МЕНЕДЖЕР РЕСУРСОВ И РЕДАКТОР ПРОФИЛЯ"
    L_SEL_PROF="Выберите профиль для работы"
    L_BACK="Назад"
    L_ANALYSIS="[АНАЛИЗ СОСТОЯНИЯ ПРОФИЛЯ"
    L_MISSING="Отсутствует"
    L_EMPTY="Пусто"
    L_READY="Готов"
    L_FOUND="Найдено"
    L_ST_CONF="Конфигурация"
    L_ST_OVER="Overlay файлы"
    L_ST_IPK="Входящие IPK"
    L_ST_SRC="Исходники PKG"
    L_ST_OUTS="Выход Source"
    L_ST_OUTI="Выход Image"
    L_ACTION="ДЕЙСТВИЕ"
    L_OPEN_FILE="Открыть файл"
    L_OPEN_EXPL="Открыть также папки ресурсов в проводнике?"
    L_START_EXPL="[INFO] Запуск проводника..."
    L_DONE_MENU="Готово. Переход в меню..."
    L_WARN_MASS="Массовая компиляция из исходников! Это займет много времени."
    L_MASS_START="МАССОВЫЙ ЗАПУСК"
    L_IMPORT_IPK_TITLE="ИМПОРТ ПАКЕТОВ (IPK) ДЛЯ ПРОФИЛЯ"
    L_SEL_IMPORT="Выберите профиль для импорта пакетов"
    L_ERR_PS1_IPK="[ERROR] system/import_ipk.sh не найден!"
    L_CLEAN_TITLE="МЕНЮ ОЧИСТКИ И ОБСЛУЖИВАНИЯ"
    L_CLEAN_TYPE="Выберите тип данных для очистки"
    L_CLEAN_IMG_SDK="Очистить кэш ImageBuilder (SDK)"
    L_CLEAN_IMG_IPK="Очистить кэш пакетов (IPK)"
    L_CLEAN_FULL="FULL FACTORY RESET (Сброс проекта)"
    L_CLEAN_SRC_SOFT="SOFT CLEAN (make clean)"
    L_CLEAN_SRC_HARD="HARD RESET (Удалить src-workdir)"
    L_CLEAN_SRC_DL="Очистить кэш исходников (dl)"
    L_CLEAN_SRC_CC="Очистить CCACHE (Кэш компилятора)"
    L_DOCKER_PRUNE="Prune Docker (Глобальная очистка)"
    L_PRUNE_RUN="[DOCKER] Выполняю system prune..."
    L_CLEAN_PROF_SEL="Для какого профиля выполнить очистку?"
    L_CLEAN_ALL_PROF="ДЛЯ ВСЕХ ПРОФИЛЕЙ"
    L_CONFIRM_YES="Введите YES для подтверждения"
    L_CLEAN_RUN="[CLEAN] Запуск процедуры..."
    L_K_TITLE="MENUCONFIG ИНТЕРАКТИВ"
    L_K_DESC="Будет создан manual_config в папке"
    L_K_SEL="Выберите профиль для настройки"
    L_K_WARN_EX="Найден сохраненный конфиг: manual_config"
    L_K_WARN_L1="1. Мы ЗАГРУЗИМ его в редактор."
    L_K_WARN_L2="2. После выхода файл будет ПЕРЕЗАПИСАН."
    L_K_CONT="Продолжить? [Y/N]"
    L_K_SAVE="Фиксация конфигурации..."
    L_K_SAVED="Сохранено"
    L_K_STR="строк"
    L_K_EMPTY_DIFF="Дифф пуст, сохраняю полный конфиг."
    L_K_FINAL="Конфигурация сохранена в firmware_output"
    L_K_STAY="Остаться в контейнере? [y/N]"
    L_K_SHELL_H1="[SHELL] Вход в консоль. Текущая папка"
    L_K_SHELL_H2="Подсказка: введите mc для файлового менеджера."
    L_K_SHELL_H3="Чтобы выйти, введите exit."
    L_K_LAUNCH="[INFO] Запуск интерактивного Menuconfig..."
    L_WIZ_START="ЗАПУСК МАСТЕРА СОЗДАНИЯ ПРОФИЛЯ"
    L_WIZ_DONE="Мастер завершил работу."
    L_ERR_WIZ="[ERROR] create_profile.sh не найден!"
    L_ERR_INPUT="Ошибка ввода."
    L_PROC_PROF="Профиль"
    L_ERR_VAR_NF="не найден."
    L_ERR_SKIP="Возможно, профиль для другого режима."
else
    # ENGLISH DICTIONARY
    L_EXIT_CONFIRM="Exit the program? (Y/N): "
    L_EXIT_BYE="See you soon!"
    H_PROF="Profile"
    H_ARCH="Architecture"
    H_RES="Resources | Builds"
    L_VERDICT="Verdict"
    L_LANG_NAME="ENGLISH"
    L_INIT_ENV="[INIT] Checking environment..."
    L_ERR_DOCKER="[ERROR] Docker not found!"
    L_ERR_DOCKER_MSG="Make sure Docker is installed and running."
    L_ERR_COMPOSE="[ERROR] docker-compose not found!"
    L_INIT_NET="[INIT] Pruning unused Docker networks..."
    L_INIT_UNPACK="[INIT] Checking unpacker..."
    L_MODE_IMG="IMAGE BUILDER (Fast Build)"
    L_MODE_SRC="SOURCE BUILDER (Full Compilation)"
    L_CUR_MODE="Current Mode"
    L_PROFILES="Build Profiles"
    L_LEGEND_IND="Indicators show the state of resources and build results."
    L_LEGEND_TEXT="Legend: F:Files P:Packages S:Src | Firmwares: OI:Image OS:Build"
    L_BTN_ALL="Build ALL"
    L_BTN_SWITCH="Switch to"
    L_BTN_EDIT="Editor"
    L_BTN_CLEAN="Maintenance"
    L_BTN_WIZ="Profile Wizard"
    L_BTN_EXIT="Exit"
    L_BTN_IPK="Import IPK"
    L_CHOICE="Your choice"
    L_RUNNING="Build started..."
    L_EDIT_TITLE="RESOURCE MANAGER AND PROFILE EDITOR"
    L_SEL_PROF="Select profile to work with"
    L_BACK="Back"
    L_ANALYSIS="[PROFILE STATE ANALYSIS"
    L_MISSING="Missing"
    L_EMPTY="Empty"
    L_READY="Ready"
    L_FOUND="Found"
    L_ST_CONF="Configuration"
    L_ST_OVER="Overlay files"
    L_ST_IPK="Inbound IPKs"
    L_ST_SRC="Source PKGs"
    L_ST_OUTS="Source Output"
    L_ST_OUTI="Image Output"
    L_ACTION="ACTION"
    L_OPEN_FILE="Open file"
    L_OPEN_EXPL="Open resource folders in Explorer/Finder too?"
    L_START_EXPL="[INFO] Launching File Manager..."
    L_DONE_MENU="Done. Returning to menu..."
    L_WARN_MASS="Massive source compilation! This will take a lot of time."
    L_MASS_START="MASSIVE LAUNCH"
    L_IMPORT_IPK_TITLE="PACKAGE IMPORT (IPK) FOR PROFILE"
    L_SEL_IMPORT="Select profile for package import"
    L_ERR_PS1_IPK="[ERROR] system/import_ipk.sh not found!"
    L_CLEAN_TITLE="CLEANUP AND MAINTENANCE MENU"
    L_CLEAN_TYPE="Select data type to clean"
    L_CLEAN_IMG_SDK="Clean ImageBuilder Cache (SDK)"
    L_CLEAN_IMG_IPK="Clean Package Cache (IPK)"
    L_CLEAN_FULL="FULL FACTORY RESET (Reset project)"
    L_CLEAN_SRC_SOFT="SOFT CLEAN (make clean)"
    L_CLEAN_SRC_HARD="HARD RESET (Remove src-workdir)"
    L_CLEAN_SRC_DL="Clean Source Cache (dl)"
    L_CLEAN_SRC_CC="Clean CCACHE (Compiler cache)"
    L_DOCKER_PRUNE="Prune Docker (Global Docker cleanup)"
    L_PRUNE_RUN="[DOCKER] Running system prune..."
    L_CLEAN_PROF_SEL="Which profile to clean?"
    L_CLEAN_ALL_PROF="FOR ALL PROFILES (Global cleanup)"
    L_CONFIRM_YES="Type YES to confirm"
    L_CLEAN_RUN="[CLEAN] Starting procedure..."
    L_K_TITLE="MENUCONFIG INTERACTIVE"
    L_K_DESC="manual_config will be created in folder"
    L_K_SEL="Select profile to configure"
    L_K_WARN_EX="Found saved config in profile folder: manual_config"
    L_K_WARN_L1="1. We will LOAD it into editor."
    L_K_WARN_L2="2. After exit, the file will be OVERWRITTEN."
    L_K_CONT="Continue? [Y/N]"
    L_K_SAVE="[SAVE] Committing configuration..."
    L_K_SAVED="Saved"
    L_K_STR="lines"
    L_K_EMPTY_DIFF="Diff is empty, saving full config."
    L_K_FINAL="Configuration saved to firmware_output"
    L_K_STAY="Stay in container for file work? [y/N]"
    L_K_SHELL_H1="[SHELL] Entering console. Current folder"
    L_K_SHELL_H2="Tip: type mc to launch file manager."
    L_K_SHELL_H3="To exit to Windows and continue, type exit."
    L_K_LAUNCH="[INFO] Launching Interactive Menuconfig..."
    L_WIZ_START="STARTING PROFILE WIZARD"
    L_WIZ_DONE="Wizard finished."
    L_ERR_WIZ="[ERROR] create_profile.sh not found!"
    L_ERR_INPUT="Input error."
    L_PROC_PROF="Profile"
    L_ERR_VAR_NF="not found."
    L_ERR_SKIP="Maybe this profile is for a different mode."
fi

# Финальный вердикт языка
if [ "$FORCE_LANG" == "AUTO" ]; then
    echo -e "${C_LBL}[INIT]${C_RST} ${L_VERDICT} ${C_OK}${L_LANG_NAME}${C_RST} (Score ${ru_score}/10)"
else
    echo -e "${C_LBL}[INIT]${C_RST} Lang set: ${C_VAL}FORCE ${FORCE_LANG}${C_RST}"
fi
echo ""

# === КОНФИГУРАЦИЯ ===
BUILD_MODE="IMAGE"
echo -e "$L_INIT_ENV"

# Проверка Docker
D_VER=$(docker --version 2>/dev/null)
if [ -z "$D_VER" ]; then
    echo -e "$L_ERR_DOCKER"
    echo -e "$L_ERR_DOCKER_MSG"
    read -p "Press enter..." && exit 1
fi
echo -e "  ${C_GRY}-${C_RST} $D_VER"

# Проверка Compose
C_VER=$(docker-compose --version 2>/dev/null || docker compose version 2>/dev/null)
echo -e "  ${C_GRY}-${C_RST} $C_VER"

# Корень
PROJECT_DIR=$(pwd)
echo -e "  ${C_GRY}-${C_RST} Root: ${C_VAL}${PROJECT_DIR}${C_RST}"

echo -e "$L_INIT_NET"
docker network prune --force >/dev/null 2>&1
echo ""

# === 0. РАСПАКОВКА ===
if [ -f "_unpacker.sh" ]; then
    echo -e "$L_INIT_UNPACK$"
    bash _unpacker.sh
fi

# === 1. ИНИЦИАЛИЗАЦИЯ ПАПОК ===
check_dir() { [ ! -d "$1" ] && mkdir -p "$1"; }
check_dir "profiles"
check_dir "custom_files"
check_dir "firmware_output"
check_dir "custom_packages"
check_dir "src_packages"

# === Вспомогательные функции (Permissions & WiFi) ===
create_perms_script() {
    local p_id=$1
    local target="custom_files/${p_id}/etc/uci-defaults/99-permissions.sh"
    if [ ! -f "$target" ]; then
        mkdir -p "$(dirname "$target")"
        echo "#!/bin/sh" > "$target"
        echo "[ -d /etc/dropbear ] && chmod 700 /etc/dropbear" >> "$target"
        echo "[ -f /etc/dropbear/authorized_keys ] && chmod 600 /etc/dropbear/authorized_keys" >> "$target"
        echo "[ -f /etc/shadow ] && chmod 600 /etc/shadow" >> "$target"
        echo "exit 0" >> "$target"
        chmod +x "$target"
    fi
}

create_wifi_on_script() {
    local p_id=$1
    local target="custom_files/${p_id}/etc/uci-defaults/10-enable-wifi"
    if [ ! -f "$target" ]; then
        mkdir -p "$(dirname "$target")"
        echo "#!/bin/sh" > "$target"
        echo "uci set wireless.radio0.disabled='0'" >> "$target"
        echo "uci set wireless.radio1.disabled='0'" >> "$target"
        echo "uci commit wireless && wifi reload" >> "$target"
        echo "exit 0" >> "$target"
        chmod +x "$target"
    fi
}

# === АВТО-ПАТЧИНГ АРХИТЕКТУРЫ (Bash Version) ===
echo -e "${C_LBL}[INIT]${C_RST} Scanning profiles for missing architecture tags..."
for p in profiles/*.conf; do
    [ -e "$p" ] || continue
    if ! grep -q "SRC_ARCH=" "$p"; then
        target=$(grep "SRC_TARGET=" "$p" | cut -d'"' -f2)
        sub=$(grep "SRC_SUBTARGET=" "$p" | cut -d'"' -f2)
        [ -z "$target" ] && target=$(grep "IMAGEBUILDER_URL=" "$p" | sed -n 's|.*/targets/\([^/]*\)/\([^/]*\)/.*|\1|p')
        [ -z "$sub" ] && sub=$(grep "IMAGEBUILDER_URL=" "$p" | sed -n 's|.*/targets/\([^/]*\)/\([^/]*\)/.*|\2|p')
        
        arch=""
        case "$target" in
            ramips) arch="mipsel_24kc" ;;
            ath79|ar71xx|lantiq|realtek) arch="mips_24kc" ;;
            x86) [[ "$sub" == "64" ]] && arch="x86_64" || arch="i386_pentium4" ;;
            mediatek)
                if [[ "$sub" =~ mt798|mt7622 ]]; then arch="aarch64_cortex-a53"
                elif [[ "$sub" == "mt7623" ]]; then arch="arm_cortex-a7_neon-vfpv4"
                else arch="mipsel_24kc"; fi ;;
            rockchip) arch="aarch64_generic" ;;
            bcm27xx)
                if [[ "$sub" == "bcm2711" ]]; then arch="aarch64_cortex-a72"
                elif [[ "$sub" == "bcm2710" ]]; then arch="aarch64_cortex-a53"
                else arch="arm_arm1176jzf-s_vfp"; fi ;;
        esac
        
        if [ -n "$arch" ]; then
            echo "SRC_ARCH=\"$arch\"" >> "$p"
            echo -e "  ${C_OK}[PATCHED]${C_RST} $(basename "$p") -> $arch"
        fi
    fi
done

# === ГЛАВНОЕ МЕНЮ ===
while true; do
    clear
    if [ "$BUILD_MODE" == "IMAGE" ]; then
        MODE_TITLE="$L_MODE_IMG"
        OPPOSITE_MODE="SOURCE"
        TARGET_VAR="IMAGEBUILDER_URL"
        MODE_COLOR="${ESC}[36m" # Cyan
    else
        MODE_TITLE="$L_MODE_SRC"
        OPPOSITE_MODE="IMAGE"
        TARGET_VAR="SRC_BRANCH"
        MODE_COLOR="${ESC}[35m" # Magenta
    fi

    echo -e "${C_GRY}┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐${C_RST}"
    echo -e "  ${C_VAL}OpenWrt FW Builder ${VER_NUM}${C_RST} [${C_VAL}${SYS_LANG}${C_RST}]          ${C_LBL}https://github.com/iqubik/routerFW${C_RST}"
    echo -e "  ${L_CUR_MODE}: [${MODE_COLOR}${MODE_TITLE}${C_RST}]"
    echo -e "${C_GRY}└────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘${C_RST}"
    echo ""
    printf "    %-5s %-45s %-20s %-20s\n" "${C_GRY}ID" "$H_PROF" "$H_ARCH" "$H_RES${C_RST}"
    echo -e "    ${C_GRY}────────────────────────────────────────────────────────────────────────────────────────────────────────────${C_RST}"

    profiles=()
    count=0
    echo -e "    ${C_LBL}${L_PROFILES}:${C_RST}\n"
    
    for f in profiles/*.conf; do
        [ -e "$f" ] || continue
        ((count++))
        p_name=$(basename "$f")
        p_id="${p_name%.conf}"
        profiles[$count]=$p_name
        
        # Инфраструктура
        mkdir -p "custom_files/$p_id" "custom_packages/$p_id" "src_packages/$p_id"
        create_perms_script "$p_id"
        create_wifi_on_script "$p_id"

        # Архитектура
        this_arch=$(grep "SRC_ARCH=" "$f" | cut -d'"' -f2)
        [ -z "$this_arch" ] && this_arch="--------"

        # Статусы ресурсов
        st_f="${C_GRY}·${C_RST}"; [ "$(ls -A "custom_files/$p_id" 2>/dev/null)" ] && st_f="${C_LBL}F${C_RST}"
        st_p="${C_GRY}·${C_RST}"; [ "$(ls -A "custom_packages/$p_id" 2>/dev/null)" ] && st_p="${C_KEY}P${C_RST}"
        st_s="${C_GRY}·${C_RST}"; [ "$(ls -A "src_packages/$p_id" 2>/dev/null)" ] && st_s="${C_VAL}S${C_RST}"
        
        # Статусы билдов
        st_oi="${C_GRY}··${C_RST}"; [ "$(find "firmware_output/imagebuilder/$p_id" -name "*.bin" -o -name "*.img" 2>/dev/null)" ] && st_oi="${C_VAL}OI${C_RST}"
        st_os="${C_GRY}··${C_RST}"; [ "$(find "firmware_output/sourcebuilder/$p_id" -name "*.bin" -o -name "*.img" 2>/dev/null)" ] && st_os="${C_VAL}OS${C_RST}"

        printf "    ${C_GRY}[${C_KEY}%2d${C_GRY}]${C_RST} %-45s ${C_LBL}%-20s${C_RST} ${C_GRY}[%s%s%s | %s%s]${C_RST}\n" \
               $count "$p_id" "$this_arch" "$st_f" "$st_p" "$st_s" "$st_oi" "$st_os"
    done

    echo -e "    ${C_GRY}────────────────────────────────────────────────────────────────────────────────────────────────────────────${C_RST}"
    echo -e "    ${L_LEGEND_IND}"
    echo -e "    ${C_GRY}${L_LEGEND_TEXT}${C_RST}\n"
    
    printf "    ${C_LBL}[${C_KEY}A${C_LBL}] %-18s ${C_LBL}[${C_KEY}M${C_LBL}] %s ${C_VAL}%-10s${C_RST}       ${C_LBL}[${C_KEY}E${C_LBL}] %s${C_RST}\n" \
           "$L_BTN_ALL" "$L_BTN_SWITCH" "$OPPOSITE_MODE" "$L_BTN_EDIT"
    printf "    ${C_LBL}[${C_KEY}C${C_LBL}] %-18s ${C_LBL}[${C_KEY}W${C_LBL}] %-22s ${C_LBL}[${C_KEY}0${C_LBL}] %s${C_RST}\n" \
           "$L_BTN_CLEAN" "$L_BTN_WIZ" "$L_BTN_EXIT"

    if [ "$BUILD_MODE" == "SOURCE" ]; then
        echo -e "    ${C_LBL}[${C_KEY}K${C_LBL}] Menuconfig/mc      ${C_LBL}[${C_KEY}I${C_LBL}] ${L_BTN_IPK}${C_RST}"
    fi
    echo ""

    read -p "${C_LBL}${L_CHOICE}${C_VAL} ⚡ ${C_RST}" choice

    case "$choice" in
        0) 
            echo -ne "${C_ERR}${L_EXIT_CONFIRM}${C_RST}"
            read -r exit_confirm
            if [[ "$exit_confirm" =~ ^[Yy]$ ]]; then
                echo -e "${C_OK}${L_EXIT_BYE}${C_RST}"
                tput cnorm; exit 0
            fi ;;
        [Mm]) 
            [[ "$BUILD_MODE" == "IMAGE" ]] && BUILD_MODE="SOURCE" || BUILD_MODE="IMAGE" ;;
        [Ee])
            # Меню редактирования (упрощенно)
            echo -e "${C_VAL}${L_EDIT_TITLE}${C_RST}"
            # Тут логика открытия редактора (vi/nano или xdg-open)
            read -p "Press enter to return..." ;;
        [Aa])
            # Массовая сборка
            for p in "${profiles[@]}"; do
                # Здесь вызов функции сборки
                echo "Building $p..."
            done
            read -p "Done. Press enter..." ;;
        [Kk])
            if [ "$BUILD_MODE" == "SOURCE" ]; then
                # Здесь вызов функции Menuconfig
                echo "Launching menuconfig logic..."
                read -p "Press enter..."
            fi ;;
        [Cc])
            # Очистка
            echo "Cleanup menu..."
            read -p "Press enter..." ;;
        [Ww])
            if [ -f "system/create_profile.sh" ]; then
                bash "system/create_profile.sh"
            else
                echo "$L_ERR_WIZ"
            fi
            read -p "Press enter..." ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "$count" ] && [ "$choice" -gt 0 ]; then
                selected="${profiles[$choice]}"
                echo -e "${C_OK}${L_RUNNING} -> $selected${C_RST}"
                # Фактический вызов функции сборки
                # build_routine "$selected"
                read -p "Press enter to return..."
            else
                echo -e "${C_ERR}${L_ERR_INPUT}${C_RST}"
                sleep 1
            fi ;;
    esac
done