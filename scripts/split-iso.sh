#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: %s <iso-file> [output-directory] [part-size-mib]\n' "${0##*/}" >&2
    printf 'Default part size: 1900 MiB (maximum: 1900 MiB)\n' >&2
}

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
    usage
    exit 2
fi

ISO_INPUT="$1"
OUTPUT_DIR="${2:-$(dirname -- "$ISO_INPUT")}"
PART_SIZE_MIB="${3:-1900}"

if [[ ! "$PART_SIZE_MIB" =~ ^[0-9]+$ ]] || [ "$PART_SIZE_MIB" -lt 1 ] || [ "$PART_SIZE_MIB" -gt 1900 ]; then
    printf 'Error: part-size-mib must be an integer from 1 to 1900.\n' >&2
    exit 2
fi

if [ ! -f "$ISO_INPUT" ] || [ ! -r "$ISO_INPUT" ]; then
    printf 'Error: ISO file is missing or unreadable: %s\n' "$ISO_INPUT" >&2
    exit 1
fi

ISO_DIR="$(cd -- "$(dirname -- "$ISO_INPUT")" && pwd -P)"
ISO_PATH="$ISO_DIR/$(basename -- "$ISO_INPUT")"
ISO_NAME="$(basename -- "$ISO_INPUT")"

if [[ ! "$ISO_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\.iso$ ]]; then
    printf 'Error: ISO filename must use only letters, digits, dot, underscore, and hyphen and end in .iso.\n' >&2
    exit 2
fi

if ! command -v split >/dev/null 2>&1 || ! command -v sha256sum >/dev/null 2>&1; then
    printf 'Error: GNU split and sha256sum are required.\n' >&2
    exit 1
fi

mkdir -p -- "$OUTPUT_DIR"
OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd -P)"
PART_SIZE_BYTES=$((PART_SIZE_MIB * 1024 * 1024))
ISO_SIZE_BYTES="$(wc -c < "$ISO_PATH" | tr -d '[:space:]')"

if [[ ! "$ISO_SIZE_BYTES" =~ ^[0-9]+$ ]] || [ "$ISO_SIZE_BYTES" -le 0 ]; then
    printf 'Error: unable to determine a non-zero ISO size.\n' >&2
    exit 1
fi

PART_COUNT=$(((ISO_SIZE_BYTES + PART_SIZE_BYTES - 1) / PART_SIZE_BYTES))
if [ "$PART_COUNT" -gt 999 ]; then
    printf 'Error: ISO requires more than 999 parts; refusing ambiguous numbering.\n' >&2
    exit 1
fi

MANIFEST_PATH="$OUTPUT_DIR/$ISO_NAME.parts"
CHECKSUM_PATH="$OUTPUT_DIR/$ISO_NAME.sha256"
if [ -e "$MANIFEST_PATH" ] || [ -e "$CHECKSUM_PATH" ] || compgen -G "$OUTPUT_DIR/$ISO_NAME.[0-9][0-9][0-9]" >/dev/null; then
    printf 'Error: refusing to overwrite existing ISO parts or metadata for %s.\n' "$ISO_NAME" >&2
    exit 1
fi

ISO_SHA256="$(sha256sum -- "$ISO_PATH" | awk '{ print $1 }')"
STAGING_DIR="$(mktemp -d "$OUTPUT_DIR/.${ISO_NAME}.split.XXXXXX")"
cleanup() {
    if [ -n "${STAGING_DIR:-}" ] && [ -d "$STAGING_DIR" ]; then
        rm -rf -- "$STAGING_DIR"
    fi
}
trap cleanup EXIT

split --bytes="$PART_SIZE_BYTES" --numeric-suffixes=1 --suffix-length=3 -- "$ISO_PATH" "$STAGING_DIR/$ISO_NAME."

for ((index = 1; index <= PART_COUNT; index++)); do
    suffix="$(printf '%03d' "$index")"
    part="$STAGING_DIR/$ISO_NAME.$suffix"
    if [ ! -s "$part" ]; then
        printf 'Error: expected split part was not created: %s\n' "$part" >&2
        exit 1
    fi
    part_size="$(wc -c < "$part" | tr -d '[:space:]')"
    if [ "$part_size" -gt "$PART_SIZE_BYTES" ]; then
        printf 'Error: split part exceeds the configured size: %s\n' "$part" >&2
        exit 1
    fi
    if [ "$index" -lt "$PART_COUNT" ] && [ "$part_size" -ne "$PART_SIZE_BYTES" ]; then
        printf 'Error: non-final split part has an unexpected size: %s\n' "$part" >&2
        exit 1
    fi
done

printf 'format=LAZZITE-SPLIT-1\nfilename=%s\nsize_bytes=%s\npart_size_bytes=%s\npart_count=%s\nsha256=%s\n' \
    "$ISO_NAME" "$ISO_SIZE_BYTES" "$PART_SIZE_BYTES" "$PART_COUNT" "$ISO_SHA256" > "$STAGING_DIR/$ISO_NAME.parts"
printf '%s  %s\n' "$ISO_SHA256" "$ISO_NAME" > "$STAGING_DIR/$ISO_NAME.sha256"

for ((index = 1; index <= PART_COUNT; index++)); do
    suffix="$(printf '%03d' "$index")"
    mv -- "$STAGING_DIR/$ISO_NAME.$suffix" "$OUTPUT_DIR/$ISO_NAME.$suffix"
done
mv -- "$STAGING_DIR/$ISO_NAME.sha256" "$CHECKSUM_PATH"
mv -- "$STAGING_DIR/$ISO_NAME.parts" "$MANIFEST_PATH"

if [ "$(wc -c < "$ISO_PATH" | tr -d '[:space:]')" -ne "$ISO_SIZE_BYTES" ] || \
    [ "$(sha256sum -- "$ISO_PATH" | awk '{ print $1 }')" != "$ISO_SHA256" ]; then
    printf 'Error: source ISO changed while splitting.\n' >&2
    exit 1
fi

printf 'Created %s parts for %s (%s bytes, SHA-256 %s).\n' "$PART_COUNT" "$ISO_NAME" "$ISO_SIZE_BYTES" "$ISO_SHA256"
