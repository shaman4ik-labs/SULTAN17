<div align="center">

# SULTAN17

**A hardened KernelSU + SUSFS kernel for the Google Pixel 7 (`panther`, gs201).**

Android 14 · Linux 6.1 · ReSukiSU · SUSFS 2.2.0 · ZeroMount · flashed via AnyKernel3

</div>

---

### Overview

SULTAN17 is a custom kernel for the Google Pixel 7 (`panther` / gs201), built on the
**Sultan** kernel tree and combining kernel-assisted root
([ReSukiSU](https://github.com/ReSukiSU/ReSukiSU)) with the
[SUSFS](https://gitlab.com/simonpunk/susfs4ksu) concealment layer and the
[ZeroMount](https://github.com/Enginex0/zeromount) VFS metamodule. The ZeroMount ⨯
SUSFS 2.2.0 integration mirrors the
[Luminaire](https://github.com/chainonyourdoor/LuminaireProtocol) recipe.

### Features

- **ReSukiSU** — kernel-assisted root (KernelSU-family fork) with an inline SUSFS
  hook and a managed allowlist; manager version-aligned to the kernel driver.
- **SUSFS 2.2.0** — mount / path / `kstat` concealment, inline-hook mode.
- **ZeroMount** — VFS concealment metamodule integrated in-tree (built-in kernel
  part + a userspace `zm` control tool over `/dev/zeromount`): uid-gated path
  redirection and directory-entry injection, reconciled onto vanilla anchors so it
  rides SUSFS 2.2.0.
- **Stock-consistent identity** — `uname` / `/proc/version` report the stock release
  string while the source stays current.
- Prebuilt arm64 `busybox` bundled for reliable flashing.

### Branches

- **`main`** — daily build (ReSukiSU + SUSFS 2.2.0 + ZeroMount).
- **`sultan-17`** — clean upstream base (tracks `Ante0/SULTAN17`).
- **`experimental-kasumi`** / **`experimental-nomount`** — research integrations.

### Building

GitHub Actions (`workflow_dispatch`) runs `patch_sultan.sh <target> <variant>` then
`build_sultan.sh <target>`, which vendor ReSukiSU + SUSFS + ZeroMount, reconcile the
patches on version-agnostic anchors, and package an AnyKernel3 zip. Toolchain and
packaging are handled in-CI.

Variants: `stock` · `ksu` · `ksu-susfs` · `ksu-next` · `ksu-next-susfs` ·
`resukisu-zeromount` (daily).

> Build is validated for `gs201` (Pixel 7). Other Tensor targets are not currently
> guaranteed to link.

### Flashing

Flash the AnyKernel3 zip from your KernelSU / Magisk manager or recovery.
**Keep a copy of your stock `boot.img` for rollback.**

> Supported device: Google Pixel 7 (`panther`) only.

### Credits & Upstreams

This build stands entirely on the work of others — full credit to:

| Project | Author | Role |
|---|---|---|
| [Sultan kernel](https://github.com/kerneltoast) | SultanXDA (Sultan Alsawaf) | gs201 / Pixel 7 optimized base tree |
| [KernelSU](https://github.com/tiann/KernelSU) | tiann | original kernel-assisted root |
| [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) | ReSukiSU | the KSU fork used here (inline SUSFS hook) |
| [SUSFS](https://gitlab.com/simonpunk/susfs4ksu) | simonpunk | mount / path / `kstat` concealment |
| [ZeroMount](https://github.com/Enginex0/zeromount) | Enginex0 | VFS concealment metamodule + kernel patch |
| [LuminaireProtocol](https://github.com/chainonyourdoor/LuminaireProtocol) | chainonyourdoor | ZeroMount ⨯ SUSFS 2.2.0 build recipe, mirrored here |
| [AnyKernel3](https://github.com/osm0sis/AnyKernel3) | osm0sis | flashable-zip framework |

Patch reconciliation, integration, and packaging in this tree by the maintainer.

### License

Linux kernel sources remain under **GPL-2.0** (see `COPYING` / `LICENSES/`).
Vendored components retain their respective upstream licenses.
