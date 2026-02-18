#!/bin/bash
# file: _Builder.sh
# Гарантируем, что мы работаем в папке скрипта
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

VER_NUM="4.43"

# Bootstrap — dict not yet available
# Функция очистки при прерывании (Ctrl+C). Вызывается по SIGINT/SIGTERM в любой момент,
# словарь может быть ещё не загружен — хардкод допустим.
cleanup_exit() {
    echo -e "\n${C_ERR}[INTERRUPT]${C_RST} Cleaning up running containers..."
    # Stop all running build containers to prevent orphans
    release_locks "ALL"
    # Remove the temporary Docker config
    rm -rf "$PROJECT_DIR/.docker_tmp" 
    echo -e "${C_RST}"
    exit 1 # Exit with an error code to indicate abnormal termination
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

# Предварительные переменные для лога детекции (будут перезаписаны в словаре, но нужны дефолты)
L_CHK_ENV="Environment LANG"
L_CHK_LOCALE="System Locale"
L_CHK_TZ="Timezone Check"

# 1. Проверка переменной окружения LANG (4 балла)
if [[ "$LANG" == *"ru"* ]]; then
    ((ru_score+=4))
    L_CHK_ENV_RES="${C_OK}RU${C_RST} [+4]"
else
    L_CHK_ENV_RES="${C_ERR}EN${C_RST}"
fi

# 2. Проверка команды locale (3 балла)
if command -v locale >/dev/null 2>&1; then
    if locale | grep -qi "ru_RU"; then
        ((ru_score+=3))
        L_CHK_LOCALE_RES="${C_OK}RU${C_RST} [+3]"
    else
        L_CHK_LOCALE_RES="${C_ERR}EN${C_RST}"
    fi
fi

# 3. Проверка временной зоны (2 балла)
if [ -f /etc/timezone ]; then
    if grep -qi "Moscow\|Europe/Russian" /etc/timezone; then
        ((ru_score+=2))
        L_CHK_TZ_RES="${C_OK}RU${C_RST} [+2]"
    fi
elif command -v timedatectl >/dev/null 2>&1; then
    if timedatectl | grep -qi "Moscow"; then
        ((ru_score+=2))
        L_CHK_TZ_RES="${C_OK}RU${C_RST} [+2]"
    fi
fi
[ -z "$L_CHK_TZ_RES" ] && L_CHK_TZ_RES="${C_ERR}EN${C_RST}"

# Логика суждения
if [ $ru_score -ge 5 ]; then SYS_LANG="RU"; fi

# === ПРИНУДИТЕЛЬНЫЙ ПЕРЕКЛЮЧАТЕЛЬ (OVERRIDE) ===
if [ "$FORCE_LANG" == "RU" ]; then SYS_LANG="RU"; fi
if [ "$FORCE_LANG" == "EN" ]; then SYS_LANG="EN"; fi

# === СЛОВАРЬ (DICTIONARY) ===
LANG_FILE="system/lang/${SYS_LANG,,}.sh.env"
[ ! -f "$LANG_FILE" ] && LANG_FILE="system/lang/en.sh.env"
source "$LANG_FILE"

# Language detector output — технический вывод детектора, хардкод допустим
echo -e "${C_LBL}[INIT]${C_RST} Language detector (Weighted Detection)..."
echo -e "  ${C_GRY}-${C_RST} ${L_CHK_ENV}${L_CHK_ENV_RES}"
if [ -n "$L_CHK_LOCALE_RES" ]; then
    echo -e "  ${C_GRY}-${C_RST} ${L_CHK_LOCALE}${L_CHK_LOCALE_RES}"
fi
echo -e "  ${C_GRY}-${C_RST} ${L_CHK_TZ}${L_CHK_TZ_RES}"

# Финальный вердикт языка
if [ "$FORCE_LANG" == "AUTO" ]; then
    echo -e "${C_LBL}[INIT]${C_RST} ${L_VERDICT} ${C_OK}${L_LANG_NAME}${C_RST} (Score ${ru_score}/10)"
else
    # Bootstrap — хардкод "Lang set: FORCE" допустим (информационное сообщение детектора)
    echo -e "${C_LBL}[INIT]${C_RST} Lang set: ${C_VAL}FORCE ${FORCE_LANG}${C_RST}"
fi
echo ""

# === КОНФИГУРАЦИЯ ===
PROJECT_DIR=$(pwd)  # Должно быть выше всего, что использует пути
export DOCKER_BUILDKIT=1
BUILD_MODE="IMAGE"
echo -e "$L_INIT_ENV"

# === ФИКС DOCKER CREDENTIALS ===
# Копируем реальный конфиг (с proxy/dns настройками), но убираем credsStore
# чтобы не падала авторизация в безголовых окружениях
export DOCKER_CONFIG_DIR="$PROJECT_DIR/.docker_tmp"
mkdir -p "$DOCKER_CONFIG_DIR"
_REAL_CFG="$HOME/.docker/config.json"
if [ -f "$_REAL_CFG" ] && command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
with open('$_REAL_CFG') as f:
    cfg = json.load(f)
cfg.pop('credsStore', None)
cfg.pop('credHelpers', None)
print(json.dumps(cfg))
" > "$DOCKER_CONFIG_DIR/config.json" 2>/dev/null || echo '{"auths":{}}' > "$DOCKER_CONFIG_DIR/config.json"
else
    echo '{"auths":{}}' > "$DOCKER_CONFIG_DIR/config.json"
fi
export DOCKER_CONFIG="$DOCKER_CONFIG_DIR"

# Предварительный пулл теперь точно сработает
echo -e "${C_LBL}${L_INIT_PULL}${C_RST}"

# Проверка Docker
D_VER=$(docker --version 2>/dev/null)
if [ -z "$D_VER" ]; then
    echo -e "$L_ERR_DOCKER"
    echo -e "$L_ERR_DOCKER_MSG"
    read -p "$L_PRESS_ENTER" && exit 1
fi
echo -e "  ${C_GRY}-${C_RST} $D_VER"

# Проверка Compose
C_EXE="docker-compose"
if ! command -v docker-compose &> /dev/null; then
    if docker compose version &> /dev/null; then
        C_EXE="docker compose"
    else
        echo -e "$L_ERR_COMPOSE"
        read -p "$L_PRESS_ENTER" && exit 1
    fi
fi
echo -e "${L_INIT_USING} $C_EXE"

# Корень
PROJECT_DIR=$(pwd)
echo -e "${L_INIT_ROOT} ${C_VAL}${PROJECT_DIR}${C_RST}"

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
check_dir "custom_patches"

# === 2. ФУНКЦИИ СБОРКИ (CORE) ===

build_routine() {
    local conf_file="$1"
    local p_id="${conf_file%.conf}"
    local target_var=""
    
    [[ "$BUILD_MODE" == "IMAGE" ]] && target_var="IMAGEBUILDER_URL" || target_var="SRC_BRANCH"
    
    local target_val=$(grep "$target_var=" "profiles/$conf_file" | cut -d'"' -f2 | tr -d '\r')
    [ -z "$target_val" ] && { echo -e "${C_ERR}[SKIP] $target_var not found${C_RST}"; return; }

    # Строгая проверка Legacy, как в BAT файле
    local is_legacy=0
    # 1. Проверка URL (ImageBuilder) - ищем паттерн "/XX."
    if [[ "$target_val" == *"/17."* ]] || [[ "$target_val" == *"/18."* ]] || [[ "$target_val" == *"/19."* ]]; then is_legacy=1; fi
    # 2. Проверка веток (Source) - конкретные версии
    if [[ "$target_val" == *"19.07"* ]] || [[ "$target_val" == *"18.06"* ]]; then is_legacy=1; fi

    # === FIX 1: ИСПОЛЬЗУЕМ АБСОЛЮТНЫЕ ПУТИ ===
    # Это решает проблемы с монтированием в WSL
    # Export Paths
    export SELECTED_CONF="$conf_file"
    export HOST_FILES_DIR="./custom_files/$p_id"
    # [NEW] Поддержка патчей (Sync v4.32)
    check_dir "custom_patches/$p_id"
    export HOST_PATCHES_DIR="./custom_patches/$p_id"
    
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

    # === FIX 2: Безопасное создание папок ===
    check_dir "$HOST_OUTPUT_DIR"
    
    echo -e "${C_LBL}[BUILD]${C_RST} ${L_BUILD_TARGET} ${C_VAL}$p_id${C_RST}"
    
    # 1. Принудительно удаляем контейнер (чистка хвостов)
    docker rm -f "${proj_name}-${service}-1" >/dev/null 2>&1
    # 2. Полный down с удалением анонимных томов (-v)
    $C_EXE -f "$comp_file" -p "$proj_name" down --remove-orphans >/dev/null 2>&1
    # 3. Пауза (важно для Windows/WSL)
    sleep 2

    # 4. Запуск (up, как в .bat: контейнер [project]_[service]_1; --build — свежий образ с CA)
    $C_EXE -f "$comp_file" -p "$proj_name" up --build --force-recreate --remove-orphans "$service"
    # === ВАЖНО: ЗАПОМИНАЕМ РЕЗУЛЬТАТ СБОРКИ ===
    local build_status=$?

    # === FIX 3: ВОССТАНОВЛЕНИЕ ПРАВ (ext4/Linux) ===
    if [ -d "$HOST_OUTPUT_DIR" ]; then
        # Используем docker для смены прав, чтобы не требовать sudo от пользователя скрипта
        docker run --rm -v "$(pwd)/${HOST_OUTPUT_DIR#./}:/work" alpine chown -R $(id -u):$(id -g) /work
    fi

    # 4. [NEW] "Stay in Container" logic (Only for Source Mode)
    if [ "$BUILD_MODE" == "SOURCE" ]; then
        if [ $build_status -eq 0 ]; then
            echo -e "\n${L_FINISHED}"

            # === POST-BUILD: поиск *imagebuilder*.tar.zst и обновление IMAGEBUILDER_URL ===
            local ib_archive=""
            ib_archive=$(find "${HOST_OUTPUT_DIR#./}" -name "*imagebuilder*.tar.zst" 2>/dev/null \
                | sort -t_ -k1 2>/dev/null | tail -1)
            if [ -n "$ib_archive" ]; then
                # Нормализуем путь: убираем ведущий ./ если есть
                ib_archive="${ib_archive#./}"
                echo ""
                echo -e "${C_KEY}${L_IB_UPDATE_ASK}${C_RST}"
                echo -e "  ${C_GRY}${ib_archive}${C_RST}"
                echo -e "${C_LBL}${L_IB_UPDATE_PROMPT}${C_RST} "
                read -r ib_upd_choice
                if [[ "$ib_upd_choice" =~ ^[Yy]$ ]]; then
                    local prof_path="profiles/${conf_file}"
                    local new_url_line="IMAGEBUILDER_URL=\"${ib_archive}\""
                    if grep -qE '^IMAGEBUILDER_URL=' "$prof_path"; then
                        # Комментируем старую строку и вставляем новую после неё
                        sed -i -E "s|^(IMAGEBUILDER_URL=.*)$|#\1\n${new_url_line}|" "$prof_path"
                    elif grep -qE '^#.*IMAGEBUILDER_URL=' "$prof_path"; then
                        # Добавляем новую строку в конец файла
                        echo "$new_url_line" >> "$prof_path"
                    else
                        echo "$new_url_line" >> "$prof_path"
                    fi
                    echo -e "${L_IB_UPDATE_OK}"
                fi
            fi
        else
            echo -e "\n${L_BUILD_FATAL}"
        fi
        
        echo -e "${C_LBL}[SHELL]${C_RST} ${L_K_STAY}" 
        read -r stay_choice
        if [[ "$stay_choice" =~ ^[Yy]$ ]]; then
            echo -e "${L_K_ENTER_SHELL}"
            echo -e "${L_K_SHELL_H3}"
            # Запускаем новый интерактивный контейнер
            $C_EXE -f "$comp_file" -p "$proj_name" run --rm -it "$service" /bin/bash
        fi
    fi

    # === ВОЗВРАЩАЕМ РЕАЛЬНЫЙ СТАТУС ===
    return $build_status    
}

run_menuconfig() {
    local conf_file="$1"
    local p_id="${conf_file%.conf}"
    local out_path="./firmware_output/sourcebuilder/$p_id"
    mkdir -p "$out_path"

    echo -e "${C_LBL}${L_K_LAUNCH}${C_RST}"

    # 1. Определяем версию (Legacy или New)
    local target_val=$(grep "SRC_BRANCH=" "profiles/$conf_file" | cut -d'"' -f2)
    # Строгая проверка Legacy, как в BAT файле
    local is_legacy=0    
    # 1. Проверка URL (ImageBuilder) - ищем паттерн "/XX."
    if [[ "$target_val" == *"/17."* ]] || [[ "$target_val" == *"/18."* ]] || [[ "$target_val" == *"/19."* ]]; then is_legacy=1; fi
    # 2. Проверка веток (Source) - конкретные версии
    if [[ "$target_val" == *"19.07"* ]] || [[ "$target_val" == *"18.06"* ]]; then is_legacy=1; fi
    [ $is_legacy -eq 1 ] && local service="builder-src-oldwrt" || local service="builder-src-openwrt"

    # 2. Экспорт переменных
    export SELECTED_CONF="$conf_file"
    export HOST_FILES_DIR="./custom_files/$p_id"
    export HOST_OUTPUT_DIR="$out_path"
    export HOST_PKGS_DIR="./src_packages/$p_id"

    # 3. Создаем скрипт-раннер
    cat <<EOF > "$out_path/_menuconfig_runner.sh"
#!/bin/bash
set -e
export HOME=/home/build
cd /home/build/openwrt

# --- 1. Load Environment ---
echo "[INIT] Loading profile vars from: \$CONF_FILE"
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
if [ -d "/input_packages" ] && [ -n "\$(ls -A /input_packages 2>/dev/null)" ]; then
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
    
    # [NEW] Smart Device Detection (Sync with Bat v4.32)
    # Check if DEVICE is already set in SRC_EXTRA_CONFIG to avoid conflict
    if echo "\$SRC_EXTRA_CONFIG" | grep -q "CONFIG_TARGET_.*_DEVICE_"; then
        echo "[CONFIG] Device explicitly set in EXTRA_CONFIG. Skipping auto-detection."
    else
        # Заменяем дефисы на подчеркивания, как делает OpenWrt build system
        CLEAN_PROFILE=\$(echo "\$TARGET_PROFILE" | tr '-' '_')
        echo "CONFIG_TARGET_\${SRC_TARGET}_\${SRC_SUBTARGET}_DEVICE_\$CLEAN_PROFILE=y" >> .config
    fi
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
    
    if [ -n "\$SRC_EXTRA_CONFIG" ]; then
        printf "%b\n" "\$SRC_EXTRA_CONFIG" | tr -d '\r' | while IFS= read -r line; do
            [ -n "\$line" ] && echo "\$line" >> .config
        done
    fi
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
    
    # Даем права на скрипт (важно для Linux/WSL)
    chmod 666 "$out_path/_menuconfig_runner.sh"

    # 4. ФАКТИЧЕСКИЙ ЗАПУСК КОНТЕЙНЕРА
    local run_cmd="chown -R build:build /home/build/openwrt && chown build:build /output && tr -d '\r' < /output/_menuconfig_runner.sh > /tmp/r.sh && chmod +x /tmp/r.sh && sudo -E -u build bash /tmp/r.sh"
    
    $C_EXE -f system/docker-compose-src.yaml -p "srcbuild_$p_id" run --rm -it "$service" /bin/bash -c "$run_cmd"
    
    # --- БЛОК ПОСТ-ОБРАБОТКИ КОНФИГУРАЦИИ ---
    if [ -f "$out_path/manual_config" ]; then
        echo -e "\n${C_KEY}${L_SEPARATOR}${C_RST}"
        echo -e "${H_PROF}: ${C_VAL}${conf_file}${C_RST}"
        
        # Генерация метки времени
        ts=$(date +"%Y%m%d_%H%M%S")
        
        read -p "$(echo -e "$L_K_MOVE_ASK: ")" m_apply
        
        if [[ "$m_apply" =~ ^[Yy]$ ]]; then
            echo -e "${L_K_UPDATING_PROFILE} profiles/$conf_file..."
            # Читаем конфиг, убираем \r, экранируем одинарные кавычки для Bash (' -> '\'')
            manual_data=$(cat "$out_path/manual_config" | tr -d '\r' | sed "s/'/'\\\\''/g")
            
            # Формируем новый блок
            new_block="SRC_EXTRA_CONFIG='${manual_data}'"
            export NEW_BLOCK="$new_block"

            if grep -q "^SRC_EXTRA_CONFIG=" "profiles/$conf_file"; then
                # Perl Regex: 
                # 1. Ищем SRC_EXTRA_CONFIG=
                # 2. (?: ... ) - группа вариантов
                # 3. (["\x27]).*?\1 - Вариант А: Есть кавычки (двойные или одинарные). Матчим до закрывающей.
                # 4. |[^\n]* - Вариант Б (Fallback): Кавычек нет или пустая строка. Матчим все до конца строки.
                # 5. Заменяем на $ENV{NEW_BLOCK}
                perl -i -0777 -pe 's/^SRC_EXTRA_CONFIG=(?:(["\x27]).*?\1|[^\n]*)/$ENV{NEW_BLOCK}/ms' "profiles/$conf_file"
            else
                echo -e "\n$new_block" >> "profiles/$conf_file"
            fi
            echo -e "$L_K_MOVE_OK"
            mv "$out_path/manual_config" "$out_path/applied_config_${ts}.bak"
            echo -e "[INFO] ${L_ARCHIVED_TO} applied_config_${ts}.bak"
        else            
            mv "$out_path/manual_config" "$out_path/discarded_config_${ts}.bak"
            echo -e "[INFO] ${L_ARCHIVED_TO} discarded_config_${ts}.bak"
        fi
        echo -e "${C_KEY}${L_SEPARATOR}${C_RST}"
    fi

    # Очистка временного файла
    rm -f "$out_path/_menuconfig_runner.sh"
    
    # Пауза, чтобы прочитать результат работы скрипта импорта
    echo ""
    read -p "$L_PRESS_ENTER"
}

# === GRANULAR CLEANUP SYSTEM ===
release_locks() {
    local p_id="$1"
    echo -e "  ${C_GRY}${L_LOCK_REL} $p_id...${C_RST}"
    if [ "$p_id" == "ALL" ]; then
        # Удаляем все контейнеры, чьи имена начинаются с префиксов build_ или srcbuild_
        # Это покрывает все возможные контейнеры сборки, созданные docker-compose
        docker ps -aq --filter "name=^build_" --filter "name=^srcbuild_" | xargs -r docker rm -f
    else
        # Удаляем контейнеры для конкретного профиля, используя оба возможных префикса
        docker ps -aq --filter "name=^build_${p_id}" --filter "name=^srcbuild_${p_id}" | xargs -r docker rm -f
    fi
}

cleanup_logic() {
    local type="$1"
    local p_id="$2"

    printf "  ${L_VOL_SEARCH_PROF}\n" "${type}" "${p_id}"

    if [ "$p_id" == "ALL" ]; then
        # FIX: Ищем тома, заканчивающиеся на _type, независимо от префикса (build_ или srcbuild_)
        local volumes_to_delete=$(docker volume ls -q | grep -E "_(srcbuild|build)_.*_${type}$")
        # Альтернатива, если grep сложный: grep -E ".*_${type}$" (но это опаснее)
        
        if [ -n "$volumes_to_delete" ]; then
            echo "$volumes_to_delete" | xargs -r docker volume rm
            echo -e "  ${L_R_OK}"
        else
            echo -e "  ${L_R_NOTHING}"
        fi
    else
        # FIX: Пробуем удалить оба варианта имени (для Source и Image режимов)
        local vol_src="srcbuild_${p_id}_${type}"
        local vol_img="build_${p_id}_${type}"
        
        # Удаляем srcbuild вариант
        if docker volume inspect "$vol_src" >/dev/null 2>&1; then
            docker volume rm "$vol_src" >/dev/null 2>&1
            echo -e "  ${L_VOL_DEL} '$vol_src'."
        fi
        
        # Удаляем build вариант
        if docker volume inspect "$vol_img" >/dev/null 2>&1; then
            docker volume rm "$vol_img" >/dev/null 2>&1
            echo -e "  ${L_VOL_DEL} '$vol_img'."
        fi
    fi
}

cleanup_wizard() {
    clear
    echo -e "${C_VAL}${L_CLEAN_TITLE} [${C_LBL}${BUILD_MODE}${C_VAL}]${C_RST}\n"

    # Разделение меню в зависимости от режима
    if [ "$BUILD_MODE" == "SOURCE" ]; then
        echo " 1. $L_CLEAN_SRC_SOFT (make clean)"
        echo " 2. $L_CLEAN_SRC_HARD (Remove src-workdir)"
        echo " 3. $L_CLEAN_SRC_DL (Sources)"
        echo " 4. $L_CLEAN_SRC_CC (CCache)"
        echo " 5. $L_CLEAN_SRC_TMP"
        echo " 6. $L_CLEAN_FULL"
    else
        # Меню для IMAGE BUILDER
        echo " 1. $L_CLEAN_IMG_SDK"   # <-- Исправлено
        echo " 2. $L_CLEAN_IMG_IPK"   # <-- Исправлено
        echo " 3. $L_CLEAN_FULL"
    fi
    echo -e "\n 9. $L_DOCKER_PRUNE" # <--- Добавлено (было пропущено)
    echo " 0. $L_BACK"
    
    read -p "$L_CHOICE: " c_choice
    [ "$c_choice" == "0" ] && return
    
    # Обработка глобального Prune (пункт 9)
    if [ "$c_choice" == "9" ]; then
        echo -e "\n$L_PRUNE_RUN"
        docker system prune -f
        read -p "$L_PRESS_ENTER"
        return
    fi

    # Выбор цели (Профиль или ALL)
    echo -e "\n${L_CLEAN_TYPE}: [1-$count] / [A] ${L_CLEAN_ALL_PROF}"
    read -p "${L_TARGET_PROMPT}: " t_choice
    
    local target_id="ALL"
    if [ "$t_choice" != "A" ] && [ "$t_choice" != "a" ]; then
        if [ -n "${profiles[$t_choice]}" ]; then
            target_id="${profiles[$t_choice]%.conf}"
            target_id=$(echo "$target_id" | tr -d '\r')
        else
            echo -e "${L_ERR_PROF_IDX}"
            sleep 1; return
        fi
    fi

    # Сначала снимаем блокировки
    release_locks "$target_id"
    
    if [ "$BUILD_MODE" == "SOURCE" ]; then
        # === ЛОГИКА SOURCE BUILDER ===
        case $c_choice in
            1) 
                # SOFT CLEAN (Make Clean) - Реализация как в BAT
                if [ "$target_id" == "ALL" ]; then
                    echo -e "${L_CLEAN_SOFT_ALL_ERR}"
                else
                    echo "$L_CLEAN_START_CONTAINER"
                    # Важно: используем абсолютные пути, как в build_routine
                    export HOST_FILES_DIR="$(pwd)/custom_files/$target_id"
                    export HOST_OUTPUT_DIR="$(pwd)/firmware_output/sourcebuilder/$target_id"
                    export HOST_PKGS_DIR="$(pwd)/src_packages/$target_id"
                    
                    # Запуск команды make clean внутри контейнера
                    docker-compose -f system/docker-compose-src.yaml -p "srcbuild_$target_id" \
                        run --rm builder-src-openwrt /bin/bash -c \
                        "cd /home/build/openwrt && if [ -f Makefile ]; then echo '[CMD] make clean'; make clean; echo '[DONE] Clean Completed'; else echo '[WARN] Makefile not found'; fi"
                fi
                ;;
            2) cleanup_logic "src-workdir" "$target_id" ;;
            3) cleanup_logic "src-dl-cache" "$target_id" ;;
            4) cleanup_logic "src-ccache" "$target_id" ;;
            5)
                # [NEW] TMP CLEANUP (Sync with Bat v4.32)
                if [ "$target_id" == "ALL" ]; then
                    echo -e "${L_CLEAN_SOFT_ALL_ERR}"
                else
                    echo "$L_CLEAN_START_CONTAINER"
                    export HOST_FILES_DIR="$(pwd)/custom_files/$target_id"
                    export HOST_OUTPUT_DIR="$(pwd)/firmware_output/sourcebuilder/$target_id"
                    export HOST_PKGS_DIR="$(pwd)/src_packages/$target_id"
                    docker-compose -f system/docker-compose-src.yaml -p "srcbuild_$target_id" \
                        run --rm builder-src-openwrt /bin/bash -c \
                        "cd /home/build/openwrt && rm -rf tmp/ && echo '[DONE] Index/Tmp cleaned'"
                fi
                ;;
            6) 
                # FULL RESET (Moved to 6)
                cleanup_logic "src-workdir" "$target_id"
                cleanup_logic "src-dl-cache" "$target_id"
                cleanup_logic "src-ccache" "$target_id"
                # Дополнительно удаляем папку вывода
                if [ "$target_id" == "ALL" ]; then
                    rm -rf firmware_output/sourcebuilder/* 2>/dev/null
                else
                    rm -rf "firmware_output/sourcebuilder/$target_id" 2>/dev/null
                fi
                echo -e "${L_CLEAN_FULL_DONE}"
                ;;
            *) return ;;
        esac
    else
        # === ЛОГИКА IMAGE BUILDER ===
        case $c_choice in
            1) cleanup_logic "imagebuilder-cache" "$target_id" ;; # SDK Cache
            2) cleanup_logic "ipk-cache" "$target_id" ;;          # IPK Cache
            3)
                # FULL RESET (Image)
                cleanup_logic "imagebuilder-cache" "$target_id"
                cleanup_logic "ipk-cache" "$target_id"
                if [ "$target_id" == "ALL" ]; then
                    rm -rf firmware_output/imagebuilder/* 2>/dev/null
                else
                    rm -rf "firmware_output/imagebuilder/$target_id" 2>/dev/null
                fi
                echo -e "${L_CLEAN_FULL_DONE}"
                ;;
            *) return ;;
        esac
    fi
    echo ""
    read -p "$L_PRESS_ENTER"
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
[ -f /root/.ssh ] && chmod 700 /root/.ssh
[ -f /root/.ssh/id_rsa ] && chmod 600 /root/.ssh/id_rsa
exit 0
EOF
    chmod +x "$target" 2>/dev/null
}

# === PROFILE VARIABLE MIGRATION (идемпотентная миграция устаревших имён) ===
# Переименовывает PKGS -> IMAGE_PKGS и EXTRA_IMAGE_NAME -> IMAGE_EXTRA_NAME
# Запускается один раз при старте; безопасна для повторного запуска.
migrate_profile_vars() {
    for p in profiles/*.conf; do
        [ -e "$p" ] || continue
        local content
        content=$(cat "$p")
        local changed=0

        # PKGS= -> IMAGE_PKGS= (только если IMAGE_PKGS ещё не существует)
        if echo "$content" | grep -qE '^#?PKGS=' && ! echo "$content" | grep -qE '^#?IMAGE_PKGS='; then
            sed -i \
                -e 's/^PKGS=/IMAGE_PKGS=/' \
                -e 's/^#PKGS=/#IMAGE_PKGS=/' \
                -e 's/\$PKGS\b/$IMAGE_PKGS/g' \
                "$p"
            changed=1
        fi

        # EXTRA_IMAGE_NAME= -> IMAGE_EXTRA_NAME= (только если IMAGE_EXTRA_NAME ещё не существует)
        if echo "$content" | grep -qE '^#?EXTRA_IMAGE_NAME=' && ! echo "$content" | grep -qE '^#?IMAGE_EXTRA_NAME='; then
            sed -i \
                -e 's/^EXTRA_IMAGE_NAME=/IMAGE_EXTRA_NAME=/' \
                -e 's/^#EXTRA_IMAGE_NAME=/#IMAGE_EXTRA_NAME=/' \
                "$p"
            changed=1
        fi

        if [ $changed -eq 1 ]; then
            echo -e "  ${C_VAL}${L_INIT_PATCHED}${C_RST} $(basename "$p") — IMAGE_PKGS / IMAGE_EXTRA_NAME"
        fi
    done
}

# === ADVANCED ARCHITECTURE MAPPING (v3.0) ===
patch_architectures() {
    echo -e "${C_LBL}${L_INIT_MAP}${C_RST}"
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
                echo -e "  ${C_OK}${L_INIT_PATCHED}${C_RST} $(basename "$p") -> $arch"
            fi
        fi
    done
}

patch_architectures
migrate_profile_vars

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
        # --- [FORCE INITIALIZATION] ---        
        for base in "custom_files" "custom_packages" "src_packages" "custom_patches" "firmware_output/imagebuilder" "firmware_output/sourcebuilder"; do
            target_path="$base/$p_id"
            
            # 1. Если там файл-призрак или мусор - сносим
            if [ -e "$target_path" ] && [ ! -d "$target_path" ]; then
                rm -f "$target_path"
            fi

            # 2. Пытаемся создать. Если ошибка (глюк NTFS) - повторяем жестко.
            if ! mkdir -p "$target_path" 2>/dev/null; then
                # Если сбой, значит WSL видит "призрак". Удаляем и ждем.
                rm -rf "$target_path"
                sleep 0.1
                mkdir -p "$target_path" 2>/dev/null
            fi
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
        st_f="${C_GRY}·${C_RST}"; [ "$(ls -A "custom_files/$p_id" 2>/dev/null)" ] && st_f="${C_GRY}F${C_RST}"
        st_p="${C_GRY}·${C_RST}"; [ "$(ls -A "custom_packages/$p_id" 2>/dev/null)" ] && st_p="${C_KEY}P${C_RST}"
        st_s="${C_GRY}·${C_RST}"; [ "$(ls -A "src_packages/$p_id" 2>/dev/null)" ] && st_s="${C_VAL}S${C_RST}"
        st_m="${C_GRY}·${C_RST}"; [ -f "firmware_output/sourcebuilder/$p_id/manual_config" ] && st_m="${C_ERR}M${C_RST}"
        
        # Индикатор Хуков (H)
        st_h="${C_GRY}·${C_RST}"
        [ -f "custom_files/$p_id/hooks.sh" ] && st_h="${C_LBL}H${C_RST}"

        # [NEW] Индикатор Патчей (X)
        st_pt="${C_GRY}·${C_RST}"
        [ -d "custom_patches/$p_id" ] && [ "$(ls -A "custom_patches/$p_id" 2>/dev/null)" ] && st_pt="${C_GRY}X${C_RST}"        

        # Статусы билдов (OI OS) - Реагируют на ЛЮБЫЕ файлы в любых подпапках
        st_oi="${C_GRY}··${C_RST}"; [ -n "$(find "firmware_output/imagebuilder/$p_id" -type f 2>/dev/null)" ] && st_oi="${C_VAL}OI${C_RST}"
        st_os="${C_GRY}··${C_RST}"; [ -n "$(find "firmware_output/sourcebuilder/$p_id" -type f 2>/dev/null)" ] && st_os="${C_VAL}OS${C_RST}"

        # Вывод
        printf "    ${C_GRY}[${C_KEY}%2d${C_GRY}]${C_RST} %-45s ${C_LBL}%-20s${C_RST} ${C_GRY}[%s%s%s%s%s%s | %s %s]${C_RST}\n" \
               $count "$p_id" "$this_arch" "$st_f" "$st_p" "$st_s" "$st_m" "$st_h" "$st_pt" "$st_oi" "$st_os"
    done

    echo -e "    ${C_GRY}────────────────────────────────────────────────────────────────────────────────────────────────────────────${C_RST}"
    echo -e "    ${L_LEGEND_IND}"
    echo -e "    ${C_GRY}${L_LEGEND_TEXT}${C_RST}\n"
    
    printf "    ${C_LBL}[${C_KEY}A${C_LBL}] %-18s ${C_LBL}[${C_KEY}M${C_LBL}] %s ${C_VAL}%-10s${C_RST}       ${C_LBL}[${C_KEY}E${C_LBL}] %s${C_RST}\n" \
           "$L_BTN_ALL" "$L_BTN_SWITCH" "$OPPOSITE_MODE" "$L_BTN_EDIT"
    printf "    ${C_LBL}[${C_KEY}C${C_LBL}] %-18s ${C_LBL}[${C_KEY}W${C_LBL}] %-22s ${C_LBL}[${C_KEY}0${C_LBL}] %s${C_RST}\n" \
           "$L_BTN_CLEAN" "$L_BTN_WIZ" "$L_BTN_EXIT"

    if [ "$BUILD_MODE" == "SOURCE" ]; then
        echo -e "    ${C_LBL}[${C_KEY}K${C_LBL}] ${L_BTN_MENUCONFIG}      ${C_LBL}[${C_KEY}I${C_LBL}] ${L_BTN_IPK}${C_RST}"
    fi
    echo ""

    read -p "${C_LBL}${L_CHOICE}${C_VAL} ⚡ ${C_RST}" choice
    choice="${choice^^}"

    case "$choice" in
        0) 
            echo -ne "${C_ERR}${L_EXIT_CONFIRM}${C_RST}"
            read -r exit_confirm
            if [[ -z "$exit_confirm" || "$exit_confirm" =~ ^[Yy]$ ]]; then
                echo -e "${C_OK}${L_EXIT_BYE}${C_RST}"
                sleep 3
                exit 0
            fi 
            continue ;;
        M) 
            [[ "$BUILD_MODE" == "IMAGE" ]] && BUILD_MODE="SOURCE" || BUILD_MODE="IMAGE" ;;
        E)
            clear
            # === EDITOR & ANALYSIS DASHBOARD (Ported from .bat) ===
            echo -e "${C_VAL}${L_EDIT_TITLE}${C_RST}"
            echo -e "  ${L_CHOICE}:"
            echo ""
            for ((i=1; i<=count; i++)); do
                # Убираем расширение .conf для отображения
                p_name_display="${profiles[$i]%.conf}"
                printf "  ${C_LBL}[${C_KEY}%d${C_LBL}]${C_RST} %s\n" "$i" "$p_name_display"
            done
            echo ""
            echo -e "  ${C_LBL}[${C_KEY}0${C_LBL}]${C_RST} ${L_BACK}"
            echo ""
            read -p "  ID: " e_choice
            
            if [[ "$e_choice" =~ ^[0-9]+$ ]] && [ "$e_choice" -le "$count" ] && [ "$e_choice" -gt 0 ]; then
                sel_conf="${profiles[$e_choice]}"
                sel_id="${sel_conf%.conf}"
                
                # --- ANALYZER LOGIC ---
                clear
                echo -e "${C_VAL}[${L_ANALYSIS}]${C_RST} ${C_KEY}${sel_id}${C_RST}"
                echo -e "${C_GRY}${L_SEPARATOR}${C_RST}"
                
                # Определяем статусы (как в BAT)
                # 1. Custom Files
                if [ -d "custom_files/$sel_id" ] && [ "$(ls -A "custom_files/$sel_id" 2>/dev/null)" ]; then
                    stat_files="${L_FOUND} ${L_ST_SUFFIX_FILES}"
                else
                    stat_files="${L_MISSING}"
                fi
                
                # 2. Custom Packages (IPK)
                if [ -d "custom_packages/$sel_id" ] && [ "$(ls -A "custom_packages/$sel_id" 2>/dev/null)" ]; then
                    stat_pkgs="${L_FOUND} ${L_ST_SUFFIX_IPK}"
                else
                    stat_pkgs="${L_MISSING}"
                fi

                # 3. Source Packages (Src)
                if [ -d "src_packages/$sel_id" ] && [ "$(ls -A "src_packages/$sel_id" 2>/dev/null)" ]; then
                    stat_srcs="${L_FOUND} ${L_ST_SUFFIX_SRC}"
                else
                    stat_srcs="${L_MISSING}"
                fi

                # 4. Outputs
                if [ -d "firmware_output/sourcebuilder/$sel_id" ] && [ "$(ls -A "firmware_output/sourcebuilder/$sel_id" 2>/dev/null)" ]; then
                    stat_out_s="${L_FOUND} ${L_ST_SUFFIX_OUT_S}"
                else
                    stat_out_s="${L_EMPTY}"
                fi
                
                if [ -d "firmware_output/imagebuilder/$sel_id" ] && [ "$(ls -A "firmware_output/imagebuilder/$sel_id" 2>/dev/null)" ]; then
                    stat_out_i="${L_FOUND} ${L_ST_SUFFIX_OUT_I}"
                else
                    stat_out_i="${L_EMPTY}"
                fi

                # Вывод отчета
                echo -e "${L_ST_CONF} ${C_VAL}profiles/$sel_conf${C_RST}"
                echo -e "${L_ST_OVER} $stat_files"
                echo -e "${L_ST_IPK} $stat_pkgs"
                echo -e "${L_ST_SRC} $stat_srcs"
                echo -e "${L_ST_OUTS} $stat_out_s"
                echo -e "${L_ST_OUTI} $stat_out_i"
                echo -e "${C_GRY}${L_SEPARATOR}${C_RST}"
                echo ""
                
                echo -e "${C_VAL}[${L_ACTION}]${C_RST} ${C_VAL}profiles/$sel_conf${C_RST} ${L_IN_EDITOR}"
                echo -e "${C_LBL}[INFO]${C_RST} Press Ctrl+X to exit nano."
                sleep 1
                
                "${EDITOR:-nano}" "profiles/$sel_conf"
            fi 
            ;;
        A)
            # Массовая сборка с параллельным выполнением и логированием
            if [ "$BUILD_MODE" == "SOURCE" ]; then
                echo -e "${C_ERR}${L_WARN_MASS}${C_RST}"
                read -p "$L_PRESS_ENTER"
            fi
            
            LOG_DIR="firmware_output/.build_logs/$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$LOG_DIR"
            
            echo -e "\n${C_VAL}${L_PARALLEL_BUILDS_START}${C_RST} ${C_LBL}$LOG_DIR${C_RST}\n"
            
            pids=()
            # ВАЖНО: Объявляем ассоциативные массивы для имен и ВРЕМЕНИ
            declare -A pid_map
            declare -A start_time_map
            
            printf "    %-65s | %s\n" "${C_GRY}${L_LOG_HEAD_PROF}" "${L_LOG_HEAD_FILE}${C_RST}"
            printf "    %s\n" "${C_GRY}--------------------------------------------------------------------------------------------------------------------${C_RST}"
            
            for p in "${profiles[@]}"; do
                # Очищаем имя от \r и расширения
                p_id=$(echo "${p%.conf}" | tr -d '\r')
                log_file="$LOG_DIR/${p_id}.log"
                
                printf "    %-65s | %s\n" "${C_KEY}${L_LOG_START} $p_id${C_RST}" "${C_LBL}${log_file}${C_RST}"
                
                # Запускаем сборку в фоне
                build_routine "$p" > "$log_file" 2>&1 &
                
                # Запоминаем PID
                pid=$!
                pids+=($pid)
                
                # Запоминаем Имя и ВРЕМЯ СТАРТА (Unix timestamp)
                pid_map[$pid]="$p_id"
                start_time_map[$pid]=$(date +%s)

                # Задержка для Docker Desktop
                sleep 1
            done
            
            echo -e "\n${C_OK}${L_ALL_BUILDS_LAUNCHED}${C_RST}"
            echo -e "${C_LBL}${L_MONITOR_HINT}${C_RST}\n"
            
            running_pids=("${pids[@]}")
            spinner=("/" "-" "\\" "|")
            spin_idx=0
            
            while [ ${#running_pids[@]} -gt 0 ]; do
                still_running=()
                
                for pid in "${running_pids[@]}"; do
                    if kill -0 "$pid" 2>/dev/null; then
                        # Процесс жив
                        still_running+=("$pid")
                    else
                        # Процесс завершился
                        
                        # --- РАСЧЕТ ВРЕМЕНИ ---
                        end_ts=$(date +%s)
                        start_ts=${start_time_map[$pid]}
                        duration=$((end_ts - start_ts))
                        
                        # Форматируем в красивый вид (Xm Ys)
                        dm=$((duration / 60))
                        ds=$((duration % 60))
                        time_str="${dm}m ${ds}s"
                        # ----------------------

                        printf "\r%120s\r" " " 
                        
                        if ! wait "$pid"; then
                            # ОШИБКА (Показываем время, потраченное впустую)
                            printf "${C_ERR}${L_LOG_FAIL_IN}${C_RST}\n" "${pid_map[$pid]}" "${time_str}"
                        else
                            # УСПЕХ (Показываем время выполнения)
                            printf "${C_OK}${L_LOG_OK_IN}${C_RST}\n" "${pid_map[$pid]}" "${time_str}"
                        fi
                    fi
                done

                # Обновляем список живых PID
                running_pids=("${still_running[@]}")
                
                # Рисуем спиннер
                if [ ${#running_pids[@]} -gt 0 ]; then
                    running_names=""
                    for pid in "${running_pids[@]}"; do
                        running_names+="${pid_map[$pid]} "
                    done
                    if [ ${#running_names} -gt 60 ]; then
                        running_names="${running_names:0:57}..."
                    fi
                    
                    printf "\r${C_LBL}[%s]${C_RST} ${L_WAITING_FOR_BUILDS} (%d left): ${C_VAL}%-60s${C_RST}" "${spinner[$spin_idx]}" "${#running_pids[@]}" "$running_names"
                fi
                
                sleep 0.5
                spin_idx=$(( (spin_idx+1) % 4 ))
            done
            
            printf "\r%120s\r" " "
            echo -e "${C_OK}${L_ALL_BUILDS_DONE}${C_RST}"
            read -p "$L_DONE_MENU"
            ;;
        K)
            if [ "$BUILD_MODE" == "SOURCE" ]; then
                # Очищаем экран, чтобы список не прилипал к главному меню
                clear
                echo -e "${C_GRY}┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐${C_RST}"
                echo -e "  ${C_VAL}${L_BTN_MENUCONFIG}${C_RST}"
                echo -e "${C_GRY}└────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘${C_RST}"
                echo ""
                echo -e "  ${L_K_SEL}:"
                echo ""
                # Выводим список красиво, с выравниванием и цветами
                for ((i=1; i<=count; i++)); do
                    printf "  ${C_LBL}[%2d]${C_RST} %s\n" "$i" "${profiles[$i]}"
                done                
                echo ""
                echo -e "  ${C_GRY}${L_CANCEL_0}${C_RST}"
                echo ""
                read -p "  ${L_CHOICE}: " k_id
                # Проверка ввода и запуск (если 0 или пусто - ничего не делаем)
                if [ "$k_id" != "0" ] && [ -n "${profiles[$k_id]}" ]; then
                    run_menuconfig "${profiles[$k_id]}"
                fi
            fi ;;
        C)
            cleanup_wizard ;;
        I)
            clear
            if [ "$BUILD_MODE" == "SOURCE" ]; then
                echo -e "${L_SEL_IMPORT}:"
                for ((i=1; i<=count; i++)); do printf "  [%d] %s\n" "$i" "${profiles[$i]}"; done
                read -p "ID: " i_id
                if [ -n "${profiles[$i_id]}" ]; then
                    p_id="${profiles[$i_id]%.conf}"
                    # FIX: Добавили tr -d '\r' для защиты от Windows-символов
                    p_arch=$(grep "SRC_ARCH=" "profiles/${profiles[$i_id]}" | cut -d'"' -f2 | tr -d '\r')
                    bash system/import_ipk.sh "$p_id" "$p_arch"
                fi
            fi ;;
        W)
            [ -f "system/create_profile.sh" ] && bash "system/create_profile.sh" || echo "$L_ERR_WIZ"
            read -p "$L_PRESS_ENTER" ;;
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