#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'Usage: %s <iso-file.parts> [output-iso-path]\n' "${0##*/}" >&2
    exit 2
fi

MANIFEST_INPUT="$1"
if [ ! -f "$MANIFEST_INPUT" ] || [ ! -r "$MANIFEST_INPUT" ]; then
    printf 'Error: manifest is missing or unreadable: %s\n' "$MANIFEST_INPUT" >&2
    exit 1
fi

MANIFEST_DIR="$(cd -- "$(dirname -- "$MANIFEST_INPUT")" && pwd -P)"
MANIFEST_NAME="$(basename -- "$MANIFEST_INPUT")"
MANIFEST_PATH="$MANIFEST_DIR/$MANIFEST_NAME"

declare -A manifest=()
while IFS='=' read -r key value; do
    case "$key" in
        format|filename|size_bytes|part_size_bytes|part_count|sha256) ;;
        *) printf 'Error: unexpected manifest entry: %s\n' "$key" >&2; exit 1 ;;
    esac
    if [ -n "${manifest[$key]+present}" ]; then
        printf 'Error: duplicate manifest entry: %s\n' "$key" >&2
        exit 1
    fi
    manifest["$key"]="$value"
done < "$MANIFEST_PATH"

for key in format filename size_bytes part_size_bytes part_count sha256; do
    if [ -z "${manifest[$key]:-}" ]; then
        printf 'Error: manifest is missing %s.\n' "$key" >&2
        exit 1
    fi
done

if [ "${manifest[format]}" != "LAZZITE-SPLIT-1" ] || \
    [[ ! "${manifest[filename]}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\.iso$ ]] || \
    [[ ! "${manifest[size_bytes]}" =~ ^[1-9][0-9]*$ ]] || \
    [[ ! "${manifest[part_size_bytes]}" =~ ^[1-9][0-9]*$ ]] || \
    [[ ! "${manifest[part_count]}" =~ ^[1-9][0-9]*$ ]] || \
    [[ ! "${manifest[sha256]}" =~ ^[A-Fa-f0-9]{64}$ ]]; then
    printf 'Error: manifest contains invalid or unsupported values.\n' >&2
    exit 1
fi

ISO_NAME="${manifest[filename]}"
ISO_SIZE_BYTES="${manifest[size_bytes]}"
PART_SIZE_BYTES="${manifest[part_size_bytes]}"
PART_COUNT="${manifest[part_count]}"
ISO_SHA256="${manifest[sha256],,}"
MAX_PART_SIZE_BYTES=$((1900 * 1024 * 1024))
MAX_ISO_SIZE_BYTES=$((999 * MAX_PART_SIZE_BYTES))

if [ "$ISO_SIZE_BYTES" -gt "$MAX_ISO_SIZE_BYTES" ] || [ "$PART_SIZE_BYTES" -gt "$MAX_PART_SIZE_BYTES" ] || [ "$PART_COUNT" -gt 999 ]; then
    printf 'Error: manifest size or part count is outside supported bounds.\n' >&2
    exit 1
fi

EXPECTED_PART_COUNT=$(((ISO_SIZE_BYTES + PART_SIZE_BYTES - 1) / PART_SIZE_BYTES))
if [ "$EXPECTED_PART_COUNT" -ne "$PART_COUNT" ]; then
    printf 'Error: manifest part count does not match the declared total and part sizes.\n' >&2
    exit 1
fi

CHECKSUM_PATH="$MANIFEST_DIR/$ISO_NAME.sha256"
if [ ! -f "$CHECKSUM_PATH" ] || ! grep -F -x -q -- "$ISO_SHA256  $ISO_NAME" "$CHECKSUM_PATH"; then
    printf 'Error: checksum file is missing or does not match the manifest: %s\n' "$CHECKSUM_PATH" >&2
    exit 1
fi

shopt -s nullglob
available_parts=("$MANIFEST_DIR/$ISO_NAME".???)
if [ "${#available_parts[@]}" -ne "$PART_COUNT" ]; then
    printf 'Error: expected %s numbered parts but found %s.\n' "$PART_COUNT" "${#available_parts[@]}" >&2
    exit 1
fi

PARTS=()
total_size=0
for ((index = 1; index <= PART_COUNT; index++)); do
    suffix="$(printf '%03d' "$index")"
    part="$MANIFEST_DIR/$ISO_NAME.$suffix"
    if [ ! -f "$part" ] || [ ! -r "$part" ]; then
        printf 'Error: missing part %s; expected sequence .001 through .%03d.\n' "$part" "$PART_COUNT" >&2
        exit 1
    fi
    part_size="$(wc -c < "$part" | tr -d '[:space:]')"
    if [ "$part_size" -le 0 ] || [ "$part_size" -gt "$PART_SIZE_BYTES" ]; then
        printf 'Error: part has an invalid size: %s\n' "$part" >&2
        exit 1
    fi
    if [ "$index" -lt "$PART_COUNT" ] && [ "$part_size" -ne "$PART_SIZE_BYTES" ]; then
        printf 'Error: non-final part has an invalid size: %s\n' "$part" >&2
        exit 1
    fi
    total_size=$((total_size + part_size))
    PARTS+=("$part")
done

if [ "$total_size" -ne "$ISO_SIZE_BYTES" ]; then
    printf 'Error: part sizes total %s bytes, expected %s bytes.\n' "$total_size" "$ISO_SIZE_BYTES" >&2
    exit 1
fi

OUTPUT_PATH="${2:-$MANIFEST_DIR/$ISO_NAME}"
OUTPUT_DIR="$(dirname -- "$OUTPUT_PATH")"
OUTPUT_NAME="$(basename -- "$OUTPUT_PATH")"
mkdir -p -- "$OUTPUT_DIR"
OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd -P)"
OUTPUT_PATH="$OUTPUT_DIR/$OUTPUT_NAME"
if [ -e "$OUTPUT_PATH" ]; then
    printf 'Error: refusing to overwrite existing output: %s\n' "$OUTPUT_PATH" >&2
    exit 1
fi

TEMP_ISO="$(mktemp "$OUTPUT_DIR/.${OUTPUT_NAME}.restore.XXXXXX")"
cleanup() {
    if [ -n "${TEMP_ISO:-}" ] && [ -f "$TEMP_ISO" ]; then
        rm -f -- "$TEMP_ISO"
    fi
}
trap cleanup EXIT

cat -- "${PARTS[@]}" > "$TEMP_ISO"
restored_size="$(wc -c < "$TEMP_ISO" | tr -d '[:space:]')"
restored_sha256="$(sha256sum -- "$TEMP_ISO" | awk '{ print $1 }')"
if [ "$restored_size" -ne "$ISO_SIZE_BYTES" ]; then
    printf 'Error: restored ISO size is %s bytes, expected %s bytes.\n' "$restored_size" "$ISO_SIZE_BYTES" >&2
    exit 1
fi
if [ "$restored_sha256" != "$ISO_SHA256" ]; then
    printf 'Error: restored ISO SHA-256 does not match the manifest.\n' >&2
    exit 1
fi

mv -- "$TEMP_ISO" "$OUTPUT_PATH"
TEMP_ISO=""
printf 'Restored %s (%s bytes, SHA-256 %s).\n' "$OUTPUT_PATH" "$restored_size" "$restored_sha256"
