#!/bin/bash
# file: _Builder.sh
# Гарантируем, что мы работаем в папке скрипта
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

VER_NUM="4.10"

# Выключаем мигающий курсор
tput civis 2>/dev/null

# Функция восстановления курсора и очистки при прерывании (Ctrl+C)
cleanup_exit() {
    rm -rf "$PROJECT_DIR/.docker_tmp" # Удаляем временный конфиг Docker
    tput cnorm
    echo -e "${C_RST}"
    exit 0
}
trap cleanup_exit SIGINT SIGTERM

# Настройка цветов ANSI
ESC=$(printf '\033')
C_KEY="${ESC}[93m"   # Bright Yellow
C_LBL="${ESC}[36m"   # Cyan/Blue
C_GRY="${ESC}[90m"   # Gray
C_VAL="${ESC}[92m"   # Bright Green
C_OK="${ESC}[92m"    # Bright Green
C_ERR="${ESC}[91m"   # Bright Red
C_RST="${ESC}[0m"    # Reset

# === ЯЗЫКОВОЙ МОДУЛЬ ===
FORCE_LANG="AUTO"  # AUTO | RU | EN
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
# Примечание: Переменные очищены от «мусора» и соответствуют только реальным вызовам в коде. v4
if [ "$SYS_LANG" == "RU" ]; then
    # RUSSIAN DICTIONARY
    L_K_MOVE_ASK="Обновить текущий профиль данными из Menuconfig? [Y/N]"
    L_K_MOVE_OK="${C_OK}[DONE]${C_RST} Переменная SRC_EXTRA_CONFIG в профиле обновлена."
    L_K_MOVE_ARCH="Временный файл переименован в _manual_config."    
    L_LANG_NAME="РУССКИЙ"
    L_VERDICT="Вердикт"
    L_INIT_ENV="[INIT] Проверка окружения..."
    L_INIT_NET="[INIT] Очистка неиспользуемых сетей Docker..."
    L_INIT_UNPACK="[INIT] Проверка распаковщика..."
    L_DONE_MENU="Готово. Переход в меню..."
    L_CHOICE="Ваш выбор"
    L_BACK="Назад"
    L_ERR_INPUT="Ошибка ввода."    
    L_ERR_DOCKER="[ERROR] Docker не обнаружен!"
    L_ERR_DOCKER_MSG="Убедитесь, что Docker установлен и запущен."
    L_ERR_COMPOSE="[ERROR] docker-compose не найден!"    
    L_CUR_MODE="Текущий режим"
    L_MODE_IMG="IMAGE BUILDER (Быстрая сборка)"
    L_MODE_SRC="SOURCE BUILDER (Полная компиляция)"
    L_PROFILES="Профили сборки"
    H_PROF="Профиль"
    H_ARCH="Архитектура"
    H_RES="Ресурсы | Сборки"
    L_LEGEND_IND="Индикаторы показывают состояние ресурсов и результатов сборки."
    L_LEGEND_TEXT="Легенда: F:Файлы P:Пакеты S:Исх M:manual_config H:hooks.sh | Прошивки: OI:Образ OS:Сборка"
    L_BTN_ALL="Собрать ВСЕ"
    L_BTN_SWITCH="Режим на"
    L_BTN_EDIT="Редактор"
    L_BTN_CLEAN="Обслуживание"
    L_BTN_WIZ="Мастер профилей"
    L_BTN_EXIT="Выход"
    L_BTN_IPK="Импорт IPK"    
    L_EXIT_CONFIRM="Выйти из программы? (Y/N): "
    L_EXIT_BYE="До новых встреч!"    
    L_EDIT_TITLE="РЕДАКТОР ПРОФИЛЯ"    
    L_SEL_IMPORT="Выберите профиль для импорта пакетов"    
    L_CLEAN_TITLE="МЕНЮ ОЧИСТКИ"
    L_CLEAN_SRC_SOFT="SOFT CLEAN (make clean)"
    L_CLEAN_SRC_HARD="HARD RESET (Удалить src-workdir)"
    L_CLEAN_SRC_DL="Очистить кэш исходников (dl)"
    L_CLEAN_SRC_CC="Очистить CCACHE (Кэш компилятора)"
    L_CLEAN_FULL="FULL FACTORY RESET (Сброс проекта)"
    L_CONFIRM_YES="Введите YES для подтверждения"    
    L_K_LAUNCH="[INFO] Запуск интерактивного Menuconfig..."
    L_K_SEL="Выберите профиль для настройки"
    L_K_SAVE="Фиксация конфигурации..."
    L_K_SAVED="Сохранено"
    L_K_STR="строк"
    L_K_EMPTY_DIFF="Дифф пуст, сохраняю полный конфиг."
    L_K_FINAL="Конфигурация сохранена в firmware_output"
    L_K_STAY="Остаться в контейнере? [y/N]"
    L_K_SHELL_H1="[SHELL] Вход в консоль. Текущая папка"
    L_K_SHELL_H2="Подсказка: введите mc для файлового менеджера."
    L_K_SHELL_H3="Чтобы выйти, введите exit."    
    L_WARN_MASS="Массовая компиляция из исходников! Это займет много времени."
    L_PARALLEL_BUILDS_START="Параллельная сборка! Логи сохраняются в:"
    L_MONITOR_HINT="Следите за процессом: 'tail -f <файл_лога>'"
    L_ALL_BUILDS_LAUNCHED="Все сборки запущены в фоновом режиме."
    L_WAITING_FOR_BUILDS="Ожидание завершения"
    L_ALL_BUILDS_DONE="Все сборки завершены."    
    L_ERR_WIZ="[ERROR] create_profile.sh не найден!"
