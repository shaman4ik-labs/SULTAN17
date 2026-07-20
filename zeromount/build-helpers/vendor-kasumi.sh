#!/bin/bash
# vendor-kasumi.sh — obj-y wire-up for the Kasumi in-tree port.
#
# The Kasumi vendored source lives at `kasumi/` (kernel-root sibling of
# drivers/, fs/, security/, ...). It ships with an in-tree Kbuild + Kconfig
# authored in this branch — see kasumi/Kbuild and kasumi/Kconfig.
#
# This helper wires that subtree into the kernel build system by:
#   1. verifying kasumi/{Kbuild,Kconfig,src/} exists (fail-loud if not),
#   2. injecting `obj-$(CONFIG_KASUMI) += kasumi/` into root Kbuild after
#      the last obj-y core-subdir line (below the drivers/ entry),
#   3. injecting `source "kasumi/Kconfig"` into root Kconfig after the
#      `source "drivers/Kconfig"` anchor.
#
# Idempotent (grep-guarded). Fails LOUD on missing anchor.
#
# Usage: vendor-kasumi.sh <kernel_root>

set -euo pipefail

KROOT="${1:?usage: vendor-kasumi.sh <kernel_root>}"
cd "$KROOT"

# ---- Sanity: kasumi tree present -------------------------------------------
for f in kasumi/Kbuild kasumi/Kconfig kasumi/src/kasumi_main.c; do
  if [ ! -f "$f" ]; then
    echo "vendor-kasumi: FATAL: expected $KROOT/$f not found" >&2
    exit 1
  fi
done

# ---- 1. Root Kbuild injection ----------------------------------------------
# Anchor: `obj-y += drivers/` — a stable kernel-tree line that has stayed put
# across every 6.x release we build against. Insert `obj-$(CONFIG_KASUMI) +=
# kasumi/` immediately after it. Placing after drivers/ (not before init/) so
# any driver may be a consumer of exported symbols via kasumi's namespace
# import; alphabetical order with respect to sibling subsystems is not a
# constraint the top-level Kbuild enforces.
if grep -q '^obj-\$(CONFIG_KASUMI)[[:space:]]*+=[[:space:]]*kasumi/' Kbuild; then
  echo "vendor-kasumi: Kbuild obj line already present (idempotent)"
else
  if ! grep -q '^obj-y[[:space:]]*+=[[:space:]]*drivers/' Kbuild; then
    echo "vendor-kasumi: FATAL: 'obj-y += drivers/' anchor not found in Kbuild" >&2
    exit 1
  fi
  # Insert after the drivers/ line. Use awk for a portable, byte-safe splice.
  awk '
    { print }
    /^obj-y[[:space:]]*\+=[[:space:]]*drivers\// && !done {
      print "obj-$(CONFIG_KASUMI)\t+= kasumi/"
      done = 1
    }
  ' Kbuild > Kbuild.kasumi.tmp
  mv Kbuild.kasumi.tmp Kbuild
  echo "vendor-kasumi: Kbuild obj line injected"
fi

# ---- 2. Root Kconfig injection ---------------------------------------------
# Anchor: `source "drivers/Kconfig"` — analogously stable. Insert
# `source "kasumi/Kconfig"` immediately after it. Kasumi is a self-contained
# leaf; placement relative to security/ / fs/ Kconfigs is irrelevant.
if grep -q '^source "kasumi/Kconfig"' Kconfig; then
  echo "vendor-kasumi: Kconfig source line already present (idempotent)"
else
  if ! grep -q '^source "drivers/Kconfig"' Kconfig; then
    echo "vendor-kasumi: FATAL: 'source \"drivers/Kconfig\"' anchor not found in Kconfig" >&2
    exit 1
  fi
  awk '
    { print }
    /^source "drivers\/Kconfig"/ && !done {
      print "source \"kasumi/Kconfig\""
      done = 1
    }
  ' Kconfig > Kconfig.kasumi.tmp
  mv Kconfig.kasumi.tmp Kconfig
  echo "vendor-kasumi: Kconfig source line injected"
fi

echo "vendor-kasumi: OK"
