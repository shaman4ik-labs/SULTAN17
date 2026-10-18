# Рецепт: build-time uname-спуф под сток (6.1.157 / CP2A-эпоха)

Состояние: **ВЫКЛЮЧЕН** (2026-10-18, решение оператора — честный UTS_RELEASE).
Скрипты и все куски на месте, включается раскомментировкой трёх мест.

## Что давал спуф
uname -a / /proc/version / vermagic модулей показывали сток-строку
`6.1.157-android14-11-gbd23337e42e7-ab14791245 ... #1 <KBUILD_BUILD_TIMESTAMP>`
— 1:1 с заводским panther-билдом, чтобы ядро не отличалось от стока по строкам.

## Три звена (где жили)

### 1. UTS_RELEASE — `zeromount/build-helpers/native-157.sh`
Вызов гашен в `patch_sultan.sh`, блок «native-157 uname + native-compiler».
Скрипт дописывает в конец корневого Makefile:
```make
override define filechk_kernel.release
	echo "6.1.157-android14-11-gbd23337e42e7-ab14791245"
endef
```
GNU make honour'ит ПОСЛЕДНИЙ override → include/config/kernel.release,
UTS_RELEASE, uname(2), /proc/version, osrelease, vermagic — все сток-строка.
LINUX_VERSION_CODE/SUBLEVEL НЕ трогаются (все `#if LINUX_VERSION_CODE`
гейты видят нативные 162 — mali/wlan компилятся без шимов).

### 2. Подстрока компилятора — `zeromount/build-helpers/native-compiler.sh`
`bash .../native-compiler.sh <kernel_root> zeromount/stock-compiler.txt`
— косметика version-string под сток-компилятор.

### 3. Билд-идентичность — `build_sultan.sh`
```sh
export KBUILD_BUILD_USER="build-user"
export KBUILD_BUILD_HOST="build-host"
export KBUILD_BUILD_TIMESTAMP="Wed Jan 28 05:34:14 UTC 2026"   # → "#1 ..." строка
```

## Как вернуть
1. `patch_sultan.sh`: раскомментировать две строки bash native-157/native-compiler.
2. `build_sultan.sh`: раскомментировать три export KBUILD_BUILD_*.
3. Пересборка: Actions `Build Kernel` (gs201, bakasu-zeromount).
4. Проверка после прошивки: `uname -a` = сток-строка; `zcat /proc/config.gz | head -1` не врёт (верить uname + kallsyms).

## Не путать
- `CONFIG_KSU_SUSFS_SPOOF_UNAME=y` в defconfig — RUNTIME-тумблер susfs
  (`ksu_susfs spoof_uname ...` по команде), нейтрален, пока не активирован. Оставлен.
- `zeromount/tools/susfs-uname.sh.example` — runtime-пример той же фичи.
- `CP2A.260705.006` — build-fingerprint телефона (props), к ядру отношения не имеет.

## Зачем выключили
Канон v-next: каждый кирпич честный и объяснимый. Плюс спуф маскировал
реальный sublevel/хеш при диагностике (uname врал о 157 при реальных 162).