else
    # ENGLISH DICTIONARY
    L_K_MOVE_ASK="Update current profile with Menuconfig data? [Y/N]"
    L_K_MOVE_OK="${C_OK}[DONE]${C_RST} SRC_EXTRA_CONFIG variable in profile updated."
    L_K_MOVE_ARCH="Temporary file renamed to _manual_config."    
    L_LANG_NAME="ENGLISH"
    L_VERDICT="Verdict"
    L_INIT_ENV="[INIT] Checking environment..."
    L_INIT_NET="[INIT] Pruning unused Docker networks..."
    L_INIT_UNPACK="[INIT] Checking unpacker..."
    L_DONE_MENU="Done. Returning to menu..."
    L_CHOICE="Your choice"
    L_BACK="Back"
    L_ERR_INPUT="Input error."
    L_ERR_DOCKER="[ERROR] Docker not found!"
    L_ERR_DOCKER_MSG="Make sure Docker is installed and running."
    L_ERR_COMPOSE="[ERROR] docker-compose not found!"
    L_CUR_MODE="Current Mode"
    L_MODE_IMG="IMAGE BUILDER (Fast Build)"
    L_MODE_SRC="SOURCE BUILDER (Full Compilation)"
    L_PROFILES="Build Profiles"
    H_PROF="Profile"
    H_ARCH="Architecture"
    H_RES="Resources | Builds"
    L_LEGEND_IND="Indicators show the state of resources and build results."
    L_LEGEND_TEXT="Legend: F:Files P:Packages S:Src M:manual_config H:hooks.sh | Firmwares: OI:Image OS:Build"
    L_BTN_ALL="Build ALL"
    L_BTN_SWITCH="Switch to"
    L_BTN_EDIT="Editor"
    L_BTN_CLEAN="Maintenance"
    L_BTN_WIZ="Profile Wizard"
    L_BTN_EXIT="Exit"
    L_BTN_IPK="Import IPK"
    L_EXIT_CONFIRM="Exit the program? (Y/N): "
    L_EXIT_BYE="See you soon!"
    L_EDIT_TITLE="PROFILE EDITOR"    
    L_SEL_IMPORT="Select profile for package import"
    L_CLEAN_TITLE="CLEANUP AND MAINTENANCE MENU"
    L_CLEAN_SRC_SOFT="SOFT CLEAN (make clean)"
    L_CLEAN_SRC_HARD="HARD RESET (Remove src-workdir)"
    L_CLEAN_SRC_DL="Clean Source Cache (dl)"
    L_CLEAN_SRC_CC="Clean CCACHE (Compiler cache)"
    L_CLEAN_FULL="FULL FACTORY RESET (Reset project)"
    L_CONFIRM_YES="Type YES to confirm"
    L_K_LAUNCH="[INFO] Launching Interactive Menuconfig..."
    L_K_SEL="Select profile to configure"
    L_K_SAVE="[SAVE] Committing configuration..."
    L_K_SAVED="Saved"
    L_K_STR="lines"
    L_K_EMPTY_DIFF="Diff is empty, saving full config."
    L_K_FINAL="Configuration saved to firmware_output"
    L_K_STAY="Stay in container for file work? [y/N]"
    L_K_SHELL_H1="[SHELL] Entering console. Current folder"
    L_K_SHELL_H2="Tip: type mc to launch file manager."
    L_K_SHELL_H3="To exit and continue, type exit."
    L_WARN_MASS="Massive source compilation! This will take a lot of time."
    L_PARALLEL_BUILDS_START="Parallel builds! Logs are being saved to:"
    L_MONITOR_HINT="You can monitor progress with: 'tail -f <logfile>'"
    L_ALL_BUILDS_LAUNCHED="All build processes have been launched in the background."
    L_WAITING_FOR_BUILDS="Waiting for completion"
    L_ALL_BUILDS_DONE="All builds are complete."
    L_ERR_WIZ="[ERROR] create_profile.sh not found!"
fi

# Финальный вердикт языка
if [ "$FORCE_LANG" == "AUTO" ]; then
    echo -e "${C_LBL}[INIT]${C_RST} ${L_VERDICT} ${C_OK}${L_LANG_NAME}${C_RST} (Score ${ru_score}/10)"
