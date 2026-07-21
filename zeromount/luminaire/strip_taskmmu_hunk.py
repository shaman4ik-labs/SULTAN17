#!/usr/bin/env python3
# strip fs/proc/task_mmu.c hunks from ZeroMount 60_ patch — its context
# (bypass_orig_flow / dev/ino) mislands under --fuzz on a susfs-2.2.0 tree;
# inject_taskmmu.py re-adds the hook on stable susfs anchors instead.
import sys
def strip(path):
    lines = open(path, errors="replace").readlines()
    out=[]; skip=False
    for i,line in enumerate(lines):
        if line.startswith("--- a/fs/proc/task_mmu.c"): skip=True
        if skip and i>0 and line.startswith("--- a/") and "task_mmu.c" not in line: skip=False
        if not skip: out.append(line)
    if len(out)==len(lines):
        print("[warn] strip_taskmmu: section not found; proceeding"); sys.exit(0)
    open(path,"w").writelines(out)
    print(f"[info] strip_taskmmu: stripped {len(lines)-len(out)} lines ✅"); sys.exit(0)
strip(sys.argv[1])
