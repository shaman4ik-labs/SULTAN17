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
        # ---- ZeroMount + ReSukiSU (susfs v2.0.0 + ZeroMount VFS) ----
        # Mirrors Sultan_KernelSU_SUSFS/.github/workflows/sultan.yml (zeromount-panther)
        # step "Integrate ReSukiSU + apply susfs/zeromount patches" for feature
        # `resukisu-zeromount`, adapted for SULTAN17's fs/namespace.c include drift.
        AV="android14"
        KV="6.1"
        KSU_DIR="KernelSU"

        cd "$KERNEL_REPO"

        echo "== ReSukiSU setup (pinned) =="
        # setup.sh from ReSukiSU/main (branch susfs-ksud); pin AFTER integration.
        curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash -s susfs-ksud
        if [ ! -d "$KSU_DIR" ]; then
            echo "FATAL: ReSukiSU setup did not create $KSU_DIR"; exit 1
        fi
        PIN="$(cat "$ORCH/resukisu-pin.txt")"
        ( cd "$KSU_DIR" && git fetch origin && git checkout "$PIN" )
        echo "ReSukiSU pinned to $PIN"

        echo "== Preflight fixers (SULTAN17 tree adjustments BEFORE 50_) =="
        # SULTAN17 has an extra `#include <trace/hooks/blk.h>` after `internal.h`
        # in fs/namespace.c which breaks 50_ Hunk#1's anchor. Relocate it above
        # the "pnode.h"/"internal.h" group (semantically neutral) so 50_ applies.
        bash "$HELPERS/fix-sultan17-namespace-includes.sh" fs/namespace.c

        echo "== Apply 50_ (susfs base, in tree root) =="
        patch -p1 -F3 --no-backup-if-mismatch < "$PATCHES/50_add_susfs_in_gki-${AV}-${KV}.patch" || true
        # tensynos-style custom newuname (byte-identical in SULTAN17): 50_ Hunk#3
        # rejects on kernel/sys.c — resolve the SPOOF_UNAME insertion by hand.
        bash "$HELPERS/fix-tensynos-newuname.sh" kernel/sys.c
        rm -f kernel/sys.c.rej

        echo "== Apply 51_ (enhanced susfs) =="
        patch -p1 -F3 --no-backup-if-mismatch < "$PATCHES/51_enhanced_susfs-${AV}-${KV}.patch" || true

        echo "== Apply 70_ (ReSukiSU supercall safety, in KSU dir) + supercalls massage =="
        P70="$PATCHES/70_ksu_safety-resukisu-${KV}.patch"
        ( cd "$KSU_DIR" && { [ -s "$P70" ] && patch -p1 --no-backup-if-mismatch < "$P70" || echo "no 70_ patch needed"; } )
        # Post-setup supercalls massage: order matters — AFTER 70_ (see CHECKPOINT3).
        SUPER="drivers/kernelsu/supercalls.c"
        if [ -f "$SUPER" ]; then
            sed -i '/ksu_mark_running_process/d' "$SUPER"
            if grep -q "vzalloc" "$SUPER" && ! head -5 "$SUPER" | grep -q "vmalloc.h"; then
                sed -i '1a #include <linux/vmalloc.h>' "$SUPER"
            fi
        fi

        echo "== Apply 60_ (ZeroMount VFS, in tree root) =="
        patch -p1 -F3 --no-backup-if-mismatch < "$PATCHES/60_zeromount-${AV}-${KV}.patch" || true

        echo "== 61_ zeromount force-dir-child ioctl (ADD_DIR_CHILD) =="
        bash "$HELPERS/zeromount-force-dir-child.sh" .

        echo "== fix-susfs-compat (sublevel-dependent source fixes) =="
        SUBLEVEL="$(awk '/^SUBLEVEL =/{print $3}' Makefile)"
        echo "SUBLEVEL=$SUBLEVEL"
        bash "$HELPERS/fix-susfs-compat.sh" . "$SUBLEVEL" "$AV" "$KV" "" || true

        echo "== ksu_file sepolicy stealth (mode from ksu-sepolicy.conf) =="
        bash "$HELPERS/fix-ksu-sepolicy-stealth.sh" . "$ORCH/ksu-sepolicy.conf"

        echo "== ksu policyload seqno-split stealth (mode from ksu-policyload.conf) =="
        bash "$HELPERS/fix-ksu-policyload-seqno.sh" . "$ORCH/ksu-policyload.conf"

        echo "== Strict reject gate (CP3 criterion: zero .rej) =="
        if find . -name '*.rej' | grep -q .; then
            echo "FATAL: unresolved rejects present:"; find . -name '*.rej'
            exit 1
        fi
        echo "no .rej — clean"

        echo "== Assemble defconfig (base + susfs + overlayfs + ZeroMount) =="
        DEFCONFIG="$KERNEL_REPO/arch/arm64/configs/${TARGET}_defconfig"
        : > /tmp/frag.dst
        bash "$HELPERS/assemble-defconfig.sh" "$ORCH/defconfig.fragment" /tmp/frag.dst "$DEFCONFIG" --susfs --overlayfs
        # ZeroMount is NOT in the fragment (60_ only patched gki_defconfig).
        grep -q '^CONFIG_ZEROMOUNT=y' "$DEFCONFIG" || echo 'CONFIG_ZEROMOUNT=y' >> "$DEFCONFIG"
        # Preserve upstream SULTAN17 defconfig convention (COMPAT=y for KSU userspace).
        grep -q '^CONFIG_COMPAT=y' "$DEFCONFIG" || echo 'CONFIG_COMPAT=y' >> "$DEFCONFIG"

        # Skip the generic tail defconfig appends (CONFIG_KSU=y etc.): the fragment
        # already carries the correct KSU/SUSFS set. Also skip the AnyKernel clone
        # at the bottom of this file — done inline here to include the A17 sed.
        echo "== Clone AnyKernel3 + Android 17 supported.versions fixup =="
        rm -rf AnyKernel
        git clone --depth=1 https://github.com/Ante0/AnyKernel3 -b sultan-17-caimito AnyKernel
        # SULTAN17 targets Android 17; upstream AnyKernel3 ships supported.versions=16.
        sed -i 's/^supported\.versions=16$/supported.versions=16 17/' AnyKernel/anykernel.sh || true

        echo "$TARGET $VARIANT done"
        exit 0
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
git clone --depth=1 https://github.com/Ante0/AnyKernel3 -b sultan-17-caimito AnyKernel