else
    echo -e "${C_LBL}[INIT]${C_RST} Lang set: ${C_VAL}FORCE ${FORCE_LANG}${C_RST}"
fi
echo ""

# === КОНФИГУРАЦИЯ ===
PROJECT_DIR=$(pwd)  # Должно быть выше всего, что использует пути
export DOCKER_BUILDKIT=1
BUILD_MODE="IMAGE"
echo -e "$L_INIT_ENV"

# === ФИКС DOCKER CREDENTIALS ===
export DOCKER_CONFIG_DIR="$PROJECT_DIR/.docker_tmp"
mkdir -p "$DOCKER_CONFIG_DIR"
# Создаем временный конфиг без credsStore
echo '{"auths": {}}' > "$DOCKER_CONFIG_DIR/config.json"
export DOCKER_CONFIG="$DOCKER_CONFIG_DIR"

# Предварительный пулл теперь точно сработает
echo -e "${C_LBL}[INIT]${C_RST} Pulling base image..."

# Проверка Docker
D_VER=$(docker --version 2>/dev/null)
if [ -z "$D_VER" ]; then
    echo -e "$L_ERR_DOCKER"
    echo -e "$L_ERR_DOCKER_MSG"
    read -p "Press enter..." && exit 1
fi
echo -e "  ${C_GRY}-${C_RST} $D_VER"

# Проверка Compose
C_EXE="docker-compose"
if ! command -v docker-compose &> /dev/null; then
    if docker compose version &> /dev/null; then
        C_EXE="docker compose"
    else
        echo -e "$L_ERR_COMPOSE"
        read -p "Press enter..." && exit 1
    fi
fi
echo -e "  ${C_GRY}-${C_RST} Using: $C_EXE"

# Корень
PROJECT_DIR=$(pwd)
echo -e "  ${C_GRY}-${C_RST} Root: ${C_VAL}${PROJECT_DIR}${C_RST}"

echo -e "$L_INIT_NET"
docker network prune --force >/dev/null 2>&1
echo ""

# === 0. РАСПАКОВКА ===
if [ -f "_unpacker.sh" ]; then
    echo -e "$L_INIT_UNPACK"
    bash _unpacker.sh
fi

# === 1. ИНИЦИАЛИЗАЦИЯ ПАПОК ===
check_dir() { [ ! -d "$1" ] && mkdir -p "$1"; }
check_dir "profiles"
check_dir "custom_files"
check_dir "firmware_output"
check_dir "custom_packages"
check_dir "src_packages"

# === 2. ФУНКЦИИ СБОРКИ (CORE) ===

build_routine() {
    local conf_file="$1"
    local p_id="${conf_file%.conf}"
    local target_var=""
    
    [[ "$BUILD_MODE" == "IMAGE" ]] && target_var="IMAGEBUILDER_URL" || target_var="SRC_BRANCH"
    
    local target_val=$(grep "$target_var=" "profiles/$conf_file" | cut -d'"' -f2)
    [ -z "$target_val" ] && { echo -e "${C_ERR}[SKIP] $target_var not found${C_RST}"; return; }

    local is_legacy=0
    [[ "$target_val" =~ /(17|18|19)\. ]] && is_legacy=1

    export SELECTED_CONF="$conf_file"
    export HOST_FILES_DIR="./custom_files/$p_id"
    
    if [ "$BUILD_MODE" == "IMAGE" ]; then
        export HOST_OUTPUT_DIR="./firmware_output/imagebuilder/$p_id"
        export HOST_PKGS_DIR="./custom_packages/$p_id"
        local proj_name="build_$p_id"
        local comp_file="system/docker-compose.yaml"
        [ $is_legacy -eq 1 ] && local service="builder-oldwrt" || local service="builder-openwrt"
    else
        export HOST_OUTPUT_DIR="./firmware_output/sourcebuilder/$p_id"
        export HOST_PKGS_DIR="./src_packages/$p_id"
        local proj_name="srcbuild_$p_id"
        local comp_file="system/docker-compose-src.yaml"
        [ $is_legacy -eq 1 ] && local service="builder-src-oldwrt" || local service="builder-src-openwrt"
    fi

    mkdir -p "$HOST_OUTPUT_DIR"
    echo -e "${C_LBL}[BUILD]${C_RST} Target: ${C_VAL}$p_id${C_RST}"
    
    # === ФИКС БАГА "file exists" ===
    # 1. Принудительно удаляем контейнер, если он завис в базе Docker
    docker rm -f "${proj_name}-${service}-1" >/dev/null 2>&1
    
    # 2. Полный down с удалением анонимных томов (-v)
    $C_EXE -f "$comp_file" -p "$proj_name" down -v --remove-orphans >/dev/null 2>&1
    
    # 3. Даем WSL "продышаться". 2 секунды — золотой стандарт для освобождения bind-mounts
    sleep 2

    # 4. Запуск через 'run --rm'. 
    # Это чище, чем 'up', так как контейнер гарантированно удалится после работы.
    $C_EXE -f "$comp_file" -p "$proj_name" run --rm --quiet-pull "$service"
}

