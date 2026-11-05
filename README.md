# LAZZITE OS

**FAST. CLEAN. YOURS.**

LAZZITE OS is a lightweight AMD64 Linux distribution based on Debian 13
(Trixie) with KDE Plasma. It uses Debian's kernel, package management, and
live-build infrastructure rather than maintaining custom system components.

## Current status

The current build configuration adds LAZZITE boot artwork, a default Plasma
wallpaper, a dark green-accented color scheme, and branded ISO metadata. These
changes have not yet been included in a built or boot-tested image. The last
confirmed ISO is a Debian Live system with KDE Plasma; Debian remains the
base system and package source.

This is an experimental preview, not an installer or a supported release. It
does not install LAZZITE to disk. Windows dual-boot behavior and installation
have not been implemented or tested. The wallpaper default is set through
the Plasma 6 Breeze Look-and-Feel defaults; users can still change their
desktop settings. A future upgrade to the Breeze Look-and-Feel package could
replace this bundled default override.

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
`dist/LAZZITE-13-amd64.iso`. GitHub Actions runs the same script in a Debian
Trixie container on an `ubuntu-24.04` hosted runner, on pushes to `main` or
when manually dispatched. Generated build output and ISO files are excluded
from version control.

An ISO is considered verified only after the build succeeds and the image has
been boot-tested. The first ISO build completed in GitHub Actions and was
reported by the project owner to boot from Ventoy on a physical laptop. The
image has not been validated across a hardware matrix, Secure Boot, or an
installer workflow.

## Initial design decisions

- Use Debian 13 Trixie's official repositories and `live-build`.
- Target AMD64 and produce a hybrid ISO with GRUB for BIOS and UEFI boot.
- Use LAZZITE artwork in the GRUB splash and provide a branded Plasma wallpaper.
- Use a short, standards-friendly LAZZITE ISO volume ID.
- Use Debian's `kde-plasma-desktop` rather than a full desktop task, with only
  a small set of basic desktop applications.
- Include Debian firmware packages to improve out-of-box hardware support.
- Defer an installer until its behavior, especially Windows dual-boot
  handling, can be tested explicitly.

## ISO parts and releases

The GitHub Actions build uploads the ISO together with a SHA-256 checksum.
After a successful build, first boot-test that exact ISO on real hardware.
Only then can an authorized maintainer manually dispatch **Prepare LAZZITE
Release** from `main`, provide the successful build run ID and a version tag,
and confirm the hardware test. The workflow validates the source run, verifies
the artifact checksum, splits the ISO, and creates a prerelease. It does not
run automatically and does not publish an untested build.

On Linux, split an ISO into numbered 1900 MiB parts with:

```sh
bash scripts/split-iso.sh dist/LAZZITE-13-amd64.iso
```

The script creates `.001`, `.002`, etc., a `.parts` manifest, and a standard
`.sha256` file. To restore and verify it:

```sh
bash scripts/restore-iso.sh LAZZITE-13-amd64.iso.parts
```

On Windows, keep all parts, the `.parts` manifest, and `.sha256` file in the
same directory. From PowerShell, run:

```powershell
.\scripts\restore-iso.ps1 -ManifestPath .\LAZZITE-13-amd64.iso.parts
```

Both restore scripts check that parts are present and sequential, validate
their sizes and the total size, verify SHA-256, and refuse to overwrite an
existing ISO. Do not boot or write an ISO to USB until restoration completes
successfully.
