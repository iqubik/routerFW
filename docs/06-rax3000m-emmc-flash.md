# file docs\06-rax3000m-emmc-flash.md

<p align="center">
  <b>🇷🇺 Русский</b> | <a href="06-rax3000m-emmc-flash.en.md"><b>🇺🇸 English</b></a>
</p>

---

# Урок 6: Установка прошивки на RAX3000M eMMC (ручная разметка)

**Цель:** Пошагово установить прошивку (в т.ч. Padavanonly) на версию RAX3000M с eMMC, когда штатный sysupgrade недоступен — через правильную разметку GPT, настройку bootenv и запись разделов по SSH.

> **ВНИМАНИЕ:** Все операции с eMMC (команда `dd`) потенциально опасны. Ошибка в одну цифру — риск кирпича. Делайте бэкапы и имейте под рукой UART, если решаетесь на ручную установку.

---

## Когда это нужно

*   На устройстве ещё нет кастомной разметки GPT (например, только что с ванильного OpenWrt или Keenetic), и sysupgrade отказывается ставить образ.
*   Вы переходите с другой прошивки (OpenWrt / ImmortalWrt / Keenetic) на сборку Padavanonly или иную, требующую своей разметки.

**Переход Keenetic → Padavanonly:** сначала установите ванильный OpenWrt по официальной инструкции, затем выполняйте шаги ниже по установке на eMMC.

---

## Ограничения и риски

*   **eMMC:** запись идёт напрямую в постоянную память. Неверный адрес или раздел может вывести устройство из строя.
*   **`dd`:** всегда проверяйте устройство (`lsblk`), имена файлов и значения `seek`/`count`.
*   **UART:** при первой ручной установке желательно иметь доступ к консоли U-Boot для восстановления bootenv в случае сбоя.
*   **Бэкапы:** по возможности сохраните полный образ eMMC или хотя бы раздел `factory` (калибровки Wi‑Fi).

---

## Необходимые файлы

Подготовьте и загрузите в `/tmp` на роутер (например, через WinSCP):

