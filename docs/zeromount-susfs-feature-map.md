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
