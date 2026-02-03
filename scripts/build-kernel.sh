#!/usr/bin/env bash
set -euo pipefail

SRC=""
CFG=""
OUT=""
JOBS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
    --src)
        SRC="$(realpath "$2")"
        shift 2
        ;;
    --config)
        CFG="$(realpath "$2")"
        shift 2
        ;;
    --out)
        OUT="$(realpath "$2")"
        shift 2
        ;;
    --jobs)
        JOBS="$2"
        shift 2
        ;;
    *)
        echo "unknown arg: $1" >&2
        exit 2
        ;;
    esac
done

mkdir -p "$OUT"
pushd "$SRC" >/dev/null

cp "$CFG" .config
make olddefconfig
make -j "${JOBS:-$(nproc)}" vmlinux
cp -v vmlinux "$OUT/x86_64-vmlinux"
cp -v System.map "$OUT/x86_64-System.map"
cp -v .config "$OUT/x86_64.config"

popd >/dev/null