*   **GPT:** таблица разделов — обычная или со swap (2 ГБ). Файлы можно взять из обсуждения на 4pda или сгенерировать утилитой [bl-mt798x-dhcpd](https://github.com/Yuzhii0718/bl-mt798x-dhcpd) (раздел «Техническая информация» в закрепе). В командах ниже используется вариант со swap: файл `gpt-rax3000m-emmc-swap.bin`; для варианта без swap имя файла будет другим (например, `gpt-rax3000m-emmc.bin`), значения `seek` в dd не меняются.
*   **Загрузчик (FIP):** `u-boot.fip` — из сборки или репозитория [bl-mt798x-dhcpd](https://github.com/Yuzhii0718/bl-mt798x-dhcpd).
*   **Ядро и rootfs:** `kernel.bin` и `rootfs.bin` — извлеките из sysupgrade-образа прошивки архиватором (7z и т.п.).

Проверьте, что eMMC видна как `mmcblk0`:

```bash
lsblk
```

---

## Шаг 0: Настройка bootenv (U-Boot)

Без правильных `bootargs` и `bootcmd` роутер не загрузит новую прошивку.

### Установка утилит

```bash
opkg update
opkg install uboot-envtools
```

### Конфигурация fw_env

Укажите утилите, где хранятся переменные U-Boot:

```bash
echo "/dev/mmcblk0p1 0x0 0x80000" > /etc/fw_env.config
```

Проверка:

```bash
fw_printenv
```

Если список переменных выводится — переходите к записи.

### Запись переменных загрузки

```bash
fw_setenv bootargs "console=ttyS0,115200 root=/dev/mmcblk0p5 rootwait"
fw_setenv bootcmd 'mmc dev 0; gpt setenv mmc 0 kernel; mmc read ${loadaddr} ${gpt_part_addr} ${gpt_part_size}; bootm ${loadaddr}'
```

Проверка:

```bash
fw_printenv bootargs
fw_printenv bootcmd
```

В выводе должны быть нужные строки (в т.ч. `${loadaddr}`), без пустых полей.

---

## Шаг 1: Запись данных

Имена файлов и значения `seek` должны соответствовать вашей GPT и инструкции из закрепа. Ниже — типичные значения для RAX3000M eMMC.

**Запись таблицы разделов (GPT):**

```bash
dd if=/tmp/gpt-rax3000m-emmc-swap.bin of=/dev/mmcblk0 bs=512 count=34 conv=notrunc
```

**Запись загрузчика (U-Boot / FIP):**

```bash
dd if=/tmp/u-boot.fip of=/dev/mmcblk0 bs=512 seek=13312 conv=notrunc
```

**Запись ядра:**

```bash
dd if=/tmp/kernel.bin of=/dev/mmcblk0 bs=512 seek=21504 conv=notrunc
```

**Запись rootfs:**

```bash
dd if=/tmp/rootfs.bin of=/dev/mmcblk0 bs=512 seek=152576 conv=notrunc
```

---

## Шаг 2: Финализация

Сброс буферов и перезагрузка:

```bash
sync
```

Подождите несколько секунд. Если использовали разметку со swap:

```bash
mkswap /dev/mmcblk0p7
```

Затем:

```bash
reboot
```

Первый запуск может быть дольше обычного (инициализация разделов). После успешной загрузки рекомендуется установить актуальный sysupgrade из полного архива прошивки (в нём корректный vermagic и набор образов).

---

## Решение проблем

### Настройки не сохраняются (overlay не монтируется)

Если после прошивки при каждой перезагрузке настройки сбрасываются, размер ФС на overlay-разделе (`/dev/mmcblk0p6`) может не совпадать с новой GPT. Система не монтирует «битый» раздел.

**«Метод саботажа»** (если нет Failsafe): затереть заголовок раздела, чтобы при следующей загрузке система посчитала раздел пустым и отформатировала его сама.

По SSH:

```bash
dd if=/dev/zero of=/dev/mmcblk0p6 bs=4096 count=100 conv=notrunc
reboot -f
```

После загрузки overlay будет пересоздан. Если использовали GPT со swap, заново настройте swap:

```bash
mkswap /dev/mmcblk0p7
uci set fstab.@swap[-1]=swap
uci set fstab.@swap[-1].device='/dev/mmcblk0p7'
uci set fstab.@swap[-1].enabled='1'
uci commit fstab
/etc/init.d/fstab boot
```

### Роутер не грузится, есть доступ к U-Boot (UART)

Если загрузка «потеряна», задайте параметры вручную в консоли U-Boot:

```
setenv bootargs "console=ttyS0,115200 root=/dev/mmcblk0p5 rootwait"
setenv bootcmd "mmc dev 0; gpt setenv mmc 0 kernel; mmc read ${loadaddr} ${gpt_part_addr} ${gpt_part_size}; bootm ${loadaddr}"
saveenv
reset
```

### Полезные команды

**Вырезать раздел `factory` (калибровки) из полного бэкапа:**

```bash
zcat full_backup.img.gz | dd of=factory.bin bs=512 skip=$((0x2400)) count=$((0x1000)) status=progress
```

**Сравнить хеш файла и раздела (например, factory):**

```bash
sha256sum /tmp/factory.bin
dd if=/dev/mmcblk0p2 bs=2M count=1 | sha256sum
```

---

## Дополнительно

*   **Генератор GPT:** [bl-mt798x-dhcpd](https://github.com/Yuzhii0718/bl-mt798x-dhcpd) — для своей разметки (в т.ч. со swap).
*   **Готовые образы и сборки:** см. обсуждение на 4pda и [Releases](https://github.com/iqubik/routerFW/releases). Для кастомизации используйте [RouterFW Builder](https://github.com/iqubik/routerFW) и [Урок 3](03-source-build.md).

Вернуться к [оглавлению уроков](index.md).
# checksum:MD5=32e9d09d87d24f29e8451be84fb80d0e