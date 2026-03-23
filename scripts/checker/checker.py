#!/usr/bin/env python3
import subprocess
import concurrent.futures
import time
import sys
import threading
import os

# ================= НАСТРОЙКИ =================
INPUT_FILE = "tocheck.txt"
GOOD_FILE = "good_snis.txt"
BAD_FILE = "bad_snis.txt"
UNSTABLE_FILE = "unstable_snis.txt"

CHECKS_PER_DOMAIN = 10      # Сколько раз проверяем
DELAY_BETWEEN_CHECKS = 0.5  # Пауза (сек) между стартами параллельных проверок (200мс)
CURL_TIMEOUT = 5            # Таймаут (сек)
MAX_THREADS = 15            # Количество одновременных доменов
# =============================================

print_lock = threading.Lock()
done_count = 0
total_count = 0

def check_domain(domain):
    domain = domain.strip()
    if not domain:
        return None
    
    url = f"https://{domain}" if not domain.startswith("http") else domain
    clean_domain = domain.split("//")[-1].split("/")[0] if "://" in domain else domain
    
    results_list = ["000"] * CHECKS_PER_DOMAIN

    # Функция для одного микро-запроса (будет работать в своем потоке)
    def _single_curl(delay, idx):
        time.sleep(delay) # Ждем свою очередь (0мс, 200мс, 400мс...)
        try:
            cmd =[
                "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", 
                "-m", str(CURL_TIMEOUT), "--tlsv1.3", url
            ]
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            code = res.stdout.strip()
            if not code or not code.isdigit():
                code = "000"
        except Exception:
            code = "000"
        results_list[idx] = code

    # Запускаем CHECKS_PER_DOMAIN потоков для ОДНОГО домена
    inner_threads =[]
    for i in range(CHECKS_PER_DOMAIN):
        # Лесенка: 0.0, 0.2, 0.4, 0.6...
        t = threading.Thread(target=_single_curl, args=(i * DELAY_BETWEEN_CHECKS, i))
        t.start()
        inner_threads.append(t)

    # Ждем завершения всех микро-запросов
    for t in inner_threads:
        t.join()
            
    # Анализируем результаты
    success_count = sum(1 for c in results_list if c != "000")
    codes_str = " ".join(results_list)
    
    # Определяем доминирующий HTTP код (для сортировки в будущем)
    valid_codes =[c for c in results_list if c != "000"]
    major_code = max(set(valid_codes), key=valid_codes.count) if valid_codes else "000"

    if success_count == CHECKS_PER_DOMAIN:
        status = "GOOD"
        status_ui = "\033[32m[ОТЛИЧНО]\033[0m"
    elif success_count == 0:
        status = "BAD"
        status_ui = "\033[31m[В МУСОР]\033[0m"
    else:
        status = "UNSTABLE"
        status_ui = "\033[33m[ПЛАВАЕТ]\033[0m"
        
    result_text = f"{status_ui} {clean_domain:<25} ({success_count}/{CHECKS_PER_DOMAIN}) | Коды: {codes_str}"
    
    return clean_domain, status, major_code, result_text

def update_ui(result_text):
    global done_count
    done_count += 1
    with print_lock:
        sys.stdout.write('\r\033[K')
        sys.stdout.write(result_text + '\n')
        
        percent = done_count / total_count if total_count > 0 else 0
        bar_len = 30
        filled = int(bar_len * percent)
        bar = '█' * filled + '░' * (bar_len - filled)
        sys.stdout.write(f'\r\033[1;36m[ПРОГРЕСС]\033[0m [{bar}] {done_count}/{total_count} ({int(percent*100)}%)')
        sys.stdout.flush()

def main():
    global total_count
    
    if not os.path.exists(INPUT_FILE):
        print(f"❌ Файл {INPUT_FILE} не найден!")
        return
        
    with open(INPUT_FILE, 'r', encoding='utf-8') as f:
        # Читаем все домены
        raw_domains =[line.strip() for line in f if line.strip()]
        
    # === ИСПРАВЛЕНИЕ 1: Удаляем дубликаты ===
    domains = list(set(raw_domains))
        
    total_count = len(domains)
    if total_count == 0:
        print("❌ Файл с доменами пуст!")
        return

    # === ИСПРАВЛЕНИЕ 2: Удаляем старые файлы перед началом ===
    for file in [GOOD_FILE, BAD_FILE, UNSTABLE_FILE]:
        if os.path.exists(file):
            os.remove(file)

    print(f"🔍 Запуск проверки в {MAX_THREADS} потоков (внутри каждого еще по {CHECKS_PER_DOMAIN} микро-потоков)...")
    print(f"ℹ️  Уникальных доменов для проверки: {total_count} (дубликаты удалены)")
    print("=" * 70)
    
    sys.stdout.write("\033[?25l")
    sys.stdout.write(f'\r\033[1;36m[ПРОГРЕСС]\033[0m[{"░" * 30}] 0/{total_count} (0%)')
    sys.stdout.flush()

    # Списки для накопления результатов
    good_list = []
    bad_list =[]
    unstable_list =[]

    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_THREADS) as executor:
            future_to_domain = {executor.submit(check_domain, dom): dom for dom in domains}
            
            for future in concurrent.futures.as_completed(future_to_domain):
                res = future.result()
                if res:
                    domain, status, major_code, result_text = res
                    
                    # Распределяем по корзинам в оперативной памяти
                    if status == "GOOD":
                        good_list.append((domain, major_code))
                    elif status == "BAD":
                        bad_list.append(domain)
                    else:
                        unstable_list.append(domain)
                        
                    update_ui(result_text)
    finally:
        with print_lock:
            sys.stdout.write('\r\033[K')
            print("=" * 70)
            
            # === ФИНАЛЬНАЯ ЗАПИСЬ И СОРТИРОВКА ===
            
            # Пишем Идеальные домены ТОЛЬКО если они есть
            if good_list:
                good_list.sort(key=lambda x: (x[1], x[0]))
                with open(GOOD_FILE, 'w', encoding='utf-8') as f:
                    current_code = ""
                    for dom, code in good_list:
                        if code != current_code:
                            f.write(f"\n# ====== HTTP {code} ======\n")
                            current_code = code
                        f.write(f"{dom}\n")
                        
            # Пишем Плавающие ТОЛЬКО если они есть
            if unstable_list:
                unstable_list.sort(key=lambda x: (x[1], x[0]))
                with open(UNSTABLE_FILE, 'w', encoding='utf-8') as f:
                    for dom in unstable_list:
                        f.write(dom + '\n')
                        
            # Пишем Мертвые ТОЛЬКО если они есть
            if bad_list:
                bad_list.sort(key=lambda x: (x[1], x[0]))
                with open(BAD_FILE, 'w', encoding='utf-8') as f:
                    for dom in bad_list:
                        f.write(dom + '\n')

            print("✅ Проверка завершена!")
            if good_list:
                print(f"🟢 Идеальные: {GOOD_FILE} (Отсортированы по HTTP-коду)")
            if unstable_list:
                print(f"🟡 Плавающие: {UNSTABLE_FILE}")
            if bad_list:
                print(f"🔴 Мертвые:   {BAD_FILE}")
                
            # Включаем отображение курсора обратно
            sys.stdout.write("\033[?25h")
            sys.stdout.flush()

if __name__ == "__main__":
    main()