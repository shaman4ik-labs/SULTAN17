#!/usr/bin/env python3
# inject ZeroMount hook into fs/proc/task_mmu.c on VANILLA-stable susfs anchors
# (added by susfs 50_): include before susfs_def; call right after the susfs
# SUS_KSTAT spoof in show_map_vma (matches Luminaire's intended order).
import sys
MARK="zeromount_spoof_mmap_metadata"
INC_ANCHOR="#include <linux/pkeys.h>"
INC_INJECT=INC_ANCHOR+"\n#ifdef CONFIG_ZEROMOUNT\n#include <linux/zeromount.h>\n#endif"
CALL_ANCHOR="susfs_sus_kstat_spoof_show_map_vma(inode, &dev, &ino);"
CALL_INJECT=CALL_ANCHOR+"\n#ifdef CONFIG_ZEROMOUNT\n\t\tzeromount_spoof_mmap_metadata(inode, &dev, &ino);\n#endif"
def main():
    p=sys.argv[1]; c=open(p).read()
    if MARK in c: print("task_mmu.c already injected, skip"); return
    if INC_ANCHOR not in c: print("ERROR: pkeys include anchor missing in task_mmu.c",file=sys.stderr); sys.exit(1)
    if CALL_ANCHOR not in c: print("ERROR: susfs SUS_KSTAT call anchor missing in task_mmu.c",file=sys.stderr); sys.exit(1)
    c=c.replace(INC_ANCHOR,INC_INJECT,1).replace(CALL_ANCHOR,CALL_INJECT,1)
    open(p,"w").write(c); print("task_mmu.c: zeromount include+call injected ✅")
main()
