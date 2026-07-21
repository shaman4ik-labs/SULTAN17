#!/bin/bash

set -e

get_script_dir()
{
    local SOURCE_PATH="${BASH_SOURCE[0]}"
    local SYMLINK_DIR
    local SCRIPT_DIR
    # Resolve symlinks recursively
    while [ -L "$SOURCE_PATH" ]; do
        # Get symlink directory
        SYMLINK_DIR="$( cd -P "$( dirname "$SOURCE_PATH" )" >/dev/null 2>&1 && pwd )"
        # Resolve symlink target (relative or absolute)
        SOURCE_PATH="$(readlink "$SOURCE_PATH")"
        # Check if candidate path is relative or absolute
        if [[ $SOURCE_PATH != /* ]]; then
            # Candidate path is relative, resolve to full path
            SOURCE_PATH=$SYMLINK_DIR/$SOURCE_PATH
        fi
    done
    # Get final script directory path from fully resolved source path
    SCRIPT_DIR="$(cd -P "$( dirname "$SOURCE_PATH" )" >/dev/null 2>&1 && pwd)"
    echo "$SCRIPT_DIR"
}

if [ $# -ne 2 ]; then
    echo "Usage: $0 <gs201|zuma|zumapro> <stock|ksu|ksu-susfs|ksu-next|ksu-next-susfs|resukisu-zeromount>"
    exit 1
fi

case "$1" in
    gs201|zuma|zumapro)
        TARGET="$1"
        ;;
    *)
        echo "Error: '$1' is not a valid target."
	echo "This will select the correct defconfig"
        echo "Valid targets are: gs201, zuma, zumapro"
        exit 1
        ;;
esac

case "$2" in
    stock|ksu|ksu-susfs|ksu-next|ksu-next-susfs|resukisu-zeromount)
        VARIANT="$2"
        ;;
    *)
        echo "Error: '$2' is not a valid variant."
        echo "Usage: $0 <gs201|zuma|zumapro> <stock|ksu|ksu-susfs|ksu-next|ksu-next-susfs|resukisu-zeromount>"
        exit 1
        ;;
esac

export KERNEL_REPO="$(get_script_dir)"

cd "$KERNEL_REPO"

# ZeroMount / ReSukiSU vendored orchestration (self-contained, no build-time fetch).
ORCH="$KERNEL_REPO/zeromount"
PATCHES="$ORCH/patches"
HELPERS="$ORCH/build-helpers"

# resukisu-zeromount does NOT need Ante0/kernel_patches (has its own vendored set).
if [ "$VARIANT" != "resukisu-zeromount" ]; then
    #clone kernel_patches
    git clone https://github.com/Ante0/kernel_patches --depth=1
fi

case "$VARIANT" in
    stock)
        ;;
    ksu)
        # KernelSU only
	cd "$KERNEL_REPO"
	#fetch ksu
	curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main

	echo "Patching utf8"
	cd "$KERNEL_REPO"
	patch -p1 < "$KERNEL_REPO"/kernel_patches/common/unicode_bypass_fix_6.1+.patch || true

	echo "$TARGET $VARIANT done"
        ;;
    ksu-susfs)
        # KernelSU
        # SUSFS
	##CLONE KERNELSU AND SUSFS##
	cd "$KERNEL_REPO"
	#fetch ksu
	curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main

	#fetch susfs
	cd "$KERNEL_REPO"
	git clone https://gitlab.com/simonpunk/susfs4ksu -b gki-android14-6.1 --depth=1

	cd "$KERNEL_REPO/"

	cp "$KERNEL_REPO"/susfs4ksu/kernel_patches/fs/* "$KERNEL_REPO"/fs/
	cp "$KERNEL_REPO"/susfs4ksu/kernel_patches/include/linux/* "$KERNEL_REPO"/include/linux/

	##PATCHING##
	echo "Patching kernel"
	cd "$KERNEL_REPO"
	if ! patch -p1 < "$KERNEL_REPO"/susfs4ksu/kernel_patches/50_add_susfs_in_gki-android14-6.1.patch; then
		echo "Some SUSFS hunks failed (expected). Continuing..."
	fi
	echo "Patching KernelSU"
	cd "$KERNEL_REPO"/KernelSU/
	if ! patch -p1 < "$KERNEL_REPO"/susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch; then
		echo "Some SUSFS hunks failed (expected). Continuing..."
	fi

	echo "Patching utf8"
	cd "$KERNEL_REPO"
	patch -p1 < "$KERNEL_REPO"/kernel_patches/common/unicode_bypass_fix_6.1+.patch || true

	echo "fixing Sultan rejects (fs/open.c, fs/namespace.c and kernel/sys.c"
	cd "$KERNEL_REPO"
	patch -p1 < "$KERNEL_REPO"/kernel_patches/sultan/fixer.patch || true

	echo "$TARGET $VARIANT done"
        ;;
    ksu-next)
        # KernelSU Next
        cd "$KERNEL_REPO"
        curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s dev

	#Scope min manual hooks
	patch -p1 < "$KERNEL_REPO"/kernel_patches/next/scope_min_manual_hooks_v1.6.patch

	#utf8 patch
	patch -p1 < "$KERNEL_REPO"/kernel_patches/common/unicode_bypass_fix_6.1+.patch || true

	echo "$TARGET $VARIANT done"
        ;;
    ksu-next-susfs)
        # KernelSU Next
	cd "$KERNEL_REPO"
	curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s dev

	# SUSFS
	#fetch susfs
	git clone https://gitlab.com/simonpunk/susfs4ksu -b gki-android14-6.1 --depth=1

	cp "$KERNEL_REPO"/susfs4ksu/kernel_patches/fs/* "$KERNEL_REPO"/fs/
	cp "$KERNEL_REPO"/susfs4ksu/kernel_patches/include/linux/* "$KERNEL_REPO"/include/linux/

	##PATCHING##
	echo "Patching kernel"

	if ! patch -p1 < "$KERNEL_REPO"/susfs4ksu/kernel_patches/50_add_susfs_in_gki-android14-6.1.patch; then
		echo "Some SUSFS hunks failed (expected). Continuing..."
	fi

	echo "Patching KernelSU"
	cd "$KERNEL_REPO"/KernelSU-Next/
	if ! patch -p1 < "$KERNEL_REPO"/susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch; then
		echo "Some SUSFS hunks failed (expected). Continuing..."
	fi

	echo "Patching utf8"
	cd "$KERNEL_REPO"
	patch -p1 < "$KERNEL_REPO"/kernel_patches/common/unicode_bypass_fix_6.1+.patch || true

	echo "fixing KSU-Next-specific patches using Wildjames fix repo."
	cd "$KERNEL_REPO"/KernelSU-Next/
	patch -p1 < "$KERNEL_REPO"/kernel_patches/next/susfs_fix_patches/v2.2.0/fix_Kbuild.patch || true
	patch -p1 < "$KERNEL_REPO"/kernel_patches/next/susfs_fix_patches/v2.2.0/fix_init.c.patch || true
	patch -p1 < "$KERNEL_REPO"/kernel_patches/next/susfs_fix_patches/v2.2.0/fix_kernel_umount.c.patch || true
	patch -p1 < "$KERNEL_REPO"/kernel_patches/next/susfs_fix_patches/v2.2.0/fix_setuid_hook.c.patch || true
	patch -p1 < "$KERNEL_REPO"/kernel_patches/next/susfs_fix_patches/v2.2.0/fix_sucompat.c.patch || true
	patch -p1 < "$KERNEL_REPO"/kernel_patches/next/susfs_fix_patches/v2.2.0/fix_supercall.c.patch || true
	patch -p1 < "$KERNEL_REPO"/kernel_patches/next/susfs_fix_patches/v2.2.0/ksu_toolkit.patch || true
	patch -p1 < "$KERNEL_REPO"/kernel_patches/next/susfs_fix_patches/v2.2.0/overwrite_hook_mode.patch || true


	echo "fixing Sultan rejects (fs/open.c, fs/namespace.c and kernel/sys.c"
	cd "$KERNEL_REPO"
	patch -p1 < "$KERNEL_REPO"/kernel_patches/sultan/fixer.patch || true

	echo "$TARGET $VARIANT done"
        ;;
    resukisu-zeromount)
        # ===== #14 LUMINAIRE-FAITHFUL BASE — mirror chainonyourdoor/LuminaireProtocol =====
        # ReSukiSU main 930f61a + susfs be08face + blk.h-dance + fix_namespace.py.
        # NO 51_/70_/ZeroMount/stealth/gestures/uname. Proves the fresh base compiles on
        # Sultan (closes #12: fs/namespace.c undeclared = this exact missing fixup).
        AV="android14"; KV="6.1"; KSU_DIR="$KERNEL_REPO/KernelSU"
        LUM="$KERNEL_REPO/zeromount/luminaire"
        cd "$KERNEL_REPO"
        SUBLEVEL=$(grep -E "^SUBLEVEL =" Makefile | awk '{print $3}')
        echo "== kernel SUBLEVEL=$SUBLEVEL =="

        echo "== ReSukiSU main HEAD 930f61a (Luminaire pin) =="
        RS=$(curl -LSs --fail --retry 3 "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh") || { echo "FATAL setup dl"; exit 1; }
        echo "$RS" | bash -s -- 97163bdc8ad2ee59b523e9e34edeb4c286eceb04 || { echo "FATAL setup"; exit 1; }
        [ -d "$KSU_DIR" ] || { echo "FATAL: KernelSU dir missing"; exit 1; }
        # main Kbuild = 30000+count+700; force 35018 (97163bdc = main HEAD, 30000+4319+700=35019; matches 35019 manager exactly)
        sed -i '/^ccflags-y += -DKSU_VERSION=\$(KSU_VERSION)/i KSU_VERSION := 35019' "$KSU_DIR"/kernel/Kbuild
        grep -q "KSU_VERSION := 35019" "$KSU_DIR"/kernel/Kbuild && echo "KSU_VERSION -> 35019" || echo "WARN KSU_VERSION sed missed"
        # ReSukiSU main enforces abi_gki_protected_exports (static_export_check.mk) -> remove (Luminaire core/protected_exports.sh)
        rm -rf "$KERNEL_REPO"/android/abi_gki_protected_exports_* 2>/dev/null || true
        echo "protected exports removed"

        echo "== susfs (susfs4ksu gki-android14-6.1 tip = 2.2.0, proven clone like #10/#13) =="
        SUSFS_DIR="$KERNEL_REPO/susfs4ksu"; rm -rf "$SUSFS_DIR"
        git clone -q --depth=1 -b gki-android14-6.1 https://gitlab.com/simonpunk/susfs4ksu.git "$SUSFS_DIR" || { echo "FATAL susfs clone"; exit 1; }
        cp "$SUSFS_DIR"/kernel_patches/fs/susfs.c "$KERNEL_REPO"/fs/susfs.c
        cp "$SUSFS_DIR"/kernel_patches/include/linux/susfs.h "$KERNEL_REPO"/include/linux/susfs.h
        cp "$SUSFS_DIR"/kernel_patches/include/linux/susfs_def.h "$KERNEL_REPO"/include/linux/susfs_def.h

        echo "== apply 50_ with blk.h-dance (sublevel>=157) =="
        if [ "${SUBLEVEL:-0}" -ge 157 ]; then
            sed -i '/^#include <trace\/hooks\/blk\.h>$/d' "$KERNEL_REPO"/fs/namespace.c
        fi
        patch -p1 --fuzz=3 --forward -d "$KERNEL_REPO" < "$SUSFS_DIR"/kernel_patches/50_add_susfs_in_gki-android14-6.1.patch || echo "50_ some hunks failed (fix_namespace covers namespace.c)"
        if [ "${SUBLEVEL:-0}" -ge 157 ] && ! grep -qF '#include <trace/hooks/blk.h>' "$KERNEL_REPO"/fs/namespace.c; then
            sed -i '/^#include "internal\.h"$/a #include <trace\/hooks\/blk.h>' "$KERNEL_REPO"/fs/namespace.c
            grep -qF '#include <trace/hooks/blk.h>' "$KERNEL_REPO"/fs/namespace.c || { echo "FATAL: blk.h restore failed"; exit 1; }
        fi
        find "$KERNEL_REPO" -name "*.rej" -delete 2>/dev/null || true

        echo "== fix_namespace.py + kconfig (susfs decls) =="
        python3 "$LUM"/fix_namespace.py "$KERNEL_REPO"/fs/namespace.c || { echo "FATAL fix_namespace"; exit 1; }
        grep -q "^config KSU_SUSFS$" "$KSU_DIR"/kernel/Kconfig 2>/dev/null && echo "KSU_SUSFS declared by fork" || python3 "$LUM"/kconfig_inject.py "$KSU_DIR"/kernel/Kconfig

        echo "== defconfig (KSU + KPM + susfs inline, target=$TARGET) =="
        DC="$KERNEL_REPO/arch/arm64/configs/${TARGET}_defconfig"
        for c in CONFIG_KSU=y CONFIG_KPM=y CONFIG_COMPAT=y \
                 CONFIG_DEBUG_KERNEL=y CONFIG_KALLSYMS=y CONFIG_KALLSYMS_ALL=y \
                 CONFIG_KSU_SUSFS=y CONFIG_KSU_SUSFS_SUS_PATH=y CONFIG_KSU_SUSFS_SUS_MOUNT=y \
                 CONFIG_KSU_SUSFS_SUS_KSTAT=y CONFIG_KSU_SUSFS_SUS_OVERLAYFS=y CONFIG_KSU_SUSFS_TRY_UMOUNT=y \
                 CONFIG_KSU_SUSFS_SPOOF_UNAME=y CONFIG_KSU_SUSFS_ENABLE_LOG=y CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y \
                 CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y CONFIG_KSU_SUSFS_OPEN_REDIRECT=y \
                 CONFIG_KSU_SUSFS_SUS_MAP=y CONFIG_KSU_SUSFS_SUS_SU=y \
                 CONFIG_KSU_SUSFS_SUS_KSTAT_REDIRECT=y \
                 CONFIG_TMPFS_XATTR=y CONFIG_TMPFS_POSIX_ACL=y; do
            grep -q "^$c" "$DC" || echo "$c" >> "$DC"
        done
        grep -E "^CONFIG_KSU" "$DC" | head -20

        # ===== ZeroMount layer (Luminaire kernel/addons/zeromount recipe) =====
        # download upstream 60_ -> strip namei/readdir hunks (susfs-2.0.0-context) ->
        # apply rest -> re-inject namei/readdir hooks on VANILLA anchors (susfs-agnostic)
        # + fix_taskmmu scope. registry: zeromount REQUIRES susfs (have it). §4.6.
        echo "== ZeroMount layer (strip+apply+anchor-inject) =="
        ZMD="$KERNEL_REPO/zeromount/luminaire"
        ZMP="/tmp/60_zeromount-android14-6.1.patch"
        curl -fSL "https://raw.githubusercontent.com/Enginex0/Super-Builders/main/android14-6.1/ReSukiSU/patches/60_zeromount-android14-6.1.patch" -o "$ZMP" || { echo "FATAL: 60_ download"; exit 1; }
        python3 "$ZMD"/strip_readdir_hunk.py "$ZMP" || { echo "FATAL: strip_readdir"; exit 1; }
        python3 "$ZMD"/strip_namei_hunk.py   "$ZMP" || { echo "FATAL: strip_namei"; exit 1; }
        python3 "$ZMD"/strip_taskmmu_hunk.py "$ZMP" || { echo "FATAL: strip_taskmmu"; exit 1; }
        patch -p1 --fuzz=3 --forward -d "$KERNEL_REPO" < "$ZMP" || { echo "FATAL: 60_ apply"; exit 1; }
        rm -f "$ZMP"
        python3 "$ZMD"/inject_namei.py   "$KERNEL_REPO"/fs/namei.c        || { echo "FATAL: inject_namei"; exit 1; }
        python3 "$ZMD"/inject_taskmmu.py "$KERNEL_REPO"/fs/proc/task_mmu.c || { echo "FATAL: inject_taskmmu"; exit 1; }
        python3 "$ZMD"/inject_readdir.py "$KERNEL_REPO"/fs/readdir.c      || { echo "FATAL: inject_readdir"; exit 1; }
        # 60_ injects CONFIG_ZEROMOUNT into gki_defconfig; ensure it in OUR target defconfig too
        grep -q "^CONFIG_ZEROMOUNT=y" "$DC" || echo "CONFIG_ZEROMOUNT=y" >> "$DC"
        echo "ZeroMount layer applied ✅"

        echo "$TARGET $VARIANT done (LUMINAIRE + ZEROMOUNT #18)"
        ;;
esac

##Patch Defconfig##

DEFCONFIG="$KERNEL_REPO/arch/arm64/configs/${TARGET}_defconfig"

if [[ "$VARIANT" != "stock" ]]; then
#KSU
        if ! grep -q "^CONFIG_KSU=y$" "$DEFCONFIG"; then
                echo "CONFIG_KSU=y" >> "$DEFCONFIG"
        fi

#SUS_SU
        if [[ "$VARIANT" == *"-susfs" ]]; then
                if ! grep -q "^CONFIG_KSU_SUSFS_SUS_SU=n$" "$DEFCONFIG"; then
                        echo "CONFIG_KSU_SUSFS_SUS_SU=n" >> "$DEFCONFIG"
                fi
                if ! grep -q "^CONFIG_KSU_SUSFS=y$" "$DEFCONFIG"; then
                        echo "CONFIG_KSU_SUSFS=y" >> "$DEFCONFIG"
                fi
	fi
fi

#FOR ALL VARIANTS
if ! grep -q "^CONFIG_COMPAT=y$" "$DEFCONFIG"; then
        echo "CONFIG_COMPAT=y" >> "$DEFCONFIG"
fi


##fetch anykernel
cd "$KERNEL_REPO"
git clone --depth=1 https://github.com/Ante0/AnyKernel3 -b sultan-17-${TARGET} AnyKernel
