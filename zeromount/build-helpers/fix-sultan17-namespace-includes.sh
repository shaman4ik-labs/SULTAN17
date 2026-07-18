#!/bin/bash
# fix-sultan17-namespace-includes.sh — SULTAN17-only relocation of the extra
# `#include <trace/hooks/blk.h>` line in fs/namespace.c so 50_ Hunk#1 finds
# its anchor.
#
# The patch (50_add_susfs_in_gki-android14-6.1.patch, Hunk#1) expects:
#
#   #include <linux/mnt_idmapping.h>
#
#   #include "pnode.h"
#   #include "internal.h"
#
#   /* Maximum number of mounts... */
#
# SULTAN17 (fs/namespace.c) ships:
#
#   #include <linux/mnt_idmapping.h>
#
#   #include "pnode.h"
#   #include "internal.h"
#   #include <trace/hooks/blk.h>          <-- extra line, breaks the anchor
#
#   /* Maximum number of mounts... */
#
# Fix (Option 1, plan H approved): move the `trace/hooks/blk.h` include up so
# it sits alongside the other <linux/…>-style includes (right after
# <linux/mnt_idmapping.h>). Semantically equivalent — pure kernel headers at
# top of TU, no ordering side effects; keeps 50_'s anchor intact so the SUSFS
# SUS_MOUNT extern/atomic block lands cleanly between "internal.h" and the
# `/* Maximum number of mounts */` comment.
#
# Idempotent (grep-guard). Fails LOUD if the expected shape is absent.
#
# Usage: fix-sultan17-namespace-includes.sh <path/to/fs/namespace.c>
set -euo pipefail
F="${1:?usage: fix-sultan17-namespace-includes.sh <path/to/fs/namespace.c>}"
[ -f "$F" ] || { echo "fix-sultan17-namespace-includes: $F not found" >&2; exit 1; }

# Idempotence check: after this fix, `trace/hooks/blk.h` sits directly below
# `<linux/mnt_idmapping.h>` and does NOT sit directly below `"internal.h"`.
if awk '
  /^#include <linux\/mnt_idmapping\.h>$/ { getline nxt; if (nxt ~ /^#include <trace\/hooks\/blk\.h>$/) grouped=1 }
  /^#include "internal\.h"$/            { getline nxt; if (nxt ~ /^#include <trace\/hooks\/blk\.h>$/) stray=1 }
  END { exit !(grouped && !stray) }
' "$F"; then
  echo "fix-sultan17-namespace-includes: already relocated in $F — nothing to do"
  exit 0
fi

python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()

old = ('#include <linux/mnt_idmapping.h>\n'
       '\n'
       '#include "pnode.h"\n'
       '#include "internal.h"\n'
       '#include <trace/hooks/blk.h>\n'
       '\n')
new = ('#include <linux/mnt_idmapping.h>\n'
       '#include <trace/hooks/blk.h>\n'
       '\n'
       '#include "pnode.h"\n'
       '#include "internal.h"\n'
       '\n')

count = s.count(old)
assert count == 1, (
    "fix-sultan17-namespace-includes: expected SULTAN17 include shape not "
    "found/unique (matches=%d). Tree drifted; re-audit before touching." % count)
s = s.replace(old, new, 1)
open(p, 'w').write(s)
print("fix-sultan17-namespace-includes: relocated <trace/hooks/blk.h> above pnode.h/internal.h")
PY