run_menuconfig() {
    local conf_file="$1"
    local p_id="${conf_file%.conf}"
    local out_path="./firmware_output/sourcebuilder/$p_id"
    mkdir -p "$out_path"

    echo -e "${C_LBL}${L_K_LAUNCH}${C_RST}"

    # 1. Определяем версию (Legacy или New), чтобы выбрать правильный контейнер
    local target_val=$(grep "SRC_BRANCH=" "profiles/$conf_file" | cut -d'"' -f2)
    local is_legacy=0
    [[ "$target_val" =~ /(17|18|19)\. ]] && is_legacy=1
    [ $is_legacy -eq 1 ] && local service="builder-src-oldwrt" || local service="builder-src-openwrt"

    # 2. Экспортируем переменные окружения для docker-compose
    export SELECTED_CONF="$conf_file"
    export HOST_FILES_DIR="./custom_files/$p_id"
    export HOST_OUTPUT_DIR="$out_path"
    export HOST_PKGS_DIR="./src_packages/$p_id"

    # 3. Создаем скрипт-раннер внутри папки вывода
    cat <<EOF > "$out_path/_menuconfig_runner.sh"
#!/bin/bash
set -e
export HOME=/home/build
cd /home/build/openwrt

# --- 1. Load Environment ---
echo "[INIT] Loading profile vars from: \$CONF_FILE"
# sed to remove BOM, tr to remove windows newlines
cat "/profiles/\$CONF_FILE" | sed '1s/^\xEF\xBB\xBF//' | tr -d '\r' > /tmp/env.sh
source /tmp/env.sh

# --- 2. Check Git State ---
if [ ! -f "Makefile" ]; then
    echo "[GIT] Makefile missing. Initializing repo..."
    rm -rf .git
    git init
    git remote add origin "\$SRC_REPO"
    git fetch origin "\$SRC_BRANCH"
    git checkout -f FETCH_HEAD
    git reset --hard FETCH_HEAD
    ./scripts/feeds update -a
    ./scripts/feeds install -a
fi

# --- 2.5 Inject Custom Packages ---
if [ -d "/input_packages" ] && [ -n "$(ls -A /input_packages 2>/dev/null)" ]; then
    echo "[PKG] Injecting custom sources..."
    mkdir -p package/custom-imports
    cp -rf /input_packages/* package/custom-imports/
    rm -rf tmp/.packageinfo tmp/.targetinfo
    ./scripts/feeds install -a
fi

# --- 3. Prepare Configuration ---
echo "[CONFIG] Preparing .config..."
rm -f .config
if [ -f "/output/manual_config" ]; then
    echo "[CONFIG] Found manual_config. Restoring..."
    cp /output/manual_config .config
    make defconfig
else
    echo "[CONFIG] Generating from profile..."
    echo "CONFIG_TARGET_\${SRC_TARGET}=y" > .config
    echo "CONFIG_TARGET_\${SRC_TARGET}_\${SRC_SUBTARGET}=y" >> .config
    echo "CONFIG_TARGET_\${SRC_TARGET}_\${SRC_SUBTARGET}_DEVICE_\${TARGET_PROFILE}=y" >> .config
    for pkg in \$SRC_PACKAGES; do
        if [[ "\$pkg" == -* ]]; then
            clean_pkg="\${pkg#-}"
            echo "# CONFIG_PACKAGE_\$clean_pkg is not set" >> .config
        else
            echo "CONFIG_PACKAGE_\$pkg=y" >> .config
        fi
    done
    [ -n "\$ROOTFS_SIZE" ] && echo "CONFIG_TARGET_ROOTFS_PARTSIZE=\$ROOTFS_SIZE" >> .config
    [ -n "\$KERNEL_SIZE" ] && echo "CONFIG_TARGET_KERNEL_PARTSIZE=\$KERNEL_SIZE" >> .config    
    # Replicating Batch logic: print -> trim CR -> loop write non-empty lines
    printf "%b\n" "\$SRC_EXTRA_CONFIG" | tr -d '\r' | while IFS= read -r line; do
        [ -n "\$line" ] && echo "\$line" >> .config
    done    
    make defconfig
fi

# --- 4. Menuconfig ---
echo "[START] Launching Menuconfig UI..."
make menuconfig

# --- 5. Save ---
echo "$L_K_SAVE"
make defconfig > /dev/null
./scripts/diffconfig.sh > /tmp/compact_config
if [ -s /tmp/compact_config ]; then
    cp /tmp/compact_config /output/manual_config
    L_COUNT=\$(cat /output/manual_config | wc -l)
    echo -e "\033[92m[SUCCESS]\033[0m $L_K_SAVED: \033[93m\$L_COUNT\033[0m $L_K_STR."
else
    echo -e "\033[91m[WARNING]\033[0m $L_K_EMPTY_DIFF"
    cp .config /output/manual_config
fi
chmod 666 /output/manual_config
touch /output/manual_config

# --- 6. Interactive Shell Option ---
printf "\n\033[92m[SUCCESS]\033[0m $L_K_FINAL \n"
read -p "$L_K_STAY " stay
if [[ "\$stay" =~ ^[Yy]$ ]]; then
    echo -e "\n\033[92m$L_K_SHELL_H1: \$(pwd)\033[0m"
    echo -e "----------------------------------------------------------"
    echo -e "$L_K_SHELL_H2"
    echo -e "$L_K_SHELL_H3"
    echo -e "----------------------------------------------------------\n"
    /bin/bash
fi
EOF
    
    # 4. ФАКТИЧЕСКИЙ ЗАПУСК КОНТЕЙНЕРА (Интерактивный режим -it)
    # Добавляем chown для установки правильных прав доступа, как в .bat
    local run_cmd="chown -R build:build /home/build/openwrt && chown build:build /output && sudo -E -u build bash /output/_menuconfig_runner.sh"
    
    $C_EXE -f system/docker-compose-src.yaml -p "srcbuild_$p_id" run --rm -it "$service" /bin/bash -c "$run_cmd"
    
    # --- БЛОК ПОСТ-ОБРАБОТКИ КОНФИГУРАЦИИ (BASH EDITION) ---
    if [ -f "$out_path/manual_config" ]; then
        echo -e "\n${C_KEY}----------------------------------------------------------${C_RST}"
        echo -e "Profile: ${C_VAL}${conf_file}${C_RST}"
        
        # Генерация метки времени
        ts=$(date +"%Y%m%d_%H%M%S")
        
        read -p "$(echo -e "$L_K_MOVE_ASK: ")" m_apply
        
        if [[ "$m_apply" =~ ^[Yy]$ ]]; then
            echo -e "[PROCESS] Updating profiles/$conf_file..."
            # 1. Читаем конфиг, убираем \r
            # 2. Экранируем одинарные кавычки для Bash-формата: ' меняем на '\''
            manual_data=$(cat "$out_path/manual_config" | tr -d '\r' | sed "s/'/'\\\\''/g")
            # Формируем новый блок, используя ОДИНАРНЫЕ кавычки (как в PowerShell версии)
            new_block="SRC_EXTRA_CONFIG='${manual_data}'"

            if grep -q "^SRC_EXTRA_CONFIG=" "profiles/$conf_file"; then
                export NEW_BLOCK="$new_block"
                # Perl Regex: ищем SRC_EXTRA_CONFIG=, затем любую кавычку (одинарную \x27 или двойную \x22),
                # захватываем контент до такой же закрывающей кавычки (\1).
                perl -i -0777 -pe 's/^SRC_EXTRA_CONFIG=([\x22\x27]).*?\1/$ENV{NEW_BLOCK}/ms' "profiles/$conf_file"
            else
                echo -e "\n$new_block" >> "profiles/$conf_file"
            fi
            echo -e "$L_K_MOVE_OK"
            mv "$out_path/manual_config" "$out_path/applied_config_${ts}.bak"
            echo -e "[INFO] Archived to: applied_config_${ts}.bak"
        fi
        echo -e "${C_KEY}----------------------------------------------------------${C_RST}"
    fi

    # Очистка временного файла
    rm -f "$out_path/_menuconfig_runner.sh"
}

# === GRANULAR CLEANUP SYSTEM ===
release_locks() {
    local p_id="$1"
    echo -e "  ${C_GRY}[LOCK] Releasing containers for $p_id...${C_RST}"
    if [ "$p_id" == "ALL" ]; then
        # Удаляем все контейнеры, связанные с проектом
        docker ps -aq -f "name=builder-" | xargs -r docker rm -f
        docker ps -aq -f "name=srcbuild-" | xargs -r docker rm -f
    else
        # Удаляем только конкретный проект
        docker ps -aq | xargs -r docker inspect --format '{{.Name}}' | grep -E "build_$p_id|srcbuild_$p_id" | xargs -r -I {} docker rm -f {}
    fi
}

cleanup_wizard() {
    clear
    echo -e "${C_VAL}${L_CLEAN_TITLE}${C_RST}\n"
    echo " 1. $L_CLEAN_SRC_SOFT (make clean)"
    echo " 2. $L_CLEAN_SRC_HARD (Delete Workdir)"
    echo " 3. $L_CLEAN_SRC_DL (Sources)"
    echo " 4. $L_CLEAN_SRC_CC (CCache)"
    echo " 5. $L_CLEAN_FULL"
    echo " 0. $L_BACK"
    read -p "$L_CHOICE: " c_choice
    
    [ "$c_choice" == "0" ] && return

    echo -e "\nApply to: [1-$count] or [A]ll"
    read -p "Target: " t_choice
    
    local target_id="ALL"
    if [ "$t_choice" != "A" ] && [ "$t_choice" != "a" ]; then
        if [ -n "${profiles[$t_choice]}" ]; then
            target_id="${profiles[$t_choice]%.conf}"
        else
            echo -e "${C_ERR}Invalid profile index${C_RST}"
            sleep 1; return
        fi
    fi

    # Сначала снимаем блокировки (гасим контейнеры)
    release_locks "$target_id"
    
    case $c_choice in
        1) 
            echo "Running make clean..."
            # Для простоты в Bash версии просто выводим уведомление, 
            # так как make clean требует запущенного контейнера
            sleep 1 
            ;;
        2) 
            cleanup_logic "src-workdir" "$target_id" 
            ;;
        3) 
            cleanup_logic "src-dl-cache" "$target_id" 
            ;;
        4) 
            cleanup_logic "src-ccache" "$target_id" 
            ;;
        5) 
            echo -ne "$L_CONFIRM_YES: "
            read -r confirm
            if [ "$confirm" == "YES" ]; then
                docker system prune -f --volumes
            fi
            ;;
        *) 
            return 
            ;;
    esac
    read -p "Done. Press Enter..."
}

# === Вспомогательные функции ===
create_perms_script() {
    local p_id=$1
    local dir="custom_files/${p_id}/etc/uci-defaults"
    local target="${dir}/99-permissions.sh"
    
    # Пытаемся создать путь, игнорируя ошибки
    mkdir -p "$dir" 2>/dev/null
    
    # Если файл уже существует - выходим
    [ -f "$target" ] && return 
    
    # Пишем файл
    cat <<EOF > "$target"
#!/bin/sh
[ -d /etc/dropbear ] && chmod 700 /etc/dropbear
[ -f /etc/dropbear/authorized_keys ] && chmod 600 /etc/dropbear/authorized_keys
[ -f /etc/shadow ] && chmod 600 /etc/shadow
exit 0
EOF
    chmod +x "$target" 2>/dev/null
}

# === ADVANCED ARCHITECTURE MAPPING (v3.0) ===
patch_architectures() {
    echo -e "${C_LBL}[INIT]${C_RST} Advanced Architecture Mapping..."
    for p in profiles/*.conf; do
        [ -e "$p" ] || continue
        if ! grep -q "SRC_ARCH=" "$p"; then
            local target=$(grep "SRC_TARGET=" "$p" | cut -d'"' -f2)
            local sub=$(grep "SRC_SUBTARGET=" "$p" | cut -d'"' -f2)
            [ -z "$target" ] && target=$(grep "IMAGEBUILDER_URL=" "$p" | sed -n 's|.*/targets/\([^/]*\)/\([^/]*\)/.*|\1|p')
            [ -z "$sub" ] && sub=$(grep "IMAGEBUILDER_URL=" "$p" | sed -n 's|.*/targets/\([^/]*\)/\([^/]*\)/.*|\2|p')
            
            local arch=""
            case "$target" in
                ramips) arch="mipsel_24kc" ;;
                ath79|ar71xx|lantiq|realtek) arch="mips_24kc" ;;
                x86) [[ "$sub" == "64" ]] && arch="x86_64" || arch="i386_pentium4" ;;
                mediatek)
                    # Добавляем filogic в проверку - это просто расширит список моделей
                    if [[ "$sub" =~ mt798|mt7622|filogic ]]; then arch="aarch64_cortex-a53"
                    elif [[ "$sub" == "mt7623" ]]; then arch="arm_cortex-a7_neon-vfpv4"
                    else arch="mipsel_24kc"; fi ;;
                mvebu)
                    if [[ "$sub" == "cortexa72" ]]; then arch="aarch64_cortex-a72"; else arch="arm_cortex-a9_vfpv3-d16"; fi ;;
                ipq40xx) arch="arm_cortex-a7_neon-vfpv4" ;;
                ipq806x) arch="arm_cortex-a15_neon-vfpv4" ;;
                rockchip) arch="aarch64_generic" ;;
                bcm27xx)
                    if [[ "$sub" == "bcm2711" ]]; then arch="aarch64_cortex-a72"
                    elif [[ "$sub" == "bcm2710" ]]; then arch="aarch64_cortex-a53"
                    else arch="arm_arm1176jzf-s_vfp"; fi ;;
                sunxi) arch="arm_cortex-a7_neon-vfpv4" ;;
                layerscape) [[ "$sub" == "64b" ]] && arch="aarch64_generic" || arch="arm_cortex-a7_neon-vfpv4" ;;
                *64*) arch="aarch64_generic" ;;
            esac
            
            if [ -n "$arch" ]; then
                echo "SRC_ARCH=\"$arch\"" >> "$p"
                echo -e "  ${C_OK}[PATCHED]${C_RST} $(basename "$p") -> $arch"
            fi
        fi
    done
}

