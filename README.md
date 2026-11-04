# LAZZITE OS

**FAST. CLEAN. YOURS.**

LAZZITE OS is a lightweight AMD64 Linux distribution based on Debian 13
(Trixie) with KDE Plasma. It uses Debian's kernel, package management, and
live-build infrastructure rather than maintaining custom system components.

## Current status

The initial build is a minimal Debian Live image with KDE Plasma. It is not
yet an installer or a release. Do not use it to install over an existing
system. In particular, Windows dual-boot behavior has not been implemented
or tested.

## Build

For a local build, use Debian 13 with `live-build`, `debootstrap`,
`debian-archive-keyring`, `ca-certificates`, `xorriso`, `squashfs-tools`,
`dosfstools`, `mtools`, `rsync`, `cpio`, and GRUB BIOS/EFI binaries installed.
From the project root, run:

```sh
sudo bash build/build-iso.sh
```

The script configures and builds from `build/`, checks that generated
configuration does not use Ubuntu archives, and copies the resulting image to
`dist/LAZZITE-13-amd64.iso`. GitHub Actions runs the same script on an
`ubuntu-24.04` runner and installs the build dependencies when manually
dispatched. Generated build output and ISO files are excluded from version
control.

An ISO is considered verified only after the build succeeds and the image has
been boot-tested; no such verification is claimed by this initial setup.

## Initial design decisions

- Use Debian 13 Trixie's official repositories and `live-build`.
- Target AMD64 and produce a hybrid ISO with GRUB for BIOS and UEFI boot.
- Use Debian's `kde-plasma-desktop` rather than a full desktop task, with only
  a small set of basic desktop applications.
- Include Debian firmware packages to improve out-of-box hardware support.
- Defer an installer until its behavior, especially Windows dual-boot
  handling, can be tested explicitly.
