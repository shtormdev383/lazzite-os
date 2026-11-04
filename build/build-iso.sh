#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
OUTPUT_ISO="$DIST_DIR/LAZZITE-13-amd64.iso"

if ! command -v lb >/dev/null 2>&1; then
    printf '%s\n' "Error: live-build (lb) is required." >&2
    exit 1
fi

if [ -e "$OUTPUT_ISO" ]; then
    printf 'Error: refusing to overwrite existing ISO: %s\n' "$OUTPUT_ISO" >&2
    exit 1
fi

cd "$BUILD_DIR"

lb config \
    --mode debian \
    --distribution trixie \
    --architectures amd64 \
    --archive-areas "main contrib non-free non-free-firmware" \
    --mirror-bootstrap https://deb.debian.org/debian \
    --mirror-chroot https://deb.debian.org/debian \
    --mirror-binary https://deb.debian.org/debian \
    --initsystem systemd \
    --security false \
    --binary-images iso-hybrid \
    --bootloader grub2

verify_config_contains() {
    local expected="$1"

    if grep -R -F -q -- "$expected" config; then
        return 0
    else
        grep_status=$?
    fi

    if [ "$grep_status" -eq 1 ]; then
        printf 'Error: generated live-build configuration is missing "%s".\n' "$expected" >&2
        exit 1
    fi

    printf 'Error: unable to inspect generated live-build configuration (grep exited %s).\n' "$grep_status" >&2
    exit "$grep_status"
}

verify_config_contains 'trixie'
verify_config_contains 'https://deb.debian.org/debian'
verify_config_contains 'https://security.debian.org/debian-security trixie-security main'

verify_config_does_not_contain() {
    local unexpected="$1"

    if grep -R -F -n -- "$unexpected" config; then
        printf 'Error: generated live-build configuration contains unexpected entry "%s".\n' "$unexpected" >&2
        exit 1
    else
        grep_status=$?
    fi

    if [ "$grep_status" -ne 1 ]; then
        printf 'Error: unable to inspect generated live-build configuration (grep exited %s).\n' "$grep_status" >&2
        exit "$grep_status"
    fi
}

verify_config_does_not_contain 'archive.ubuntu.com'
verify_config_does_not_contain 'trixie/updates'

lb build

ISO="$BUILD_DIR/live-image-amd64.hybrid.iso"
if [ ! -s "$ISO" ]; then
    printf 'Error: expected ISO was not generated at %s.\n' "$ISO" >&2
    exit 1
fi

mkdir -p "$DIST_DIR"
mv -- "$ISO" "$OUTPUT_ISO"
printf 'Created %s\n' "$OUTPUT_ISO"