patch_architectures

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
    echo -e "  ${C_VAL}OpenWrt FW Linux Builder ${VER_NUM}${C_RST} [${C_VAL}${SYS_LANG}${C_RST}]          ${C_LBL}https://github.com/iqubik/routerFW${C_RST}"
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
        # Очищаем имя от возможных невидимых символов Windows (\r)
        p_id=$(echo "${p_name%.conf}" | tr -d '\r')
        profiles[$count]=$p_name
        
        # --- [БЫСТРАЯ ИНИЦИАЛИЗАЦИЯ] ---
        # Создаем только основные пути один раз, без лишних проверок
        # --- [FORCE INITIALIZATION] ---
        for base in "custom_files" "custom_packages" "src_packages" "firmware_output/imagebuilder" "firmware_output/sourcebuilder"; do
            target_path="$base/$p_id"
            
            # Если это файл (а не папка) - удаляем принудительно, иначе mkdir не сработает
            if [ -e "$target_path" ] && [ ! -d "$target_path" ]; then
                rm -f "$target_path"
            fi

            # Создаем папку. 
            mkdir -p "$target_path" 2>/dev/null
        done

        # Создаем вложенную структуру (etc/uci-defaults)
        # Если 'etc' - это файл, сносим его
        if [ -e "custom_files/$p_id/etc" ] && [ ! -d "custom_files/$p_id/etc" ]; then
             rm -f "custom_files/$p_id/etc"
        fi
        mkdir -p "custom_files/$p_id/etc/uci-defaults" 2>/dev/null

        # Теперь создание скрипта точно сработает
        create_perms_script "$p_id"
        # ------------------------------

        # Архитектура
        this_arch=$(grep "SRC_ARCH=" "$f" | cut -d'"' -f2 | tr -d '\r')
        [ -z "$this_arch" ] && this_arch="--------"

        # Статусы ресурсов (F P S M H)
        st_f="${C_GRY}·${C_RST}"; [ "$(ls -A "custom_files/$p_id" 2>/dev/null)" ] && st_f="${C_LBL}F${C_RST}"
        st_p="${C_GRY}·${C_RST}"; [ "$(ls -A "custom_packages/$p_id" 2>/dev/null)" ] && st_p="${C_KEY}P${C_RST}"
        st_s="${C_GRY}·${C_RST}"; [ "$(ls -A "src_packages/$p_id" 2>/dev/null)" ] && st_s="${C_VAL}S${C_RST}"
        st_m="${C_GRY}·${C_RST}"; [ -f "firmware_output/sourcebuilder/$p_id/manual_config" ] && st_m="${C_OK}M${C_RST}"
        
        # Индикатор Хуков (H) - Исправленный путь
        st_h="${C_GRY}·${C_RST}"
        [ -f "custom_files/$p_id/hooks.sh" ] && st_h="${C_KEY}H${C_RST}"

        # Статусы билдов (OI OS) - Реагируют на ЛЮБЫЕ файлы в любых подпапках
        st_oi="${C_GRY}··${C_RST}"; [ -n "$(find "firmware_output/imagebuilder/$p_id" -type f 2>/dev/null)" ] && st_oi="${C_VAL}OI${C_RST}"
        st_os="${C_GRY}··${C_RST}"; [ -n "$(find "firmware_output/sourcebuilder/$p_id" -type f 2>/dev/null)" ] && st_os="${C_VAL}OS${C_RST}"

        # Вывод
        printf "    ${C_GRY}[${C_KEY}%2d${C_GRY}]${C_RST} %-45s ${C_LBL}%-20s${C_RST} ${C_GRY}[%s%s%s%s%s | %s %s]${C_RST}\n" \
               $count "$p_id" "$this_arch" "$st_f" "$st_p" "$st_s" "$st_m" "$st_h" "$st_oi" "$st_os"
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
                tput cnorm
                exit 0
            fi 
            continue ;;
        [Mm]) 
            [[ "$BUILD_MODE" == "IMAGE" ]] && BUILD_MODE="SOURCE" || BUILD_MODE="IMAGE" ;;
        [Ee])
            # Меню редактирования (упрощенно)
            echo -e "${C_VAL}${L_EDIT_TITLE}${C_RST}"
            # Тут логика открытия редактора (vi/nano или xdg-open)
            for ((i=1; i<=count; i++)); do printf "  [%d] %s\n" "$i" "${profiles[$i]}"; done
            read -p "ID: " e_id
            [ -n "${profiles[$e_id]}" ] && "${EDITOR:-nano}" "profiles/${profiles[$e_id]}" ;;
        [Aa])
            # Массовая сборка с параллельным выполнением и логированием
            if [ "$BUILD_MODE" == "SOURCE" ]; then
                echo -e "${C_ERR}${L_WARN_MASS}${C_RST}"
                read -p "Press Enter to continue..."
            fi
            
            LOG_DIR="firmware_output/.build_logs/$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$LOG_DIR"
            
            echo -e "\n${C_VAL}${L_PARALLEL_BUILDS_START}${C_RST} ${C_LBL}$LOG_DIR${C_RST}\n"
            
            pids=()
            printf "    %-65s | %s\n" "${C_GRY}PROFILE" "LOG FILE${C_RST}"
            printf "    %s\n" "${C_GRY}--------------------------------------------------------------------------------------------------------------------${C_RST}"
            for p in "${profiles[@]}"; do
                p_id="${p%.conf}"
                log_file="$LOG_DIR/${p_id}.log"
                
                printf "    %-65s | %s\n" "${C_KEY}-> Starting: $p_id${C_RST}" "${C_LBL}${log_file}${C_RST}"
                
                # Запускаем сборку в фоне, перенаправляя вывод в лог
                build_routine "$p" > "$log_file" 2>&1 &
                pids+=($!)
            done
            
            echo -e "\n${C_OK}${L_ALL_BUILDS_LAUNCHED}${C_RST}"
            echo -e "${C_LBL}${L_MONITOR_HINT}${C_RST}\n"
            
            # --- ADVANCED WAIT with STATUS ---
            # Create an associative array to map PIDs to profile names for better reporting
            declare -A pid_map
            for i in "${!pids[@]}"; do
                # Bash array is 0-indexed, 'profiles' array is 1-indexed
                pid_map[${pids[$i]}]="${profiles[$((i+1))]%.conf}"
            done
            
            running_pids=("${pids[@]}")
            spinner=("/" "-" "\\" "|")
            spin_idx=0
            
            while [ ${#running_pids[@]} -gt 0 ]; do
                still_running=()
                
                for pid in "${running_pids[@]}"; do
                    if kill -0 "$pid" 2>/dev/null; then
                        # Process is still alive
                        still_running+=("$pid")
                    else
                        # Process has finished, check its exit code
                        if ! wait "$pid"; then
                            # Clear the spinner line before printing an error to avoid visual glitches
                            printf "\r%120s\r" " " 
                            echo -e "${C_ERR}[ERROR] Build for profile '${pid_map[$pid]}' failed. Check log.${C_RST}"
                        fi
                    fi
                done

                # Update the list of running PIDs for the next loop iteration
                running_pids=("${still_running[@]}")
                
                # Print the dynamic status line with spinner and list of running jobs
                if [ ${#running_pids[@]} -gt 0 ]; then
                    running_names=""
                    for pid in "${running_pids[@]}"; do
                        running_names+="${pid_map[$pid]} "
                    done
                    # The trailing spaces are to clear any previous, longer text on the same line
                    printf "\r${C_LBL}[%s]${C_RST} ${L_WAITING_FOR_BUILDS} (%d left): ${C_VAL}%s${C_RST}      " "${spinner[$spin_idx]}" "${#running_pids[@]}" "$running_names"
                fi
                
                sleep 0.5
                spin_idx=$(( (spin_idx+1) % 4 ))
            done
            
            # Clear the final status line and show the completion message
            printf "\r%120s\r" " "
            echo -e "${C_OK}${L_ALL_BUILDS_DONE}${C_RST}"
            read -p "$L_DONE_MENU"
            ;;
        [Kk])
            if [ "$BUILD_MODE" == "SOURCE" ]; then
                # Здесь вызов функции Menuconfig
                echo -e "${L_K_SEL}:"
                for ((i=1; i<=count; i++)); do printf "  [%d] %s\n" "$i" "${profiles[$i]}"; done
                read -p "ID: " k_id
                [ -n "${profiles[$k_id]}" ] && run_menuconfig "${profiles[$k_id]}"
            fi ;;
        [Cc])
            cleanup_wizard ;;
        [Ii])
            if [ "$BUILD_MODE" == "SOURCE" ]; then
                echo -e "${L_SEL_IMPORT}:"
                for ((i=1; i<=count; i++)); do printf "  [%d] %s\n" "$i" "${profiles[$i]}"; done
                read -p "ID: " i_id
                if [ -n "${profiles[$i_id]}" ]; then
                    p_id="${profiles[$i_id]%.conf}"
                    p_arch=$(grep "SRC_ARCH=" "profiles/${profiles[$i_id]}" | cut -d'"' -f2)
                    bash system/import_ipk.sh "$p_id" "$p_arch"
                fi
            fi ;;
        [Ww])
            [ -f "system/create_profile.sh" ] && bash "system/create_profile.sh" || echo "$L_ERR_WIZ"
            read -p "Press enter..." ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "$count" ] && [ "$choice" -gt 0 ]; then
                # Фактический вызов функции сборки
                build_routine "${profiles[$choice]}"
                read -p "$L_DONE_MENU"
            else
                # Важно: здесь тоже должны быть пробелы!
                [ -n "$choice" ] && echo -e "${C_ERR}${L_ERR_INPUT}${C_RST}" && sleep 1
            fi 
            ;;
    esac
done