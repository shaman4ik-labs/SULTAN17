<div align="center">

# SULTAN17

**A hardened KernelSU + SUSFS kernel for the Pixel 7 (`panther`, gs201).**

Android 14 · Linux 6.1 · flashed via AnyKernel3

</div>

---

### Overview

SULTAN17 is a custom kernel for the Google Pixel 7, built around kernel-assisted root ([ReSukiSU](https://github.com/tiann/KernelSU) / KernelSU) and mount/path concealment ([SUSFS](https://gitlab.com/simonpunk/susfs4ksu)), with additional in-tree privacy features. Base: the Sultan kernel tree for gs201.

### Features

- **ReSukiSU / KernelSU** — kernel-assisted root with a managed allowlist.
- **SUSFS** — mount / path / `kstat` concealment layer.
- **ZeroMount** — a VFS concealment metamodule integrated into this tree: uid-gated path redirection and directory-entry injection, driven by the `zm` control tool over `/dev/zeromount`. Hides root and module artifacts from unprivileged apps while leaving privileged/loader paths untouched.
- **Native SELinux stealth** (`CONFIG_NATIVE_SELINUX_STEALTH`) — a standalone, self-contained kernel patch (no external module) that blinds SELinux policy-drift probing: injected framework types are made invisible to an unprivileged carrier's `selinuxfs` oracle, so policy-drift detection reads clean. Enforcing mode is fully preserved.
- **Stock-consistent identity** — `uname` and `/proc/version` report the stock release string (via a `UTS_RELEASE` override) while the source stays current.
- Prebuilt arm64 `busybox` bundled for reliable flashing across recovery/manager environments.

### Branches

- **`resukisu-zeromount`** — main daily build (ReSukiSU + ZeroMount).
- **`selinux-stealth`** — adds the native SELinux stealth patch.
- **`experimental-nomount`** — research integration of the NoMount VFS framework.

### Building

GitHub Actions `build.yml` (`workflow_dispatch`) compiles the kernel and packages an AnyKernel3 zip; toolchain and packaging are handled in-CI.

### Flashing

Flash the AnyKernel3 zip from your KernelSU/Magisk manager or recovery. **Keep a copy of your stock `boot.img`** for recovery.

> Supported device: Pixel 7 (`panther`) only.

### Credits

Sultan kernel (SultanXDA) · [KernelSU](https://github.com/tiann/KernelSU) / ReSukiSU · [SUSFS](https://gitlab.com/simonpunk/susfs4ksu). ZeroMount and the native SELinux stealth patch are developed in this tree.
