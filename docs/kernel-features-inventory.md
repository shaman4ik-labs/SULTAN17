# Инвентаризация фич нашего ядра (этап-1 сборка: cp2a + BakaSU f308ed0/35233-линия + susfs 5369359d)

Стек: Ante0 cp2a-tip (6.1.162) + BakaSU sync-susfs ветка (PR#624) + susfs v2.3.0
(свежий SHA) + ZeroMount 60_-слой (наш форк) + Droidspaces-KaBI + TPROXY-инжект
+ 71_flush + спуф uname ВЫКЛЮЧЕН (честный UTS_RELEASE).

## РАБОТАЕТ СЕЙЧАС (эмпирика на телефоне, [FACT])

### Root / BakaSU
- root-доступ, Superuser, App Profiles (Custom + Umount per-app) — менеджер жив
- загрузка модулей через zm-движок — compass/BRENE/DebugTools стоят и работают
- susfs-интеграция менеджера (runtime-суперколлы ksud)
- KSU_VERSION handshake (unshallow-метод)

### susfs v2.3.0 — 9/9 kernel features (BRENE-статус)
- SUS_PATH (+LOOP; наш 71_flush: скрытие до File.exists — Duck-тайминг)
- SUS_KSTAT (+сентябрьские фиксы: f_flags, statfs_by_dentry, is_statically)
- SUS_MAP / SUS_MOUNT (новая архитектура, без зависимости от kernel_umount)
- TRY_UMOUNT / SPOOF_UNAME (runtime) / SPOOF_CMDLINE_OR_BOOTCONFIG
- OPEN_REDIRECT / SUS_SU / HIDE_KSU_SUSFS_SYMBOLS / ENABLE_LOG / SUS_OVERLAYFS

### ZeroMount (наш 60_-форк)
- MOUNTLESS module loading — [FACT] mountinfo: 0 модульных следов при живом модуле
- VFS path redirection (getname) + dirent injection
- d_path / mmap-metadata / SELinux-xattr / statfs спуфы
- write protection, bloom, unicode filter, AS_FLAGS guards, fast-path,
  two-level readdir guard, RCU, zygote-SID guard
- overlay=true, tmpfs_xattr=true [FACT zm detect]

### Сеть (компас-специфика)
- TPROXY v4/v6 + XT_TARGET_TPROXY + MATCH_SOCKET + IP6_NF_NAT [FACT cfg OK]
- TCP-REDIRECT hijack per-uid (рабочий перехват компаса) [FACT]
- DoT-анти-MITM (uid 0/1073, v6 tcp-reset)
- policy routing fwmark→local [FACT ip rule]

### Прочее
- Droidspaces LXC: SYSVIPC KaBI + ns/cgroup/binfmt [FACT applied]
- TUN=y (VpnService), KALLSYMS_ALL, DEBUG_KERNEL
- uname ЧЕСТНЫЙ (спуф выключен с этой сборки)

## СОБРАНО, ЖДЁТ ПРОВЕРКИ ПОСЛЕ ЭТАПА-1
- selinux_hide (BakaSU PR#624): тумблер в менеджере + runtime-эффект
- KSU_VERSION ~35233 (бамп-линия)
- честный uname после персиста (uname -r покажет 6.1.162-...g<наш-хеш>)

## ЧТО ДОРАБОТАТЬ СЛЕДУЮЩИМ ЭТАПОМ
1. TCP-TPROXY миграция компаса — ЯДРО ГОТОВО (всё проверено), работа
   юзерспейсная: gen-policy (инбаунды tproxy) + hijack (MARK+TPROXY для TCP)
   + переключатель redirect|tproxy. Следствие: find_process оживёт нативно —
   per-app атрибуция в clash_api без ss-поллинга (баг process-not-found
   закрывается классом, issue #4646 у апстрима).
2. ss-поллинг в BFF — переходный слой статистики до/независимо от TPROXY.
3. Поверхности управления (BRENE/zm/BakaSU-менеджер): эксперимент-матрица
   «изменил в X → ядро сразу/после ребута» → решение один-хозяин-или-мосты.
4. ЯДРО следующей пересборки: кандидатов НЕТ — все планы юзерспейсные.
   (KSIE/ftrace — отдельная ветка, никогда не смешивается с daily.)

## НЕ НАДО (закрыто, см. zeromount-susfs-feature-map.md)
- kstat_redirect: не уникален, гибриды не используем, susfs-эквивалент жив
- uname-спуф: честность канона (рецепт сохранён docs/recipe-uname-spoof.md)
