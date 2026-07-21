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
        # ===== MINIMAL FIRST BUILD (Option A) — pure ReSukiSU v4.1.0 + susfs 2.2.0 =====
        # NOTHING of ours (no ZeroMount / stealth / gestures / uname spoof). Goal:
        # prove the AUTHORS' base compiles + boots + gives WORKING Inline hook + root
        # = Luminaire's base. Then re-add layer by layer: ZeroMount -> stealth ->
        # gestures -> uname. Hook = CONFIG_KSU_SUSFS ("SUSFS Inline Hook" in ReSukiSU
        # = Luminaire's "Hook type: Inline"), NOT the default tracepoint.
        AV="android14"; KV="6.1"; KSU_DIR="KernelSU"
        cd "$KERNEL_REPO"

        echo "== ReSukiSU setup (clones ReSukiSU repo -> KernelSU/; its OWN hook) =="
        curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash -s susfs-ksud
        if [ ! -d "$KSU_DIR" ]; then echo "FATAL: ReSukiSU setup failed"; exit 1; fi
        ( cd "$KSU_DIR" && git fetch --tags origin && git checkout 0d27e685cb9f1b873cd334371c0d8b6ea4c3aea9 )
        echo "ReSukiSU pinned to v4.1.0 (0d27e685) = Luminaire's version"
        # v4.1.0 detached-HEAD -> Kbuild version calc (git rev-list / GitHub API) yields
        # EMPTY -DKSU_VERSION= -> supercalls.c:91 "expected expression before ',' token".
        # Force real v4.1.0 version 34987 (= Luminaire). android-re §4.5.
        sed -i '/^ccflags-y += -DKSU_VERSION=\$(KSU_VERSION)/i KSU_VERSION := 34987' "$KSU_DIR"/kernel/Kbuild
        grep -q "KSU_VERSION := 34987" "$KSU_DIR"/kernel/Kbuild && echo "KSU_VERSION forced -> 34987" || echo "WARN: KSU_VERSION sed missed - check Kbuild path"

        echo "== susfs 2.2.0 (upstream simonpunk + Ante0 tree-fix recipe, reject-tolerant) =="
        git clone https://gitlab.com/simonpunk/susfs4ksu -b gki-android14-6.1 --depth=1
        cp "$KERNEL_REPO"/susfs4ksu/kernel_patches/fs/* "$KERNEL_REPO"/fs/
        cp "$KERNEL_REPO"/susfs4ksu/kernel_patches/include/linux/* "$KERNEL_REPO"/include/linux/
        patch -p1 -F3 --no-backup-if-mismatch < "$KERNEL_REPO"/susfs4ksu/kernel_patches/50_add_susfs_in_gki-android14-6.1.patch || echo "50_ hunks failed (expected)"
        ( cd "$KSU_DIR" && { patch -p1 -F3 --no-backup-if-mismatch < "$KERNEL_REPO"/susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch || echo "10_enable hunks failed (expected)"; } )
        patch -p1 < "$KERNEL_REPO"/kernel_patches/sultan/fixer.patch || true
        for p in fix_Kbuild fix_init.c fix_kernel_umount.c; do
            patch -p1 -F3 --no-backup-if-mismatch < "$KERNEL_REPO"/kernel_patches/next/susfs_fix_patches/v2.2.0/$p.patch || true
        done
        patch -p1 < "$KERNEL_REPO"/kernel_patches/common/unicode_bypass_fix_6.1+.patch || true

        echo "== defconfig: KSU + SUSFS Inline Hook, NO ZeroMount/stealth/uname =="
        DEFCONFIG="$KERNEL_REPO/arch/arm64/configs/${TARGET}_defconfig"
        add_cfg(){ grep -q "^$1=y" "$DEFCONFIG" || echo "$1=y" >> "$DEFCONFIG"; }
        add_cfg CONFIG_KSU
        add_cfg CONFIG_KSU_SUSFS
        add_cfg CONFIG_KSU_SUSFS_SUS_PATH
        add_cfg CONFIG_KSU_SUSFS_SUS_MOUNT
        add_cfg CONFIG_KSU_SUSFS_SUS_KSTAT
        add_cfg CONFIG_KSU_SUSFS_TRY_UMOUNT
        add_cfg CONFIG_KSU_SUSFS_SPOOF_UNAME
        add_cfg CONFIG_KSU_SUSFS_ENABLE_LOG
        add_cfg CONFIG_KSU_SUSFS_OPEN_REDIRECT
        add_cfg CONFIG_COMPAT
        echo "== defconfig KSU/susfs lines =="; grep -E "^CONFIG_KSU" "$DEFCONFIG" | head -20

        echo "$TARGET $VARIANT done (MINIMAL)"
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
