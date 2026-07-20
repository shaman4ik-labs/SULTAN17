/* SPDX-License-Identifier: Apache-2.0 OR GPL-2.0 */
/*
 * Kasumi - module metadata and the thin entrypoint that forwards into bootstrap.
 *
 * License: Author's work under Apache-2.0; when used as a kernel module
 * (or linked with the Linux kernel), GPL-2.0 applies for kernel compatibility.
 *
 * Author: Anatdx
 */
#include <linux/module.h>
#include <linux/init.h>
#include <linux/version.h>

#include "kasumi_bootstrap.h"

/*
 * obj-y in-tree port note:
 *   - Compiled as built-in (obj-y) on SULTAN17 (CONFIG_MODULES=n). module_init/
 *     module_exit machinery is unavailable; entry lives at late_initcall (slot
 *     7 — runs after mark_rodata_ro so the arm64 patch_memory fixmap-poke path
 *     is safe; see kasumi-recon §5.1). No exit hook — obj-y is not unloadable.
 *   - MODULE_LICENSE/AUTHOR/DESC/VERSION are no-ops when !MODULE; harmless.
 *   - MODULE_SOFTDEP dropped: no runtime module loader, KernelSU is in-tree.
 *   - MODULE_IMPORT_NS is honored for obj-y via __section("__ksymtab_strings")
 *     link-time marker; keep it (ZeroMount + susfs use the same namespace).
 */
MODULE_LICENSE("GPL");
MODULE_AUTHOR("Anatdx");
MODULE_DESCRIPTION("Kasumi kernel module");
#ifndef KASUMI_VERSION
#define KASUMI_VERSION "0.1.0-dev"
#endif
MODULE_VERSION(KASUMI_VERSION);
#ifdef MODULE_IMPORT_NS
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 13, 0)
MODULE_IMPORT_NS("VFS_internal_I_am_really_a_filesystem_and_am_NOT_a_driver");
#else
MODULE_IMPORT_NS(VFS_internal_I_am_really_a_filesystem_and_am_NOT_a_driver);
#endif
#endif

static int __init kasumi_lkm_init(void)
{
	return kasumi_bootstrap_init();
}

static void __maybe_unused kasumi_lkm_exit(void)
{
	kasumi_bootstrap_exit();
}

late_initcall(kasumi_lkm_init);
