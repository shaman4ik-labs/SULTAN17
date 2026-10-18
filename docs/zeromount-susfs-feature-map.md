# Карта фич: ZeroMount → susfs/KSU (канон, 2026-10-18)

Задача: полный список фич последнего офф-релиза ZeroMount/Super-Builders
(Enginex0, апрель 2026, репо замерло 15.04) против свежего susfs
(5369359d v2.3.0) + BakaSU. Судьба каждой: переехала / заменена / осталась
ZeroMount-специфой / выпилена. Основа эмпирики: zm detect на нашем ядре
cp2a-bakasu (BakaSU 35233-линия).

## Переехали в апстрим susfs — работают у нас (zm detect: true)

| ZeroMount-фича | Где теперь | Эмпирика |
|---|---|---|
| Path hiding | SUS_PATH (+LOOP, наш 71_flush) | ✅ |
| Kstat spoofing | SUS_KSTAT (+сентябрьские фиксы f_flags/statfs) | ✅ |
| Maps hiding | SUS_MAP | ✅ |
| Mount hiding / Mount ID spoof | SUS_MOUNT (рефактор 12.09: не нужен kernel_umount) | ✅ |
| Uname spoofing | SUSFS_SET_UNAME (runtime, тумблер оставлен) | ✅ |
| Cmdline/bootconfig | SET_CMDLINE_OR_BOOTCONFIG | ✅ |
| Kallsyms hiding | HIDE_KSU_SUSFS_SYMBOLS | ✅ |
| AVC log suppression | ЗАМЕНЕНО: не в susfs — selinux_hide в BakaSU (PR#624) | ✅ собран |

## Остались ZeroMount-специфой (наш 60_-слой) — работают

VFS path redirection, dirent injection, d_path spoofing, mmap-metadata,
SELinux xattr injection, statfs spoofing, write protection, bloom filter,
unicode filter, AS_FLAGS collision guards, inline fast-path, two-level
readdir guard, RCU, zygote SID guard. Плюс overlay=true, tmpfs_xattr=true
(наш fa024eb-хвост июля).

## Дельта: kstat_redirect — ОТКАЗ (решение оператора 2026-10-18)

- Суть фичи (51_enhanced, Enginex0): stat виртуального ZM-пути → метаданные
  реального файла, одним supercall (susfs_add_sus_kstat_redirect).
- В апстриме НЕ заменена и не отвергнута — сирота: динамическая, завязана на
  ZM-правила, susfs о них не знает. Смежная идея покрыта иначе: рефактор
  12.09 — «SUS_KSTAT + OPEN_REDIRECT работают вместе для redirected paths».
- Наш вердикт: отказ. Причина: эквивалент решается живыми инструментами
  (SUS_KSTAT ручной спуф + OPEN_REDIRECT), susfs развивается, ZeroMount — нет.
  Исторический тест fa024eb («detect showed false») выигрыша не доказал.
  51_-слой на BakaSU-пути не проверен, AS_FLAGS — зона коллизий.
- Возврат возможен предметно: если реальный детектор поймаем именно на
  stat-расхождении ZM-путей — вернуться с конкретным кейсом.

## Метамодуль zm: открытое (развилка оператора)

zm (Enginex0, Rust) показывает kstat_redirect: false — честно, но пункт
«AVAILABLE ENHANCEMENTS» вводит в заблуждение. Варианты:
(a) оставить как есть (детект-правдивость важнее меню);
(b) форкнуть zeromount-репо (мёртв с 15.04) и почистить меню —
    отдельный мини-профикт поддержки.

## Поверхности управления и пути записи (конфликт 3+ модулей, разбор — следующим заходом)

| поверхность | куда пишет | когда применяется |
|---|---|---|
| BRENE (модуль + WebUI-кнопка) | /data/adb/brene/config.sh — файл-истина | при буте (post-fs-data → суперколлы) |
| zm (метамодуль) | config.toml + bridge write → тот же config.sh; bridge reconcile — обратно | немедленно |
| BakaSU-менеджер | свои prefs + runtime-суперколлы в ядро | мгновенно, НЕ персистит в config.sh |

Root ADB — двойной выключатель: zm→BRENE (config_usb_debugging) vs менеджер
(свой механизм). Главный риск — перезапись на буте: runtime-изменение
менеджера откатывается BRENE-конфигом (или наоборот). Требует
эксперимента-матрицы «изменил в X → ядро сразу / после ребута».
Решение (один хозяин vs мосты) — после матрицы.

## Уникальность ZeroMount-драйвера и её сохранность (анализ + эмпирика, 2026-10-18)

**Уникальность на момент разработки:** mountless-принцип — не «прятать маунты»,
а «не создавать» (перехват getname() в VFS): записей в mountinfo нет онтологически,
гонки «успел спрятать» нет. Плюс целостная легенда файла (dirent-инъекция, d_path,
mmap-метаданные, SELinux-xattr, statfs) и производительность (bloom/RCU/fast-path).

**[FACT] Эмпирика на нашем ядре:** /proc/self/mountinfo — 162 строки, модульных
путей 0, overlay с upperdir=/data/adb — 0. Модуль compass загружен и работает.
Mountless жив.

**Что съел прогресс susfs/KSU:** прятание существующих маунтов стало сильнее
(SUS_MOUNT-рефактор), весь спуф-инструментарий ушёл в апстрим (см. таблицу выше).

**ЧТО не съедено:** mountless не повторён никем (susfs прячет, не устраняет);
VFS-редирект + dirent-инъекция — единственные в экосистеме; zm-метамодуль —
универсальный mount-engine. Вердикт: держим, 60_-слой — наш форк навсегда
(KABI-чувствительность + susfs-якоря — цена владения).

## kstat_redirect — переоценка с позиции mountless (вскрыто по 51_-патчу)

Механика susfs_add_sus_kstat_redirect(vpath, rpath): НЕ отдельный спуф —
ГЕНЕРАТОР записей стандартного SUS_KSTAT: резолвит real → его метаданные,
кладёт двойную запись (ino real + ino virtual, если виртуальный файл физически
существует) в SUS_KSTAT_HLIST, ставит AS_FLAGS_SUS_KSTAT. Задача —
автоматизация согласованности для гибридных режимов ZM (физически созданные
виртуальные файлы, overlay-режимы), где stat виртуального выдаёт чужие метаданные.

При чистом getname-редиректе stat(A) и так резолвится в inode B — согласовано
автоматически. Эквивалент живой и полный: SUS_KSTAT (тот же апстрим-механизм).
Утрачивается только АВТОМАТИЗАЦИЯ генерации записей — при необходимости
возвращается 15 строками userspace в нашей zm-обвязке: при vfs add →
stat реального файла → ksu_susfs add_sus_kstat. Без 51_-ядерного слоя,
без AS_FLAGS-рисков, без мёртвого upstream.

Отказ подтверждён с обеих сторон: и по экосистеме (см. выше), и по механике.

Финальный аргумент (оператор, 2026-10-18): ZeroMount ставится у нас ИМЕННО ради
нативного mountless-монтирования — гибридные режимы (overlay/magic) не
используются в принципе. kstat_redirect — клей для гибридов → в нашей
конфигурации ему нет работы по определению. Вопрос закрыт окончательно.
