#!/bin/bash
# Dumps Kconfig toggle states from the built kernel's .config into GITHUB_STEP_SUMMARY.
# Usage: report-config.sh <kernel_root> <android_ver> <kernel_ver>

KERNEL_ROOT="$1"
ANDROID_VER="$2"
KERNEL_VER="$3"

DOT_CONFIG=""
for candidate in \
  "$KERNEL_ROOT/.config" \
  "$KERNEL_ROOT/out/${ANDROID_VER}-${KERNEL_VER}/common/.config" \
  "$KERNEL_ROOT/out/${ANDROID_VER}-${KERNEL_VER}/.config" \
  "$KERNEL_ROOT/out/.config" \
  "$KERNEL_ROOT/bazel-bin/common/kernel_aarch64/.config" \
  "$KERNEL_ROOT/common/.config"; do
  [ -f "$candidate" ] && DOT_CONFIG="$candidate" && break
done

if [ -z "$DOT_CONFIG" ]; then
  DOT_CONFIG=$(find "$KERNEL_ROOT" -name ".config" -type f 2>/dev/null \
    | grep -v '/AnyKernel/' | head -1)
fi

if [ -z "$DOT_CONFIG" ]; then
  echo "::error title=Kasumi verify::No .config found — cannot verify CONFIG_KASUMI stickiness"
  echo "### Kasumi config-stick verify" >> "$GITHUB_STEP_SUMMARY"
  echo "" >> "$GITHUB_STEP_SUMMARY"
  echo ":x: FAIL: no .config file found under \`$KERNEL_ROOT\`" >> "$GITHUB_STEP_SUMMARY"
  exit 1
fi

{
  echo ""
  echo "### Kernel Config Toggles"
  echo ""
  echo "| Config | State |"
  echo "|--------|-------|"

  for symbol in \
    CONFIG_KSU \
    CONFIG_KSU_SUSFS \
    CONFIG_KSU_SUSFS_SUS_PATH \
    CONFIG_KSU_SUSFS_SUS_MOUNT \
    CONFIG_KSU_SUSFS_SUS_KSTAT \
    CONFIG_KSU_SUSFS_SUS_KSTAT_REDIRECT \
    CONFIG_KSU_SUSFS_SUS_MAP \
    CONFIG_KSU_SUSFS_SPOOF_UNAME \
    CONFIG_KSU_SUSFS_ENABLE_LOG \
    CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
    CONFIG_KSU_SUSFS_OPEN_REDIRECT \
    CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
    CONFIG_KSU_SUSFS_UNICODE_FILTER \
    CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT \
    CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT \
    CONFIG_KSU_SUSFS_UID_GATED_HIDING \
    CONFIG_KSU_SUSFS_HIDDEN_NAME \
    CONFIG_KSU_SUSFS_HARDENED \
    CONFIG_ZEROMOUNT \
    CONFIG_KASUMI \
    CONFIG_KPROBES \
    CONFIG_KALLSYMS_ALL \
    CONFIG_KPM; do

    val=$(grep "^${symbol}=" "$DOT_CONFIG" 2>/dev/null | head -1 | cut -d= -f2)
    not_set=$(grep "# ${symbol} is not set" "$DOT_CONFIG" 2>/dev/null)

    if [ -n "$val" ]; then
      echo "| \`${symbol}\` | \`${val}\` |"
    elif [ -n "$not_set" ]; then
      echo "| \`${symbol}\` | not set |"
    else
      echo "| \`${symbol}\` | — |"
    fi
  done

  echo ""
  echo "<details><summary>.config path</summary>"
  echo ""
  echo "\`${DOT_CONFIG}\`"
  echo "</details>"
} >> "$GITHUB_STEP_SUMMARY"

# ---------------------------------------------------------------------------
# Hard verify — CONFIG_KASUMI stickiness + kasumi_builtin.o presence.
#
# We were previously bitten by a "green build" that shipped ZERO kasumi
# objects because CONFIG_KASUMI silently dropped when its `depends on
# KPROBES && KALLSYMS_ALL` chain was unmet (KPROBES depends on MODULES,
# MODULES is forced off by INTEGRATE_MODULES=y on this tree; KALLSYMS_ALL
# depends on DEBUG_KERNEL which isn't in gs201_defconfig). Kconfig was now
# reworked to `select` those deps, but a future regression could easily
# reintroduce a silent drop.
#
# Two independent signals — both must pass:
#   (V1) CONFIG_KASUMI=y in the generated .config
#   (V2) kasumi_builtin.o present under the build output tree
#
# Print PASS/FAIL to step summary + emit ::error:: annotation + exit non-zero
# on failure so CI turns red at report time even if the earlier build step
# reported success. See /workspace/kasumi-configstick.md.
# ---------------------------------------------------------------------------

kasumi_config_pass=false
kasumi_object_pass=false

if grep -q '^CONFIG_KASUMI=y$' "$DOT_CONFIG" 2>/dev/null; then
  kasumi_config_pass=true
fi

# Search the build output tree(s) for the compiled builtin object.
KASUMI_OBJ_HITS=""
for search_root in \
  "$KERNEL_ROOT/out" \
  "$KERNEL_ROOT/bazel-bin" \
  "$KERNEL_ROOT"; do
  [ -d "$search_root" ] || continue
  hits=$(find "$search_root" -name 'kasumi_builtin.o' -type f 2>/dev/null | head -5)
  if [ -n "$hits" ]; then
    KASUMI_OBJ_HITS="$hits"
    kasumi_object_pass=true
    break
  fi
done

{
  echo ""
  echo "### Kasumi config-stick verify"
  echo ""
  if $kasumi_config_pass; then
    echo "- **V1 CONFIG_KASUMI=y in .config**: :white_check_mark: PASS"
  else
    echo "- **V1 CONFIG_KASUMI=y in .config**: :x: FAIL"
  fi
  if $kasumi_object_pass; then
    echo "- **V2 kasumi_builtin.o compiled**: :white_check_mark: PASS"
    echo ""
    echo '```'
    echo "$KASUMI_OBJ_HITS"
    echo '```'
  else
    echo "- **V2 kasumi_builtin.o compiled**: :x: FAIL (no object under $KERNEL_ROOT/{out,bazel-bin})"
  fi
} >> "$GITHUB_STEP_SUMMARY"

if ! $kasumi_config_pass; then
  echo "::error title=Kasumi config-stick::CONFIG_KASUMI=y did NOT stick in generated .config ($DOT_CONFIG). See kasumi/Kconfig select-chain."
fi
if ! $kasumi_object_pass; then
  echo "::error title=Kasumi build::kasumi_builtin.o was NOT produced by the build. Kbuild wired but nothing compiled — probable Kconfig-stick regression."
fi

if ! $kasumi_config_pass || ! $kasumi_object_pass; then
  exit 1
fi

echo "kasumi config-stick verify: OK"
